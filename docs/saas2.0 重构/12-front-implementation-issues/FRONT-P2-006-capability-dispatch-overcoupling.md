# FRONT-P2-006 银行 + capability 未直接映射到能力 Handler

- 状态：CLOSED
- 优先级：P2
- 影响：当前 Registry 只按银行返回“大 Handle”，公共 Dispatch 再按 capability `switch` 选择方法。
  新增能力必须同步修改中央分派代码，无法满足“能力 + 银行作为 key 直接映射”的扩展目标。

## 修复前证据

- `FrontTransactionApplicationService` 与 `FrontQueryApplicationService` 的每个 API 入口会在服务内部传入
  固定 `FrontCapability`；请求对象没有 capability 字段，这部分边界正确。
- 13 条 LiteFlow 具名链已经按交易和查询分开，但同一领域内仍复用公共
  `frontTransactionDispatch/frontQueryDispatch`。
- `TransactionHandleRegistry/QueryHandleRegistry` 当前只按 `BankCode` 返回
  `Citic/PingAnTransactionHandle` 或 `Citic/PingAnQueryHandle`。
- `FrontTransactionDispatchNode` 再按 capability 选择 8 个方法，`FrontQueryDispatchNode` 再选择 5 个方法。
- 这使“API 固定 capability”和“公共 Dispatch switch”同时成为流程事实来源；新增枚举后还必须修改公共
  Dispatch，遗漏时只能到运行期暴露。

## 2026-08-09 本轮实现进展

已完成路由和执行框架部分：

- 新增类型安全的 `BankCapabilityKey(BankCode, FrontCapability)`；
- 新增 `BankCapabilityDefinition` 和绑定后的单能力 `BankCapabilityHandle`；能力定义接收容器中的银行
  Handle 实例，调用具体业务方法时不会绕过现有 Handle AOP 日志；
- `TransactionHandleRegistry`、`QueryHandleRegistry` 已按复合键展开登记，重复复合键启动失败；
- 已接入银行但未登记的能力返回 `CAPABILITY_NOT_SUPPORTED`；
- `TransactionRouter`、`QueryRouter` 及各自 RouteNode 已按银行 + 精确能力选择执行器；
- `FrontTransactionDispatchNode`、`FrontQueryDispatchNode` 已删除 capability switch，只执行路由结果；
- 中信交易登记 6 个能力，平安交易登记 6 个能力；中信查询登记 5 个能力；平安查询登记 5 个
  `PENDING_INTEGRATION` 能力，实际调用仍由现有 Handle 返回 `ADAPTER_NOT_READY`；
- LiteFlow、模块 README 和 Nacos 注释已同步新调用链。

实际修改文件：

- `handle/BankCapabilityDefinition.java`
- `handle/BankCapabilityHandle.java`
- `route/BankCapabilityKey.java`
- `handle/BankTransactionHandle.java`
- `handle/BankQueryHandle.java`
- `route/TransactionHandleRegistry.java`
- `route/QueryHandleRegistry.java`
- `route/TransactionRouter.java`
- `route/QueryRouter.java`
- `flow/context/FrontFlowContext.java`
- `flow/component/FrontTransactionRouteNode.java`
- `flow/component/FrontQueryRouteNode.java`
- `flow/component/BankHandleContextPrepareNode.java`
- `flow/component/FrontTransactionDispatchNode.java`
- `flow/component/FrontQueryDispatchNode.java`
- `channel/citic/CiticTransactionHandle.java`
- `channel/citic/CiticQueryHandle.java`
- `channel/pingan/PingAnTransactionHandle.java`
- `channel/pingan/PingAnQueryHandle.java`
- `resources/liteflow/front-flow.xml`
- `catering-front/README.md`
- `script/config/nacos/catering-front.yml`

持久化固定绑定也已完成：

- 中信 6 个交易方法分别显式绑定固定 Mapper 和固定 INIT 写入函数；
- 平安普通转账、短信鉴权转账、授权码重发显式绑定同一转账 Mapper，但授权码使用独立 INIT 字段写入函数；
- 平安消费、提现、退款分别显式绑定自己的 Mapper 和 INIT 写入函数；
- 通用重复检查、SENDING 更新、异常更新和响应更新只接收调用能力方法传入的固定 Mapper；
- 两个交易 Handle 已删除 `resolveMapper(capability)`、`doInsertInit` capability switch 及其他 capability
  到物理表的动态选择；capability 只继续用于复合路由键、日志和渠道流水字段。

据此用户已确认关闭；当前修改仍未 commit、未 push。

本轮只进行了静态检查和 `git diff --check`，按会话约束未运行测试、未执行编译。

## 已确认目标边界

1. capability 由具体 API 方法在服务内部固定，调用方不得在 `FrontRequest/baseData/specialData` 中传入
   或覆盖。
2. API 所属领域直接决定进入 Transaction、Query 或后续 Account Registry；禁止根据 capability 名称、
   `TRANSFER` 前缀或枚举列表猜测领域。
3. 每个领域 Registry 以类型安全的 `(BankCode, FrontCapability)` 为唯一 key，直接返回“当前银行 + 当前
   能力”的具体 Handler。
4. 每个能力 Handler 只实现一个 capability，声明自己的 `bankCode()` 和 `capability()`；通用执行节点只
   调用已选 Handler 的统一执行入口，不再 `switch(capability)`。
5. Registry 中真实存在的复合键就是唯一支持事实来源，不建立统一能力状态表或能力预校验矩阵：银行无法
   解析/整体未接入返回 `BANK_NOT_SUPPORTED`；银行已接入但 key 不存在返回
   `CAPABILITY_NOT_SUPPORTED`；已明确登记但尚未联调的 Handler 返回 `ADAPTER_NOT_READY`。
6. capability 同时用于结构化日志和渠道流水 `capability` 字段。完成 Handler 定位后，不得再用 capability
   动态选择 Repository；具体能力 Handler 使用自己的固定 Repository。
7. 平安 `TRANSFER/TRANSFER_AUTH/TRANSFER_AUTH_CODE_RESEND` 分别由三个复合键定位，但可在各自 Handler
   内复用公共实现，并继续写入同一平安转账表，以落库 capability 区分记录。
8. 新增能力时，公共路由框架只新增 API 入口和 capability 枚举；真实支持的银行还需新增对应能力 Handler，
   但不得修改中央 switch、Router 领域判断或独立支持矩阵。

目标调用链：

```text
API 方法内部固定 capability
→ 进入 Transaction/Query/Account 领域链
→ platformCode 解析为 BankCode
→ 领域 Registry.route(bankCode, capability)
→ 唯一 BankCapabilityHandler
→ prepareContext
→ 通用 execute 调 Handler
→ Handler 使用固定 Repository、组装银行请求并调用钱包
```

## 与 FRONT-P2-005 的边界

- `FRONT-P2-005` 已解决“统一节点按 capability 猜交易/查询 Router”和“统一能力预校验”问题，用户已确认关闭。
- 本问题负责把各领域内部从“只按银行选大 Handle + Dispatch switch”收口为“银行 + capability 直接选
  能力 Handler”。使用 capability 作为领域 Registry 复合键，不等于恢复 P2-005 的统一 Router 猜测。

## 建议修改范围

- Transaction/Query（后续 Account）能力 Handler SPI 与类型安全复合 key；
- `TransactionHandleRegistry` / `QueryHandleRegistry`；
- `FrontTransactionRouteNode` / `FrontQueryRouteNode`；
- `FrontTransactionDispatchNode` / `FrontQueryDispatchNode`：删除 capability switch，改为调用已选 Handler；
- `FrontFlowContext` 中已选 Handler 的类型和注释；
- 中信、平安大 Handle 按“银行 + 能力”拆分或注册为等价的单能力 Handler；
- LiteFlow 规则、Nacos 注释、模块 README 和记忆体文档。

不要求为 13 个 API 新建 13 套重复的公共执行节点；13 条具名链可以保留并复用所属领域的通用路由、
上下文装配和执行节点。

## 验收标准

1. 请求对象不存在 capability 输入字段；13 个 API 均在服务内部使用自己的固定枚举值。
2. Transaction、Query、Account Registry 相互独立，不存在 capability 名称/前缀到领域 Router 的判断。
3. 对应领域 Registry 的唯一键为 `(BankCode, FrontCapability)`，重复键启动失败。
4. 公共 Dispatch 不存在 `switch(capability)`，只调用 Registry 已选中的单能力 Handler。
5. 未注册的银行能力返回 `CAPABILITY_NOT_SUPPORTED`，不会调用银行或写入错误业务表；待接入 Handler
   返回 `ADAPTER_NOT_READY`。
6. 每个交易能力 Handler 使用固定 Repository；不存在 capability 到物理表的公共 switch 或动态 SQL。
7. capability 继续进入结构化日志和渠道流水；平安共享转账表三种记录仍可区分。
8. 新增一个 capability 不需要修改现有 Registry/Router/Dispatch 的中央分支代码。
9. LiteFlow 业务异常写 Slot 后中断，系统异常继续抛出。
10. 不改变 `baseData/specialData/accountSpecialData` 边界及 API 返回类型。
