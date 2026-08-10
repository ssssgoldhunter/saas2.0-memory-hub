# Front 后续待办

本文只记录已明确延后、需要后续人工确认或逐项接入的工作，不属于
`12-front-implementation-issues` 缺陷清单，也不计入 P0/P1/P2 Issue 完成度。

## TODO-001 平安五个查询 Handle 逐接口核对和接入

- 状态：待办
- 代码入口：`PingAnQueryHandle`
- 当前行为：五个公开查询方法在任何银行调用前统一抛出 `ADAPTER_NOT_READY`

### 延后原因

平安查询字段、`bizFunc`、请求路径、账户定位方式和返回数组结构尚未逐接口对照银行 Word 文档确认。
当前 Handle 中的本地常量、字段映射和请求组装只属于历史实现分析草稿，不是正式字段契约，不能通过
整理参数或补字段常量的方式顺带启用。

### 待推进接口

| Front 方法 | 当前状态 | 后续必须确认 |
|---|---|---|
| `queryAccountStatus` | 待办 / `ADAPTER_NOT_READY` | 平安是否存在等价能力、请求字段和状态映射 |
| `queryAccountBalance` | 待办 / `ADAPTER_NOT_READY` | `63/64/01/02/03` 的能力边界、账户范围及返回结构 |
| `queryTransactionStatus` | 待办 / `ADAPTER_NOT_READY` | 普通交易与提现的 `02/03` 选择、原渠道记录定位及状态映射 |
| `queryPlatformTransactionDetails` | 待办 / `ADAPTER_NOT_READY` | 是否需要聚合多个 `bizFunc`、分页字段和数组节点 |
| `queryTransactionDetails` | 待办 / `ADAPTER_NOT_READY` | 子账户类型、日期范围、分页字段和数组节点 |

### 后续领取前必读

1. [03-平安银行接口能力汇总](03-平安银行接口能力汇总.md)
2. [10-transaction-query-field-contract](10-transaction-query-field-contract.md)
3. [05-front代码开发约束](05-front代码开发约束.md)
4. 对应平安银行 Word 接口文档

### 启用门槛

1. 每次只领取一个查询接口并完成人工字段核对，不批量启用五个接口。
2. 明确该接口的路径、`bizFunc`、`chnlNo`、顶层字段、`reserve` 字段、响应节点和状态映射。
3. `bizFunc/chnlNo/API path` 作为带业务注释的 Handle 本地固定参数；字段 key 才进入该接口专属的
   PingAn Query ContractKeys，且使用银行协议原始名。
4. 只在对应接口的确认实现中增加实际使用的本地固定参数，不为尚未实现的分支预留草稿常量或映射。
5. 删除该接口对中信 ContractKeys、普通转账 ContractKeys 和未确认字符串字段 key 的借用。
6. 保持 `baseData/specialData/accountSpecialData` 边界及既定 API 返回类型。
7. 只有该接口核对完成后，才允许移除对应入口的 `pendingIntegration()`；其他四个入口继续返回
   `ADAPTER_NOT_READY`。
8. LiteFlow 业务异常写 Slot 后中断，系统异常继续抛出。
9. 按用户当次明确授权决定是否新增测试或执行编译，不以历史编译记录作为验收证据。

### 当前禁止事项

- 不根据现有草稿猜测或补齐平安查询协议。
- 不为了统一参数而创建未经银行文档确认的正式字段契约。
- 不移除五个入口的待接入挡板。
- 不将本待办计为当前 P0/P1/P2 未修复缺陷。

## TODO-002 平安退款边界与协议字段人工确认

- 状态：待办

### 说明

中信退款已确认只承担银行渠道报文装配，不承担原交易状态、累计金额和业务退款资格校验。
该结论不得自动套用到平安退款。当前平安 Handle 也存在查询并锁定原交易、校验状态和累计金额、
更新 `refundedAmount` 的实现，但是否删除以及平安银行请求需要哪些原交易字段，必须先逐项核对平安协议。

### 后续确认内容

1. 平安退款原交易定位字段及顶层/reserve 位置。
2. 业务系统可直接提供哪些字段，哪些必须由 Front 渠道数据补齐。
3. 是否允许部分退款，以及银行如何判定累计金额。
4. 当前 `oriTransSsn`、交易日期和原交易类型的真实来源。
5. 确认前保持独立待办，不纳入中信 `FRONT-P1-005` 修改范围。
