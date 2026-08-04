# Front 分银行、分交易业务渠道流水 DDL 与落库规则

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：DDL 首版已确认
> 确认日期：2026-08-04
> 范围：中信、平安的转账、消费、退款、提现，以及中信平台付款、平台收款

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

当前只落地 DDL 和 API 业务关联字段。Entity、Mapper、Repository、显式表路由、状态机服务及真实写入
流程仍待后续实现；当前项目也尚未接入数据库迁移执行组件，不能把 SQL 文件存在等同于已自动建表。

## 2. 表路由规则

两级路由职责必须分离：

```text
FrontRequest.baseData.platformCode
→ TransactionRouter 选择中信或平安 TransactionHandle
→ Application Service / 持久化端口按 capability 选择该银行对应业务表
→ 具体 Repository 执行固定表 SQL
```

约束：

- 对外请求只传 `platformCode` 和业务逻辑类型，不允许传数据库表名；
- Router 仍只按银行选择 Handle，不改回复合路由键；
- 表路由必须使用枚举或显式 `switch` 映射到固定 Repository，禁止字符串拼接动态表名；
- 表名中的银行维度是事实来源，表内不重复保存可产生矛盾的 `platform_code`；
- 未支持能力在进入持久化前抛 `CAPABILITY_NOT_SUPPORTED`，不得写入别的业务表；
- 状态查询已知 `platformCode + capability` 时直接访问单表；只有 `frontSsn` 时，只在该银行的有限业务表
  中通过固定 `UNION ALL` 或固定 Repository 顺序定位，禁止扫描另一家银行；
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
| `bizRequestNo` | `biz_request_no` | 当前能力的一次调用幂等号 |
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

每张表还必须保存公共金额、手续费、币种、业务日期时间、付款/收款门店及业务备注。为避免具体交易
对象新增字段后丢失信息，每条记录同时保存：

```text
business_base_snapshot_cipher
business_special_snapshot_cipher
```

前者是完整 `baseData` 的加密快照，后者是按当前“银行 + 能力”白名单过滤后的 `specialData` 加密快照。
因此“保留业务基础数据”同时包含可索引的明确列和用于审计、重放分析的完整加密快照。

禁止：

- 接收、保存或执行来源业务物理表名；
- 对其他微服务的业务表建立数据库外键；
- 用 `bizRequestNo` 代替业务主表 ID；
- 只保存快照而漏掉上述明确业务关联列；
- 明文保存卡号、姓名、手机号、证件号等敏感业务数据。

Java 统一使用 `String` 承载业务记录 ID，以兼容数字 ID 和 UUID。

## 4. 每张表的通用字段组

10 张表均包含以下字段组；精确类型、长度、默认值、注释和索引以代码仓库的 V001 SQL 为准。

| 字段组 | 主要字段 | 用途 |
|---|---|---|
| 主键与租户 | `id/tenant_id/store_id` | 数据隔离和门店审计 |
| 能力与配置 | `capability/interface_code/config_version` | 确认实际调用能力、接口和配置版本 |
| Front 标识 | `front_ssn/front_query_id` | 渠道查询及对外关联 |
| 业务关联 | `biz_system_code/biz_transaction_type/biz_transaction_id/biz_sub_transaction_id` | 关联来源业务交易表 |
| 业务流水 | `biz_request_no/biz_order_no/biz_sub_order_no` | 幂等和业务订单查询 |
| 门店 | `pay_store_no/pay_store_id/rec_store_no/rec_store_id` | 保存业务收付款门店 |
| 金额与时间 | `amount/fee/currency/business_date/business_time/business_remark` | 保存公共业务基础数据，金额单位均为分 |
| 幂等摘要 | `request_hash` | HMAC-SHA256 业务请求指纹 |
| 银行协议 | `bank_channel_no/bank_biz_func/external_platform_ssn` | 保存 Handle 实际使用的协议标识 |
| 银行流水 | `bank_query_id/bank_user_ssn/bank_trans_date/bank_trans_time` | 查询和排障 |
| 两层银行响应 | `wallet_resp_code/desc`、`bank_resp_code/desc`、`bank_status` | 保存钱包系统层与银行业务层原始结果 |
| 加密快照 | 4 个 `*_snapshot_cipher` 和 `snapshot_key_version` | 保存过滤、脱敏后的业务及银行数据 |
| Front 结果 | `front_resp_code/front_resp_desc/front_status/front_remark` | 保存统一响应和归一化状态 |
| 审计与并发 | `send_started_at/bank_responded_at/completed_at/created_at/updated_at/version` | 耗时、补偿和乐观锁 |
| 临时扩展 | `reserve1/reserve2/reserve3` | 联调期短期扩展 |

转账、消费原交易表额外保存：

```text
refunded_amount  // 累计已确认退款金额，单位为分
```

退款表额外保存：

```text
original_capability
original_channel_transaction_id
original_front_ssn
original_biz_transaction_id
original_biz_sub_transaction_id
original_biz_order_no
original_biz_sub_order_no
```

`original_capability + original_channel_transaction_id` 用于在同银行的转账表或消费表中定位原交易，
不保存原物理表名。

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
- 禁止保存密钥、验证码、银行卡号、证件号、完整账户配置或无限制 JSON；
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
任何表字段或快照。

## 7. 标准写入时机

```text
请求校验
→ Router 选择银行 Handle 并校验能力
→ 租户银行配置加载成功
→ 按银行 + capability 选择固定业务 Repository
→ 计算 requestHash 并执行当前物理表幂等检查
→ Handle 按银行规则生成 frontSsn
→ INSERT INIT，保存业务关联字段和业务加密快照
→ 组装银行请求
→ UPDATE SENDING、银行协议字段和请求快照
→ 调用银行
→ UPDATE 钱包层/银行层原始响应和响应快照
→ 响应归一化
→ UPDATE Front 响应及最终或非最终状态
```

约束：

- 必须在发送银行请求前成功创建对应银行、对应业务表记录；
- 配置加载失败、银行不支持、能力未接入时不得写其他业务表；
- 流水创建失败时禁止调用银行；
- 银行超时写 `UNKNOWN`，禁止直接写 `FAILED` 或自动重发；
- 银行同步受理但非终态时写 `ACCEPTED/PROCESSING`；
- 查询确认后再更新为 `SUCCESS/FAILED/RETURNED/REFUNDED`；
- 所有状态更新必须携带 `version` 乐观锁条件；
- 表路由结果、记录 ID、`frontSsn`、业务关联键、状态变化和耗时必须记录日志，但禁止记录快照内容。

## 8. 幂等规则

每张物理表的唯一键为：

```text
tenant_id + biz_system_code + capability + biz_request_no
```

`request_hash` 使用服务端密钥对规范化请求计算 HMAC-SHA256。规范化内容至少包括：

```text
tenant/platform/capability
业务主/子记录关联字段
主/子订单字段
金额/手续费/币种
收付款门店
当前能力允许参与幂等判断的业务字段
```

处理规则：

1. 当前目标表不存在唯一键：创建新记录；
2. 已存在且 `request_hash` 相同：返回原结果或当前处理中状态；
3. 已存在但 `request_hash` 不同：返回 `IDEMPOTENCY_CONFLICT`；
4. `SENDING/ACCEPTED/PROCESSING/UNKNOWN` 不允许再次发送资金请求；
5. 业务系统主动重做必须使用新的 `bizRequestNo`，业务主表 ID 可以保持不变。

不得把 appKey、银行 URL、运行时 `transSsn/transTime`、短信验证码放入摘要明文或快照。

## 9. 退款关联与并发控制

退款先按 `platformCode + originalFrontSsn` 在同银行转账、消费表定位原记录，并确认
`original_capability`。必须校验租户、原业务关联、订单、原状态、原金额、原账户和资金类型。

同一数据库事务中：

1. 对对应银行原转账或消费表记录执行 `SELECT ... FOR UPDATE`；
2. 汇总同银行退款表中关联该原记录、状态属于
   `INIT/SENDING/ACCEPTED/PROCESSING/SUCCESS/UNKNOWN` 的退款金额；
3. 校验“已成功 + 正在处理/未知 + 本次退款”不超过原交易 `amount`；
4. 插入同银行退款表 `INIT` 记录后提交事务；
5. 退款确认成功后，使用乐观锁更新原转账或消费表的 `refunded_amount`；
6. `UNKNOWN` 退款在状态确认前持续占用可退款额度。

禁止跨银行关联原交易，也禁止在调用银行期间长时间持有数据库事务或行锁。

## 10. 快照与敏感数据

| 字段 | 内容 |
|---|---|
| `business_base_snapshot_cipher` | 完整业务 `baseData` 的可逆加密快照 |
| `business_special_snapshot_cipher` | 当前银行、当前能力白名单过滤后的 `specialData` 加密快照 |
| `bank_request_snapshot_cipher` | 移除密钥、验证码等敏感内容后的银行请求加密快照 |
| `bank_response_snapshot_cipher` | 过滤后的银行原始响应加密快照 |
| `snapshot_key_version` | 快照密钥版本，只保存版本号 |

以下内容禁止入库：

- appKey、私钥、完整租户银行配置；
- 短信验证码、支付密码；
- 未经白名单过滤的 `specialData/accountSpecialData`；
- 明文银行卡号、证件号、手机号和账户姓名；
- 来源业务物理表名和可执行 SQL。

快照只能通过专用加解密组件访问，不允许 Mapper、日志或普通查询 API 直接返回。

## 11. 索引和外键

每张表统一提供：

| 索引 | 用途 |
|---|---|
| `uk_front_ssn` | 当前表按 Front 流水唯一定位交易 |
| `uk_front_idempotency` | 当前银行、当前业务表内的交易幂等 |
| `idx_front_business_main/sub` | 由来源业务主表或子表反查渠道记录 |
| `idx_front_biz_order` | 由业务主/子订单查询 |
| `idx_front_bank_query` | 通过银行 queryId 查询 |
| `idx_front_bank_user_ssn` | 通过银行 USER_SSN 排障或查询 |
| `idx_front_status_time` | 当前表状态轮询和未知交易补偿 |
| `idx_front_store_time` | 租户门店时间范围审计查询 |

退款表额外提供 `idx_front_original_transaction` 和 `idx_front_original_ssn`。

所有渠道表均不建立跨表外键。业务表可能位于其他服务或数据库；退款与原交易的完整性由 Front
Repository/Domain Service 在事务内显式校验。
