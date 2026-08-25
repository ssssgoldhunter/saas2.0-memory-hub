# catering-front 扁平化重构设计（28 号）

> 状态：implemented（2026-08-25 三域注册收口完成并静态验收通过，运行验证由用户人工测试承接；实施与验收记录见 29 号文末）
> 用户确认：2026-08-25
> 当前实施范围：只在 `cateringsass/limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2`
> 已提交扁平代码上完成三域注册增量。
> 30 号报告及 `99e696f4` 只用于追溯三域裁决前历史，不是本轮实现基线或最终验收证据。
> 核心目标：API 不动，内部结构扁平，代码像原 `catering-consume` Handler 和旧 Front Handle 一样能按业务顺序直接阅读。

## 1. 用户裁决

以下内容是本方案的最高优先级约束：

1. `catering-api-front` 不修改；对外 API、DTO、返回类型、调用方组装方式均不受影响。
2. 保留 LiteFlow，但 LiteFlow 只做薄编排，不承载银行业务和层层转发；
   2026-08-25 用户进一步裁决收敛为单节点，后又裁决分域注册：交易链挂
   `frontTransExecute`、交易查询链挂 `frontQueryExecute`、账户链挂 `frontAccountExecute`，每域节点三合一
   （本域 Registry 路由 + 租户配置加载 + 本域能力执行），FrontException 由节点
   收口写 Slot 并结束链；校验与响应归一化分别由 Capability 和
   FrontFlowExecutor/ApplicationService 承接。
3. Slot 参考 lsym UAT `catering-consume` 的命名和继承关系，当前固定命名为
   `FrontBaseSlot`、`FrontTransSlot`、`FrontQuerySlot`、`FrontAccountSlot`；禁止再引入
   `FrontFlowContext`、`BankRequestContext` 等业务 Context。
   2026-08-25 追加裁决（分域注册）：新域 Slot 必须直接平级继承 `FrontBaseSlot`，不得挂在其他域 Slot 之下。
4. Slot 继承关系严格只有两层：`FrontBaseSlot`，以及直接继承它的
   `FrontTransSlot`、`FrontQuerySlot`、`FrontAccountSlot`；不得增加第三层或按能力继续拆 Slot。
5. `flow` 下继续分包：Slot 放在一起，公共节点放在一起，Registry 与 Route 放在一起。
6. 银行模块先按银行放置，再按业务域分包（2026-08-25 用户裁决三域：
   `transaction` 交易 / `query` 查询 / `account` 账户；平台收付款属交易域，
   两家银行域结构对称）；真正跨该银行多个能力复用的代码才进入该银行的 `common`。
7. 每个“银行 × 能力”允许保留自己的组装代码和少量重复，优先保证单个能力从上到下可读。
8. Front 的银行能力扩展框架只有两项：Registry 注册、Route 路由。2026-08-25 追加裁决
   （分域注册）：按业务域拆分——每个域各一套「Capability 接口 + Registry + Execute 节点 +
   链组 + Slot + Application Service」六件套。当前就是交易、查询、账户三个执行域；账户状态、账户余额
   归 Account 域，不再注册到 Query 域。域接口使用强类型 Slot 参数
   （`execute(FrontTransSlot)` / `execute(FrontQuerySlot)` / `execute(FrontAccountSlot)`），
   编译期防错配，禁止父类参数+instanceof 的宽声明。域间零耦合；请求校验和租户加载直接在
   本域唯一 ExecuteNode 内顺序执行，不拆成公共前置节点；禁止恢复 Router、Dispatch、Handle 继承体系。
9. 钱包业务发送只有 `BankWalletGateway.post` 一个统一出口；允许 Gateway 根据银行选择最终
   `BankWalletSender`，但 Sender 必须直接完成实际 HTTP 调用，不再继续套 Client、Support、Invoker。
10. 日志参考旧 Front Handle：Capability 记录业务开始、校验、流水状态、结果和异常；钱包请求/响应
    只由最终 BankWalletSender 各记录一次，删除 Capability/旧 Handle 中重复的完整钱包报文日志。
11. 文件数量不是优化目标。允许多文件，但 package 层级和单笔流程必须简单，不得为了“复用”让阅读者连续跳转。
12. 中信、平安 22 个通用能力的扁平化第一阶段已完成；本轮只做三域接口归属和 13 条单节点链切换，
    不支持能力继续明确不支持，不伪造实现。
13. 扁平化不取消扩展能力：在“不新增 FrontCapability、只接入新银行”的场景下，复用原 API 与 LiteFlow
    链，通过向对应域 Registry 注册该银行 Capability，并注册该银行 Sender 即可路由；不得修改 Controller、
    Application Service、LiteFlow 链结构、三个 Registry 或三个 ExecuteNode 的路由代码。

## 2. 设计目标与非目标

### 2.1 设计目标

- Controller 到银行能力只有一条明显路径：

```text
交易：Controller → FrontTransApplicationService → THEN(frontTransExecute)
     → FrontTransExecuteNode → BankTransCapabilityRegistry → BankTransCapability

查询：Controller → FrontQueryApplicationService → THEN(frontQueryExecute)
     → FrontQueryExecuteNode → BankQueryCapabilityRegistry → BankQueryCapability

账户：Controller → FrontAccountApplicationService → THEN(frontAccountExecute)
     → FrontAccountExecuteNode → BankAccountCapabilityRegistry → BankAccountCapability

三个域的 Capability → BankWalletGateway.post → BankWalletSender
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
│  │  ├─ RoutingBankWalletGateway
│  │  ├─ BankWalletSender
│  │  └─ OpenBodySigSigner
│  ├─ citic/
│  │  ├─ common/          # SequenceGenerator/Sm2Crypto/ResponseChecker/CryptoProperties/最终 Sender 实现（直接 HTTP）
│  │  ├─ transaction/     # Transfer/Consume/Refund/Withdraw/PlatformPay/PlatformReceive 六个 Capability
│  │  ├─ query/           # TransStatus/TransDetail/PlatformDetail 三个 Capability
│  │  ├─ account/         # AccountStatus/AccountBalance 两个 Capability
│  │  └─ unidentified/    # 既有专项，当前不动
│  └─ pingan/
│     ├─ common/          # 最终 Sender 实现（直接 HTTP）/ResponseChecker/CryptoProperties/Sm2Crypto/SequenceGenerator
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
├─ TransStatusResult
├─ TableDataInfo<PlatformTransDetailItem>
└─ TableDataInfo<AccountTransDetailItem>

FrontAccountSlot extends FrontBaseSlot
├─ request/baseData/specialData
├─ capability
├─ AccountStatusResult
└─ AccountBalanceResult
```

约束：

- 继承只允许上图两层，不得增加 `AbstractFrontSlot`、`BankSlot`、`CiticSlot` 等中间层，也不得新增
  `TransferSlot/RefundSlot/AccountStatusSlot` 等能力级 Slot。
- 一次请求只创建一个 Slot，链路全程传同一实例，不做 Slot ↔ Context ↔ DTO 包装转换。
- LiteFlow 节点使用无参 `getFirstContextBean()` 取得当前 Slot，再做明确类型校验；不得写不存在或不兼容的按 Class 精确查找用法。
- Slot 只承载本次调用数据和结果，不注入 Service、Mapper、Gateway，不承载业务执行方法。
- `capability` 由 Application Service 根据当前 API 方法赋值，调用方不能传入或覆盖。
- 参考 lsym UAT 的是 `BaseSlot ← TransSlot/QuerySlot` 命名、继承和无参取 Slot 的方式，
  不复制其与 Front 无关的字段或 Slot 内业务方法。

## 5. Flow：三域单节点薄链

当前执行域固定为交易、查询、账户。每个 API 保留原 chain id，但链内只有所属域的一个 ExecuteNode：

```xml
<chain name="chainFrontTransfer">
    THEN(frontTransExecute);
</chain>

<chain name="chainFrontQueryTransStatus">
    THEN(frontQueryExecute);
</chain>

<chain name="chainFrontQueryAccountStatus">
    THEN(frontAccountExecute);
</chain>
```

LiteFlow v2.16.X 支持单节点 `THEN(node)`。LiteFlow 在此只保留稳定 API chain id 和域入口，不再用多个节点
拆分一次银行调用，也不再存在 `FrontValidateNode`、`TenantResolveNode`、`BankRouteNode`、Prepare、
Dispatch 或 Normalize 节点。

### 5.1 三个 ExecuteNode

三个节点结构同构，分别使用本域强类型 Slot、Loader、Registry 和 Capability：

```text
FrontTransExecuteNode
→ TenantBankConfigLoader
→ BankTransCapabilityRegistry
→ BankTransCapability.execute(FrontTransSlot)

FrontQueryExecuteNode
→ TenantBankConfigLoader
→ BankQueryCapabilityRegistry
→ BankQueryCapability.execute(FrontQuerySlot)

FrontAccountExecuteNode
→ TenantBankConfigLoader
→ BankAccountCapabilityRegistry
→ BankAccountCapability.execute(FrontAccountSlot)
```

每个 ExecuteNode 的主流程固定直接展开：

1. 使用无参 `getFirstContextBean()` 取得唯一 Slot，并在节点入口校验为本域 Slot；禁止使用不存在的
   `getFirstContextBean(Class)`。
2. 校验公共请求结构与 `tenantId`。
3. 调用 `TenantBankConfigLoader.loadTenantBaseInfo(tenantId)`。
4. 回填并核对 `clientId/platformCode/dataSourceId`，解析 `BankCode`。
5. 调用 `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)`，把账户配置写回同一个 Slot。
6. 使用 `(bankCode, capability)` 从本域 Registry 取得唯一 Capability 并执行。
7. 捕获 `FrontException`，写入 Slot 错误码与说明并结束链；其他系统异常继续抛出。

公共校验、租户加载、路由和异常收口只在这一个域节点中按顺序出现，不再拆节点或建立父类。三个域允许
保留少量相同编排代码，禁止为了消除这点重复再创建 `AbstractExecuteNode`、Resolver 或 Support。

`FrontFlowExecutor` 统一执行 LiteFlow，内部允许在 Slot 业务中断或结果为空时返回 `null`；单条非空结果
缺少 `frontRespCode` 时仍按现有语义补 `INTERNAL_ERROR`。三个 Application Service 必须在调用后先检查
Slot、再检查结果：Slot 未标记失败但结果为 `null` 时，单条接口返回带 `INTERNAL_ERROR` 的失败响应，
分页接口返回非空的 `INTERNAL_ERROR` 失败页；禁止形成 `R.ok(null)` 或向 Controller 返回 `null`。

### 5.2 扁平租户配置加载

`TenantBankConfigLoader` 是一个具体类，直接调用 `RemoteConfigServiceClient` 查询租户基础配置和银行配置，
并直接构造 `TenantBankAccountConfig`。Loader 只保留：

- `loadTenantBaseInfo(tenantId)`；
- `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)`。

中信、平安 `accountSpecialData` 白名单在 Loader 内分别使用一个平铺私有方法组装；私有方法不得再调用
第二层业务 helper。删除并禁止恢复 Provider 接口、AssemblerRouter、Assembler 接口/父类、银行 Assembler、
配置 Bundle/Result/Context 和 `prepareContext`。

### 5.3 三个强类型 Registry

```java
public interface BankTransCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontTransSlot slot);
}

public interface BankQueryCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontQuerySlot slot);
}

public interface BankAccountCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontAccountSlot slot);
}
```

每个 Registry 只构造器收集本域接口列表，并建立不可变的
`Map<BankCode, Map<FrontCapability, 本域Capability>>`。同一域内重复 `(BankCode, FrontCapability)`
必须启动失败；银行不存在返回 `BANK_NOT_SUPPORTED`，银行存在但本域能力未注册返回
`CAPABILITY_NOT_SUPPORTED`。三个 Registry/ExecuteNode 内均不得按具体银行写 `if/switch`，也不得建立
统一父接口、统一 Registry、`BankCapabilityKey` 或第二份支持矩阵。

账户状态、账户余额明确归 `BankAccountCapabilityRegistry`；交易状态、平台明细、登记簿明细归
`BankQueryCapabilityRegistry`，禁止交叉注册。

### 5.4 新银行复用已有能力

新银行接入既有能力时，只增加：

1. `BankCode` 枚举值；
2. Loader 内该银行一个平级配置组装分支；
3. 该银行最终 `BankWalletSender`；
4. 该银行真实支持的交易、查询、账户 Capability，并注册到对应域 Registry。

不修改 API 方法/路径/DTO/返回签名、三个 Application Service、13 条 LiteFlow 链、三个 Registry、三个
ExecuteNode 或其他银行代码。未支持能力不注册。本次不创建第三家示例银行。

新增第四个执行域必须同时满足：中间数据/状态形态确实不同、现有三种 Slot 无法准确承载、用户明确批准。
获批后才按强类型 Capability、Registry、ExecuteNode、链组、Slot、Application Service 六件套平行新增；
禁止仅因能力名不同创建新域，也禁止在域内继续拆能力级 Slot。

## 6. Capability：参考 consume/旧 Front 的顺序式代码

每个银行能力只实现所属域接口，不继承业务父类。交易能力主方法按真实执行顺序展开：

```java
public void execute(FrontTransSlot slot) {
    // 1. 读取并校验当前能力输入
    // 2. 直接组装当前银行请求 DTO
    // 3. 查重并写 INIT，再更新 SENDING
    // 4. 通过 BankWalletGateway.post 发送
    // 5. 检查银行响应、更新渠道流水、组装结果并写回 slot
}
```

### 6.1 代码层级硬约束

- Capability 只实现 `BankTransCapability`、`BankQueryCapability`、`BankAccountCapability` 之一，
  禁止实现统一宽接口，禁止 `extends AbstractBankHandle` 或其他业务父类。
- 禁止 `AbstractBankHandle → BankHandle → BankTransHandle → XxxHandle` 一类继承链。
- 禁止 `Route → Dispatch → Handle → Support → Client → Gateway` 调用链。
- 主方法必须直接显示上述五步；不得把五步分别转发到五个 Service 后只剩方法名。
- 能力自己的字段校验、setter 组报文、渠道 Entity 组装和结果映射可以留在同一个类中。
- 复杂片段可以提取为当前类的私有方法；私有业务 helper 最多一层，且紧跟对应主流程，禁止 helper 再层层调用业务 helper。
- 同一银行两个能力即使有 10～30 行相似组装代码，也允许分别保留；先保证独立可读，再讨论真实复用。
- 不设“每个类必须少于 300 行”等机械指标。类长不是问题，职责混杂和阅读跳跃才是问题。
- 一个 Capability 只处理一个 `(bank, capability)`，不得跨域注册或在类内 `switch(capability)`。
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
- Gateway 按银行路由到一个最终 `BankWalletSender` 实现，该实现直接执行 HTTP。现有实现类可以保留
  `WalletHttpClient` 名称，类名不是验收指标；但它本身必须就是最终 Sender，后面不得再增加
  `WalletHttpClient`、`Invoker`、`ClientFacade`、`Support.invokeBank` 等包装层。
- 连接、统一签名、HTTP、超时和底层响应读取属于 Gateway 基础设施，其中最终银行 Sender 直接执行 HTTP；
  能力专属的 apiName、bizFunc、chnlNo 和请求字段仍在 Capability 明示。
- Capability 只记录业务步骤和渠道流水，不记录钱包请求/响应报文；最终 Sender 分别记录一次完整明文
  请求 JSON 和一次完整明文响应 JSON，不做字段脱敏。这一明文规则只适用于钱包报文 body；`appKey`、
  私钥、签名原文、签名头、`Authorization`、Cookie 和非报文配置不得进入日志。
- 银行响应判断使用该银行 `common` 下的小型 `ResponseChecker`，不得把结果组装也塞进 Checker。

## 8. 日志、异常与敏感信息

日志参考旧 Handle 的就地写法，职责固定如下：

1. API：入口、完成和异常收口日志保持，定位一次外部调用。
2. 租户加载与 Route：配置加载开始/完成/失败、路由选中/未注册/重复注册均有日志，不打印配置密钥。
3. Capability 开始：bank、capability、tenantId、业务主/子流水。
4. Capability 过程：关键校验、报文组装完成、渠道流水 INIT/SENDING/最终状态及 recordId。
5. 钱包发送前：只由最终 Sender 记录一次 `wallet_request_sending`，明确包含 bank、apiName、frontSsn
   和完整明文请求 JSON，不脱敏。
6. 钱包响应后：只由最终 Sender 记录一次 `wallet_response_received`，明确包含同一组定位字段、完整明文
   响应 JSON、HTTP 状态和耗时，不脱敏；Capability 只记录归一化结果。
7. 异常：Capability 记录业务执行阶段、recordId、状态和异常；最终 Sender 记录一次
   `wallet_request_failed`，明确包含同一组定位字段、失败阶段、是否已经发出请求、耗时和通信异常。
   异常必须保留堆栈，不得只打印异常 message。

旧 Handle/Capability 中与 Sender 重复的“发送钱包请求/银行响应”日志必须删除。钱包报文 body 按用户
裁决完整明文记录；调用凭证、密钥、签名材料和 HTTP 鉴权头仍禁止记录。日志不得依赖多层 AOP 才能理解
真实业务步骤；AOP 只保留跨接口的入口/完成/失败事件。

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

## 10. 三域注册增量范围

1. 以 `cateringsass/limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2`
   已提交扁平代码为唯一实现起点；全部 22 个 Capability 都必须完成三域接口、Slot 参数和 Registry
   归属迁移，但不得重写第一阶段已经完成的银行业务逻辑。
2. 建立 `FrontAccountSlot` 和 `FrontAccountApplicationService`；已有 Trans/Query 与新增 Account Slot
   均直接继承 `FrontBaseSlot`。
3. 把既有 22 个通用 Capability 改为实现所属域强类型接口：Transaction 12、Query 6、Account 4；
   不改能力内部银行字段、持久化、成功判定和支持状态。
4. 建立三个 Registry 和三个 ExecuteNode，删除单一 Capability 接口、单一 Registry 和
   `FrontBankExecuteNode`，不保留兼容转发层。
5. 13 条原 chain id 改为三类单节点表达式：交易 8、交易查询 3、账户 2。
6. 租户配置统一由三个 ExecuteNode 直接调用 `TenantBankConfigLoader`，不恢复 Provider/Assembler 链。
7. 平安账户状态/余额继续返回既有 `ADAPTER_NOT_READY` 挡板；平安 `platformPay/platformReceive`
   继续不注册，返回能力不支持。
8. 中信不明来款保持独立契约、package 和调用链，只继续复用现有 Loader/Gateway/common，不注册三域 Capability。
9. `catering-api-front`、Controller 对外签名、渠道表、domain、mapper、DDL 和上游组装方式不变。

## 11. 全量验收标准

### 11.1 可读性验收

- 任一 API 主路径不超过：所属域 Application Service → 单节点 chain → 本域 ExecuteNode → 本域 Registry
  → 目标 Capability。
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
通用能力类 = 22（交易 12 + 查询 6 + 账户 4，含平安两个账户挡板）
执行域 = 3（transaction/query/account）
强类型 Registry = 3
ExecuteNode = 3
LiteFlow 单节点薄链 = 13（交易 8 + 查询 3 + 账户 2）
```

### 11.3 行为验收

- 所有已支持能力的请求字段、固定值、加密、签名、响应码、查询回查和渠道流水行为不变。
- 不支持与待接入状态不变；`FrontFlowExecutor` 内部 `null` 必须由 Application Service 转成失败响应，
  对外禁止返回 null 或模拟成功。
- 日志满足 §8：业务日志就地，完整明文钱包请求/响应只在最终 Sender 各出现一次；密钥、签名材料和
  HTTP 鉴权头不进入日志。
- 仅新增一家银行并复用既有能力时，不需要修改 Controller、Application Service、API 方法/路径/DTO/
  返回签名、LiteFlow 链、Registry 或 Route；新增 BankCode 枚举值、Loader 平级分支、该银行 Sender 和
  已支持 Capability 即可完成注册式接入。
- 本轮三域注册改造不新增/运行测试、不执行编译；交付只提供静态证据并等待用户 review，不得把旧版本
  的编译记录表述为三域最终状态已编译通过。

## 12. 交付门禁

三域注册增量完成后提交结构清单、22 个能力矩阵、13 条链、行为差异和静态证据给用户 review。
本轮不编译、不测试；代码 commit/push 仍等待用户明确授权。
