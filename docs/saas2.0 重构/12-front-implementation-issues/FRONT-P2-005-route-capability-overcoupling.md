# FRONT-P2-005 统一路由与能力预验证过度耦合

- 状态：CLOSED
- 优先级：P2
- 影响：统一节点通过 capability 名称猜测交易/查询 Router；新增账户大类或非 TRANSFER 前缀交易时，必须修改公共分流代码。Handle 能力状态表与具体方法又形成两份事实来源。

## 原问题证据

- `FrontRouteAndCapabilityCheckNode.resolveHandle()` 使用 `capability.name().startsWith("TRANSFER")`
  加若干枚举分支判断交易，其余能力默认进入 QueryRouter。
- `BankHandle.capabilityStatus()` 与具体银行 Handle 方法同时表达支持状态，存在不一致风险。
- lsym consume 使用公共 BaseSlot，但交易与查询分别使用 TransSlot、QuerySlot；旧 front 的账户、查询和
  各交易能力也使用独立 Router/Handle。

## 修复结果

- 删除统一 `FrontRouteAndCapabilityCheckNode`，新增 `frontTransactionRoute` 与 `frontQueryRoute`；
  交易、查询链只引用自己的 Router，后续账户链可独立新增，不修改现有分流代码。
- 删除 `IntegrationStatus`、`capabilityStatus/requireCapability/checkCapability`。
- `BankTransactionHandle/BankQueryHandle` 未被具体银行覆盖的方法直接返回
  `CAPABILITY_NOT_SUPPORTED`。
- 平安五个待人工核对的查询方法在 Handle 入口直接抛 `ADAPTER_NOT_READY`，由查询分派节点写 Slot
  后中断；保留现有草稿，不调用银行。
- `platformCode` 转 `BankCode` 的公共校验保留在 `AbstractFrontNode`。
- 本问题只收口 Router 类型判断和统一能力预验证；公共 Dispatch 仍按 capability 二次选择具体方法的
  遗留单独登记为 [FRONT-P2-006](FRONT-P2-006-capability-dispatch-overcoupling.md)。
- 本问题所禁止的是“统一节点根据 capability 名称/前缀猜测 Transaction/Query/Account Router”，不是禁止
  capability 参与正确领域内的精确路由。最新目标由 `FRONT-P2-006` 收口：进入交易或查询领域后，Registry
  应使用类型安全的 `(BankCode, FrontCapability)` 直接定位能力 Handler。

## 实际修改范围

- `catering-front/flow/component/FrontTransactionRouteNode.java`
- `catering-front/flow/component/FrontQueryRouteNode.java`
- `catering-front/flow/component/AbstractFrontNode.java`
- `catering-front/flow/component/FrontRouteAndCapabilityCheckNode.java`（删除）
- `catering-front/handle/BankHandle.java`
- `catering-front/handle/BankTransactionHandle.java`
- `catering-front/handle/BankQueryHandle.java`
- 中信、平安四个具体 Handle
- `catering-front/resources/liteflow/front-flow.xml`
- `catering-api-front/model/enums/IntegrationStatus.java`（删除）
- Nacos 注释、模块 README、WIKI、实施方案和开发约束

## 验收标准

1. 交易链不引用 QueryRouter，查询链不引用 TransactionRouter。
2. 不通过 capability 名称或枚举列表判断 Router 类型。
3. 不再维护统一能力状态表；当前代码由具体 Handle 表达不支持/待接入，完成 `FRONT-P2-006` 后由
   Registry 缺失复合键表达不支持、由明确待接入 Handle 表达待接入。
4. 新增账户能力时增加独立 AccountRouter/BankAccountHandle/账户链，不修改交易、查询路由节点。
5. 不建立独立能力状态表；领域 Registry 中真实注册的“银行 + capability”键是唯一支持事实来源。
