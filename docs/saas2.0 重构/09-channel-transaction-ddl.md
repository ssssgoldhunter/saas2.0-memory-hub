# Front 分银行、分交易业务渠道流水 DDL 与落库规则

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：DDL 首版已确认
> 确认日期：2026-08-04
> 范围：中信、平安的转账、消费、退款、提现，以及中信平台付款、平台收款

> 2026-08-09 中信退款边界修订：中信退款不查询或关联 Front 本地原转账、消费记录，不维护累计退款
> 金额。当前仅 `original_biz_order_no + original_biz_sub_order_no` 用于原交易定位；
> `original_capability/original_channel_transaction_id/original_front_ssn/original_biz_transaction_id/
> original_biz_sub_transaction_id` 作为可空兼容列保留，中信 Handle 不读写。
> 平安退款结构已按 `TODO-002` 确认：必须关联同银行原 transfer/consume 渠道记录，并保存
> `original_capability/original_channel_transaction_id/original_front_ssn`。

## 1. 最终拆表结论

渠道交易数据必须同时按银行和交易业务拆分物理表。禁止再建立一张
`front_channel_transaction` 统一承载全部银行与交易。

| 银行 | 交易业务 | 物理表 | 说明 |
|---|---|---|---|
| 中信 | 转账 | `front_citic_transfer_transaction` | `capability=TRANSFER` |
| 中信 | 消费 | `front_citic_consume_transaction` | `capability=CONSUME` |
| 中信 | 真退款 | `front_citic_refund_transaction` | 调用真实退款接口，不得以反向转账代替 |
| 中信 | 提现 | `front_citic_withdraw_transaction` | `capability=WITHDRAW` |
| 中信 | 平台付款 | `front_citic_platform_pay_transaction` | 中信独有 |
| 中信 | 平台收款 | `front_citic_platform_receive_transaction` | 中信独有 |
| 平安 | 转账及授权辅助调用 | `front_pingan_transfer_transaction` | 由 `capability` 区分 3 个方法 |
| 平安 | 消费 | `front_pingan_consume_transaction` | `capability=CONSUME` |
| 平安 | 退款 | `front_pingan_refund_transaction` | 平安真实退款能力 |
| 平安 | 提现 | `front_pingan_withdraw_transaction` | `capability=WITHDRAW` |

平安转账表中的 `capability` 允许：

```text
TRANSFER
TRANSFER_AUTH
TRANSFER_AUTH_CODE_RESEND
```

中信不支持后两个平安授权能力，因此不创建中信授权表；平安不支持 `PLATFORM_PAY` 和
`PLATFORM_RECEIVE`，因此不创建平安平台收付款空表。

代码仓库中的完整可执行结构基线：

```text
cateringsass/catering-modules/catering-front/src/main/resources/db/migration/
V001__create_front_bank_business_transaction_tables.sql
```

可直接交给其他 AI 或 DBA 的逐表字段字典：

```text
09A-channel-transaction-table-field-catalog.md
```

`09A` 已将 10 张表分别展开，逐字段列出字段名、顺序、数据类型、NULL 约束、默认值、更新规则、业务说明以及
每张表的主键和普通索引。最终 SQL 提供方只根据目标环境补充或调整 `ENGINE/CHARSET/COLLATE/
ROW_FORMAT`；如果字符集导致索引长度或数据库方言不兼容，必须先给出差异，不得静默改变字段设计。

当前 Entity、VO、Mapper、Service 和 Handle 写入骨架已经落地；数据库迁移执行组件及目标环境建表仍需
单独执行，不能把 SQL 文件存在等同于已经建表。

## 2. 表路由规则

两级路由职责必须分离：

```text
FrontRequest.baseData.platformCode
→ 当前 API 方法内部固定 capability
→ Transaction Registry 按 (BankCode, capability) 选择具体能力 Handler
→ 该 Handler 使用自己的固定业务 Repository
→ 具体 Repository 执行固定表 SQL
```

约束：

- 对外请求不传 `capability` 或数据库表名；当前 API 方法在服务内部固定确定业务类型；
- 交易领域 Registry 使用类型安全的 `(BankCode, FrontCapability)` 直接定位能力 Handler；不得把 bizFunc、
  账户类型或物理表名混入 key；
- `capability` 同时作为渠道流水记录值，平安转账共享表用它区分三种真实调用；不得用于猜测领域、统一
  能力预校验、公共 Dispatch 二次分派或动态选择 Repository；
- 表由当前能力 Handler 固定，不得字符串拼接动态表名；
- 表名中的银行维度是事实来源，表内不重复保存可产生矛盾的 `platform_code`；
- 具体银行未注册该 capability 时由 Registry 返回 `CAPABILITY_NOT_SUPPORTED`，不得写入别的业务表；
- 状态查询只在 `platformCode` 已选中的银行范围内，通过明确业务定位条件或固定 Repository 顺序查找，
  禁止扫描另一家银行，也不得让调用方提交物理表名；
- `frontSsn` 由 Front 的全局流水算法生成；每张表再使用唯一索引防止表内重复。跨表唯一性不能依赖
  单表索引，必须由生成器保证。

## 3. 业务基础数据与业务表关联

所有交易请求基础对象 `BaseTransactionBusinessData` 必须提供：

| Java 字段 | 数据库字段 | 说明 |
|---|---|---|
| `bizSystemCode` | `biz_system_code` | 来源业务系统编码 |
| `bizTransactionType` | `biz_transaction_type` | 来源业务交易逻辑类型，不是物理表名 |
| `bizTransactionId` | `biz_transaction_id` | 来源业务交易主表记录 ID |
| `bizSubTransactionId` | `biz_sub_transaction_id` | 来源业务交易子表或明细表记录 ID，可空 |
| `bizRequestNo` | `biz_request_no` | 当前能力的一次业务调用标识；不参与本期重复交易键 |
| `bizOrderNo` | `biz_order_no` | 业务主流水或主订单号 |
| `bizSubOrderNo` | `biz_sub_order_no` | 业务子流水或子订单号，可空 |

业务关联键为：

```text
tenantId
+ bizSystemCode
+ bizTransactionType
+ bizTransactionId
+ bizSubTransactionId（存在子记录时）
```

每张表还必须按明确列保存公共金额、手续费、币种、付款/收款门店，以及当前银行业务需要的账户、
会员、姓名、卡号和银行响应字段。不保存完整 `baseData/specialData`、银行请求或银行响应快照。

禁止：

- 接收、保存或执行来源业务物理表名；
- 对其他微服务的业务表建立数据库外键；
- 用 `bizRequestNo` 代替业务主表 ID；
- 使用整段 JSON/text 快照代替明确业务字段；
- 将 appKey、私钥、验证码、支付密码或完整租户银行配置落库。

本期渠道表允许保存本系统内部使用的账户、会员、姓名和卡号原始值，不要求数据库字段加密；这些值仍是
敏感数据，日志、异常消息和普通接口响应不得输出。
ShardingSphere 数据源连接配置的加密和安全加固本阶段暂不处理，后续由部署任务单独收口；银行协议要求的
签名、传输或字段加密仍必须保留。

Java 统一使用 `String` 承载业务记录 ID，以兼容数字 ID 和 UUID。

## 4. 每张表的通用字段组

10 张表均包含以下字段组；精确类型、长度、默认值、注释和索引以
[09A 逐表完整字段字典](./09A-channel-transaction-table-field-catalog.md) 及代码仓库 V001 SQL 为准。

| 字段组 | 主要字段 | 用途 |
|---|---|---|
| 主键与租户 | `id/tenant_id/store_id/data_source_id` | 数据隔离、门店审计和库实例标识 |
| 能力 | `capability` | 确认实际调用能力 |
| Front 标识 | `front_ssn/front_query_id` | 渠道查询及对外关联 |
| 业务关联 | `biz_system_code/biz_transaction_type/biz_transaction_id/biz_sub_transaction_id` | 关联来源业务交易表 |
| 业务流水 | `biz_request_no/biz_order_no/biz_sub_order_no` | 调用标识、重复交易检查和业务订单查询 |
| 门店 | `pay_store_no/pay_store_id/rec_store_no/rec_store_id` | 保存业务收付款门店 |
| 银行动态业务字段 | `pay/rec/withdraw/bank_card` 相关字段 | 从请求 `specialData` 白名单解析后保存 |
| 金额 | `amount/fee/currency` | 保存公共业务基础数据，金额单位均为分 |
| 银行协议 | `bank_channel_no/bank_biz_func/external_platform_ssn` | 保存 Handle 实际使用的协议标识 |
| 银行流水 | `bank_query_id/bank_user_ssn/bank_trans_date/bank_trans_time` | 查询和排障 |
| 两层银行响应 | `wallet_resp_code/desc`、`bank_resp_code/desc`、`bank_status` | 保存钱包系统层与银行业务层原始结果 |
| Front 状态 | `front_status` | 保存归一化交易状态 |
| 审计时间 | `create_time/update_time/bank_responded_at` | 创建、更新和银行响应时间 |
| 临时扩展 | `reserve1/reserve2/reserve3` | 联调期短期扩展 |

`data_source_id` 在每张表中的列定义为：

```text
`data_source_id` VARCHAR(30) NOT NULL DEFAULT '' COMMENT '数据源实例标识（如 ds_0/ds_2），记录数据所在库实例'
```

位置紧跟 `store_id` 列之后。该列由 Handle 在 INSERT 渠道流水时通过 `data.getDataSourceId()` 写入，
仅作实例标识记录，不参与 ShardingSphere 分片路由决策（路由仍按 `tenant_id`）。10 张表（中信 6 张 +
平安 4 张）均按此统一定义，已内置于 [09-final-rebuild-all-tables.sql](./09-final-rebuild-all-tables.sql)
（DROP+CREATE 一步到位，不需要 ALTER）。

当前转账、消费表仍存在以下旧字段：

```text
refunded_amount  // 平安 transfer/consume 兼容保留；TODO-002 当前不读取、不更新，不作为退款资格判断依据
```

退款表的 `original_*` 字段分为当前有效定位字段和兼容保留字段：

```text
original_biz_order_no              // 当前中信退款必填，映射 ORI_BUSS_ID
original_biz_sub_order_no          // 当前中信退款必填，映射 ORI_BUSS_SUB_ID
original_capability                // 可空兼容列，当前中信 Handle 不读写
original_channel_transaction_id    // 可空兼容列，当前中信 Handle 不读写
original_front_ssn                 // 可空兼容列，当前中信 Handle 不读写
original_biz_transaction_id        // 可空兼容列，当前中信 Handle 不读写
original_biz_sub_transaction_id    // 可空兼容列，当前中信 Handle 不读写
```

五个兼容列只为保持现有表结构可平滑迁移，必须允许 `NULL`，不得因其存在要求 Handle
回填，也不得依赖它们查询本地原交易。现有库执行
[09C-citic-refund-legacy-columns-nullable.sql](09C-citic-refund-legacy-columns-nullable.sql) 放宽非空约束；新建库直接使用
09B 或 09-final。

## 5. 三个 reserve 字段约束

每一张渠道交易表都必须包含：

```text
reserve1 VARCHAR(1024)
reserve2 VARCHAR(1024)
reserve3 VARCHAR(1024)
```

使用规则：

- 只处理联调期或紧急兼容期的短期扩展；
- 必须在使用位置记录字段含义、来源、启用时间和清理计划；
- 同一表、同一版本内，一个 reserve 字段只能表达一种含义；
- 字段稳定后必须通过 DDL 增加明确业务列并迁移数据；
- 禁止保存密钥、验证码、支付密码、完整账户配置或无限制 JSON；
- 不得使用数据库 reserve 字段绕开 API `baseData/specialData` 字段契约。

## 6. 方法到物理表映射

| Front 方法 | 中信表 | 平安表 |
|---|---|---|
| `transfer` | `front_citic_transfer_transaction` | `front_pingan_transfer_transaction` |
| `transferAuth` | 不支持，不落库 | `front_pingan_transfer_transaction` |
| `resendTransferAuthCode` | 不支持，不落库 | `front_pingan_transfer_transaction` |
| `consume` | `front_citic_consume_transaction` | `front_pingan_consume_transaction` |
| `refund` | `front_citic_refund_transaction` | `front_pingan_refund_transaction` |
| `withdraw` | `front_citic_withdraw_transaction` | `front_pingan_withdraw_transaction` |
| `platformPay` | `front_citic_platform_pay_transaction` | 不支持，不落库 |
| `platformReceive` | `front_citic_platform_receive_transaction` | 不支持，不落库 |

授权码申请或重发发生真实银行调用时，每次都生成新的 `frontSsn` 和独立记录；验证码、支付密码不得进入
任何表字段。

## 7. 标准写入时机

```text
请求校验
→ 当前 API 方法内部固定 capability 并进入交易领域
→ Transaction Registry 按 (BankCode, capability) 选择能力 Handler
→ 租户银行配置加载成功
→ 通用执行节点进入已选能力 Handler
→ 能力 Handler 使用固定 Repository
→ 在当前银行业务表执行重复交易检查
→ Handle 按银行规则生成 frontSsn
→ INSERT INIT，保存业务关联字段和明确业务字段
→ 组装银行请求
→ UPDATE SENDING 和银行协议字段
→ 调用银行
→ UPDATE 钱包层/银行层原始响应
→ 响应归一化
→ UPDATE Front 响应及最终或非最终状态
```

约束：

- 必须在发送银行请求前成功创建对应银行、对应业务表记录；
- 配置加载失败、银行不支持、具体方法不支持或未接入时不得写其他业务表；
- 流水创建失败时禁止调用银行；
- 银行超时写 `UNKNOWN`，禁止直接写 `FAILED` 或自动重发；
- 银行同步受理但非终态时写 `ACCEPTED/PROCESSING`；
- 查询确认后再更新为 `SUCCESS/FAILED/RETURNED/REFUNDED`；
- 状态更新必须限制目标记录并校验实际更新行数，禁止静默覆盖不存在的记录；
- 表路由结果、记录 ID、`frontSsn`、业务关联键、状态变化和耗时必须记录日志，但禁止记录账户、姓名、
  卡号及银行完整报文。

## 8. 重复交易校验

本期不实现请求 Hash、旧结果重放或“相同请求返回原结果”语义，因此该规则不称为请求幂等。
发送银行请求前，在当前银行、当前交易业务物理表内按以下三项查询：

```text
tenant_id + biz_order_no + biz_sub_order_no
```

处理规则：

1. 三项均相同且已存在记录：返回统一错误“交易已存在”，禁止再次调用银行；
2. 不比较金额、`specialData` 或请求 Hash，也不返回、重放原交易结果；
3. `bizSubOrderNo` 为空时，以数据库空值语义匹配同一 `tenantId + bizOrderNo + 空子流水`；
4. 业务系统确需重新发起交易时，必须使用新的 `bizOrderNo` 或 `bizSubOrderNo`；
5. 平安 `TRANSFER/TRANSFER_AUTH/TRANSFER_AUTH_CODE_RESEND` 共用同一物理表，因此三者之间也执行同一
   重复交易检查。

## 9. 退款边界与并发控制

### 9.1 中信退款

中信退款固定使用请求 `orgBizOrderNo + orgBizSubOrderNo` 组装银行
`ORI_BUSS_ID + ORI_BUSS_SUB_ID`。其他中信协议必填字段由请求 `specialData` 或账户配置按字段契约提供。
Front 不查询本地原转账、消费记录，不校验原交易状态或累计退款金额，也不更新原交易表。

中信仅对本次退款表执行 `tenantId + bizOrderNo + bizSubOrderNo` 重复交易检查；并发请求由该表的
三字段唯一性或等效原子写入规则防止重复发送。部分退款额度、原交易状态和退款资格由上游业务系统及银行负责。

### 9.2 平安退款

平安退款必须只读原 transfer/consume 渠道表补齐银行协议字段：按
`tenantId + originalBizOrderNo + originalBizSubOrderNo` 精确定位，`oriTransSsn` 取原记录
`frontSsn`，并在退款表保存 `original_capability/original_channel_transaction_id/original_front_ssn`
及原账户字段。未命中或双表同时命中均明确失败。

该查询不承担额度控制、原交易资格或累计退款判断，不锁定、不更新原表；`refunded_amount` 当前不读写。

## 10. 明确字段与敏感数据

渠道表只保存 DDL 中定义的明确字段，不保存以下快照字段：

```text
business_base_snapshot_cipher
business_special_snapshot_cipher
bank_request_snapshot_cipher
bank_response_snapshot_cipher
snapshot_key_version
```

以下内容禁止入库：

- appKey、私钥、完整租户银行配置；
- 短信验证码、支付密码；
- 未经白名单映射的整段 `specialData/accountSpecialData`；
- 来源业务物理表名和可执行 SQL。

账户、会员、姓名、卡号等内部业务字段允许按明确列保存原始值，本期不要求数据库字段加密；但这些字段
不得进入日志、异常消息或普通查询 API，银行请求是否加密仍严格按对应银行协议执行。

## 11. 索引和外键

每张表统一提供：

| 索引 | 用途 |
|---|---|
| `idx_front_ssn` | 当前表按 Front 流水定位交易；跨表唯一性由 Front 流水生成规则保证 |
| `idx_front_biz_order` | 当前银行、当前业务表内按主/子订单执行重复交易检查 |
| `idx_front_business_main/sub` | 由来源业务主表或子表反查渠道记录 |
| `idx_front_bank_query` | 通过银行 queryId 查询 |
| `idx_front_bank_user_ssn` | 通过银行 USER_SSN 排障或查询 |
| `idx_front_status_time` | 当前表状态轮询和未知交易补偿 |
| `idx_front_store_time` | 租户门店时间范围审计查询 |
| `idx_front_data_source` (`tenant_id`, `data_source_id`) | 支持按租户+数据源实例查询 |

中信退款的 `idx_front_original_transaction/idx_front_original_ssn` 随兼容列暂时保留，当前 Handle
不依赖这两个索引。后续如需删除，必须另行确认并提供 ALTER 脚本；平安退款保留
`idx_front_original_transaction/idx_front_original_ssn`，用于原渠道关联审计和查询。

所有渠道表均不建立跨表外键。中信退款的原业务完整性由上游业务系统负责，Front 只保存和发送明确字段。

## 12. 分库与分区

> 全新库直接执行 [09-final-rebuild-all-tables.sql](./09-final-rebuild-all-tables.sql) 即可，已含
> `data_source_id` + 账户字段 + 分区 + 组合主键（DROP+CREATE 一步到位，不需要 ALTER）。下面仅描述
> 分库与分区的设计规则。

### 12.1 分库：ShardingSphere-JDBC（STANDARD 分片）

10 张渠道流水表与业务表绑定，分布在多个物理数据库实例中。分库使用 ShardingSphere-JDBC
STANDARD 模式，分片键 `tenant_id`，SQL 自带分片值自动路由，Handle 代码零侵入。

- **分片键**：`tenant_id`（每条 SQL 自带）；
- **分片算法**：`TenantDataSourceShardingAlgorithm`（查配置中心 `tenant_base_config`（JSON），
  解析 `data_source_id` 字段 → 拼 `ds_x`）；
- **配置**：`resources/shardingsphere-config.yaml`，`mode: Standalone`；
- **配置值示例**：`tenant_base_config` = `{"data_source_id":"2"}`；
- **新增库**：加 `ds_x` 数据源 + 配置租户 `tenant_base_config` JSON 的 `data_source_id=x`，不改代码；
- **配置前提**：租户数据源配置属于上线必备配置，正常情况下必须存在；
- **失败策略**：若运行时仍发生配置缺失、JSON 解析失败、`data_source_id` 缺失或目标 `ds_x` 不存在，立即失败；
  禁止默认路由到 `ds_0`、第一个数据源或其他租户数据库；
- **不使用 Hint / dynamic-datasource**。

详细分片算法和配置约束见 [05-front代码开发约束](05-front代码开发约束.md) §3.10.1。

> 说明：`data_source_id` 会存入渠道流水表的 `data_source_id` 列，仅作实例标识记录，不参与
> ShardingSphere 路由决策（路由仍按 `tenant_id`）。该列已内置于
> [09-final-rebuild-all-tables.sql](./09-final-rebuild-all-tables.sql)（DROP+CREATE 一步到位，不需要 ALTER）。

### 12.2 分区：MySQL LINEAR KEY

- **分区方式**：`PARTITION BY LINEAR KEY (tenant_id, store_id) PARTITIONS 30`；
- **ShardingSphere + MySQL 分区共存**：两层路由不冲突。

分区定义已内置于 [09-final-rebuild-all-tables.sql](./09-final-rebuild-all-tables.sql) §2（DROP+CREATE
一步到位，不需要 ALTER）。

### 12.3 FeignClient 拦截器（通用）

4 个必要参数（tenantId/clientId/platformCode/dataSourceId）由 `catering-common-feign` 的
拦截器链自动传递和注入。所有服务引入 `catering-common-feign` 即生效。

详细链路和类职责见 [05-front代码开发约束](05-front代码开发约束.md) §3.10.3。

> 落库衔接：Handle 在 INSERT 渠道流水时，通过 `data.getDataSourceId()` 把 dataSourceId 写入
> `data_source_id` 列，使拦截器链注入的实例标识落到每条流水记录上。
