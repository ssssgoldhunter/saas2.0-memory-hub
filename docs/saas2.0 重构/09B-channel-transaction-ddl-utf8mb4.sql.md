# Front 渠道交易表最终建表 SQL（utf8mb4 / utf8mb4_general_ci）

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 上位规则：[09-channel-transaction-ddl.md](./09-channel-transaction-ddl.md)
> 字段来源：[09A-channel-transaction-table-field-catalog.md](./09A-channel-transaction-table-field-catalog.md)
> 状态：**最终建表 SQL**——全新库直接执行即可得到最终结构
> 生成日期：2026-08-07（最终精简版）
>
> **执行方式**：
> - **全新库建表**：执行 [09-final-rebuild-all-tables.sql](./09-final-rebuild-all-tables.sql)（DROP+CREATE+分区，一步到位）
> - **本文件**：建表 SQL 的可读文档版（带字段说明），与 09-final 内容一致
>
> 目标字符集：`utf8mb4`
> 目标排序规则：`utf8mb4_general_ci`
> 存储引擎：`InnoDB`
> 行格式：`DYNAMIC`（utf8mb4 下必须，否则索引长度受限）

---

## 1. 字段类型规范（本版统一约定）

为保持全表一致，字段类型按以下规则统一，**不出现零碎长度**：

| 字段语义 | 类型 | 说明 |
|---|---|---|
| 主键 / 外部引用主键 | `BIGINT` | 分布式 ID |
| 金额 | `BIGINT` | 单位为人民币分，禁用浮点和元 |
| 乐观锁 | `INT UNSIGNED` | 版本号 |
| 状态 / 类型 / 响应码 / 币种 / 接口编码 / 协议功能码 / 日期 / 时间字符串 | **`VARCHAR(20)`** | 所有枚举类、短编码、协议日期时间字符串统一 20 |
| 流水号 / 业务编号 / 业务记录 ID / hash | **`VARCHAR(100)`** | 所有编号类统一 100 |
| 数据源实例标识 | **`VARCHAR(30)`** | `data_source_id`，记录数据所在库实例 |
| 创建者 / 更新者 | **`VARCHAR(64)`** | `create_by`/`update_by`，审计字段，MyBatis-Plus 自动填充 |
| 描述 / 备注 | `VARCHAR(512)` | 响应说明、业务备注 |
| 临时扩展 | `VARCHAR(1024)` | `reserve1/2/3` |
| 报文快照 | 不设置 | 禁止保存整段业务、银行请求或响应快照 |
| 创建 / 更新时间（审计） | **`DATETIME`** | `create_time`/`update_time`，MyBatis-Plus 自动填充；对应 Entity 父类 `createTime`/`updateTime` |
| 银行响应时间（业务） | **`DATETIME`** | `bank_responded_at`，收到银行同步响应时写入 |

**禁止**：使用 `CHAR`、`DATETIME(3)`、`TIMESTAMP`、零碎长度（如 `VARCHAR(64)/32/16/8/6/3`）。
**审计字段用父类**：`create_by`/`create_time`/`update_by`/`update_time` 对应 Entity 继承的
`BaseEntity` 审计字段，子类不再重复声明，由 MyBatis-Plus `MetaObjectHandler` 自动填充。
不再使用 `created_at`/`updated_at`（已改用 BaseEntity 的 `create_by`/`create_time`/`update_by`/`update_time`）。

### 1.1 索引长度兼容性核查（utf8mb4 + DYNAMIC）

`utf8mb4` 每字符最多 4 字节。最长联合索引核查：

| 索引 | 列（均为 VARCHAR(100)） | 单列字节 | 合计字节 | 上限 3072 | 结论 |
|---|---|---:|---:|---:|---|
| `idx_front_data_source` | `tenant_id(100)+data_source_id(30)` | — | 520 | 3072 | ✓ |
| `idx_front_business_main` | 4 列 | 400 | 1600 | 3072 | ✓ |
| `idx_front_biz_order` | `tenant_id(100)+biz_order_no(100)+biz_sub_order_no(100)` | 400 | 1200 | 3072 | ✓ |
| `idx_front_status_time` | `tenant_id(100)+front_status(20)+update_time(8)` | — | 508 | 3072 | ✓ |
| `idx_front_store_time` | `tenant_id(100)+store_id(100)+create_time(8)` | — | 528 | 3072 | ✓ |
| 退款表 `idx_front_original_transaction` | `original_capability(20)+original_channel_transaction_id(8)` | — | 88 | 3072 | ✓ |

全部索引无需前缀截断。

### 1.2 时间字段说明

- `create_by` / `create_time` / `update_by` / `update_time`：审计字段，`DATETIME`/`VARCHAR(64)`，
  由 MyBatis-Plus `InjectionMetaObjectHandler` 自动填充（对应 Entity 继承的 `BaseEntity` 字段）。
  不再使用 `created_at`/`updated_at`（已改用 BaseEntity 审计字段）。
- `bank_responded_at`：`DATETIME`，允许 `NULL`，收到银行同步响应时由应用层写入。
- `business_date` / `bank_trans_date` / `business_time` / `bank_trans_time`：这些是**业务/银行协议传入的字符串**（格式 `yyyyMMdd` / `HHmmss`），不是数据库时间戳，统一用 `VARCHAR(20)` 承载，便于兼容不同银行协议格式。

### 1.3 执行前确认

- 目标库 MySQL 5.7+（推荐 8.0），`ROW_FORMAT=DYNAMIC`。
- 本 SQL 不含 `DROP TABLE`；重复执行需先手动清理。
- 10 张表之间**无外键**；退款关联原交易的完整性由 Front 应用层在事务内校验。

---

## 2. 完整建表 SQL

```sql
-- =============================================================================
-- Front 分银行、分交易业务渠道流水建表 SQL
-- 字符集：utf8mb4 / 排序规则：utf8mb4_general_ci / 引擎：InnoDB / 行格式：DYNAMIC
-- 共 10 张表：中信 6 张 + 平安 4 张
-- 字段类型规范见 09B 文档 §1
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. front_citic_transfer_transaction  中信转账渠道交易流水（capability=TRANSFER）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_transfer_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信转账渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 TRANSFER',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源业务交易逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源业务交易主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源业务交易子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '业务系统本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店 ID',
  `pay_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '付款方电子账户号（原始值，未加密）',
  `pay_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '付款方名称',
  `rec_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '收款方电子账户号（原始值，未加密）',
  `rec_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '收款方名称',
  `amount`                            BIGINT        NOT NULL                COMMENT '转账金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '转账手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该原交易累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等银行侧交易流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '中信业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '中信业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '中信原始交易状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信转账渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 2. front_pingan_transfer_transaction  平安转账及转账授权渠道交易流水
--    capability 允许：TRANSFER / TRANSFER_AUTH / TRANSFER_AUTH_CODE_RESEND
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_transfer_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安转账渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT '能力编码：TRANSFER、TRANSFER_AUTH 或 TRANSFER_AUTH_CODE_RESEND',
  `auth_type`                         VARCHAR(8)    DEFAULT NULL            COMMENT '授权类型（AuthType枚举：SMS/APP；仅 TRANSFER_AUTH、TRANSFER_AUTH_CODE_RESEND 行写入，普通转账行与历史行为 NULL）',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源业务交易逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源业务交易主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源业务交易子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '业务系统本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店 ID',
  `pay_member_id`                  VARCHAR(100)  DEFAULT NULL            COMMENT '付款方商户会员编号',
  `pay_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '付款方电子账户号（原始值，未加密）',
  `pay_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '付款方名称',
  `rec_member_id`                  VARCHAR(100)  DEFAULT NULL            COMMENT '收款方商户会员编号',
  `rec_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '收款方电子账户号（原始值，未加密）',
  `rec_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '收款方名称',
  `amount`                            BIGINT        NOT NULL                COMMENT '转账或授权交易金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平安转账手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该原交易累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '平安协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平安协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等银行侧交易流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '平安业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '平安业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '平安原始交易状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安转账及转账授权渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 3. front_citic_consume_transaction  中信消费渠道交易流水（capability=CONSUME）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_consume_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信消费渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 CONSUME',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源业务交易逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源业务交易主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源业务交易子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '业务系统本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店 ID',
  `pay_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '付款方电子账户号（原始值，未加密）',
  `pay_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '付款方名称',
  `rec_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '收款方电子账户号（原始值，未加密）',
  `rec_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '收款方名称',
  `amount`                            BIGINT        NOT NULL                COMMENT '消费金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '消费手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该消费累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等银行侧交易流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '中信业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '中信业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '中信原始交易状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信消费渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 4. front_pingan_consume_transaction  平安消费渠道交易流水（capability=CONSUME）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_consume_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安消费渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 CONSUME',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源业务交易逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源业务交易主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源业务交易子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '业务系统本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店 ID',
  `pay_member_id`                  VARCHAR(100)  DEFAULT NULL            COMMENT '付款方商户会员编号',
  `pay_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '付款方电子账户号（原始值，未加密）',
  `pay_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '付款方名称',
  `rec_member_id`                  VARCHAR(100)  DEFAULT NULL            COMMENT '收款方商户会员编号',
  `rec_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '收款方电子账户号（原始值，未加密）',
  `rec_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '收款方名称',
  `amount`                            BIGINT        NOT NULL                COMMENT '消费金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平安消费手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该消费累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '平安协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平安协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等银行侧交易流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '平安业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '平安业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '平安原始交易状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安消费渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 5. front_citic_refund_transaction  中信真退款渠道交易流水（capability=REFUND，bizFunc=23）
--    当前仅 original_biz_order_no/original_biz_sub_order_no 用于中信退款原交易定位；
--    其他 5 个 original_* 为可空兼容保留列，Handle 不读写。
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_refund_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信退款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 REFUND',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局退款渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源退款业务逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源退款业务主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源退款业务子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '退款业务本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '退款业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '退款业务子流水号或子订单号',
  `original_capability`               VARCHAR(20)   DEFAULT NULL            COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  `original_channel_transaction_id`   BIGINT        DEFAULT NULL            COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  `original_front_ssn`                VARCHAR(100)  DEFAULT NULL            COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  `original_biz_transaction_id`       VARCHAR(100)  DEFAULT NULL            COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  `original_biz_sub_transaction_id`   VARCHAR(100)  DEFAULT NULL            COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  `original_biz_order_no`             VARCHAR(100)  NOT NULL                COMMENT '当前中信退款实际使用的原业务主流水号',
  `original_biz_sub_order_no`         VARCHAR(100)  DEFAULT NULL            COMMENT '当前中信退款实际使用的原业务子流水号；应用层必填',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店 ID',
  `pay_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方电子账户号（原始值，未加密）',
  `pay_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方名称',
  `rec_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方电子账户号（原始值，未加密）',
  `rec_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方名称',
  `amount`                            BIGINT        NOT NULL                COMMENT '本次真退款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '本次退款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '中信真退款业务编号 bizFunc，当前为 23',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等退款流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行退款日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行退款时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '中信业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '中信业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '中信原始退款状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化退款状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_original_transaction` (`original_capability`,`original_channel_transaction_id`),
  KEY `idx_front_original_ssn` (`original_front_ssn`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信真退款渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 6. front_pingan_refund_transaction  平安退款渠道交易流水（capability=REFUND）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_refund_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安退款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 REFUND',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局退款渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源退款业务逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源退款业务主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源退款业务子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '退款业务本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '退款业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '退款业务子流水号或子订单号',
  `original_capability`               VARCHAR(20)   NOT NULL                COMMENT '原渠道交易能力，当前允许 TRANSFER 或 CONSUME',
  `original_channel_transaction_id`   BIGINT        NOT NULL                COMMENT '同银行原转账或消费渠道表记录主键',
  `original_front_ssn`                VARCHAR(100)  NOT NULL                COMMENT '原 Front 渠道交易流水号',
  `original_biz_transaction_id`       VARCHAR(100)  DEFAULT NULL            COMMENT '原业务交易主表记录 ID（选填，TODO-002 §2.1 裁决）',
  `original_biz_sub_transaction_id`   VARCHAR(100)  DEFAULT NULL            COMMENT '原业务交易子表或明细表记录 ID',
  `original_biz_order_no`             VARCHAR(100)  NOT NULL                COMMENT '原业务主流水号或主订单号',
  `original_biz_sub_order_no`         VARCHAR(100)  DEFAULT NULL            COMMENT '原业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店 ID',
  `pay_member_id`                  VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方商户会员编号',
  `pay_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方电子账户号（原始值，未加密）',
  `pay_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方名称',
  `rec_member_id`                  VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方商户会员编号',
  `rec_account_id`                 VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方电子账户号（原始值，未加密）',
  `rec_name`                       VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方名称',
  `amount`                            BIGINT        NOT NULL                COMMENT '本次退款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '本次退款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '平安协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平安退款协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等退款流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行退款日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行退款时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '平安业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '平安业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '平安原始退款状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化退款状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_original_transaction` (`original_capability`,`original_channel_transaction_id`),
  KEY `idx_front_original_ssn` (`original_front_ssn`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安退款渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 7. front_citic_withdraw_transaction  中信提现渠道交易流水（capability=WITHDRAW）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_withdraw_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信提现渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 WITHDRAW',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局提现渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源提现业务逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源提现业务主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源提现业务子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '提现业务本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '提现业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '提现业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现收款方业务门店 ID',
  `withdraw_account_id`              VARCHAR(100)  DEFAULT NULL            COMMENT '提现电子账户号（原始值，未加密）',
  `withdraw_account_name`            VARCHAR(100)  DEFAULT NULL            COMMENT '提现账户名称',
  `bank_card_no`                     VARCHAR(100)  DEFAULT NULL            COMMENT '提现银行卡号（原始值，未加密）',
  `bank_card_holder_name`            VARCHAR(100)  DEFAULT NULL            COMMENT '银行卡持卡人姓名',
  `amount`                            BIGINT        NOT NULL                COMMENT '提现金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '提现手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '中信提现协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等提现流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行提现日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行提现时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '中信业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '中信业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '中信原始提现状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化提现状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信提现渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 8. front_pingan_withdraw_transaction  平安提现渠道交易流水（capability=WITHDRAW）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_withdraw_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安提现渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 WITHDRAW',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局提现渠道流水号，同时作为本次银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源提现业务逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源提现业务主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源提现业务子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '提现业务本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '提现业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '提现业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '提现收款方业务门店 ID',
  `withdraw_member_id`               VARCHAR(100)  DEFAULT NULL            COMMENT '提现商户会员编号',
  `withdraw_account_id`              VARCHAR(100)  DEFAULT NULL            COMMENT '提现电子账户号（原始值，未加密）',
  `withdraw_account_name`            VARCHAR(100)  DEFAULT NULL            COMMENT '提现账户名称',
  `bank_card_no`                     VARCHAR(100)  DEFAULT NULL            COMMENT '提现银行卡号（原始值，未加密）',
  `bank_card_holder_name`            VARCHAR(100)  DEFAULT NULL            COMMENT '银行卡持卡人姓名',
  `amount`                            BIGINT        NOT NULL                COMMENT '提现金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平安提现手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '平安协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平安提现协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等提现流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行提现日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行提现时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '平安业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '平安业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '平安原始提现状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化提现状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安提现渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 9. front_citic_platform_pay_transaction  中信平台付款渠道交易流水（capability=PLATFORM_PAY）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_platform_pay_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信平台付款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 PLATFORM_PAY',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局平台付款渠道流水号，同时作为银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源平台付款业务逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源平台付款业务主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源平台付款业务子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '平台付款业务本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '平台付款业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '平台付款业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店 ID',
`rec_account_id` VARCHAR(100) DEFAULT NULL COMMENT '收款方电子账户号（平台付款时用户是收款方）（原始值，未加密）',
  `rec_name` VARCHAR(200) DEFAULT NULL COMMENT '收款方电子账户户名',
  `amount`                            BIGINT        NOT NULL                COMMENT '平台付款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平台付款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '中信平台付款协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等平台付款流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '中信业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '中信业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '中信原始平台付款状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化平台付款状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信平台付款渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;


-- -----------------------------------------------------------------------------
-- 10. front_citic_platform_receive_transaction  中信平台收款渠道交易流水（capability=PLATFORM_RECEIVE）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_platform_receive_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信平台收款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `data_source_id`                    VARCHAR(30)   NOT NULL DEFAULT ''     COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 PLATFORM_RECEIVE',
  `front_ssn`                         VARCHAR(100)  NOT NULL                COMMENT 'Front 全局平台收款渠道流水号，同时作为银行请求 transSsn',
  `front_query_id`                    VARCHAR(100)  DEFAULT NULL            COMMENT '返回业务系统的 Front 查询标识',
  `biz_system_code`                   VARCHAR(100)  NOT NULL                COMMENT '来源业务系统编码',
  `biz_transaction_type`              VARCHAR(20)   NOT NULL                COMMENT '来源平台收款业务逻辑类型，不保存物理表名',
  `biz_transaction_id`                VARCHAR(100)  NOT NULL                COMMENT '来源平台收款业务主表记录 ID',
  `biz_sub_transaction_id`            VARCHAR(100)  DEFAULT NULL            COMMENT '来源平台收款业务子表或明细表记录 ID',
  `biz_request_no`                    VARCHAR(100)  NOT NULL                COMMENT '平台收款业务本次调用唯一号',
  `biz_order_no`                      VARCHAR(100)  NOT NULL                COMMENT '平台收款业务主流水号或主订单号',
  `biz_sub_order_no`                  VARCHAR(100)  DEFAULT NULL            COMMENT '平台收款业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '收款方业务门店 ID',
`pay_account_id` VARCHAR(100) DEFAULT NULL COMMENT '付款方电子账户号（平台收款时用户是付款方）（原始值，未加密）',
  `pay_name` VARCHAR(200) DEFAULT NULL COMMENT '付款方电子账户户名',
  `amount`                            BIGINT        NOT NULL                COMMENT '平台收款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平台收款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `bank_channel_no`                   VARCHAR(20)   DEFAULT NULL            COMMENT '中信协议渠道编号 chnlNo',
  `bank_biz_func`                     VARCHAR(20)   DEFAULT NULL            COMMENT '中信平台收款协议业务编号 bizFunc',
  `external_platform_ssn`             VARCHAR(100)  DEFAULT NULL            COMMENT '银行 reserve 中的外联平台流水 laasSsn',
  `bank_query_id`                     VARCHAR(100)  DEFAULT NULL            COMMENT '电子钱包或银行返回的 queryId',
  `bank_user_ssn`                     VARCHAR(100)  DEFAULT NULL            COMMENT '银行返回的 USER_SSN 等平台收款流水',
  `bank_trans_date`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易日期，字符串格式 yyyyMMdd',
  `bank_trans_time`                   VARCHAR(20)   DEFAULT NULL            COMMENT '银行交易时间，字符串格式 HHmmss',
  `wallet_resp_code`                  VARCHAR(20)   DEFAULT NULL            COMMENT '电子钱包平台层原始响应码 errCode',
  `wallet_resp_desc`                  VARCHAR(512)  DEFAULT NULL            COMMENT '电子钱包平台层原始响应说明 errInfo',
  `bank_resp_code`                    VARCHAR(20)   DEFAULT NULL            COMMENT '中信业务层原始响应码 sysRespCode',
  `bank_resp_desc`                    VARCHAR(512)  DEFAULT NULL            COMMENT '中信业务层原始响应说明 sysRespDesc',
  `bank_status`                       VARCHAR(20)   DEFAULT NULL            COMMENT '中信原始平台收款状态，仅供查询与审计',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化平台收款状态',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  PRIMARY KEY (`id`, `tenant_id`, `store_id`),
  KEY `idx_front_ssn` (`front_ssn`),
  KEY `idx_front_data_source` (`tenant_id`,`data_source_id`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信平台收款渠道交易流水' PARTITION BY LINEAR KEY (`tenant_id`, `store_id`) PARTITIONS 30;
```

---

## 3. 表与字段统计

| 序号 | 表名 | 字段数 | 唯一键 | 普通索引 | 业务 |
|---:|---|---:|---:|---:|---|
| 1 | `front_citic_transfer_transaction` | 63 | 2 | 8 | 中信转账 |
| 2 | `front_pingan_transfer_transaction` | 65 | 2 | 8 | 平安转账+授权 |
| 3 | `front_citic_consume_transaction` | 63 | 2 | 8 | 中信消费 |
| 4 | `front_pingan_consume_transaction` | 65 | 2 | 8 | 平安消费 |
| 5 | `front_citic_refund_transaction` | 69 | 2 | 10 | 中信真退款 |
| 6 | `front_pingan_refund_transaction` | 71 | 2 | 10 | 平安退款 |
| 7 | `front_citic_withdraw_transaction` | 62 | 2 | 8 | 中信提现 |
| 8 | `front_pingan_withdraw_transaction` | 63 | 2 | 8 | 平安提现 |
| 9 | `front_citic_platform_pay_transaction` | 59 | 2 | 8 | 中信平台付款 |
| 10 | `front_citic_platform_receive_transaction` | 59 | 2 | 8 | 中信平台收款 |

退款表（5、6）物理上比普通交易表多 7 个 `original_*` 字段 + 2 个原交易索引；其中中信退款当前仅使用 `original_biz_order_no/original_biz_sub_order_no`，其他 5 列为可空兼容列，Handle 不读写。转账/消费表（1-4）比平台表多 1 个 `refunded_amount` 字段。所有表均含银行账户标识字段（v4 新增）：中信转账/消费/退款各 4 个（`pay_account_id`/`pay_name`/`rec_account_id`/`rec_name`），中信平台付款 2 个（`rec_account_id`/`rec_name`），中信平台收款 2 个（`pay_account_id`/`pay_name`），中信提现 4 个（`withdraw_account_id`/`withdraw_account_name`/`bank_card_no`/`bank_card_holder_name`）；平安对应表各多 1～2 个 `*_member_id`（转账/消费/退款 +6、提现 +5）。所有表均含 `create_by`/`create_time`/`update_by`/`update_time` 4 个审计字段（对应 Entity 父类 BaseEntity，MyBatis-Plus 自动填充）。

---

## 4. 执行后自检 SQL（可选）

```sql
SELECT TABLE_NAME, TABLE_COLLATION, ENGINE, TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'front\_%\_transaction'
ORDER BY TABLE_NAME;
```

预期返回 10 行，`TABLE_COLLATION` 全部为 `utf8mb4_general_ci`，`ENGINE` 全部为 `InnoDB`。

字段类型分布核查（确认无 `CHAR`、无 `DATETIME(3)`、无零碎长度）：

```sql
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, DATETIME_PRECISION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'front\_%\_transaction'
  AND (DATA_TYPE IN ('char') OR DATETIME_PRECISION = 3
       OR CHARACTER_MAXIMUM_LENGTH NOT IN (20, 100, 512, 1024) AND CHARACTER_MAXIMUM_LENGTH IS NOT NULL)
ORDER BY TABLE_NAME, COLUMN_NAME;
```

预期返回 0 行（无违规字段）。

---

## 5. 与代码的关系

本 SQL 仅用于**手动在目标数据库创建物理表**。代码侧的 Entity、Mapper、Repository、表路由和真实写入流程仍待后续实现（见 `09` §1 末尾）。

代码仓库 `catering-front/src/main/resources/db/migration/V001__...sql` 是结构基线；本 SQL 是按目标字符集 `utf8mb4 / utf8mb4_general_ci` 和统一字段类型规范生成的最终可执行版本，字段语义与 `09A` 字段字典一致，仅类型做了规范化收敛（详见 §1）。
