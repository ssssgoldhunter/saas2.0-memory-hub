# SaaS 2.0 多银行渠道 Front 总体结构设计

> 状态：current-design / three-domain-pending-implementation
> 更新日期：2026-08-25
> 代码起点：`cateringsass/limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2`
> 结构裁决：[28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)
> 实施计划：[29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)

本文描述 Front 的现行目标结构。旧 `FrontFlowContext → BankRequestContext → Handle`、
Router/Dispatch、多节点 LiteFlow、单一 `BankCapabilityRegistry` 和
`Provider → AssemblerRouter → Assembler` 均已退出目标设计。

## 1. 建设目标

Front 面向内部业务系统提供统一的多银行交易、交易查询和账户能力：

1. API、Feign、请求/响应 DTO 和上游组装方式稳定不变。
2. LiteFlow 保留稳定 chain id，只承担执行域入口，不拆业务步骤。
3. Transaction、Query、Account 三个执行域独立注册和路由。
4. 每个“银行 × 能力”使用一个扁平 Capability，代码按真实业务顺序展开。
5. 租户配置加载保留清晰调用链，但不保留多层 Provider/Assembler 继承。
6. 钱包发送统一经 Gateway/Sender，业务报文日志只在最终 Sender 输出。
7. 新银行复用已有能力时，不修改 API、chain id、三个 Registry 或三个 ExecuteNode。

不在本次范围内：修改公共 API、改表/DDL、改变银行协议、增加虚假能力、抽象未来银行、把中信不明来款纳入通用能力框架。

## 2. 总体架构

```text
交易 API
→ FrontTransApplicationService
→ THEN(frontTransExecute)
→ FrontTransExecuteNode
→ BankTransCapabilityRegistry
→ BankTransCapability.execute(FrontTransSlot)

交易查询 API
→ FrontQueryApplicationService
→ THEN(frontQueryExecute)
→ FrontQueryExecuteNode
→ BankQueryCapabilityRegistry
→ BankQueryCapability.execute(FrontQuerySlot)

账户状态/余额 API
→ FrontAccountApplicationService
→ THEN(frontAccountExecute)
→ FrontAccountExecuteNode
→ BankAccountCapabilityRegistry
→ BankAccountCapability.execute(FrontAccountSlot)

三个域 Capability
→ BankWalletGateway.post
→ BankWalletSender
→ HTTP
```

分层职责：

| 层 | 职责 |
|---|---|
| API/Controller | 定义并透传外部契约，不包含银行判断 |
| Application Service | 固定当前 capability，创建本域 Slot，执行原 chain id，转换最终返回 |
| LiteFlow | 每条链只挂一个本域 ExecuteNode |
| ExecuteNode | 公共校验、租户配置加载、BankCode 解析、本域 Registry 路由、异常写 Slot |
| Registry | 按 `(BankCode, FrontCapability)` 返回本域强类型 Capability |
| Capability | 校验、组报文、流水处理、调用钱包、响应判断和结果映射 |
| Gateway/Sender | 统一发送入口、按银行选择 Sender、签名/HTTP/超时和最终报文日志 |
| Domain/Mapper/Service | 固定银行和能力的渠道流水持久化 |

## 3. 目标目录

```text
com.chinaums.front
├─ controller/
├─ application/
│  ├─ FrontFlowExecutor
│  ├─ FrontTransApplicationService
│  ├─ FrontQueryApplicationService
│  └─ FrontAccountApplicationService
├─ flow/
│  ├─ slot/
│  │  ├─ FrontBaseSlot
│  │  ├─ FrontTransSlot
│  │  ├─ FrontQuerySlot
│  │  └─ FrontAccountSlot
│  ├─ node/
│  │  ├─ FrontTransExecuteNode
│  │  ├─ FrontQueryExecuteNode
│  │  └─ FrontAccountExecuteNode
│  └─ route/
│     ├─ BankTransCapability / BankTransCapabilityRegistry
│     ├─ BankQueryCapability / BankQueryCapabilityRegistry
│     └─ BankAccountCapability / BankAccountCapabilityRegistry
├─ channel/
│  ├─ gateway/
│  │  ├─ BankWalletGateway
│  │  ├─ BankWalletSender
│  │  └─ OpenBodySigSigner
│  ├─ citic/
│  │  ├─ common/
│  │  ├─ transaction/
│  │  ├─ query/
│  │  ├─ account/
│  │  └─ unidentified/
│  └─ pingan/
│     ├─ common/
│     ├─ transaction/
│     ├─ query/
│     └─ account/
├─ config/
│  ├─ TenantBankConfigLoader
│  ├─ TenantBaseInfo
│  └─ TenantBankAccountConfig
├─ domain/
├─ mapper/
└─ service/
```

`flow` 只允许 `slot/node/route` 三类职责。银行目录只按
`transaction/query/account` 三域、`common` 和已确认专项分组；不得恢复多层
`client/service/support/assembler/handle` 结构。

## 4. Slot 与执行域

Slot 继承严格两层：

```text
FrontBaseSlot
├─ FrontTransSlot
├─ FrontQuerySlot
└─ FrontAccountSlot
```

- `FrontBaseSlot`：tenant base、account config、bankCode、统一失败信息等公共执行数据。
- `FrontTransSlot`：8 个交易入口的请求、capability 和 `FrontTransResult`。
- `FrontQuerySlot`：交易状态、平台明细、登记簿明细的请求和结果。
- `FrontAccountSlot`：账户状态、账户余额的请求和结果。

一次调用只创建一个域 Slot。禁止新增 `FrontFlowContext`、`BankRequestContext`、银行 Slot 或能力级 Slot。
ExecuteNode 使用 LiteFlow v2.16.X 无参 `getFirstContextBean()` 获取当前 Slot，再显式校验所属域类型。

## 5. 三域注册模型

三个接口均为强类型：

```java
interface BankTransCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontTransSlot slot);
}

interface BankQueryCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontQuerySlot slot);
}

interface BankAccountCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontAccountSlot slot);
}
```

每个 Registry 只注入本域接口列表，建立不可变
`Map<BankCode, Map<FrontCapability, 本域Capability>>`。同域重复复合键必须启动失败；银行不存在和能力未注册使用不同错误。

当前 22 个通用能力归域：

| 域 | 数量 | 能力 |
|---|---:|---|
| Transaction | 12 | 两家 transfer、consume、refund、withdraw；平安 transferAuth/resend；中信 platformPay/platformReceive |
| Query | 6 | 两家交易状态、平台交易明细、登记簿交易明细 |
| Account | 4 | 两家账户状态、账户余额；平安现有两个挡板状态不变 |

不存在统一 `BankCapability`、统一 Registry、通用 ExecuteNode 或跨域支持矩阵。

## 6. LiteFlow 规则

13 个原 chain id 保持不变：

| 域 | 数量 | 节点 |
|---|---:|---|
| Transaction | 8 | `THEN(frontTransExecute)` |
| Query | 3 | `THEN(frontQueryExecute)` |
| Account | 2 | `THEN(frontAccountExecute)` |

LiteFlow v2.16.X 支持单节点 `THEN(node)`。公共校验、配置加载、路由和异常收口直接在所属域 ExecuteNode
顺序执行，不再拆成 Validate/Resolve/Route/Prepare/Dispatch/Normalize 节点。

## 7. 请求与响应边界

通用能力继续使用现有 `FrontRequest<T>`：

```text
FrontRequest
├─ baseData：跨银行公共强类型业务字段
└─ specialData：当前银行 + 当前能力的动态业务字段
```

- API 方法内部固定 capability，调用方不得传入或覆盖。
- `specialData` 按字段契约白名单逐键映射，禁止整体 `putAll`。
- `accountConfig/accountSpecialData` 只来自租户配置，不接受调用方输入。
- 单条能力返回 `R<具体结果>`；分页明细直接返回 `TableDataInfo<具体行>`。
- 银行原始响应码只用于 Capability 判定和渠道审计；对外使用统一 Front 错误码。
- 中信不明来款请求/返回为全字段强类型，不使用 `FrontRequest` 或 `specialData`。

字段细节以 06、07、08、10、25、27 号契约为准。

## 8. 租户配置

调用链固定为：

```text
域 ExecuteNode
→ TenantBankConfigLoader
→ RemoteConfigServiceClient
```

Loader 是具体类，只保留：

- `loadTenantBaseInfo(tenantId)`；
- `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)`。

Loader 直接查询并扁平组装中信/平安配置。禁止恢复
`TenantBankConfigProvider → AssemblerRouter → Assembler`、抽象父类、Bundle/Context 或银行配置组装器继承链。

## 9. Capability 业务顺序

每个交易 Capability 的主流程必须能够从上到下读完：

1. 校验请求和当前能力字段。
2. 直接组装当前银行请求 DTO。
3. 在固定渠道表查重并写 `INIT`。
4. 更新 `SENDING`。
5. 调用 `BankWalletGateway.post`。
6. 判断银行结果并更新终态。
7. 组装 Front 结果写回 Slot。

查询和账户能力不产生交易流水，但仍需完整展示校验、组装、发送、判断、映射。允许不同能力保留少量重复；
禁止业务父类、BankSupport God class、多层 helper 或 `switch(capability)`。

## 10. 钱包发送与日志

`BankWalletGateway.post` 是业务代码唯一钱包出口；Gateway 后只允许最终 `BankWalletSender` 直接执行 HTTP。

日志采用 B 方案：

- API/Application Service：入口、完成和异常收口。
- ExecuteNode：配置加载与域路由结果，不记录钱包 body。
- Capability：业务开始、校验、流水状态、银行结果和业务异常，不重复钱包报文。
- Sender：唯一记录一次完整明文请求 JSON、一次完整明文响应 JSON 或通信失败，body 不做字段脱敏。

完整明文规则只适用于钱包报文 body。`appKey`、私钥、签名原文/材料、签名或认证 Header、
`Authorization`、`Cookie` 等非业务报文凭证禁止进入日志。

## 11. 渠道流水和分库

- 交易按“银行 + 交易能力”使用固定表，禁止统一动态表和动态表名。
- 重复检查固定使用当前表的 `tenantId + bizOrderNo + bizSubOrderNo`。
- 状态按 `INIT → SENDING → 最终状态` 更新；超时或结果不明进入 `UNKNOWN`，不得自动重发资金交易。
- `data_source_id` 是分库键；缺失配置或目标数据源不存在时立即失败，不得兜底到 `ds_0`。
- 本结构增量不修改 10 张表、Entity、VO、Mapper、XML、DDL 或分片规则。

## 12. 中信不明来款专项

中信不明来款是独立特殊能力：

```text
CiticUnidentifiedRemittanceApi
→ Controller
→ CiticUnidentifiedRemittanceApplicationService
→ TenantBankConfigLoader
→ CiticUnidentifiedRemittanceChannel
→ BankWalletGateway
```

它不注册为通用 `FrontCapability`，不进入三域 Registry/LiteFlow，不使用 `specialData`；仅复用租户上下文、
Loader、Gateway 和中信 common 基础设施。协议以 27 号接入手册和专项文档为准。

## 13. 新银行接入

在不新增 Front 能力的情况下，新银行只增加：

1. `BankCode` 枚举值；
2. Loader 内一个平级配置组装分支；
3. 一个最终 BankWalletSender；
4. 该银行真实支持的三域 Capability 实现。

不修改 API、Controller、三个 Application Service、13 条 chain id、三个 Registry、三个 ExecuteNode 或其他银行代码。
只有新能力的数据和状态形态无法由现有三种 Slot 准确承载，并经用户明确批准后，才允许增加第四执行域。

## 14. 结构验收

- API/Controller/DTO 零结构变化。
- Slot 为 Base + Trans/Query/Account 两层。
- 强类型 Capability 接口、Registry、ExecuteNode 各 3 个。
- 22 个通用能力归域为 12/6/4。
- 13 条单节点链归域为 8/3/2。
- 账户状态/余额只注册 Account 域。
- 业务 Context、Router、Dispatch、Handle 父类、统一 Registry、Provider/Assembler 链为 0。
- 钱包发送出口只有 Gateway/Sender；完整明文 body 只在 Sender 出现一次。
- 中信不明来款仍为独立专项。
- 本轮按用户约束只做静态验收，不新增/运行测试、不执行编译。

## 15. 文档分工

- 05：强制代码约束。
- 19：框架与业务能力开发手册。
- 20：交易 API 对接。
- 21：交易查询和账户 API 对接。
- 27：中信不明来款专项接入。
- 28：最终结构裁决。
- 29：三域增量实施计划。
- 30：三域裁决前历史交付快照，不作为最终证据。
