# FRONT-P2-007 Handle 银行固定参数和公共常量口径混用

- 状态：CLOSED
- 优先级：P2
- 影响：同类银行协议固定值有的放公共 ContractKeys、有的放 Handle 常量、有的直接写字符串，后续维护无法判断值是否跨接口共享。

## 修复前证据

- Handle 的 `bizFunc/chnlNo/API` 多数使用 Handle 本地常量。
- 部分固定枚举值继续使用 `*ContractKeys` 中的 value 常量。
- 中信提现的 `WITH_TYPE="00"`、`FEE_TYPE="2"` 仍通过 common-core value 常量读取；这两个值只服务当前
  中信提现接口，应按最新约束放入具体 Handle 本地并保留银行语义注释。

## 边界

- 业务系统组装 `specialData/accountSpecialData` 或读取响应 `specialData` 所需的银行协议原始字段 key，
  放入对应 `*ContractKeys`，并与 API 字段契约、银行协议原始拼写保持一致。
- 银行请求、reserve 和响应取值所需的协议字段 key 继续放在 `*ContractKeys`，Handle 不允许写裸 key。
- `bizFunc/chnlNo/API path` 及 Front 固定上送的类型码、标志位、默认备注只属于具体接口实现，放在
  对应 Handler 本地并写清银行含义，不向业务系统暴露。
- 由业务系统选择并通过 `specialData` 上送的协议枚举值仍属于对外字段契约，可以保留在
  `*ContractKeys`；不得把它们误当成 Handler 固定值删除。

## 验收标准

1. 同一类固定值采用一致口径，不混用公共 value 常量、局部常量和无注释字面量。
2. 删除 common-core 中确认无调用方的 value 常量及其过时文档。
3. Handle 中保留的固定值有明确注释，不出现无法识别含义的裸字符串。
4. 不移动银行协议字段 key，不改变实际发送值。
5. 一次只整理当前领取的银行和具体接口，不顺带重构其他 Handle。

## 当前核验结果（2026-08-09）

- `bizFunc/chnlNo/API path` 保持在具体 Handle 本地；
- 中信转账/消费的币种、自有资金标志/金额和默认备注，中信退款的自有资金标志/金额，中信提现的
  提现类型/手续费承担方，均已改用 `CiticTransHandle` 本地带语义常量；
- 平安转账/消费、鉴权转账、授权码重发和提现的固定 functionFlag/tranType/交易网/证件类型值，均已
  改用 `PingAnTransHandle` 本地带语义常量；平安查询草稿中的固定值保留在
  `PingAnQueryHandle` 本地并继续受 `TODO-001` 约束；
- 已删除 common-core 中上述确认无其他调用方的公共 value 常量；协议字段 key 和业务方选择的
  `dealType` 等枚举值保持不变；
- 实际发送值未改变，用户已确认关闭。

## 本次修改（2026-08-09）

1. 对所有迁移项先检查全仓引用，只删除已由具体 Handler 等值接管且无其他调用方的公共 value。
2. 保留所有协议字段 key；没有修改 `specialData/accountSpecialData` 的输入 key、响应 key 或实际银行报文值。
3. 同步更新 `05-front代码开发约束.md`、`06-transfer-consume字段契约.md` 和历史交接说明中的常量职责。
4. 未启用或补写平安查询能力；其草稿代码仍由 `TODO-001` 管理。

## 关闭记录（2026-08-09）

- 按"一个银行 + 一个具体接口"逐项整理，不跨 Handle 批量重构；
- 单接口固定值移动到 Handle 本地并写清银行含义，公共 ContractKeys 只保留字段 key 和真实跨接口值；
- 删除迁移后无调用方的公共 value 常量和过时注释；
- 实际银行发送值保持不变；
- 用户确认当前常量职责：业务系统需要使用的额外数据协议 key 保留在 ContractKeys；单接口
  `bizFunc/chnlNo` 等固定 value 留在具体 Handle 并写明语义；
- 当前代码满足上述条件，本问题关闭。
