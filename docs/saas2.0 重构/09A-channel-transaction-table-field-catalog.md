# Front 渠道交易表逐表完整字段字典

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 上位规则：[09-channel-transaction-ddl.md](./09-channel-transaction-ddl.md)
> 状态：字段、默认值、更新规则和索引基线已完整展开
> 基线日期：2026-08-04
> 用途：交给其他 AI 或 DBA，按目标数据库字符集、排序规则和行格式生成最终建表 SQL

## 1. 使用边界

本文逐张列出中信 6 张、平安 4 张渠道交易表的全部字段。以下内容属于已确认结构，不得在生成 SQL
时擅自改变：

- 表数量和表名；
- 字段名、字段顺序、数据类型、可空性、默认值、更新规则和业务说明；
- 主键、唯一键和普通索引的字段组合；
- 每张表的 `reserve1/reserve2/reserve3`；
- 业务主/子记录关联字段及业务数据加密快照；
- 退款表的原交易关联字段；
- 转账、消费表的 `refunded_amount`。

以下内容由最终 SQL 提供方按目标环境要求补充，不在本字段字典中固定：

- `ENGINE`；
- `DEFAULT CHARSET`；
- `COLLATE`；
- `ROW_FORMAT`；
- 表空间、分区及数据库厂商专属语法。

当前代码仓库 V001 使用 `InnoDB + utf8mb4` 只是结构基线，不代表目标环境字符集已经确认。生成最终
SQL 时必须检查目标数据库版本对 `DATETIME(3)`、`CURRENT_TIMESTAMP(3)`、`MEDIUMTEXT`、
`ON UPDATE` 及联合索引字节长度的支持；如需改变字段类型或索引，必须先返回差异清单评审。

## 2. 表和字段数量

| 序号 | 表名 | 字段数 | 表用途 |
|---:|---|---:|---|
| 1 | `front_citic_transfer_transaction` | 57 | Front 中信转账渠道交易流水 |
| 2 | `front_pingan_transfer_transaction` | 57 | Front 平安转账及转账授权渠道交易流水 |
| 3 | `front_citic_consume_transaction` | 57 | Front 中信消费渠道交易流水 |
| 4 | `front_pingan_consume_transaction` | 57 | Front 平安消费渠道交易流水 |
| 5 | `front_citic_refund_transaction` | 63 | Front 中信真退款渠道交易流水 |
| 6 | `front_pingan_refund_transaction` | 63 | Front 平安退款渠道交易流水 |
| 7 | `front_citic_withdraw_transaction` | 56 | Front 中信提现渠道交易流水 |
| 8 | `front_pingan_withdraw_transaction` | 56 | Front 平安提现渠道交易流水 |
| 9 | `front_citic_platform_pay_transaction` | 56 | Front 中信平台付款渠道交易流水 |
| 10 | `front_citic_platform_receive_transaction` | 56 | Front 中信平台收款渠道交易流水 |

## 3. 逐表完整字段

### 3.1 `front_citic_transfer_transaction`

表说明：Front 中信转账渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信转账渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 TRANSFER |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际中信接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 转账金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 转账手续费，单位为人民币分 |
| 22 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该原交易累计确认退款金额，单位为人民币分 |
| 23 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 24 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 业务日期，格式 yyyyMMdd |
| 25 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 业务时间，格式 HHmmss |
| 26 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 业务备注 |
| 27 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化业务请求的 HMAC-SHA256 指纹 |
| 28 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 29 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 中信协议业务编号 bizFunc |
| 30 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 31 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 32 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 33 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 34 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 35 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 36 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 37 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 38 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 39 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信原始交易状态，仅供查询与审计 |
| 40 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整业务 baseData 加密快照，用于保留业务交易数据 |
| 41 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的业务 specialData 加密快照 |
| 42 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的中信请求加密快照 |
| 43 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 中信原始响应加密快照 |
| 44 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 45 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 46 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 47 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 48 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 49 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 50 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 51 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化交易备注 |
| 52 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 53 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 54 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 55 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 56 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 57 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.2 `front_pingan_transfer_transaction`

表说明：Front 平安转账及转账授权渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安转账渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | 能力编码：TRANSFER、TRANSFER_AUTH 或 TRANSFER_AUTH_CODE_RESEND |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际平安接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 转账或授权交易金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 平安转账手续费，单位为人民币分 |
| 22 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该原交易累计确认退款金额，单位为人民币分 |
| 23 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 24 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 业务日期，格式 yyyyMMdd |
| 25 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 业务时间，格式 HHmmss |
| 26 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 业务备注 |
| 27 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化业务请求的 HMAC-SHA256 指纹 |
| 28 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 29 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 平安协议业务编号 bizFunc |
| 30 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 31 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 32 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 33 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 34 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 35 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 36 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 37 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 38 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 39 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安原始交易状态，仅供查询与审计 |
| 40 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整业务 baseData 加密快照，用于保留业务交易数据 |
| 41 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的业务 specialData 加密快照 |
| 42 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥和验证码后的平安请求加密快照 |
| 43 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 平安原始响应加密快照 |
| 44 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 45 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 46 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 47 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 48 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 49 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 50 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 51 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化交易备注 |
| 52 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 53 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 54 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 55 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 56 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 57 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.3 `front_citic_consume_transaction`

表说明：Front 中信消费渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信消费渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 CONSUME |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际中信接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 消费金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 消费手续费，单位为人民币分 |
| 22 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该消费累计确认退款金额，单位为人民币分 |
| 23 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 24 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 业务日期，格式 yyyyMMdd |
| 25 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 业务时间，格式 HHmmss |
| 26 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 业务备注 |
| 27 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化业务请求的 HMAC-SHA256 指纹 |
| 28 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 29 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 中信协议业务编号 bizFunc |
| 30 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 31 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 32 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 33 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 34 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 35 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 36 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 37 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 38 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 39 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信原始交易状态，仅供查询与审计 |
| 40 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整业务 baseData 加密快照，用于保留业务交易数据 |
| 41 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的业务 specialData 加密快照 |
| 42 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的中信请求加密快照 |
| 43 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 中信原始响应加密快照 |
| 44 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 45 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 46 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 47 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 48 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 49 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 50 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 51 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化交易备注 |
| 52 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 53 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 54 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 55 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 56 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 57 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.4 `front_pingan_consume_transaction`

表说明：Front 平安消费渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安消费渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 CONSUME |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际平安接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 消费金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 平安消费手续费，单位为人民币分 |
| 22 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该消费累计确认退款金额，单位为人民币分 |
| 23 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 24 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 业务日期，格式 yyyyMMdd |
| 25 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 业务时间，格式 HHmmss |
| 26 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 业务备注 |
| 27 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化业务请求的 HMAC-SHA256 指纹 |
| 28 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 29 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 平安协议业务编号 bizFunc |
| 30 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 31 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 32 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 33 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 34 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 35 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 36 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 37 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 38 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 39 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安原始交易状态，仅供查询与审计 |
| 40 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整业务 baseData 加密快照，用于保留业务交易数据 |
| 41 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的业务 specialData 加密快照 |
| 42 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的平安请求加密快照 |
| 43 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 平安原始响应加密快照 |
| 44 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 45 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 46 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 47 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 48 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 49 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 50 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 51 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化交易备注 |
| 52 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 53 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 54 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 55 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 56 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 57 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.5 `front_citic_refund_transaction`

表说明：Front 中信真退款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信退款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 REFUND |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 中信真退款接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局退款渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源退款业务逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源退款业务主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源退款业务子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 退款业务本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 退款业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款业务子流水号或子订单号 |
| 16 | `original_capability` | `VARCHAR(64)` | 否 | `—` | `—` | 原渠道交易能力，当前允许 TRANSFER 或 CONSUME |
| 17 | `original_channel_transaction_id` | `BIGINT` | 否 | `—` | `—` | 同银行原转账或消费渠道表记录主键 |
| 18 | `original_front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | 原 Front 渠道交易流水号 |
| 19 | `original_biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 原业务交易主表记录 ID |
| 20 | `original_biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 原业务交易子表或明细表记录 ID |
| 21 | `original_biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 原业务主流水号或主订单号 |
| 22 | `original_biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 原业务子流水号或子订单号 |
| 23 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款付款方业务门店编码 |
| 24 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款付款方业务门店 ID |
| 25 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款收款方业务门店编码 |
| 26 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款收款方业务门店 ID |
| 27 | `amount` | `BIGINT` | 否 | `—` | `—` | 本次真退款金额，单位为人民币分 |
| 28 | `fee` | `BIGINT` | 否 | `0` | `—` | 本次退款手续费，单位为人民币分 |
| 29 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 30 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 退款业务日期，格式 yyyyMMdd |
| 31 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 退款业务时间，格式 HHmmss |
| 32 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 退款业务备注 |
| 33 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化退款业务请求的 HMAC-SHA256 指纹 |
| 34 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 35 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 中信真退款业务编号 bizFunc，当前为 23 |
| 36 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 37 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 38 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等退款流水 |
| 39 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行退款日期，格式 yyyyMMdd |
| 40 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行退款时间，格式 HHmmss |
| 41 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 42 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 43 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 44 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 45 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信原始退款状态，仅供查询与审计 |
| 46 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整退款业务 baseData 加密快照，用于保留业务交易数据 |
| 47 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的退款 specialData 加密快照 |
| 48 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的中信真退款请求加密快照 |
| 49 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 中信真退款原始响应加密快照 |
| 50 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 51 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 52 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 53 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 54 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 55 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 56 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化退款状态 |
| 57 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化退款备注 |
| 58 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 59 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 60 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 61 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 62 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 63 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_original_transaction` | `original_capability` → `original_channel_transaction_id` |
| INDEX | `idx_front_original_ssn` | `original_front_ssn` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.6 `front_pingan_refund_transaction`

表说明：Front 平安退款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安退款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 REFUND |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 平安退款接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局退款渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源退款业务逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源退款业务主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源退款业务子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 退款业务本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 退款业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款业务子流水号或子订单号 |
| 16 | `original_capability` | `VARCHAR(64)` | 否 | `—` | `—` | 原渠道交易能力，当前允许 TRANSFER 或 CONSUME |
| 17 | `original_channel_transaction_id` | `BIGINT` | 否 | `—` | `—` | 同银行原转账或消费渠道表记录主键 |
| 18 | `original_front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | 原 Front 渠道交易流水号 |
| 19 | `original_biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 原业务交易主表记录 ID |
| 20 | `original_biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 原业务交易子表或明细表记录 ID |
| 21 | `original_biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 原业务主流水号或主订单号 |
| 22 | `original_biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 原业务子流水号或子订单号 |
| 23 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款付款方业务门店编码 |
| 24 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款付款方业务门店 ID |
| 25 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款收款方业务门店编码 |
| 26 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 退款收款方业务门店 ID |
| 27 | `amount` | `BIGINT` | 否 | `—` | `—` | 本次退款金额，单位为人民币分 |
| 28 | `fee` | `BIGINT` | 否 | `0` | `—` | 本次退款手续费，单位为人民币分 |
| 29 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 30 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 退款业务日期，格式 yyyyMMdd |
| 31 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 退款业务时间，格式 HHmmss |
| 32 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 退款业务备注 |
| 33 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化退款业务请求的 HMAC-SHA256 指纹 |
| 34 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 35 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 平安退款协议业务编号 bizFunc |
| 36 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 37 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 38 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等退款流水 |
| 39 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行退款日期，格式 yyyyMMdd |
| 40 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行退款时间，格式 HHmmss |
| 41 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 42 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 43 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 44 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 45 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安原始退款状态，仅供查询与审计 |
| 46 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整退款业务 baseData 加密快照，用于保留业务交易数据 |
| 47 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的退款 specialData 加密快照 |
| 48 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的平安退款请求加密快照 |
| 49 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 平安退款原始响应加密快照 |
| 50 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 51 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 52 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 53 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 54 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 55 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 56 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化退款状态 |
| 57 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化退款备注 |
| 58 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 59 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 60 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 61 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 62 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 63 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_original_transaction` | `original_capability` → `original_channel_transaction_id` |
| INDEX | `idx_front_original_ssn` | `original_front_ssn` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.7 `front_citic_withdraw_transaction`

表说明：Front 中信提现渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信提现渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 WITHDRAW |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际中信提现接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局提现渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源提现业务逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源提现业务主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源提现业务子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 提现业务本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 提现业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 提现金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 提现手续费，单位为人民币分 |
| 22 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 23 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 提现业务日期，格式 yyyyMMdd |
| 24 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 提现业务时间，格式 HHmmss |
| 25 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 提现业务备注 |
| 26 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化提现业务请求的 HMAC-SHA256 指纹 |
| 27 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 中信提现协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等提现流水 |
| 32 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行提现日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行提现时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信原始提现状态，仅供查询与审计 |
| 39 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整提现业务 baseData 加密快照，用于保留业务交易数据 |
| 40 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的提现 specialData 加密快照 |
| 41 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的中信提现请求加密快照 |
| 42 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 中信提现原始响应加密快照 |
| 43 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 44 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 45 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 46 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 47 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 48 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 49 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化提现状态 |
| 50 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化提现备注 |
| 51 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 52 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 53 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 54 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 55 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 56 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.8 `front_pingan_withdraw_transaction`

表说明：Front 平安提现渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安提现渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 WITHDRAW |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际平安提现接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局提现渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源提现业务逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源提现业务主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源提现业务子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 提现业务本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 提现业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 提现收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 提现金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 平安提现手续费，单位为人民币分 |
| 22 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 23 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 提现业务日期，格式 yyyyMMdd |
| 24 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 提现业务时间，格式 HHmmss |
| 25 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 提现业务备注 |
| 26 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化提现业务请求的 HMAC-SHA256 指纹 |
| 27 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 平安提现协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等提现流水 |
| 32 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行提现日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行提现时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平安原始提现状态，仅供查询与审计 |
| 39 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整提现业务 baseData 加密快照，用于保留业务交易数据 |
| 40 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的提现 specialData 加密快照 |
| 41 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的平安提现请求加密快照 |
| 42 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 平安提现原始响应加密快照 |
| 43 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 44 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 45 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 46 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 47 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 48 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 49 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化提现状态 |
| 50 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化提现备注 |
| 51 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 52 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 53 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 54 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 55 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 56 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.9 `front_citic_platform_pay_transaction`

表说明：Front 中信平台付款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信平台付款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 PLATFORM_PAY |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际中信平台付款接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局平台付款渠道流水号，同时作为银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源平台付款业务逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源平台付款业务主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源平台付款业务子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 平台付款业务本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 平台付款业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平台付款业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 平台付款金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 平台付款手续费，单位为人民币分 |
| 22 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 23 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 平台付款业务日期，格式 yyyyMMdd |
| 24 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 平台付款业务时间，格式 HHmmss |
| 25 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平台付款业务备注 |
| 26 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化平台付款请求的 HMAC-SHA256 指纹 |
| 27 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 中信平台付款协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等平台付款流水 |
| 32 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信原始平台付款状态，仅供查询与审计 |
| 39 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整平台付款 baseData 加密快照，用于保留业务交易数据 |
| 40 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的平台付款 specialData 加密快照 |
| 41 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的中信平台付款请求加密快照 |
| 42 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 中信平台付款原始响应加密快照 |
| 43 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 44 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 45 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 46 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 47 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 48 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 49 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化平台付款状态 |
| 50 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化平台付款备注 |
| 51 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 52 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 53 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 54 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 55 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 56 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

### 3.10 `front_citic_platform_receive_transaction`

表说明：Front 中信平台收款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信平台收款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(64)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(64)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `capability` | `VARCHAR(64)` | 否 | `—` | `—` | Front 能力编码；本表固定为 PLATFORM_RECEIVE |
| 5 | `interface_code` | `VARCHAR(64)` | 否 | `—` | `—` | 实际中信平台收款接口逻辑编码，不保存完整 URL |
| 6 | `config_version` | `VARCHAR(64)` | 是 | `NULL` | `—` | 本次调用使用的租户银行配置版本 |
| 7 | `front_ssn` | `VARCHAR(64)` | 否 | `—` | `—` | Front 全局平台收款渠道流水号，同时作为银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(64)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(64)` | 否 | `—` | `—` | 来源平台收款业务逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(64)` | 否 | `—` | `—` | 来源平台收款业务主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 来源平台收款业务子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(64)` | 否 | `—` | `—` | 平台收款业务本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(64)` | 否 | `—` | `—` | 平台收款业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 平台收款业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `amount` | `BIGINT` | 否 | `—` | `—` | 平台收款金额，单位为人民币分 |
| 21 | `fee` | `BIGINT` | 否 | `0` | `—` | 平台收款手续费，单位为人民币分 |
| 22 | `currency` | `CHAR(3)` | 否 | `'CNY'` | `—` | 币种 |
| 23 | `business_date` | `CHAR(8)` | 是 | `NULL` | `—` | 平台收款业务日期，格式 yyyyMMdd |
| 24 | `business_time` | `CHAR(6)` | 是 | `NULL` | `—` | 平台收款业务时间，格式 HHmmss |
| 25 | `business_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平台收款业务备注 |
| 26 | `request_hash` | `CHAR(64)` | 否 | `—` | `—` | 规范化平台收款请求的 HMAC-SHA256 指纹 |
| 27 | `bank_channel_no` | `VARCHAR(16)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(32)` | 是 | `NULL` | `—` | 中信平台收款协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(64)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等平台收款流水 |
| 32 | `bank_trans_date` | `CHAR(8)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `CHAR(6)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(64)` | 是 | `NULL` | `—` | 中信原始平台收款状态，仅供查询与审计 |
| 39 | `business_base_snapshot_cipher` | `MEDIUMTEXT` | 否 | `—` | `—` | 完整平台收款 baseData 加密快照，用于保留业务交易数据 |
| 40 | `business_special_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 白名单过滤后的平台收款 specialData 加密快照 |
| 41 | `bank_request_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 移除密钥后的中信平台收款请求加密快照 |
| 42 | `bank_response_snapshot_cipher` | `MEDIUMTEXT` | 是 | `NULL` | `—` | 中信平台收款原始响应加密快照 |
| 43 | `snapshot_key_version` | `VARCHAR(32)` | 是 | `NULL` | `—` | 快照加密密钥版本，不保存密钥本身 |
| 44 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 45 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 46 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 47 | `front_resp_code` | `VARCHAR(64)` | 是 | `NULL` | `—` | Front 统一业务响应码 |
| 48 | `front_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 统一业务响应说明 |
| 49 | `front_status` | `VARCHAR(32)` | 否 | `'INIT'` | `—` | Front 归一化平台收款状态 |
| 50 | `front_remark` | `VARCHAR(512)` | 是 | `NULL` | `—` | Front 归一化平台收款备注 |
| 51 | `send_started_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 开始向银行发送时间 |
| 52 | `bank_responded_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 53 | `completed_at` | `DATETIME(3)` | 是 | `NULL` | `—` | 确认当前终态时间 |
| 54 | `created_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `—` | 创建时间 |
| 55 | `updated_at` | `DATETIME(3)` | 否 | `CURRENT_TIMESTAMP(3)` | `ON UPDATE CURRENT_TIMESTAMP(3)` | 更新时间 |
| 56 | `version` | `INT UNSIGNED` | 否 | `0` | `—` | 乐观锁版本号 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` |
| UNIQUE | `uk_front_ssn` | `front_ssn` |
| UNIQUE | `uk_front_idempotency` | `tenant_id` → `biz_system_code` → `capability` → `biz_request_no` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_system_code` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `updated_at` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `created_at` |

## 4. 交给 SQL 生成 AI 的固定指令

```text
请根据本字段字典为目标数据库生成 10 张完整建表 SQL。

约束：
1. 必须保持“银行 + 交易业务”10 张物理表，禁止合并成统一渠道表。
2. 必须逐表保留全部字段、字段顺序、类型、NULL 约束、默认值、更新规则、注释和索引字段顺序。
3. 每张表必须保留 reserve1、reserve2、reserve3。
4. 不得新增 platform_code；银行已经由物理表名确定。
5. 不得接收或保存来源业务物理表名。
6. 只允许根据目标环境调整 ENGINE、DEFAULT CHARSET、COLLATE、ROW_FORMAT 及必要的数据库方言。
7. 如果目标字符集导致索引长度、TEXT 默认值、DATETIME(3) 或 ON UPDATE 不兼容，
   先列出受影响的表、字段、索引和可选方案，不得静默修改结构。
8. 输出应包含 10 个独立 CREATE TABLE，并附字符集与排序规则选择说明。
```

## 5. 一致性来源

字段字典机械展开自：

```text
cateringsass/catering-modules/catering-front/src/main/resources/db/migration/
V001__create_front_bank_business_transaction_tables.sql
```

字段设计、表路由、幂等、状态迁移、退款并发和敏感数据规则仍以
[09-channel-transaction-ddl.md](./09-channel-transaction-ddl.md) 为准。
