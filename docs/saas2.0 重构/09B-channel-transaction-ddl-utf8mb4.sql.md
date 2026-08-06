# Front 渠道交易表最终建表 SQL（utf8mb4 / utf8mb4_general_ci）

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 上位规则：[09-channel-transaction-ddl.md](./09-channel-transaction-ddl.md)
> 字段来源：[09A-channel-transaction-table-field-catalog.md](./09A-channel-transaction-table-field-catalog.md)
> 状态：可执行最终 SQL，由用户手动在目标数据库创建
> 生成日期：2026-08-05
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
| 流水号 / 业务编号 / 业务记录 ID / hash / 配置版本 | **`VARCHAR(100)`** | 所有编号类统一 100 |
| 创建者 / 更新者 | **`VARCHAR(64)`** | `create_by`/`update_by`，审计字段，MyBatis-Plus 自动填充 |
| 描述 / 备注 | `VARCHAR(512)` | 响应说明、业务备注 |
| 临时扩展 | `VARCHAR(1024)` | `reserve1/2/3` |
| 加密快照 | `MEDIUMTEXT` | 业务/银行数据加密快照 |
| 创建 / 更新时间（审计） | **`DATETIME`** | `create_time`/`update_time`，MyBatis-Plus 自动填充；对应 Entity 父类 `createTime`/`updateTime` |
| 发送 / 响应 / 完成时间（业务） | **`DATETIME`** | `send_started_at`/`bank_responded_at`/`completed_at`，业务时间字段 |

**禁止**：使用 `CHAR`、`DATETIME(3)`、`TIMESTAMP`、零碎长度（如 `VARCHAR(64)/32/16/8/6/3`）。
**审计字段用父类**：`create_by`/`create_time`/`update_by`/`update_time` 对应 Entity 继承的
`BaseEntity` 审计字段，子类不再重复声明，由 MyBatis-Plus `MetaObjectHandler` 自动填充。
不再使用 `created_at`/`updated_at`（旧字段已由 [09C](09C-alter-add-audit-columns.sql.md) 的 ALTER 移除）。

### 1.1 索引长度兼容性核查（utf8mb4 + DYNAMIC）

`utf8mb4` 每字符最多 4 字节。最长联合索引核查：

| 索引 | 列（均为 VARCHAR(100)） | 单列字节 | 合计字节 | 上限 3072 | 结论 |
|---|---|---:|---:|---:|---|
| `uk_front_idempotency` | 4 列 | 400 | 1600 | 3072 | ✓ |
| `idx_front_business_main` | 4 列 | 400 | 1600 | 3072 | ✓ |
| `idx_front_biz_order` | 4 列 | 400 | 1600 | 3072 | ✓ |
| `idx_front_status_time` | `tenant_id(100)+front_status(20)+update_time(8)` | — | 508 | 3072 | ✓ |
| `idx_front_store_time` | `tenant_id(100)+store_id(100)+create_time(8)` | — | 528 | 3072 | ✓ |
| 退款表 `idx_front_original_transaction` | `original_capability(20)+original_channel_transaction_id(8)` | — | 88 | 3072 | ✓ |

全部索引无需前缀截断。

### 1.2 时间字段说明

- `created_at` / `updated_at`：`DATETIME`，默认 `CURRENT_TIMESTAMP`，`updated_at` 加 `ON UPDATE CURRENT_TIMESTAMP`。
- `send_started_at` / `bank_responded_at` / `completed_at`：`DATETIME`，允许 `NULL`，由应用层写入。
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
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 TRANSFER',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际中信接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '转账金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '转账手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该原交易累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的业务 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的中信请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '中信原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化交易备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信转账渠道交易流水';


-- -----------------------------------------------------------------------------
-- 2. front_pingan_transfer_transaction  平安转账及转账授权渠道交易流水
--    capability 允许：TRANSFER / TRANSFER_AUTH / TRANSFER_AUTH_CODE_RESEND
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_transfer_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安转账渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT '能力编码：TRANSFER、TRANSFER_AUTH 或 TRANSFER_AUTH_CODE_RESEND',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际平安接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '转账或授权交易金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平安转账手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该原交易累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的业务 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥和验证码后的平安请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '平安原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化交易备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安转账及转账授权渠道交易流水';


-- -----------------------------------------------------------------------------
-- 3. front_citic_consume_transaction  中信消费渠道交易流水（capability=CONSUME）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_consume_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信消费渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 CONSUME',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际中信接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '消费金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '消费手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该消费累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的业务 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的中信请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '中信原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化交易备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信消费渠道交易流水';


-- -----------------------------------------------------------------------------
-- 4. front_pingan_consume_transaction  平安消费渠道交易流水（capability=CONSUME）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_consume_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安消费渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 CONSUME',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际平安接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '消费金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平安消费手续费，单位为人民币分',
  `refunded_amount`                   BIGINT        NOT NULL DEFAULT 0      COMMENT '该消费累计确认退款金额，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的业务 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的平安请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '平安原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化交易状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化交易备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安消费渠道交易流水';


-- -----------------------------------------------------------------------------
-- 5. front_citic_refund_transaction  中信真退款渠道交易流水（capability=REFUND，bizFunc=23）
--    退款表含 7 个原交易关联字段 + 2 个原交易索引；不含 refunded_amount（在原交易表）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_refund_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信退款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 REFUND',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '中信真退款接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `original_biz_transaction_id`       VARCHAR(100)  NOT NULL                COMMENT '原业务交易主表记录 ID',
  `original_biz_sub_transaction_id`   VARCHAR(100)  DEFAULT NULL            COMMENT '原业务交易子表或明细表记录 ID',
  `original_biz_order_no`             VARCHAR(100)  NOT NULL                COMMENT '原业务主流水号或主订单号',
  `original_biz_sub_order_no`         VARCHAR(100)  DEFAULT NULL            COMMENT '原业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店 ID',
  `amount`                            BIGINT        NOT NULL                COMMENT '本次真退款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '本次退款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '退款业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '退款业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '退款业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化退款业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整退款业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的退款 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的中信真退款请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '中信真退款原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化退款状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化退款备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_original_transaction` (`original_capability`,`original_channel_transaction_id`),
  KEY `idx_front_original_ssn` (`original_front_ssn`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信真退款渠道交易流水';


-- -----------------------------------------------------------------------------
-- 6. front_pingan_refund_transaction  平安退款渠道交易流水（capability=REFUND）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_refund_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安退款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 REFUND',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '平安退款接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `original_biz_transaction_id`       VARCHAR(100)  NOT NULL                COMMENT '原业务交易主表记录 ID',
  `original_biz_sub_transaction_id`   VARCHAR(100)  DEFAULT NULL            COMMENT '原业务交易子表或明细表记录 ID',
  `original_biz_order_no`             VARCHAR(100)  NOT NULL                COMMENT '原业务主流水号或主订单号',
  `original_biz_sub_order_no`         VARCHAR(100)  DEFAULT NULL            COMMENT '原业务子流水号或子订单号',
  `pay_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店编码',
  `pay_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款付款方业务门店 ID',
  `rec_store_no`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店编码',
  `rec_store_id`                      VARCHAR(100)  DEFAULT NULL            COMMENT '退款收款方业务门店 ID',
  `amount`                            BIGINT        NOT NULL                COMMENT '本次退款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '本次退款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '退款业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '退款业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '退款业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化退款业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整退款业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的退款 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的平安退款请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '平安退款原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化退款状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化退款备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_original_transaction` (`original_capability`,`original_channel_transaction_id`),
  KEY `idx_front_original_ssn` (`original_front_ssn`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安退款渠道交易流水';


-- -----------------------------------------------------------------------------
-- 7. front_citic_withdraw_transaction  中信提现渠道交易流水（capability=WITHDRAW）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_withdraw_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信提现渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 WITHDRAW',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际中信提现接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '提现金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '提现手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '提现业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '提现业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '提现业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化提现业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整提现业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的提现 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的中信提现请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '中信提现原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化提现状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化提现备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信提现渠道交易流水';


-- -----------------------------------------------------------------------------
-- 8. front_pingan_withdraw_transaction  平安提现渠道交易流水（capability=WITHDRAW）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_pingan_withdraw_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '平安提现渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 WITHDRAW',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际平安提现接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '提现金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平安提现手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '提现业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '提现业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '提现业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化提现业务请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整提现业务 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的提现 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的平安提现请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '平安提现原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化提现状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化提现备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 平安提现渠道交易流水';


-- -----------------------------------------------------------------------------
-- 9. front_citic_platform_pay_transaction  中信平台付款渠道交易流水（capability=PLATFORM_PAY）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_platform_pay_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信平台付款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 PLATFORM_PAY',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际中信平台付款接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '平台付款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平台付款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平台付款业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平台付款业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '平台付款业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化平台付款请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整平台付款 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的平台付款 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的中信平台付款请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '中信平台付款原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化平台付款状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化平台付款备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信平台付款渠道交易流水';


-- -----------------------------------------------------------------------------
-- 10. front_citic_platform_receive_transaction  中信平台收款渠道交易流水（capability=PLATFORM_RECEIVE）
-- -----------------------------------------------------------------------------
CREATE TABLE `front_citic_platform_receive_transaction` (
  `id`                                BIGINT        NOT NULL                COMMENT '中信平台收款渠道记录主键，由 Front 生成分布式 ID',
  `tenant_id`                         VARCHAR(100)  NOT NULL                COMMENT 'SaaS 租户标识',
  `store_id`                          VARCHAR(100)  NOT NULL                COMMENT '发起本次调用的业务门店 ID',
  `capability`                        VARCHAR(20)   NOT NULL                COMMENT 'Front 能力编码；本表固定为 PLATFORM_RECEIVE',
  `interface_code`                    VARCHAR(20)   NOT NULL                COMMENT '实际中信平台收款接口逻辑编码，不保存完整 URL',
  `config_version`                    VARCHAR(100)  DEFAULT NULL            COMMENT '本次调用使用的租户银行配置版本',
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
  `amount`                            BIGINT        NOT NULL                COMMENT '平台收款金额，单位为人民币分',
  `fee`                               BIGINT        NOT NULL DEFAULT 0      COMMENT '平台收款手续费，单位为人民币分',
  `currency`                          VARCHAR(20)   NOT NULL DEFAULT 'CNY'  COMMENT '币种',
  `business_date`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平台收款业务日期，字符串格式 yyyyMMdd',
  `business_time`                     VARCHAR(20)   DEFAULT NULL            COMMENT '平台收款业务时间，字符串格式 HHmmss',
  `business_remark`                   VARCHAR(512)  DEFAULT NULL            COMMENT '平台收款业务备注',
  `request_hash`                      VARCHAR(100)  NOT NULL                COMMENT '规范化平台收款请求的 HMAC-SHA256 指纹',
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
  `business_base_snapshot_cipher`     MEDIUMTEXT    NOT NULL                COMMENT '完整平台收款 baseData 加密快照，用于保留业务交易数据',
  `business_special_snapshot_cipher`  MEDIUMTEXT    DEFAULT NULL            COMMENT '白名单过滤后的平台收款 specialData 加密快照',
  `bank_request_snapshot_cipher`      MEDIUMTEXT    DEFAULT NULL            COMMENT '移除密钥后的中信平台收款请求加密快照',
  `bank_response_snapshot_cipher`     MEDIUMTEXT    DEFAULT NULL            COMMENT '中信平台收款原始响应加密快照',
  `snapshot_key_version`              VARCHAR(20)   DEFAULT NULL            COMMENT '快照加密密钥版本，不保存密钥本身',
  `reserve1`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 1，稳定后迁移为明确业务列',
  `reserve2`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 2，稳定后迁移为明确业务列',
  `reserve3`                          VARCHAR(1024) DEFAULT NULL            COMMENT '临时扩展字段 3，稳定后迁移为明确业务列',
  `front_resp_code`                   VARCHAR(20)   DEFAULT NULL            COMMENT 'Front 统一业务响应码',
  `front_resp_desc`                   VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 统一业务响应说明',
  `front_status`                      VARCHAR(20)   NOT NULL DEFAULT 'INIT' COMMENT 'Front 归一化平台收款状态',
  `front_remark`                      VARCHAR(512)  DEFAULT NULL            COMMENT 'Front 归一化平台收款备注',
  `send_started_at`                   DATETIME      DEFAULT NULL            COMMENT '开始向银行发送时间',
  `bank_responded_at`                 DATETIME      DEFAULT NULL            COMMENT '收到银行同步响应时间',
  `completed_at`                      DATETIME      DEFAULT NULL            COMMENT '确认当前终态时间',
  `create_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '创建者',
  `create_time`                       DATETIME      DEFAULT NULL            COMMENT '创建时间',
  `update_by`                         VARCHAR(64)   DEFAULT NULL            COMMENT '更新者',
  `update_time`                       DATETIME      DEFAULT NULL            COMMENT '更新时间',
  `version`                           INT UNSIGNED  NOT NULL DEFAULT 0      COMMENT '乐观锁版本号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_front_ssn` (`front_ssn`),
  UNIQUE KEY `uk_front_idempotency` (`tenant_id`,`biz_system_code`,`capability`,`biz_request_no`),
  KEY `idx_front_business_main` (`tenant_id`,`biz_system_code`,`biz_transaction_type`,`biz_transaction_id`),
  KEY `idx_front_business_sub` (`tenant_id`,`biz_system_code`,`biz_sub_transaction_id`),
  KEY `idx_front_biz_order` (`tenant_id`,`biz_system_code`,`biz_order_no`,`biz_sub_order_no`),
  KEY `idx_front_bank_query` (`bank_query_id`),
  KEY `idx_front_bank_user_ssn` (`bank_user_ssn`),
  KEY `idx_front_status_time` (`tenant_id`,`front_status`,`update_time`),
  KEY `idx_front_store_time` (`tenant_id`,`store_id`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='Front 中信平台收款渠道交易流水';
```

---

## 3. 表与字段统计

| 序号 | 表名 | 字段数 | 唯一键 | 普通索引 | 业务 |
|---:|---|---:|---:|---:|---|
| 1 | `front_citic_transfer_transaction` | 59 | 2 | 8 | 中信转账 |
| 2 | `front_pingan_transfer_transaction` | 59 | 2 | 8 | 平安转账+授权 |
| 3 | `front_citic_consume_transaction` | 59 | 2 | 8 | 中信消费 |
| 4 | `front_pingan_consume_transaction` | 59 | 2 | 8 | 平安消费 |
| 5 | `front_citic_refund_transaction` | 65 | 2 | 10 | 中信真退款 |
| 6 | `front_pingan_refund_transaction` | 65 | 2 | 10 | 平安退款 |
| 7 | `front_citic_withdraw_transaction` | 58 | 2 | 8 | 中信提现 |
| 8 | `front_pingan_withdraw_transaction` | 58 | 2 | 8 | 平安提现 |
| 9 | `front_citic_platform_pay_transaction` | 58 | 2 | 8 | 中信平台付款 |
| 10 | `front_citic_platform_receive_transaction` | 58 | 2 | 8 | 中信平台收款 |

退款表（5、6）比普通交易表多 7 个 `original_*` 原交易关联字段 + 2 个原交易索引；转账/消费表（1-4）比提现/平台表多 1 个 `refunded_amount` 字段。所有表均含 `create_by`/`create_time`/`update_by`/`update_time` 4 个审计字段（对应 Entity 父类 BaseEntity，MyBatis-Plus 自动填充）。

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
