# FRONT-TODO-001 平安五个查询 Handle 后续接入

- 状态：TODO
- 类别：延后能力，不计入当前 P0/P1/P2 缺陷清零
- 代码入口：`PingAnQueryHandle`
- 当前行为：五个公开查询方法在任何银行调用前统一抛出 `ADAPTER_NOT_READY`

## 延后原因

平安查询字段、`bizFunc`、请求路径、账户定位方式和返回数组结构尚未逐接口对照银行 Word 文档确认。
当前 Handle 中的本地常量、字段映射和请求组装只属于历史实现分析草稿，不是正式字段契约，不能通过
整理参数或补字段常量的方式顺带启用。

## 待推进接口

| Front 方法 | 当前状态 | 后续必须确认 |
|---|---|---|
| `queryAccountStatus` | TODO / `ADAPTER_NOT_READY` | 平安是否存在等价能力、请求字段和状态映射 |
| `queryAccountBalance` | TODO / `ADAPTER_NOT_READY` | `63/64/01/02/03` 的能力边界、账户范围及返回结构 |
| `queryTransactionStatus` | TODO / `ADAPTER_NOT_READY` | 普通交易与提现的 `02/03` 选择、原渠道记录定位及状态映射 |
| `queryPlatformTransactionDetails` | TODO / `ADAPTER_NOT_READY` | 是否需要聚合多个 `bizFunc`、分页字段和数组节点 |
| `queryTransactionDetails` | TODO / `ADAPTER_NOT_READY` | 子账户类型、日期范围、分页字段和数组节点 |

## 后续领取前必读

1. [03-平安银行接口能力汇总](../03-平安银行接口能力汇总.md)
2. [10-transaction-query-field-contract](../10-transaction-query-field-contract.md)
3. [05-front代码开发约束](../05-front代码开发约束.md)
4. 对应平安银行 Word 接口文档

## 启用门槛

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

## 当前禁止事项

- 不根据现有草稿猜测或补齐平安查询协议。
- 不为了统一参数而创建未经银行文档确认的正式字段契约。
- 不移除五个入口的待接入挡板。
- 不将本 TODO 计为当前 P0/P1/P2 未修复缺陷。
