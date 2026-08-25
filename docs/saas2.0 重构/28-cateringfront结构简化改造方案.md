# catering-front 扁平化重构设计（28 号）

> 状态：approved-design / not-implemented
> 用户确认：2026-08-25
> 当前实施授权：全量迁移（2026-08-25 用户最新裁决）。
> 基线说明：2026-08-25 的未提交全面改造代码已放弃，不是设计事实，也不得作为下一位 AI 的续写基础；是否清理工作区必须另行确认。
> 核心目标：API 不动，内部结构扁平，代码像原 `catering-consume` Handler 和旧 Front Handle 一样能按业务顺序直接阅读。

## 1. 用户裁决

以下内容是本方案的最高优先级约束：

1. `catering-api-front` 不修改；对外 API、DTO、返回类型、调用方组装方式均不受影响。
2. 保留 LiteFlow，但 LiteFlow 只做薄编排，不承载银行业务和层层转发。
3. 业务数据载体统一命名为 Slot，禁止再引入 `FrontFlowContext`、`BankRequestContext` 等业务 Context。
4. Slot 继承关系严格只有两层：`FrontBaseSlot`，以及直接继承它的 `FrontTransSlot`、`FrontQuerySlot`。
5. `flow` 下继续分包：Slot 放在一起，公共节点放在一起，Registry 与 Route 放在一起。
6. 银行模块先按银行放置，再按能力分包；真正跨该银行多个能力复用的代码才进入该银行的 `common`。
7. 每个“银行 × 能力”允许保留自己的组装代码和少量重复，优先保证单个能力从上到下可读。
8. Front 的框架职责只有两项：Registry 注册、Route 路由。禁止恢复 Router、Dispatch、Handle 继承体系。
9. 钱包发送只有一个统一出口；能力类直接调用该出口，不再套银行 Client、Support、Invoker 等多层包装。
10. 日志参考旧 Front Handle：在真实步骤附近记录，不为了日志建立额外业务层。
11. 文件数量不是优化目标。允许多文件，但 package 层级和单笔流程必须简单，不得为了“复用”让阅读者连续跳转。
12. 中信、平安现有通用交易与查询能力全部迁移，13 条 LiteFlow 链全部切换；不支持能力继续明确不支持，不伪造实现。

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
- 新增银行能力时新增能力包和注册实现，不修改 Controller、公共 Route 或其他银行能力。
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
├─ service/
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
│  │  └─ RoutingBankWalletGateway
│  ├─ citic/
│  │  ├─ common/
│  │  │  ├─ CiticSequenceGenerator
│  │  │  ├─ CiticSm2Crypto
│  │  │  ├─ CiticResponseChecker
│  │  │  └─ CiticCryptoProperties
│  │  ├─ transfer/
│  │  │  ├─ CiticTransferCapability
│  │  │  └─ CiticTransferRequest
│  │  ├─ consume/
│  │  ├─ withdraw/
│  │  ├─ refund/
│  │  ├─ platformpay/
│  │  ├─ platformreceive/
│  │  ├─ accountstatus/
│  │  ├─ accountbalance/
│  │  ├─ transstatus/
│  │  ├─ transdetail/
│  │  ├─ platformdetail/
│  │  └─ unidentified/          # 既有专项，当前不动
│  └─ pingan/
│     ├─ common/
│     ├─ transfer/
│     ├─ consume/
│     ├─ withdraw/
│     ├─ refund/
│     ├─ transferauth/
│     ├─ resendauthcode/
│     ├─ accountstatus/
│     ├─ accountbalance/
│     ├─ transstatus/
│     ├─ transdetail/
│     └─ platformdetail/
├─ config/
├─ domain/
└─ mapper/
```

### 3.1 package 硬约束

- `flow` 只允许 `slot`、`node`、`route` 三个职责包；不得再出现 `flow/context`、`flow/component/dispatch` 等层级。
- `channel/{bank}` 只允许“能力包 + common + 已确认的独立专项包”。
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
└─ 查询结果
```

约束：

- 继承只允许上图两层，不得增加 `AbstractFrontSlot`、`BankSlot`、`CiticSlot` 等中间层。
- 一次请求只创建一个 Slot，链路全程传同一实例，不做 Slot ↔ Context ↔ DTO 包装转换。
- LiteFlow 节点使用无参 `getFirstContextBean()` 取得当前 Slot，再做明确类型校验；不得写不存在或不兼容的按 Class 精确查找用法。
- Slot 只承载本次调用数据和结果，不注入 Service、Mapper、Gateway，不承载业务执行方法。
- `capability` 由 Application Service 根据当前 API 方法赋值，调用方不能传入或覆盖。

## 5. Flow：只做公共校验、租户装配和路由

每个 API 仍有具名链，但链结构一致且不知道银行：

```xml
<chain name="transferChain">
    THEN(frontValidate, tenantResolve, bankRoute);
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

不得为了加载一个配置建立父类、模板方法或多级 Resolver。若现有配置端口可以直接完成查询，节点直接调用它。

### 5.3 `BankRouteNode` 与 Registry

`BankRouteNode` 只做一件事：

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

## 6. Capability：参考 consume/旧 Front 的顺序式代码

每个银行能力实现一个 `BankCapability`，不继承业务父类。主方法按真实执行顺序展开：

```java
public FrontTransResult execute(FrontTransSlot slot) {
    // 1. 读取并校验当前能力输入
    // 2. 直接组装当前银行请求 DTO
    // 3. 查重并写 INIT，再更新 SENDING
    // 4. 通过 BankWalletGateway.post 发送
    // 5. 检查银行响应、更新渠道流水、组装 Front 结果
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
- 该银行统一的 SM2/签名算法；
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
- 不再为每个银行或能力增加 `WalletHttpClient`、`Invoker`、`ClientFacade`、`Support.invokeBank` 包装层。
- 连接、统一签名、HTTP、超时和底层响应读取属于 Gateway；能力专属的 apiName、bizFunc、chnlNo 和请求字段仍在 Capability 明示。
- Capability 在发送语句前记录脱敏请求摘要，在收到结果后记录脱敏响应与耗时。
- 银行响应判断使用该银行 `common` 下的小型 `ResponseChecker`，不得把结果组装也塞进 Checker。

## 8. 日志、异常与敏感信息

日志参考旧 Handle 的就地写法，至少覆盖：

1. 能力开始：bank、capability、tenantId、业务主/子流水。
2. 渠道流水状态：INIT、SENDING、最终状态和 recordId。
3. 钱包发送前：apiName、frontSsn、脱敏后的请求摘要。
4. 钱包响应后：Front 归一化码、银行响应码、耗时。
5. 异常：执行阶段、是否明确未发送、recordId、耗时和异常堆栈。

禁止记录密钥、完整账号/卡号、手机号、证件号、姓名、验证码和完整原始报文。日志不得依赖多层 AOP 才能理解真实业务步骤；AOP 只保留跨接口的入口/完成/失败事件。

异常保持既有语义：请求错误、银行不支持、能力不支持、重复交易、通信失败、结果未知、银行拒绝必须使用各自错误码；`F300001` 只表示重复交易，绝不是“不支持能力”。

## 9. API、数据和行为保持

- `catering-api-front` 必须零 diff。
- Controller 方法签名、Feign 契约、`R<T>` / `TableDataInfo<T>` 返回结构不变。
- 10 张渠道表、Entity、VO、Mapper、XML、DDL 和分片规则不因本结构迁移调整。
- 金额继续使用 `Long` 人民币分。
- 重复交易仍按当前银行当前能力的固定渠道表检查，禁止动态表名。
- 交易流水仍执行 `INIT → SENDING → 最终状态`。
- 中信退款、平安退款回查、提现查询补字段等既有能力规则必须逐能力完整迁移。
- 中信不明来款保持独立 API 和独立业务链，不注册为通用 Capability；其 package 与公共组件按新结构整理。

## 10. 全量迁移范围

1. 以代码仓库当前已提交 HEAD 为行为基线，不沿用 2026-08-25 已放弃的未提交改造。
2. 建立两层 Slot、`flow/slot|node|route`、统一 Registry/Route 和 13 条三节点薄链。
3. 中信迁移 11 个通用能力：6 个交易 + 5 个查询。
4. 平安迁移 11 个通用能力：6 个交易 + 5 个查询；账户状态/余额继续返回既有 `ADAPTER_NOT_READY` 挡板。
5. 平安 `platformPay/platformReceive` 继续不注册，返回能力不支持。
6. 每个银行按能力分包；真复用组件放该银行 `common`。
7. 所有 Capability 直接调用统一 `BankWalletGateway.post`，旧 Router/Dispatch/Handle/业务 Context 在切换完成后删除。
8. 中信不明来款保持独立契约和调用链，仅整理 package 与公共组件引用。
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
钱包业务发送出口 = BankWalletGateway.post 一个
通用能力类 = 22（Citic 11 + PingAn 11，含平安两个挡板）
LiteFlow 薄链 = 13
```

### 11.3 行为验收

- 所有已支持能力的请求字段、固定值、加密、签名、响应码、查询回查和渠道流水行为不变。
- 不支持与待接入状态不变；禁止返回 null 或模拟成功。
- 日志满足 §8 且不泄露敏感信息。
- 编译和测试只有在用户明确授权后执行，并只能引用最终代码状态产生的结果。

## 12. 交付门禁

全量迁移完成后提交结构清单、22 个能力矩阵、13 条链、行为差异和静态证据给用户 review。代码 commit/push、编译和测试仍分别等待用户明确授权。
