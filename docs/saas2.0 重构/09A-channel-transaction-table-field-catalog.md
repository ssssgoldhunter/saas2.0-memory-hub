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
- 业务主/子记录关联字段及业务、银行明确字段；不保存整段数据快照；
- 退款表的原交易关联字段；中信表中五个旧字段为可空兼容列，当前 Handle 不读写；
- 转账、消费表的 `refunded_amount`。

以下内容由最终 SQL 提供方按目标环境要求补充，不在本字段字典中固定：

- `ENGINE`；
- `DEFAULT CHARSET`；
- `COLLATE`；
- `ROW_FORMAT`；
- 表空间、分区及数据库厂商专属语法。

当前代码仓库 V001 使用 `InnoDB + utf8mb4` 只是结构基线，不代表目标环境字符集已经确认。生成最终
SQL 时必须检查目标数据库版本对 `DATETIME`、`CURRENT_TIMESTAMP`、`MEDIUMTEXT`、
`ON UPDATE` 及联合索引字节长度的支持；如需改变字段类型或索引，必须先返回差异清单评审。

### 1.1 字段类型规范（本版统一约定，与 09B 一致）

为保持全表一致，字段类型按以下规则统一，**不出现零碎长度**：

| 字段语义 | 类型 | 说明 |
|---|---|---|
| 主键 / 外部引用主键 | `BIGINT` | 分布式 ID |
| 金额 | `BIGINT` | 单位为人民币分，禁用浮点和元 |
| 乐观锁 | `INT UNSIGNED` | 版本号 |
| 状态 / 类型 / 响应码 / 币种 / 接口编码 / 协议功能码 / 业务日期时间字符串 | `VARCHAR(20)` | 所有枚举类、短编码、协议日期时间字符串统一 20 |
| 流水号 / 业务编号 / 业务记录 ID / hash | `VARCHAR(100)` | 所有编号类统一 100 |
| 创建者 / 更新者 | `VARCHAR(64)` | `create_by`/`update_by`，审计字段，MyBatis-Plus 自动填充 |
| 描述 / 备注 | `VARCHAR(512)` | 响应说明、业务备注 |
| 数据源实例标识 | `VARCHAR(30)` | `data_source_id`，记录数据所在库实例（如 ds_0/ds_2） |
| 临时扩展 | `VARCHAR(1024)` | `reserve1/2/3` |
| 报文快照 | 不设置 | 禁止保存整段业务、银行请求或响应快照 |
| 创建 / 更新时间（审计） | `DATETIME` | `create_time`/`update_time`，MyBatis-Plus 自动填充；对应 Entity 父类 `createTime`/`updateTime` |
| 银行响应时间（业务） | `DATETIME` | `bank_responded_at`，收到银行同步响应时写入 |

**禁止**：使用 `CHAR`、`DATETIME(3)`、`TIMESTAMP`、零碎长度（如 `VARCHAR(64)/32/16/8/6/3`）。
**例外**：`data_source_id` 采用 `VARCHAR(30)`，是数据源实例标识的约定长度，单独豁免上述零碎长度禁令。
**审计字段用父类**：`create_by`/`create_time`/`update_by`/`update_time` 对应 Entity 继承的
`BaseEntity` 审计字段，子类不再重复声明，由 MyBatis-Plus `MetaObjectHandler` 自动填充。
不再使用 `created_at`/`updated_at`（已改用 BaseEntity 的 `create_by`/`create_time`/`update_by`/`update_time`）。

### 1.2 最终可执行 SQL

目标库字符集为 `utf8mb4 / utf8mb4_unicode_ci` 时的完整可执行建表 SQL 见
[09B-channel-transaction-ddl-utf8mb4.sql](09B-channel-transaction-ddl-utf8mb4.sql.md)。
本字段字典的每个字段类型已与 09B 完全一致；09B 额外包含 `ENGINE/CHARSET/COLLATE/ROW_FORMAT`
和索引长度兼容性核查。

## 2. 表和字段数量

| 序号 | 表名 | 字段数 | 表用途 |
|---:|---|---:|---|
| 1 | `front_citic_transfer_transaction` | 47 | Front 中信转账渠道交易流水 |
| 2 | `front_pingan_transfer_transaction` | 50 | Front 平安转账及转账授权渠道交易流水 |
| 3 | `front_citic_consume_transaction` | 47 | Front 中信消费渠道交易流水 |
| 4 | `front_pingan_consume_transaction` | 47 | Front 平安消费渠道交易流水 |
| 5 | `front_citic_refund_transaction` | 53 | Front 中信真退款渠道交易流水 |
| 6 | `front_pingan_refund_transaction` | 55 | Front 平安退款渠道交易流水 |
| 7 | `front_citic_withdraw_transaction` | 46 | Front 中信提现渠道交易流水 |
| 8 | `front_pingan_withdraw_transaction` | 47 | Front 平安提现渠道交易流水 |
| 9 | `front_citic_platform_pay_transaction` | 43 | Front 中信平台付款渠道交易流水 |
| 10 | `front_citic_platform_receive_transaction` | 43 | Front 中信平台收款渠道交易流水 |

## 3. 逐表完整字段

### 3.1 `front_citic_transfer_transaction`

表说明：Front 中信转账渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信转账渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 TRANSFER |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 19 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方电子账户号（原始值，未加密） |
| 20 | `pay_name` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方名称 |
| 21 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方电子账户号（原始值，未加密） |
| 22 | `rec_name` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方名称 |
| 23 | `amount` | `BIGINT` | 否 | `—` | `—` | 转账金额，单位为人民币分 |
| 24 | `fee` | `BIGINT` | 否 | `0` | `—` | 转账手续费，单位为人民币分 |
| 25 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该原交易累计确认退款金额，单位为人民币分 |
| 26 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 27 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 32 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信原始交易状态，仅供查询与审计 |
| 39 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 40 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 41 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 42 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 43 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 44 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 45 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 46 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 47 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.2 `front_pingan_transfer_transaction`

表说明：Front 平安转账及转账授权渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安转账渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | 能力编码：TRANSFER、TRANSFER_AUTH 或 TRANSFER_AUTH_CODE_RESEND |
| 6 | `auth_type` | `VARCHAR(8)` | 是 | `NULL` | `—` | 授权类型（AuthType枚举：SMS/APP；仅 TRANSFER_AUTH、TRANSFER_AUTH_CODE_RESEND 行写入，普通转账行与历史行为 NULL） |
| 7 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 8 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 9 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 10 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 11 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 12 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 13 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 14 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 15 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 16 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 17 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 18 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 19 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 20 | `pay_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方商户会员编号 |
| 21 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方电子账户号（原始值，未加密） |
| 22 | `pay_name` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方名称 |
| 23 | `rec_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方商户会员编号 |
| 24 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方电子账户号（原始值，未加密） |
| 25 | `rec_name` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方名称 |
| 26 | `amount` | `BIGINT` | 否 | `—` | `—` | 转账或授权交易金额，单位为人民币分 |
| 27 | `fee` | `BIGINT` | 否 | `0` | `—` | 平安转账手续费，单位为人民币分 |
| 28 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该原交易累计确认退款金额，单位为人民币分 |
| 29 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 30 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 31 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安协议业务编号 bizFunc |
| 32 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 33 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 34 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 35 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | INIT：请求 `transTime[0,8)` | 银行请求交易日期，格式 yyyyMMdd；供平安退款原交易定位 |
| 36 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | INIT：请求 `transTime[8,14)` | 银行请求交易时间，格式 HHmmss |
| 37 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 38 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 39 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 40 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 41 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安原始交易状态，仅供查询与审计 |
| 42 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 43 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 44 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 45 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 46 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 47 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 48 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 49 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 50 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.3 `front_citic_consume_transaction`

表说明：Front 中信消费渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信消费渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 CONSUME |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 19 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方电子账户号（原始值，未加密） |
| 20 | `pay_name` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方名称 |
| 21 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方电子账户号（原始值，未加密） |
| 22 | `rec_name` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方名称 |
| 23 | `amount` | `BIGINT` | 否 | `—` | `—` | 消费金额，单位为人民币分 |
| 24 | `fee` | `BIGINT` | 否 | `0` | `—` | 消费手续费，单位为人民币分 |
| 25 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该消费累计确认退款金额，单位为人民币分 |
| 26 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 27 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 32 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信原始交易状态，仅供查询与审计 |
| 39 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 40 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 41 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 42 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 43 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 44 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 45 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 46 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 47 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.4 `front_pingan_consume_transaction`

表说明：Front 平安消费渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安消费渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 CONSUME |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源业务交易逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务交易主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源业务交易子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务系统本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 19 | `pay_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方商户会员编号 |
| 20 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方电子账户号（原始值，未加密） |
| 21 | `pay_name` | `VARCHAR(100)` | 是 | `NULL` | — | 付款方名称 |
| 22 | `rec_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方商户会员编号 |
| 23 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方电子账户号（原始值，未加密） |
| 24 | `rec_name` | `VARCHAR(100)` | 是 | `NULL` | — | 收款方名称 |
| 25 | `amount` | `BIGINT` | 否 | `—` | `—` | 消费金额，单位为人民币分 |
| 26 | `fee` | `BIGINT` | 否 | `0` | `—` | 平安消费手续费，单位为人民币分 |
| 27 | `refunded_amount` | `BIGINT` | 否 | `0` | `—` | 该消费累计确认退款金额，单位为人民币分 |
| 28 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 29 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 30 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安协议业务编号 bizFunc |
| 31 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 32 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 33 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等银行侧交易流水 |
| 34 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | INIT：请求 `transTime[0,8)` | 银行请求交易日期，格式 yyyyMMdd；供平安退款原交易定位 |
| 35 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | INIT：请求 `transTime[8,14)` | 银行请求交易时间，格式 HHmmss |
| 36 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 37 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 38 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 39 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 40 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安原始交易状态，仅供查询与审计 |
| 41 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 42 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 43 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 44 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化交易状态 |
| 45 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 46 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 47 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 48 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 49 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.5 `front_citic_refund_transaction`

表说明：Front 中信真退款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信退款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 REFUND |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局退款渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源退款业务逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源退款业务主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源退款业务子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 退款业务本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 退款业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款业务子流水号或子订单号 |
| 15 | `original_capability` | `VARCHAR(20)` | 是 | `NULL` | `—` | 兼容保留列；中信当前退款路径不使用且不回填 |
| 16 | `original_channel_transaction_id` | `BIGINT` | 是 | `NULL` | `—` | 兼容保留列；中信当前退款路径不使用且不回填 |
| 17 | `original_front_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 兼容保留列；中信当前退款路径不使用且不回填 |
| 18 | `original_biz_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 兼容保留列；中信当前退款路径不使用且不回填 |
| 19 | `original_biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 兼容保留列；中信当前退款路径不使用且不回填 |
| 20 | `original_biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 当前中信退款实际使用的原业务主流水号 |
| 21 | `original_biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 当前中信退款实际使用的原业务子流水号；应用层必填 |
| 22 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款付款方业务门店编码 |
| 23 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款付款方业务门店 ID |
| 24 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款收款方业务门店编码 |
| 25 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款收款方业务门店 ID |
| 26 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 退款付款方电子账户号 |
| 27 | `pay_name` | `VARCHAR(100)` | 是 | `NULL` | — | 退款付款方名称 |
| 28 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 退款收款方电子账户号 |
| 29 | `rec_name` | `VARCHAR(100)` | 是 | `NULL` | — | 退款收款方名称 |
| 30 | `amount` | `BIGINT` | 否 | `—` | `—` | 本次真退款金额，单位为人民币分 |
| 31 | `fee` | `BIGINT` | 否 | `0` | `—` | 本次退款手续费，单位为人民币分 |
| 32 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 33 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 34 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信真退款业务编号 bizFunc，当前为 23 |
| 35 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 36 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 37 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等退款流水 |
| 38 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行退款日期，格式 yyyyMMdd |
| 39 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行退款时间，格式 HHmmss |
| 40 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 41 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 42 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 43 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 44 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信原始退款状态，仅供查询与审计 |
| 45 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 46 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 47 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 48 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化退款状态 |
| 49 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 50 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 51 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 52 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 53 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_original_transaction` | `original_capability` → `original_channel_transaction_id` |
| INDEX | `idx_front_original_ssn` | `original_front_ssn` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.6 `front_pingan_refund_transaction`

表说明：Front 平安退款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安退款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 REFUND |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局退款渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源退款业务逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源退款业务主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源退款业务子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 退款业务本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 退款业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款业务子流水号或子订单号 |
| 15 | `original_capability` | `VARCHAR(20)` | 否 | `—` | `—` | 原渠道交易能力，当前允许 TRANSFER 或 CONSUME |
| 16 | `original_channel_transaction_id` | `BIGINT` | 否 | `—` | `—` | 同银行原转账或消费渠道表记录主键 |
| 17 | `original_front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | 原 Front 渠道交易流水号 |
| 18 | `original_biz_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 原业务交易主表记录 ID（选填，TODO-002 §2.1 裁决：契约选填，目标 DDL 已同步可空） |
| 19 | `original_biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 原业务交易子表或明细表记录 ID |
| 20 | `original_biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 原业务主流水号或主订单号 |
| 21 | `original_biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 原业务子流水号或子订单号 |
| 22 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款付款方业务门店编码 |
| 23 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款付款方业务门店 ID |
| 24 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款收款方业务门店编码 |
| 25 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 退款收款方业务门店 ID |
| 26 | `pay_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 退款付款方商户会员编号 |
| 27 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 退款付款方电子账户号 |
| 28 | `pay_name` | `VARCHAR(100)` | 是 | `NULL` | — | 退款付款方名称 |
| 29 | `rec_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 退款收款方商户会员编号 |
| 30 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 退款收款方电子账户号 |
| 31 | `rec_name` | `VARCHAR(100)` | 是 | `NULL` | — | 退款收款方名称 |
| 32 | `amount` | `BIGINT` | 否 | `—` | `—` | 本次退款金额，单位为人民币分 |
| 33 | `fee` | `BIGINT` | 否 | `0` | `—` | 本次退款手续费，单位为人民币分 |
| 34 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 35 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 36 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安退款协议业务编号 bizFunc |
| 37 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 38 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 39 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等退款流水 |
| 40 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行退款日期，格式 yyyyMMdd |
| 41 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行退款时间，格式 HHmmss |
| 42 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 43 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 44 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 45 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 46 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安原始退款状态，仅供查询与审计 |
| 47 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 48 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 49 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 50 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化退款状态 |
| 51 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 52 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 53 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 54 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 55 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_original_transaction` | `original_capability` → `original_channel_transaction_id` |
| INDEX | `idx_front_original_ssn` | `original_front_ssn` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.7 `front_citic_withdraw_transaction`

表说明：Front 中信提现渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信提现渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 WITHDRAW |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局提现渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源提现业务逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源提现业务主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源提现业务子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 提现业务本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 提现业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现收款方业务门店 ID |
| 19 | `withdraw_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 提现电子账户号（原始值，未加密） |
| 20 | `withdraw_account_name` | `VARCHAR(100)` | 是 | `NULL` | — | 提现账户名称 |
| 21 | `bank_card_no` | `VARCHAR(100)` | 是 | `NULL` | — | 提现银行卡号（原始值，未加密） |
| 22 | `bank_card_holder_name` | `VARCHAR(100)` | 是 | `NULL` | — | 银行卡持卡人姓名 |
| 23 | `amount` | `BIGINT` | 否 | `—` | `—` | 提现金额，单位为人民币分 |
| 24 | `fee` | `BIGINT` | 否 | `0` | `—` | 提现手续费，单位为人民币分 |
| 25 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 26 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 27 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信提现协议业务编号 bizFunc |
| 28 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 29 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 30 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等提现流水 |
| 31 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行提现日期，格式 yyyyMMdd |
| 32 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行提现时间，格式 HHmmss |
| 33 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 34 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 35 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 36 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 37 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信原始提现状态，仅供查询与审计 |
| 38 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 39 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 40 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 41 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化提现状态 |
| 42 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 43 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 44 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 45 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 46 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.8 `front_pingan_withdraw_transaction`

表说明：Front 平安提现渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 平安提现渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 WITHDRAW |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局提现渠道流水号，同时作为本次银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源提现业务逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源提现业务主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源提现业务子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 提现业务本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 提现业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 提现收款方业务门店 ID |
| 19 | `withdraw_member_id` | `VARCHAR(100)` | 是 | `NULL` | — | 提现商户会员编号 |
| 20 | `withdraw_account_id` | `VARCHAR(100)` | 是 | `NULL` | — | 提现电子账户号（原始值，未加密） |
| 21 | `withdraw_account_name` | `VARCHAR(100)` | 是 | `NULL` | — | 提现账户名称 |
| 22 | `bank_card_no` | `VARCHAR(100)` | 是 | `NULL` | — | 提现银行卡号（原始值，未加密） |
| 23 | `bank_card_holder_name` | `VARCHAR(100)` | 是 | `NULL` | — | 银行卡持卡人姓名 |
| 24 | `amount` | `BIGINT` | 否 | `—` | `—` | 提现金额，单位为人民币分 |
| 25 | `fee` | `BIGINT` | 否 | `0` | `—` | 平安提现手续费，单位为人民币分 |
| 26 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 27 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安协议渠道编号 chnlNo |
| 28 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安提现协议业务编号 bizFunc |
| 29 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 30 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 31 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等提现流水 |
| 32 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行提现日期，格式 yyyyMMdd |
| 33 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行提现时间，格式 HHmmss |
| 34 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 35 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 36 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安业务层原始响应码 sysRespCode |
| 37 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 平安业务层原始响应说明 sysRespDesc |
| 38 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 平安原始提现状态，仅供查询与审计 |
| 39 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 40 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 41 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 42 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化提现状态 |
| 43 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 44 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 45 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 46 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 47 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.9 `front_citic_platform_pay_transaction`

表说明：Front 中信平台付款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信平台付款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 PLATFORM_PAY |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局平台付款渠道流水号，同时作为银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源平台付款业务逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源平台付款业务主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源平台付款业务子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 平台付款业务本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 平台付款业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 平台付款业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 19 | `rec_account_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方电子账户号（平台付款时用户是收款方）（原始值，未加密） |
| 20 | `rec_name` | `VARCHAR(200)` | 是 | `NULL` | `—` | 收款方电子账户户名 |
| 21 | `amount` | `BIGINT` | 否 | `—` | `—` | 平台付款金额，单位为人民币分 |
| 22 | `fee` | `BIGINT` | 否 | `0` | `—` | 平台付款手续费，单位为人民币分 |
| 23 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 24 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 25 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信平台付款协议业务编号 bizFunc |
| 26 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 27 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 28 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等平台付款流水 |
| 29 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 30 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 31 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 32 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 33 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 34 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 35 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信原始平台付款状态，仅供查询与审计 |
| 36 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 37 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 38 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 39 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化平台付款状态 |
| 40 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 41 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 42 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 43 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 44 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

### 3.10 `front_citic_platform_receive_transaction`

表说明：Front 中信平台收款渠道交易流水。

| 序号 | 字段名 | 数据类型 | 允许 NULL | 默认值 | 更新规则 | 字段说明 |
|---:|---|---|:---:|---|---|---|
| 1 | `id` | `BIGINT` | 否 | `—` | `—` | 中信平台收款渠道记录主键，由 Front 生成分布式 ID |
| 2 | `tenant_id` | `VARCHAR(100)` | 否 | `—` | `—` | SaaS 租户标识 |
| 3 | `store_id` | `VARCHAR(100)` | 否 | `—` | `—` | 发起本次调用的业务门店 ID |
| 4 | `data_source_id` | `VARCHAR(30)` | 否 | `''` | `—` | 数据源实例标识（如 ds_0/ds_2），记录数据所在库实例 |
| 5 | `capability` | `VARCHAR(20)` | 否 | `—` | `—` | Front 能力编码；本表固定为 PLATFORM_RECEIVE |
| 6 | `front_ssn` | `VARCHAR(100)` | 否 | `—` | `—` | Front 全局平台收款渠道流水号，同时作为银行请求 transSsn |
| 7 | `front_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 返回业务系统的 Front 查询标识 |
| 8 | `biz_system_code` | `VARCHAR(100)` | 否 | `—` | `—` | 来源业务系统编码 |
| 9 | `biz_transaction_type` | `VARCHAR(20)` | 否 | `—` | `—` | 来源平台收款业务逻辑类型，不保存物理表名 |
| 10 | `biz_transaction_id` | `VARCHAR(100)` | 否 | `—` | `—` | 来源平台收款业务主表记录 ID |
| 11 | `biz_sub_transaction_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 来源平台收款业务子表或明细表记录 ID |
| 12 | `biz_request_no` | `VARCHAR(100)` | 否 | `—` | `—` | 平台收款业务本次调用唯一号 |
| 13 | `biz_order_no` | `VARCHAR(100)` | 否 | `—` | `—` | 平台收款业务主流水号或主订单号 |
| 14 | `biz_sub_order_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 平台收款业务子流水号或子订单号 |
| 15 | `pay_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店编码 |
| 16 | `pay_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方业务门店 ID |
| 17 | `rec_store_no` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店编码 |
| 18 | `rec_store_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 收款方业务门店 ID |
| 19 | `pay_account_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 付款方电子账户号（平台收款时用户是付款方）（原始值，未加密） |
| 20 | `pay_name` | `VARCHAR(200)` | 是 | `NULL` | `—` | 付款方电子账户户名 |
| 21 | `amount` | `BIGINT` | 否 | `—` | `—` | 平台收款金额，单位为人民币分 |
| 22 | `fee` | `BIGINT` | 否 | `0` | `—` | 平台收款手续费，单位为人民币分 |
| 23 | `currency` | `VARCHAR(20)` | 否 | `'CNY'` | `—` | 币种 |
| 24 | `bank_channel_no` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信协议渠道编号 chnlNo |
| 25 | `bank_biz_func` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信平台收款协议业务编号 bizFunc |
| 26 | `external_platform_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行 reserve 中的外联平台流水 laasSsn |
| 27 | `bank_query_id` | `VARCHAR(100)` | 是 | `NULL` | `—` | 电子钱包或银行返回的 queryId |
| 28 | `bank_user_ssn` | `VARCHAR(100)` | 是 | `NULL` | `—` | 银行返回的 USER_SSN 等平台收款流水 |
| 29 | `bank_trans_date` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易日期，格式 yyyyMMdd |
| 30 | `bank_trans_time` | `VARCHAR(20)` | 是 | `NULL` | `—` | 银行交易时间，格式 HHmmss |
| 31 | `wallet_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应码 errCode |
| 32 | `wallet_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 电子钱包平台层原始响应说明 errInfo |
| 33 | `bank_resp_code` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信业务层原始响应码 sysRespCode |
| 34 | `bank_resp_desc` | `VARCHAR(512)` | 是 | `NULL` | `—` | 中信业务层原始响应说明 sysRespDesc |
| 35 | `bank_status` | `VARCHAR(20)` | 是 | `NULL` | `—` | 中信原始平台收款状态，仅供查询与审计 |
| 36 | `reserve1` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 1，稳定后迁移为明确业务列 |
| 37 | `reserve2` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 2，稳定后迁移为明确业务列 |
| 38 | `reserve3` | `VARCHAR(1024)` | 是 | `NULL` | `—` | 临时扩展字段 3，稳定后迁移为明确业务列 |
| 39 | `front_status` | `VARCHAR(20)` | 否 | `'INIT'` | `—` | Front 归一化平台收款状态 |
| 40 | `bank_responded_at` | `DATETIME` | 是 | `NULL` | `—` | 收到银行同步响应时间 |
| 41 | `create_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 创建者 |
| 42 | `create_time` | `DATETIME` | 是 | `NULL` | `—` | 创建时间 |
| 43 | `update_by` | `VARCHAR(64)` | 是 | `NULL` | `—` | 更新者 |
| 44 | `update_time` | `DATETIME` | 是 | `NULL` | `—` | 更新时间 |

索引：

| 类型 | 索引名 | 字段顺序 |
|---|---|---|
| PRIMARY | `PRIMARY` | `id` → `tenant_id` → `store_id` |
| INDEX | `idx_front_ssn` | `front_ssn` |
| INDEX | `idx_front_business_main` | `tenant_id` → `biz_system_code` → `biz_transaction_type` → `biz_transaction_id` |
| INDEX | `idx_front_business_sub` | `tenant_id` → `biz_system_code` → `biz_sub_transaction_id` |
| INDEX | `idx_front_biz_order` | `tenant_id` → `biz_order_no` → `biz_sub_order_no` |
| INDEX | `idx_front_bank_query` | `bank_query_id` |
| INDEX | `idx_front_bank_user_ssn` | `bank_user_ssn` |
| INDEX | `idx_front_status_time` | `tenant_id` → `front_status` → `update_time` |
| INDEX | `idx_front_store_time` | `tenant_id` → `store_id` → `create_time` |
| INDEX | `idx_front_data_source` | `tenant_id` → `data_source_id` |

## 4. 最终 SQL 已生成

目标库字符集 `utf8mb4 / utf8mb4_unicode_ci` 的完整可执行建表 SQL 已在
[09B-channel-transaction-ddl-utf8mb4.sql](09B-channel-transaction-ddl-utf8mb4.sql.md) 中生成，
包含 10 张表完整 `CREATE TABLE`、`ENGINE/CHARSET/COLLATE/ROW_FORMAT` 和索引长度兼容性核查。

后续无需再让 AI 重新生成 SQL；若目标库要求的字符集或排序规则与 09B 当前目标（`utf8mb4 / utf8mb4_unicode_ci`）不同，
再按以下约束派生新版本：

```text
1. 必须保持“银行 + 交易业务”10 张物理表，禁止合并成统一渠道表。
2. 必须逐表保留全部字段、字段顺序、类型、NULL 约束、默认值、更新规则、注释和索引字段顺序。
3. 字段类型遵守 §1.1 规范（VARCHAR(20/30/100/512/1024)、BIGINT、DATETIME、MEDIUMTEXT、INT UNSIGNED）。
4. 每张表必须保留 reserve1、reserve2、reserve3。
5. 不得新增 platform_code；银行已经由物理表名确定。
6. 不得接收或保存来源业务物理表名。
7. 只允许根据目标环境调整 ENGINE、DEFAULT CHARSET、COLLATE、ROW_FORMAT 及必要的数据库方言。
8. 如果目标字符集导致索引长度、TEXT 默认值、DATETIME 或 ON UPDATE 不兼容，
   先列出受影响的表、字段、索引和可选方案，不得静默修改结构。
9. 输出应包含 10 个独立 CREATE TABLE，并附字符集与排序规则选择说明。
```

## 5. 一致性来源

字段字典机械展开自：

```text
cateringsass/catering-modules/catering-front/src/main/resources/db/migration/
V001__create_front_bank_business_transaction_tables.sql
```

字段设计、表路由、重复交易检查、状态迁移、退款并发和敏感数据规则仍以
[09-channel-transaction-ddl.md](./09-channel-transaction-ddl.md) 为准。
