# catering-front 扁平化重构设计（28 号）

> 状态：approved-design / not-implemented
> 用户确认：2026-08-25
> 当前实施授权：全量迁移（2026-08-25 用户最新裁决）。
> 代码基线：`cateringsass/limeng_front@99e696f4e7ab78a1b307b5a2fd3c911698c143fb`。
> 2026-08-25 的未提交全面改造代码已放弃，不是设计事实，也不得作为下一位 AI 的续写基础。
> 核心目标：API 不动，内部结构扁平，代码像原 `catering-consume` Handler 和旧 Front Handle 一样能按业务顺序直接阅读。

## 1. 用户裁决

以下内容是本方案的最高优先级约束：

1. `catering-api-front` 不修改；对外 API、DTO、返回类型、调用方组装方式均不受影响。
2. 保留 LiteFlow，但 LiteFlow 只做薄编排，不承载银行业务和层层转发；
   2026-08-25 用户进一步裁决：每条链收敛为单节点 `THEN(frontBankExecute)`，
   由 `FrontBankExecuteNode` 三合一（Registry 路由 + 租户配置加载 + 能力执行），
   校验与响应归一化分别由 Capability 和 FrontFlowExecutor/ApplicationService 承接。
3. Slot 参考 lsym UAT `catering-consume` 的命名和继承关系，固定命名为
   `FrontBaseSlot`、`FrontTransSlot`、`FrontQuerySlot`；禁止再引入
   `FrontFlowContext`、`BankRequestContext` 等业务 Context。
4. Slot 继承关系严格只有两层：`FrontBaseSlot`，以及直接继承它的
   `FrontTransSlot`、`FrontQuerySlot`；不得增加第三层或其他业务 Slot。
5. `flow` 下继续分包：Slot 放在一起，公共节点放在一起，Registry 与 Route 放在一起。
6. 银行模块先按银行放置，再按业务域分包（2026-08-25 用户裁决三域：
   `transaction` 交易 / `query` 查询 / `account` 账户；平台收付款属交易域，
   两家银行域结构对称）；真正跨该银行多个能力复用的代码才进入该银行的 `common`。
7. 每个“银行 × 能力”允许保留自己的组装代码和少量重复，优先保证单个能力从上到下可读。
8. Front 的银行能力扩展框架只有两项：Registry 注册、Route 路由。请求校验和租户加载只是固定的薄前置节点，
   不是扩展层；禁止恢复 Router、Dispatch、Handle 继承体系。
9. 钱包业务发送只有 `BankWalletGateway.post` 一个统一出口；允许 Gateway 根据银行选择最终
   `BankWalletSender`，但 Sender 必须直接完成实际 HTTP 调用，不再继续套 Client、Support、Invoker。
10. 日志参考旧 Front Handle：Capability 记录业务开始、校验、流水状态、结果和异常；钱包请求/响应
    只由最终 BankWalletSender 各记录一次，删除 Capability/旧 Handle 中重复的完整钱包报文日志。
11. 文件数量不是优化目标。允许多文件，但 package 层级和单笔流程必须简单，不得为了“复用”让阅读者连续跳转。
12. 中信、平安现有通用交易与查询能力全部迁移，13 条 LiteFlow 链全部切换；不支持能力继续明确不支持，不伪造实现。
13. 扁平化不取消扩展能力：在“不新增 FrontCapability、只接入新银行”的场景下，复用原 API 与 LiteFlow
    链，通过注册该银行的 Capability 和 Sender 即可进入现有 Route；不得修改 Controller、Application
    Service、LiteFlow 链结构、Registry 或 BankRouteNode 的路由代码。

## 2. 设计目标与非目标

### 2.1 设计目标

- Controller 到银行能力只有一条明显路径：

```text
Controller
→ Application Service
→ LiteFlow 薄链
→ BankRouteNode
→ BankCapabilityRegistry
→ 某银行某能力 Capability
→ BankWalletGateway.post
```

- 打开任意 Capability，能从上到下看到该能力的完整业务步骤。
- 只在理解统一钱包发送时允许跳到 `BankWalletGateway`；协议 DTO、固定值和私有组装方法均与能力相邻。
- 新银行复用已有能力时，新增该银行能力包和注册实现，不修改 Controller、Application Service、
  LiteFlow 链、公共 Route 或其他银行能力。
- 保持既有请求、返回、错误码、渠道流水、分库和银行协议行为。

### 2.2 非目标

- 不以减少文件数、减少代码行数或消除重复为目标。
- 不抽象未来银行、未来协议或尚未出现的复用点。
- 不把全部银行能力合并到一个 God class。
- 不改 `catering-api-front`、数据库表、DDL、上游组装器或中信不明来款专项链路。
- 不改变任何能力的支持状态、字段协议或业务行为。

## 3. 目标 package 结构

```text
com.chinaums.front
├─ controller/
├─ application/             # 保留现有 package，不做无关移动
│  ├─ FrontFlowExecutor
│  ├─ FrontTransApplicationService
│  └─ FrontQueryApplicationService
├─ flow/
│  ├─ slot/
│  │  ├─ FrontBaseSlot
│  │  ├─ FrontTransSlot
│  │  └─ FrontQuerySlot
│  ├─ node/
│  │  ├─ FrontValidateNode
│  │  └─ TenantResolveNode
│  └─ route/
│     ├─ BankCapability
│     ├─ BankCapabilityRegistry
│     └─ BankRouteNode
├─ channel/
│  ├─ gateway/
│  │  ├─ BankWalletGateway
│  │  ├─ RoutingBankWalletGateway
│  │  ├─ BankWalletSender
│  │  └─ OpenBodySigSigner
│  ├─ citic/
│  │  ├─ common/          # SequenceGenerator/Sm2Crypto/ResponseChecker/CryptoProperties/WalletHttpClient(最终 Sender)
│  │  ├─ transaction/     # Transfer/Consume/Refund/Withdraw/PlatformPay/PlatformReceive 六个 Capability
│  │  ├─ query/           # TransStatus/TransDetail/PlatformDetail 三个 Capability
│  │  ├─ account/         # AccountStatus/AccountBalance 两个 Capability
│  │  └─ unidentified/    # 既有专项，当前不动
│  └─ pingan/
│     ├─ common/          # WalletHttpClient(最终 Sender)/ResponseChecker/CryptoProperties/Sm2Crypto/SequenceGenerator
│     ├─ transaction/     # Transfer/Consume/Refund/Withdraw/TransferAuth/ResendAuthCode 六个 Capability
│     ├─ query/           # TransStatus/TransDetail/PlatformDetail 三个 Capability
│     └─ account/         # AccountStatus/AccountBalance 两个 Capability（挡板）
├─ config/
│  ├─ TenantBankConfigLoader
│  ├─ TenantBankAccountConfig
│  └─ TenantBaseInfo
├─ domain/
└─ mapper/
```

### 3.1 package 硬约束

- `flow` 只允许 `slot`、`node`、`route` 三个职责包；不得再出现 `flow/context`、`flow/component/dispatch` 等层级。
- `channel/{bank}` 只允许“三域包（transaction/query/account）+ common + 已确认的独立专项包”。
- 能力包内部不再继续拆 `client/config/crypto/protocol/request/service/support/assembler/mapper` 子包。
- 协议 Request/Response DTO 放在其能力包；确实被同一银行多个能力使用的 DTO 才放该银行 `common`。
- `common` 不是杂物包。代码只有在至少两个已实现能力真实复用、且不隐藏业务步骤时才能进入。
- 所有 package 必须处于 `com.chinaums.front...` 下，禁止 `package citic;`、`package pingan;` 等脱离应用根包的声明。

## 4. Slot 设计：严格两层

```text
FrontBaseSlot
├─ tenantBaseInfo
├─ accountConfig
├─ bankCode
├─ businessFailed
├─ frontRespCode
└─ frontRespDesc

FrontTransSlot extends FrontBaseSlot
├─ request/baseData/specialData
├─ capability
└─ FrontTransResult

FrontQuerySlot extends FrontBaseSlot
├─ request/baseData/specialData
├─ capability
├─ AccountStatusResult
├─ AccountBalanceResult
├─ TransStatusResult
├─ TableDataInfo<PlatformTransDetailItem>
└─ TableDataInfo<AccountTransDetailItem>
```

约束：

- 继承只允许上图两层，不得增加 `AbstractFrontSlot`、`BankSlot`、`CiticSlot` 等中间层。
- 一次请求只创建一个 Slot，链路全程传同一实例，不做 Slot ↔ Context ↔ DTO 包装转换。
- LiteFlow 节点使用无参 `getFirstContextBean()` 取得当前 Slot，再做明确类型校验；不得写不存在或不兼容的按 Class 精确查找用法。
- Slot 只承载本次调用数据和结果，不注入 Service、Mapper、Gateway，不承载业务执行方法。
- `capability` 由 Application Service 根据当前 API 方法赋值，调用方不能传入或覆盖。
- 参考 lsym UAT 的是 `BaseSlot ← TransSlot/QuerySlot` 命名、继承和无参取 Slot 的方式，
  不复制其与 Front 无关的字段或 Slot 内业务方法。

## 5. Flow：只做公共校验、租户装配和路由

“扩展框架只有 Registry + Route”指新增银行/能力时只通过注册和路由扩展；
`FrontValidateNode`、`TenantResolveNode` 是所有请求固定经过的公共前置步骤，不允许再派生父类、
Resolver、Prepare 或 Context 转换体系。

每个 API 仍有具名链，但链结构一致且不知道银行：

```xml
<chain name="chainFrontTransfer">
    THEN(frontBankExecute);
</chain>
```

### 5.1 `FrontValidateNode`

- 只校验跨银行、无 IO 的请求结构。
- 不组装银行报文，不读取账户配置，不判断银行支持矩阵。
- `tenantId` 必填；`clientId/platformCode/dataSourceId` 允许由租户节点按既有契约回填。
- 能力专属字段由具体 Capability 校验，避免公共节点变成能力 `switch`。

### 5.2 `TenantResolveNode`

顺序固定：

1. 按 `tenantId` 查询一次 `tenant_base_config`。
2. 回填请求缺失的 `clientId/platformCode/dataSourceId`。
3. 校验回填后的必要定位字段。
4. 从 `platformCode` 解析 `BankCode`。
5. 使用 `supportBankConfig` 指定的配置 key 加载账户配置。
6. 将租户与账户配置写回同一个 Slot。

调用链保留但严格压缩为：

```text
TenantResolveNode
→ TenantBankConfigLoader
→ RemoteConfigServiceClient
```

- `TenantResolveNode` 明示回填、解析银行和写 Slot 的顺序。
- `TenantBankConfigLoader` 是一个具体类，直接查询租户基础配置和银行配置，并直接构造
  `TenantBankAccountConfig`。
- Loader 只保留两个与现有真实行为对应的公共方法：
  `loadTenantBaseInfo(tenantId)` 和 `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)`；
  不再为返回值增加 Bundle/Result/Context 包装对象。
- 中信、平安 `accountSpecialData` 白名单在 Loader 内分别使用一个平铺私有方法组装；私有方法不得再调用
  第二层业务 helper。
- 删除 `TenantBankConfigProvider/RemoteTenantBankConfigProvider`、`BankAccountConfigAssemblerRouter`、
  `BankAccountConfigAssembler`、`AbstractBankAccountConfigAssembler` 和两个银行 Assembler。
- 不得恢复 Provider 接口、Assembler 注册表、模板父类、Resolver、`prepareContext` 节点或第二个业务载体。

### 5.3 `BankRouteNode` 与 Registry

`BankRouteNode` 不再通过 Router/Dispatch 转发，核心调用只有：

```text
registry.get(slot.bankCode(), slot.capability()).execute(slot)
```

Registry 规则：

- Spring 构造器收集 `List<BankCapability>`。
- Capability 通过 `bank()`、`capability()` 自描述。
- 启动时建立不可变的 `Map<BankCode, Map<FrontCapability, BankCapability>>`。
- 同一 `(BankCode, FrontCapability)` 重复注册时启动失败。
- 银行不存在返回 `BANK_NOT_SUPPORTED`；银行存在但能力未注册返回 `CAPABILITY_NOT_SUPPORTED`。
- 不再增加 `Router`、`Dispatch`、`BankCapabilityKey`、能力状态矩阵或第二份支持清单。

### 5.4 新银行复用已有能力的接入格式

本节只定义框架扩展方式，不在本次迁移中创建第三家银行或新增能力。假设新银行需要接入现有
`transfer/consume/...` 能力，调用路径保持：

```text
既有 API
→ 既有 Application Service
→ 既有 LiteFlow 三节点链
→ BankRouteNode
→ Registry 按 (新银行, 既有 capability) 找到新 Capability
→ BankWalletGateway.post
→ 新银行 BankWalletSender
```

只需完成以下银行增量：

1. 在当前类型安全的 `BankCode` 中增加新银行编码；这是银行枚举扩展，不新增或修改 API 方法、DTO、
   Feign 路径和返回签名。本次中信/平安迁移仍保持 `catering-api-front` 零 diff。
2. 在 `TenantBankConfigLoader` 增加该银行一个平级的 `accountSpecialData` 组装分支；不增加 Provider、
   Assembler、Router 或父类。
3. 新增一个实现 `BankWalletSender` 的最终发送类，自描述 `bankCode()`，直接完成该银行 HTTP、签名、
   请求前日志、响应后日志和发送异常日志；Gateway 通过现有构造器列表自动注册，不修改分派代码。
4. 对新银行真实支持的每个既有能力，新增一个扁平 Capability，自描述 `bank()` 与 `capability()`；
   Registry 通过现有构造器列表自动注册，不修改 Route。未支持能力不注册。
5. 能力自己的校验、报文组装、渠道流水和结果映射保留在该 Capability；只有至少两个已实现能力真实复用
   的银行基础组件才进入该银行 `common`。

因此，“快速接入新银行”不是零代码，而是只增加银行配置分支、Sender 和实际支持的 Capability；
公共 API 入口、LiteFlow 编排、Registry 建表逻辑、Route 调用和其他银行实现均不改。

`BankCapability` 的签名固定为以下形式，避免接口使用 `FrontBaseSlot`、实现类却缩窄为
`FrontTransSlot`/`FrontQuerySlot` 而无法覆写：

```java
public interface BankCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontBaseSlot slot);
}
```

具体 Capability 在 `execute` 第一段使用 `instanceof` 明确取得 `FrontTransSlot` 或
`FrontQuerySlot`，类型错误立即失败；执行结果写回对应 Slot 的明确结果字段。

`BankRouteNode` 同时承接旧 Dispatch 的必要收口行为，但不增加 Dispatch 层：捕获 Capability 抛出的
`FrontException`，把错误码写入 Slot 并 `setIsEnd(true)`；其他系统异常继续抛出。
`FrontFlowExecutor` 在链结束后承接旧 Normalize 的兜底：结果为空或单条结果缺少 `frontRespCode` 时按
现有语义补 `INTERNAL_ERROR`。分页结果仍由 Application Service 按现有契约返回。

## 6. Capability：参考 consume/旧 Front 的顺序式代码

每个银行能力实现一个 `BankCapability`，不继承业务父类。主方法按真实执行顺序展开：

```java
public void execute(FrontBaseSlot baseSlot) {
    if (!(baseSlot instanceof FrontTransSlot slot)) {
        throw new IllegalStateException("当前能力要求 FrontTransSlot");
    }
    // 1. 读取并校验当前能力输入
    // 2. 直接组装当前银行请求 DTO
    // 3. 查重并写 INIT，再更新 SENDING
    // 4. 通过 BankWalletGateway.post 发送
    // 5. 检查银行响应、更新渠道流水、组装结果并写回 slot
}
```

### 6.1 代码层级硬约束

- Capability 只 `implements BankCapability`，禁止 `extends AbstractBankHandle` 或其他业务父类。
- 禁止 `AbstractBankHandle → BankHandle → BankTransHandle → XxxHandle` 一类继承链。
- 禁止 `Route → Dispatch → Handle → Support → Client → Gateway` 调用链。
- 主方法必须直接显示上述五步；不得把五步分别转发到五个 Service 后只剩方法名。
- 能力自己的字段校验、setter 组报文、渠道 Entity 组装和结果映射可以留在同一个类中。
- 复杂片段可以提取为当前类的私有方法；私有业务 helper 最多一层，且紧跟对应主流程，禁止 helper 再层层调用业务 helper。
- 同一银行两个能力即使有 10～30 行相似组装代码，也允许分别保留；先保证独立可读，再讨论真实复用。
- 不设“每个类必须少于 300 行”等机械指标。类长不是问题，职责混杂和阅读跳跃才是问题。
- 一个 Capability 只处理一个 `(bank, capability)`，不得在类内 `switch(capability)`。
- 每个类的类注释必须写明：银行、能力、银行接口/功能码、请求 DTO、渠道表、是否产生流水。

### 6.2 `common` 的准入条件

允许进入 `channel/{bank}/common`：

- 该银行统一的序列号生成；
- 该银行统一的 SM2 算法；跨银行共用的 OPEN-BODY-SIG 只保留在 Gateway 基础设施；
- 该银行统一的响应码判断；
- 该银行多个已实现能力共同使用的配置属性或协议基础对象。

禁止进入 `common`：

- 某一能力专属的请求组装；
- 某一能力专属的渠道 Entity 组装；
- 为减少几行重复而提取的业务步骤；
- 聚合校验、组装、持久化、发送和结果映射的 `CiticBankSupport`、`PingAnBankSupport` God class。

## 7. 钱包发送：唯一出口

所有通用能力直接调用现有统一出口：

```java
JSONObject response = bankWalletGateway.post(
    slot.getBankCode(), apiName, requestJson, slot.getAccountConfig(), metadata);
```

约束：

- `BankWalletGateway.post` 是业务代码唯一的钱包发送位置。
- Gateway 后只保留一个直接执行 HTTP 的银行 `BankWalletSender`；不再增加
  `WalletHttpClient`、`Invoker`、`ClientFacade`、`Support.invokeBank` 包装层。
- 连接、统一签名、HTTP、超时和底层响应读取属于 Gateway 基础设施，其中最终银行 Sender 直接执行 HTTP；
  能力专属的 apiName、bizFunc、chnlNo 和请求字段仍在 Capability 明示。
- Capability 只记录业务步骤和渠道流水，不记录完整钱包请求/响应；最终 Sender 分别记录一次真实请求和
  一次真实响应。Sender 日志 payload 的字段范围和明文/脱敏行为沿用代码基线。
- 银行响应判断使用该银行 `common` 下的小型 `ResponseChecker`，不得把结果组装也塞进 Checker。

## 8. 日志、异常与敏感信息

日志参考旧 Handle 的就地写法，职责固定如下：

1. API：入口、完成和异常收口日志保持，定位一次外部调用。
2. 租户加载与 Route：配置加载开始/完成/失败、路由选中/未注册/重复注册均有日志，不打印配置密钥。
3. Capability 开始：bank、capability、tenantId、业务主/子流水。
4. Capability 过程：关键校验、报文组装完成、渠道流水 INIT/SENDING/最终状态及 recordId。
5. 钱包发送前：只由最终 Sender 记录一次 apiName、frontSsn 和完整请求。
6. 钱包响应后：只由最终 Sender 记录一次响应、HTTP 状态和耗时；Capability 只记录归一化结果。
7. 异常：Capability 记录业务执行阶段、recordId、状态和异常；最终 Sender 记录发送阶段、是否已发送、
   耗时和通信异常。异常必须保留堆栈，不得只打印异常 message。

旧 Handle/Capability 中与 Sender 重复的“发送钱包请求/银行响应”日志必须删除；除去该去重，日志 payload
字段范围和明文/脱敏行为沿用代码基线。日志不得依赖多层 AOP 才能理解真实业务步骤；AOP 只保留跨接口的
入口/完成/失败事件。

异常保持既有语义：请求错误、银行不支持、能力不支持、重复交易、通信失败、结果未知、银行拒绝必须使用各自错误码；`F300001` 只表示重复交易，绝不是“不支持能力”。

## 9. API、数据和行为保持

- `catering-api-front` 必须零 diff。
- Controller 方法签名、Feign 契约、`R<T>` / `TableDataInfo<T>` 返回结构不变。
- 10 张渠道表、Entity、VO、Mapper、XML、DDL 和分片规则不因本结构迁移调整。
- 金额继续使用 `Long` 人民币分。
- 重复交易仍按当前银行当前能力的固定渠道表检查，禁止动态表名。
- 交易流水仍执行 `INIT → SENDING → 最终状态`。
- 中信退款、平安退款回查、提现查询补字段等既有能力规则必须逐能力完整迁移。
- 中信不明来款保持独立 API、package 和业务链，不注册为通用 Capability；其 Application Service 当前
  直接依赖待删除的 `TenantBankConfigProvider`，迁移时仅将该依赖替换为同一个
  `TenantBankConfigLoader`，继续调用上述两个公共方法。除此之外，只允许共享组件移动导致的 import
  调整，不改专项 API、校验、Channel、请求/响应或银行业务逻辑。
- 现有跨银行 `QueryTransStatusRequest` 依赖待删除的 `BankRequestContext`，迁移时删除该共享对象；
  中信、平安 `transstatus` Capability 各自在能力包内读取 Query Slot 并组装请求。
- 平安不得继续依赖 `citic.crypto.CiticOpenBodySigSigner`；将相同的 OPEN-BODY-SIG 算法以中性名称
  `OpenBodySigSigner` 放入 Gateway 基础设施，由两个最终 Sender 直接复用。

## 10. 全量迁移范围

1. 以 `cateringsass/limeng_front@99e696f4e7ab78a1b307b5a2fd3c911698c143fb`
   为行为基线，不沿用 2026-08-25 已放弃的未提交改造。
2. 建立两层 Slot、`flow/slot|node|route`、统一 Registry/Route 和 13 条三节点薄链。
3. 中信迁移 11 个通用能力：6 个交易 + 5 个查询。
4. 平安迁移 11 个通用能力：6 个交易 + 5 个查询；账户状态/余额继续返回既有 `ADAPTER_NOT_READY` 挡板。
5. 平安 `platformPay/platformReceive` 继续不注册，返回能力不支持。
6. 每个银行按能力分包；真复用组件放该银行 `common`。
7. 所有 Capability 直接调用统一 `BankWalletGateway.post`，旧 Router/Dispatch/Handle/业务 Context 在切换完成后删除。
8. 中信不明来款保持独立契约、package 和调用链；只把已删除的配置 Provider 依赖替换为同一个
   `TenantBankConfigLoader`，并允许因中信共享组件移动产生的 import 调整，不改变专项业务行为。
9. `catering-api-front`、渠道表、domain、mapper、DDL 和上游组装方式不变。

## 11. 全量验收标准

### 11.1 可读性验收

- 任一 API 主路径不超过：Service → 三节点 chain → BankRouteNode → 目标 Capability。
- 打开任一 Capability 能按业务顺序读完校验、组装、持久化（如有）、发送、响应和结果。
- 除统一 Gateway 与银行小型 common 组件外，不需跳到 Support/Assembler/Invoker 理解流程。
- Slot 只有两层；`flow` 只有 slot、node、route 三类职责。

### 11.2 静态结构验收

```text
catering-api-front diff = empty
业务 Context = 0
业务抽象父类 = 0
BankSupport God class = 0
Router/Dispatch = 0
Provider/AssemblerRouter/Assembler = 0
钱包业务发送出口 = BankWalletGateway.post 一个
通用能力类 = 22（Citic 11 + PingAn 11，含平安两个挡板）
LiteFlow 薄链 = 13
```

### 11.3 行为验收

- 所有已支持能力的请求字段、固定值、加密、签名、响应码、查询回查和渠道流水行为不变。
- 不支持与待接入状态不变；禁止返回 null 或模拟成功。
- 日志满足 §8：业务日志就地，钱包请求/响应只在最终 Sender 各出现一次。
- 仅新增一家银行并复用既有能力时，不需要修改 Controller、Application Service、API 方法/路径/DTO/
  返回签名、LiteFlow 链、Registry 或 Route；新增 BankCode 枚举值、Loader 平级分支、该银行 Sender 和
  已支持 Capability 即可完成注册式接入。
- 用户 2026-08-25 明确本轮不新增/运行测试、不执行编译；交付只提供静态证据并等待用户 review，
  不得声称“编译通过”“测试通过”或“行为已验证”。

## 12. 交付门禁

全量迁移完成后提交结构清单、22 个能力矩阵、13 条链、行为差异和静态证据给用户 review。
本轮不编译、不测试；代码 commit/push 仍等待用户明确授权。
