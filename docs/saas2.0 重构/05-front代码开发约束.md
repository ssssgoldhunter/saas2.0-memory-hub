# Front 代码开发约束

> **28 号结构简化修订（2026-08-25，用户已批准设计）**：初版扁平化已实施，最终三域注册待实施。
> 28 号是结构简化的最高优先级设计。本文旧章节中的 Router/Handle 继承、三段式 Context、
> 银行多级 Client 和全量迁移描述只用于核对已提交基线，不得作为新代码模板。
> 目标结构固定为两层 Slot、交易/查询/账户三个强类型执行域、`flow/slot|node|route`、
> 按域分组的 `channel/{bank}/{transaction|query|account}`、
> 银行 `common` 小型真复用组件和唯一 `BankWalletGateway.post` 发送出口；明确禁止 BankSupport God class。

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：current
> 生效日期：2026-08-04
> 适用模块：`catering-api-front`、`catering-front` 及其使用的 `catering-common-core`
> 约束级别：后续 Front 代码开发必须遵守

---

## 0. 28 号三域注册增量强制结构约束

1. **范围**：在既有扁平代码上将中信、平安全部 22 个通用 Capability 迁移到所属域的强类型接口、
   Slot 参数和 Registry，并切换 13 条 LiteFlow 单节点链；不得跳过任何能力。只调整框架归属，
   不重写第一阶段已经完成的银行业务逻辑，支持状态和业务行为不变。
2. **API**：`catering-api-front` 必须零 diff；Controller、Feign、请求 DTO 和返回签名不变。
3. **Slot**：只允许 `FrontBaseSlot ← FrontTransSlot/FrontQuerySlot/FrontAccountSlot` 两层；
   禁止新增业务 `*Context` 或能力级 Slot。
4. **flow 分包**：只按 `slot`、`node`、`route` 分组；Route 只有
   三域注册（2026-08-25 裁决）：交易 `FrontTransExecuteNode → BankTransCapabilityRegistry →
   BankTransCapability`、查询 `FrontQueryExecuteNode → BankQueryCapabilityRegistry →
   BankQueryCapability`、账户 `FrontAccountExecuteNode → BankAccountCapabilityRegistry →
   BankAccountCapability`；域接口强类型 Slot 参数，禁止父类参数+instanceof 宽声明；
   禁止 Router、Dispatch 和 Handle 继承体系。
5. **channel 分包**：银行下先按 `transaction/query/account` 域分包，银行真实共用组件放 `common`；域包内不得继续拆
   `client/protocol/request/service/support/assembler/mapper`。
6. **能力代码**：主方法按“校验→组报文→查重/INIT→SENDING→统一发送→响应落库/结果”顺序展开；
   允许能力间保留少量重复，不得用多层 helper、父类或 Support 隐藏业务步骤。
7. **common 准入**：只有至少两个已实现能力真实复用的序列号、加密、响应判断或配置对象可以进入；
   禁止聚合校验、组装、持久化、发送和结果映射的 `CiticBankSupport/PingAnBankSupport`。
8. **发送**：业务能力只直接调用 `BankWalletGateway.post`；Gateway 只再分派到最终
   `BankWalletSender`，Sender 直接完成 HTTP 调用。现有实现类名可以保留，但该类本身必须就是最终
   Sender，后面禁止继续套 Client、Support、Invoker、Facade。
9. **代码层级**：Capability 只实现一个接口，不继承业务父类；私有业务 helper 最多一层并紧邻主流程。
   文件数和类行数不是指标，“打开能力类能读完主流程”才是验收标准。
10. **package**：所有类必须位于 `com.chinaums.front...`，禁止 `package citic;`、`package pingan;`。
11. **日志**：采用用户确认的 B 方案。Capability 只记录业务步骤和状态变化；最终
    `BankWalletSender` 在发送前统一记录一次 `wallet_request_sending`，响应后记录一次
    `wallet_response_received`，失败时记录一次 `wallet_request_failed`；请求/响应 JSON 完整明文展示，
    迁移时删除其他层对同一报文的重复日志。`appKey`、私钥、签名原文/签名头、
    Authorization、Cookie 等非报文调用凭证仍禁止入日志。
12. **租户配置**：保留清晰调用链，但彻底压缩层级：
    三个 ExecuteNode 均直接调用 `TenantBankConfigLoader → RemoteConfigServiceClient`。Loader 是具体类，
    直接查询并组装；禁止保留 `Provider → AssemblerRouter → Assembler`、抽象父类或银行组装器继承链。
13. **验证**：三域切换后删除旧统一 Capability/Registry/ExecuteNode，不恢复 Context/Router/Dispatch/Handle；
    本轮用户明确要求不新增/运行测试、
    不执行编译，仅做静态 review，不得把静态检查表述为测试或编译通过。
14. **新银行扩展**：复用已有 FrontCapability 时，保留原 API、三个 Application Service 与 LiteFlow 链；
    只增加 `BankCode` 枚举项、Loader 平级组装分支、该银行最终 Sender 和真实支持的三域扁平 Capability。
    三个 Registry/ExecuteNode/Gateway 依赖实现自描述与列表注册，不得增加具体银行 `if/switch`。

完整设计、目录和三域验收标准见
[28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)。
具体执行步骤、文件清单和停止门禁见
[29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)。

---

## 1. 核心结论

1. `catering-api-front` 只保存 API 契约、请求响应模型、常量和枚举。
2. `catering-front` 保存全部功能实现，不再建立 `api/common/service` 子模块。
3. 跨模块公共返回、Front 错误码和 Front 公共异常统一放在 `catering-common-core`。
4. 所有 Front API 的返回结构遵守以下固定规范，禁止增加 `FrontResponse` 中间包装层：
   - **单条交易、交易状态和账户查询**：返回 `R<具体结果>`（如 `R<FrontTransResult>`）；
   - **分页明细查询**：直接返回工程统一的 `TableDataInfo<具体行>`，不用 `R` 包裹；
   - **无返回体操作类**：返回 `R<Void>`。
5. API、Controller、Application Service 均使用同一个返回签名；Controller 只透传
   Application Service 返回值。内部 Route 和 Capability 不返回 `R`；**分页 Capability 直接返回
   `TableDataInfo<具体行>`**（含 code/msg/rows/total/totalPage，业务失败 Capability 内填
   `code=500` + 空 rows + 安全 msg）。非空分页结果由 Application Service 纯透传；仅当
   `FrontFlowExecutor` 返回 `null` 时，Application Service 负责构造非空的 `INTERNAL_ERROR` 失败页。
   **禁止引入 `FrontPageResult` 等分页中间承接对象**（2026-08-19 用户裁决，
   原内部承接层废除）。
6. LiteFlow 节点遇可预期业务失败时写 Slot 后中断；非 LiteFlow 路径抛 `FrontException`；
   系统异常继续抛出，由 `FrontExceptionHandler` 收口。
7. 不支持、未接入和结果未知必须显式表达。`FrontFlowExecutor` 内部允许返回 `null`，但三个
   Application Service 必须立即判断并转换为失败响应；Controller 和最终 API 禁止返回 `null` 或模拟成功。
8. 对外请求固定为 `baseData + specialData` 两段；进入链路后由所属域 ExecuteNode 调用具体 Loader，
   将 `accountConfig` 写入同一个 Slot，不再转换为三段式 Context。
9. 租户银行配置只能由 Front 使用 `tenantId + bankCode` 查询，禁止由调用方传入或由具体银行
   Capability 各自重复查询。
10. 银行账户配置必须按“通用强类型对象 + 银行 `accountSpecialData` 策略”组装；
    交易 `specialData` 与账户 `accountSpecialData` 必须完全分离。
11. 渠道流水必须按“银行 + 交易业务”拆分；每张表必须保留来源业务主/子记录关联、业务及银行明确字段
    和 `reserve1/reserve2/reserve3`，禁止恢复单一统一渠道表或保存整段报文快照。
12. 持久层 Entity ↔ VO/BO 对象转换必须使用 MapStruct（`@AutoMapper` + `MapstructUtils.convert`），
    禁止手写 `setXxx(getXxx())`；依赖经 `catering-common-core` 传递，catering-front 不重复声明（见 §3.9）。
13. `FrontCapability` 是 API 方法内部固定的业务能力标识，调用方不得传入或覆盖；
    `BankTransCapabilityRegistry`/`BankQueryCapabilityRegistry`/`BankAccountCapabilityRegistry` 各以
    类型安全的 `(BankCode, FrontCapability)` 精确定位唯一 Capability（三域注册）。
    capability 同时用于日志定位和渠道流水记录，但不得用于动态选表或公共 `switch`。
14. Front 的定位是银行渠道适配层，只校验路由、银行协议、报文组装和本次渠道调用所必需的条件；
    余额、业务资格、原业务状态、累计金额、业务限额等属于业务系统的规则，未被当前银行协议或明确需求
    指定为 Front 职责时，不得在 Front 中擅自增加校验、跨服务查询、锁或状态维护。

---

## 2. 模块职责与依赖方向

### 2.1 `catering-common-core`

允许保存：

- `com.chinaums.common.core.domain.R`：工程统一返回主体；
- `com.chinaums.common.core.error.FrontErrorCode`：Front 公共错误码；
- `com.chinaums.common.core.exception.FrontException`：Front 公共业务异常；
- `com.chinaums.common.core.constant.front`：Front 银行配置查询 key 和账户配置 `JSONObject` 字段 key 常量；
- 真正跨业务模块复用、与具体银行无关的基础能力。

禁止保存：

- Front Controller、Application Service、Router、Handle；
- 中信、平安协议 DTO；
- 中信、平安账户配置对象或组装实现；
- 银行地址、渠道号、功能码、签名和加密实现；
- 只被单个 Front 实现类使用的工具。

### 2.2 `catering-api-front`

允许保存：

- Feign/API 接口；
- `FrontRequest`、`FrontBaseResult` 及其具体结果对象；
- API 方法签名使用的请求和响应模型；
- API 路径等契约常量；
- 银行编码、能力、交易状态等契约枚举；
- Bean Validation 和 OpenAPI 契约注解；
- specialData 组装工具类 `FrontSpecialDataAssembler`（纯静态映射、全实例方法零 static，
  银行路由为工厂模式：同包独立银行组装类实现 `BankSpecialDataAssembler` 接口，契约见 15 号 spec §5）。

禁止保存：

- Controller 和业务实现；
- Router、Registry、Handle；
- `FrontException`、异常处理器；
- 银行请求响应 DTO；
- 配置加载、HTTP、签名、加密和数据库代码；
- 仅为某一家银行服务的字段模型。

### 2.3 `catering-front`

保存所有运行时功能实现：

- Controller；
- Application Service；
- Router 和不可变 Handle Registry；
- Handle SPI 与中信、平安实现；
- 银行协议 DTO、配置解析、HTTP、签名和加密；
- LiteFlow、渠道流水、重复交易校验、状态机；
- 钱包发送共用网关（`channel/gateway/BankWalletGateway` + `BankWalletSender`，2026-08-18 用户裁决
  公共化）：全部银行钱包调用统一入口，两个 HttpClient 收编为银行 sender；**新银行接口（账户类/
  划付等）一律走网关五步 SOP（ContractKeys→常量键报文→gateway.post→ResponseChecker→capability
  注册），禁止新建 InterService 式每银行方法封装类**。HttpClient 收尾纪律（2026-08-20）：
  响应体完整读取并记录日志后，收尾异常（如资源关闭）不得丢弃银行结果；BOM 去除后再解析；
  `JSONException` 独立映射 `F400002`；
- `FrontExceptionHandler`；
- 单元测试和集成测试。

### 2.4 依赖方向

```text
catering-front
├─→ catering-api-front
└─→ catering-common-core

catering-api-front
└─→ catering-common-core

catering-common-core
  ─X→ catering-api-front
  ─X→ catering-front
```

禁止形成反向依赖或循环依赖。

### 2.5 依赖版本管理约束

所有第三方大依赖的版本必须统一在工程根 `pom.xml` 的 `<properties>` 声明版本号、在
`<dependencyManagement>` 注册坐标，子模块 `pom.xml` 引用时**只写 groupId + artifactId，禁止写
`<version>`**。当前已统一管理的第三方依赖包括但不限于：Spring Boot/Cloud（BOM）、MyBatis Plus 全家桶
（starter/extension/generator/jsqlparser/annotation）、dynamic-datasource、LiteFlow、MapStruct &
MapStruct Plus、Hutool（BOM）、Fastjson2、BouncyCastle、Redisson、Lock4j、Sa-Token、Velocity、
p6spy、FastExcel、OpenCSV、SpringDoc、Lombok 等。

新增第三方依赖时必须：

1. 先在根 `pom.xml` 的 `<properties>` 增加版本号属性（如 `<xxx.version>`);
2. 在根 `pom.xml` 的 `<dependencyManagement>` 注册 `groupId/artifactId/version`;
3. 子模块 `pom.xml` 只写 `groupId/artifactId`，不写 `version`。

禁止：

- 在 `catering-front`、`catering-api-front` 等子模块 `pom.xml` 内写死第三方依赖 `<version>`;
- 同一第三方库在多个子模块出现不同版本;
- 绕过 parent 直接引入未在根 pom 管理的第三方大依赖（如确需引入，先按上述 1、2 步登记再使用）。

目的：保证全工程第三方依赖版本一致，便于统一升级和安全漏洞修复，避免依赖冲突。

---

## 3. 已提交基线的运行时层级（仅供 P0 对照）

> 本节记录 28 号实施前的已提交结构，用于核对行为和迁移差异。新增结构必须执行 §0 和 28 号，
> 不得继续扩展本节的 Router、Handle 父类、BankRequestContext 或银行多级子包。

```text
Feign/API 接口
→ Controller
→ Application Service
→ Transaction/Query/Account Registry
→ Bank Capability Handler
→ channel/{bank} 协议客户端
→ 银行或钱包平台
```

LiteFlow 业务失败写 Slot 并主动结束；非 LiteFlow 业务异常和系统异常沿调用栈抛出，由
`FrontExceptionHandler` 转换为 `R<FrontBaseResult>`。

### 3.1 Controller

Controller 必须：

- 实现 `catering-api-front` 中的 API 接口；
- 接收已经定义好的强类型 `FrontRequest<T>`；
- 调用 Application Service；
- 单笔接口直接透传 Application Service 返回的 `R<具体结果>`，分页接口直接透传
  `TableDataInfo<具体行>`，不得再次包装。

Controller 禁止：

- 编写银行判断；
- 解析 `specialData`；
- 直接调用 Router、Handle、HTTP 客户端或 Mapper；
- 捕获业务异常后返回自定义 Map；
- 手工构造另一套响应主体。

### 3.2 Application Service

Application Service 负责：

- 公共业务编排；
- 读取请求上下文；
- 根据当前 API 方法固定 capability 并进入对应领域业务链；
- 将 `platformCode` 解析为 `BankCode`，在该领域 Registry 中按
  `(BankCode, FrontCapability)` 精确选择能力 Handler；
- 调用已选 Handle 的 `prepareContext()` 完成内部上下文装配；
- 通过通用执行节点调用已选能力 Handler，禁止再按 `capability` 做公共 `switch` 分派；
- 重复交易校验、渠道流水和状态机协调；
- 记录业务分派、结果与耗时日志。

Application Service 与内部 API 方法签名一致：单笔接口返回 `R<具体结果>`，Front 业务成功使用
`R.ok(result)`，银行业务失败、能力失败或其他可预期业务失败使用 `R.fail(message, result)`；分页接口
返回 `TableDataInfo<具体行>`，成功固定 `code=200`，业务失败固定 `code=500`、空 `rows` 和安全 `msg`。

Application Service 禁止：

- 写死中信或平安功能码；
- 直接组装银行报文；
- 直接执行签名、加密或 HTTP 调用；
- 使用 `instanceof` 判断具体银行实现。

### 3.3 分域 Registry（28 号三域定稿）

交易、查询、账户三个域各自拥有强类型 Registry（无独立 Router 类，路由在域 ExecuteNode 第⑥步内完成）：

```text
BankTransCapabilityRegistry.get(bankCode, capability)
BankQueryCapabilityRegistry.get(bankCode, capability)
BankAccountCapabilityRegistry.get(bankCode, capability)
```
（银行未注册 → BANK_NOT_SUPPORTED；能力未注册 → CAPABILITY_NOT_SUPPORTED，均默认统一文案）

API/Controller/Application Service 已经表达所属领域，禁止统一 Router 再根据 capability 名称、枚举集合或
`TRANSFER` 前缀猜测 Transaction/Query/Account。进入正确领域后，Registry 必须读取 API 内部固定的
capability，并以类型安全的 `(BankCode, FrontCapability)` 直接定位唯一能力 Handler。

Registry 必须：

- 通过构造器注入当前领域的 `List<BankCapabilityHandler>`；
- 启动时创建不可变映射；
- 发现同一 Registry 内同一 `(BankCode, FrontCapability)` 重复实现时立即启动失败；
- `BankCode` 无法解析或银行整体未接入时返回 `BANK_NOT_SUPPORTED`；
- 银行已接入但未注册当前 capability 时返回 `CAPABILITY_NOT_SUPPORTED`；
- 记录注册、重复注册、查找失败和路由结果日志。

禁止使用 `BeanPostProcessor` 隐式注册，也禁止静默覆盖已有 Handle。

Transaction、Query 和后续 Account 是不同 Registry；同一银行可以在不同领域、不同 capability 下分别注册，
不属于重复。不得额外维护“银行支持能力矩阵”，Registry 中真实存在的复合键就是唯一支持事实来源。

### 3.4 Handle

Handle 负责：

- 声明银行编码和唯一 capability；
- 通过统一父类加载并校验当前租户的银行账户配置；
- 在被调用的明确业务方法中解析本银行、本业务的 `specialData`；
- 选择功能码、路径和协议；
- 组装银行请求；
- 调用银行客户端；
- 把银行结果转换为确定类型的 `FrontBaseResult` 子类。

Handle 方法必须使用明确请求和明确返回类型，禁止使用无法约束的 `<T> T`。

Handle 的业务校验边界固定为“能否组装并发出当前银行接口的有效报文”：

- 校验公共请求结构、当前银行具体接口的协议必填字段、字段格式和加密前置条件；
- 校验 `platformCode` 路由、租户银行配置和当前渠道调用所需配置是否有效；
- 交易发送前在当前银行当前业务表检查本次渠道流水是否重复；
- 只读取当前银行具体接口确实需要的字段，不因旧项目存在某项业务判断就迁移该判断；
- 银行协议中的“原交易定位字段二选一”和其他协议字段的必填性必须分别判断；选择一种定位方式不能
  免除原账户、原交易日期、资金类型等独立必填字段。Front 只校验这些字段能否完整组装报文，不得自行
  扩展为原业务记录存在性、业务终态、余额、原金额、累计金额或业务资格校验；
- 除非当前字段契约明确规定由 Front 负责，否则不得为业务规则增加跨服务查询、数据库行锁、累计字段、
  原业务状态更新或补偿台账。银行对业务条件的拒绝按银行响应归一化返回，不在调用前重复实现业务系统规则。

能力处理不建立统一状态表：

- 注册的“银行 + capability”能力 Handler 执行该唯一业务，不在类内维护能力 `switch`；
- Registry 找不到当前复合键时直接返回 `CAPABILITY_NOT_SUPPORTED`；
- 已保留草稿但尚未完成接入时，可注册明确的待接入 Handler，并在其入口返回或抛出
  `ADAPTER_NOT_READY`；
- 禁止在 Registry 之外、公共校验节点或公共 Dispatch 中维护第二份支持矩阵。

### 3.5 已提交基线的 Handle 与配置端口（仅用于迁移核对）

> 本节以下内容描述 `99e696f4e7ab78a1b307b5a2fd3c911698c143fb` 已提交基线，不是目标实现模板。
> 28/29 号迁移必须删除 `AbstractBankHandle` 和 `TenantBankConfigProvider`。最终由交易、查询、账户三个
> ExecuteNode 分别直接调用 `TenantBankConfigLoader → RemoteConfigServiceClient`；Node 只负责本域顺序编排，
> 具体 Loader 直接完成两次配置查询、校验和账户配置组装。Loader 只暴露
> `loadTenantBaseInfo(tenantId)` 与 `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)` 两个方法，
> 不新增配置 Bundle/Result/Context；中信不明来款 Application Service 也直接复用该 Loader。

中信、平安的 Transaction/Query 能力 Handler 必须复用统一的 `AbstractBankHandle` 配置装配能力。统一
父类负责：

1. 使用当前能力 Handler 的 `bankCode()`，禁止信任调用方传入另一个银行编码；
2. 通过 `TenantBankConfigProvider.load(tenantId, bankCode)` 查询配置；
3. 通过配置查询接口读取 `support_bank_config`，按 `bankCode` 解析用户银行配置模板 key；
4. 在当前 `tenantId` 上下文中通过同一接口查询该模板 key，并校验内容非空；
5. 组装三段式 `BankRequestContext`；
6. 记录配置加载开始、完成、失败日志，但不记录配置内容。

配置端口和账户配置对象固定放在 `catering-front`：

```java
public interface TenantBankConfigProvider {
    TenantBankAccountConfig load(String tenantId, BankCode bankCode);
}
```

```text
TenantBankAccountConfig
├─ appId
├─ appKey
├─ url
├─ mchntId
├─ mchntMbrId
└─ accountSpecialData: JSONObject
```

配置模板 key 不得在 Provider 中按银行硬编码。`support_bank_config` 必须定义在
`FrontBankConfigQueryKeys`；其返回结构按 `platformCode` 保存唯一的“配置模板 key → 银行名称”映射。
Provider 先查询该映射，再使用返回的模板 key 第二次调用配置查询接口获取当前租户的银行配置。
`configVersion/config_version` 已废弃：配置接口没有提供真实版本来源，不是待实现能力。禁止在配置
Provider、执行上下文、日志、Entity 或 DDL 中恢复该字段；本流程也不引入配置快照或无真实来源的
`enabled`。

只允许存在一个 `TenantBankConfigProvider` 实现；多个实现必须在启动阶段失败。当前真实配置系统协议
尚未确定时，可以只保留端口、不提供伪造配置实现；一旦某项银行能力标记为 `SUPPORTED`，部署环境
必须提供真实 Provider。

具体银行 Handle 禁止：

- 直接调用租户配置服务；
- 自行用 `tenantId/storeId` 或其他组合重新定位配置；
- 接受调用方通过 `specialData` 覆盖配置；
- 输出完整配置或密钥字段日志。

### 3.6 已提交基线的银行账户配置组装（仅用于迁移核对）

> 以下 `AssemblerRouter → AbstractAssembler → 银行 Assembler` 是待删除基线。目标实现不再建立配置
> Provider 接口、路由器、抽象组装器或银行组装器类；`TenantBankConfigLoader` 在一个具体类中完成公共字段
> 复制，并通过两个平级私有方法组装中信/平安 `accountSpecialData`。私有方法不得再调用组装 helper，
> 从而保留银行差异的可读性，同时避免再次形成嵌套层级。

账户配置组装固定使用以下分层：

```text
BankAccountConfigAssemblerRouter
└─ AbstractBankAccountConfigAssembler       # 只组装跨银行通用字段
   ├─ PingAnBankAccountConfigAssembler       # 只组装平安 accountSpecialData
   └─ CiticBankAccountConfigAssembler        # 只组装中信 accountSpecialData
```

通用对象只包含 `appId/appKey/url/mchntId/mchntMbrId`。
`transSsn` 由具体银行 Handle 按银行规则生成，`transTime` 是每笔请求运行时字段，
`bizFunc/chnlNo/API path` 以及由 Front 固定上送的类型码、标志位、默认备注等值，由具体银行
Handle 使用带业务注释的本地常量确定，禁止固化为账户配置或放入公共 `*ContractKeys`。
`*ContractKeys` 保存银行请求/reserve/响应字段 key，以及需要业务系统通过
`specialData/accountSpecialData` 传入或从响应 `specialData` 读取的原始 key；这些对外 key 必须与
银行协议和 API 字段契约完全一致。只有由业务系统选择并上送的协议枚举值，或确实跨多个接口/Handle
复用的协议值，才允许作为公共 value 常量；单接口内部固定 value 不得暴露给业务系统。

| 银行 | `accountSpecialData` 允许字段 |
|---|---|
| 平安 | `txnClientNo`、`mrchCode`、`stlAcctNo`（资金汇总账号） |
| 中信 | `default_role`、`default_fund_type`、`self_role`、`self_fund_type`、`self_dealType`、`self_store_no`、`self_store_id` |

中信上述 7 个字段对中信交易能力是通用账户配置，但不是跨银行通用字段，
不得添加到 `TenantBankAccountConfig` 强类型属性中。银行字段 key 在
`catering-common-core/com.chinaums.common.core.constant.front` 中集中定义，对象和组装策略仍属于
`catering-front`。常量类职责固定如下：

| 常量类 | 内容 |
|---|---|
| `FrontBankConfigQueryKeys` | 配置查询入口 key：`support_bank_config`；具体银行配置模板 key 由该配置动态返回，禁止硬编码 |
| `FrontBankAccountConfigKeys` | `appId/appKey/url/mchntId/mchntMbrId` |
| `PingAnBankAccountConfigKeys` | `txnClientNo/mrchCode/stlAcctNo` |
| `CiticBankAccountConfigKeys` | 中信 7 个 `accountSpecialData` 字段 |
| `FrontBankRequestConstants` | 钱包公共请求字段名及 `transSsn/transTime/bizFunc/chnlNo` 来源约束 |
| `FrontBankResponseConstants` | 钱包原始响应字段、平台成功标志、中信 5 位和平安 6 位银行成功码 |
| `CiticTransferContractKeys` | 中信 transfer/consume 请求、reserve、响应特殊字段 key；不保存 Handle 内部固定 value |
| `PingAnTransferContractKeys` | 平安 transfer/consume 请求和 reserve 字段 key；不保存 Handle 内部固定 value |

配置查询 key 的常量名称只表达配置系统中的原始值，不在 `catering-common-core` 内绑定具体银行。
真实 `TenantBankConfigProvider` 接入时必须根据最终确认的银行与配置 key 对应关系显式选择，禁止根据
`zx/pa` 前缀自行推断。

银行协议常量必须以“当前真实 Handle 已映射或本次需求已确认”为准，禁止把 Word 文档全部字段一次性
搬进常量类。文档存在但当前 Handle 未使用的字段只能在能力汇总中保留说明，不得成为活动常量或
`specialData` 白名单。以中信 transfer/consume 为例，当前不启用 `USER_SHARE_*`、
`REQ_RESERVED`；`P_SELF_FLAG/P_SELF_AMT` 固定使用 `N/0`。

策略路由必须通过构造器注入 `List<BankAccountConfigAssembler>` 建立不可变映射，
同一银行出现两个策略时必须启动失败，不得静默覆盖。组装日志只记录银行、策略、
结果和耗时，不得记录原始配置、`appKey`、`accountSpecialData` 内容。

### 3.7 `channel/{bank}`

28 号目标中，银行差异实现统一按“银行 → 能力”放置：

```text
channel/citic
├─ common/                 # 至少两个已实现能力真实复用的小型组件
├─ transfer/               # Capability + 该能力协议 DTO
├─ consume/
├─ withdraw/
├─ refund/
└─ ...其他真实能力

channel/pingan
├─ common/
├─ transfer/
├─ consume/
└─ ...其他真实能力
```

银行协议 DTO 与能力相邻，不得进入 `catering-api-front` 或 `catering-common-core`。能力包内不得再继续拆
`client/protocol/request/service/support/assembler/mapper`。禁止 BankSupport God class；统一钱包发送只走
`channel/gateway/BankWalletGateway.post`。

### 3.8 渠道流水持久化

渠道流水物理表固定为：

```text
中信：transfer / consume / refund / withdraw / platform_pay / platform_receive
平安：transfer / consume / refund / withdraw
```

表路由和落库规则以 [09-channel-transaction-ddl](09-channel-transaction-ddl.md) 为准；10 张表的完整
字段、默认值、更新规则和索引以
[09A-channel-transaction-table-field-catalog](09A-channel-transaction-table-field-catalog.md) 为准。

持久化实现必须：

- 当前 API 方法内部固定 capability，进入对应领域 Registry；Registry 按
  `(BankCode, FrontCapability)` 选择具体能力 Handler，该 Handler 使用自己的固定 Repository；
- capability 既是 Registry 复合键的一部分，也是写入渠道流水的业务类型值；完成 Handler 定位后不得
  再拿 capability 通过 `switch` 选择方法或动态选择 Repository；
- 不得接收表名或拼接动态表名；
- 在调用银行前成功写入目标表 `INIT` 记录，发送前更新为 `SENDING`；

**渠道流水表字段范围**（清晰字段化存储，禁止 text 快照）：

| 分类 | 字段 | 说明 |
|---|---|---|
| 主键+租户 | id, tenant_id, store_id, data_source_id | |
| 能力+流水 | capability, front_ssn, front_query_id, front_status | front_status 是流水状态（INIT/SENDING/SUCCESS/FAILED 等） |
| 业务关联 | biz_system_code, biz_transaction_type, biz_transaction_id, biz_sub_transaction_id, biz_request_no, biz_order_no, biz_sub_order_no | |
| 收付款门店 | pay_store_no, pay_store_id, rec_store_no, rec_store_id | |
| 收付款账户 | pay_account_id, pay_name, rec_account_id, rec_name（平安加 pay_member_id, rec_member_id） | |
| 金额 | amount, fee, currency | 中信不维护 `refunded_amount`；平安原交易表的兼容字段也不参与退款资格或累计金额校验 |
| 银行请求字段 | bank_channel_no, bank_biz_func, external_platform_ssn | |
| 银行返回字段 | bank_query_id, bank_user_ssn, bank_trans_date, bank_trans_time, wallet_resp_code, wallet_resp_desc, bank_resp_code, bank_resp_desc, bank_status | 每个字段单独成列 |
| 3 个时间 | create_time, update_time, bank_responded_at | |
| 3 个额外字段 | reserve1, reserve2, reserve3 | |
| 审计 | create_by, update_by | BaseEntity 父类 |

**禁止落库的字段**：
- `front_resp_code`/`front_resp_desc`/`front_remark` — 返回接口返回就行，不存库；
- `business_base_snapshot_cipher`/`business_special_snapshot_cipher`/`bank_request_snapshot_cipher`/`bank_response_snapshot_cipher` — 禁止 MEDIUMTEXT 快照，所有请求/返回字段单独成列；
- `snapshot_key_version`/`version`/`request_hash` — 不要；
- `interface_code`/`config_version`/`business_date`/`business_time`/`business_remark` — 冗余；
- `send_started_at`/`completed_at` — 只要 3 个时间（create/update/respond）。

渠道表允许保存本系统内部使用的账户号、会员编号、姓名和银行卡号原始值，本期不要求数据库字段加密。
最终 Sender 的钱包请求/响应 body 按用户裁决允许完整明文记录；除此之外，这只放宽数据库落库方式，
其他日志、异常消息和普通查询响应仍不得额外输出这些敏感值。
本阶段按内部系统信任边界处理，ShardingSphere 数据源连接配置的加密和安全加固暂不纳入开发与验收；
银行协议要求的签名、传输/字段加密仍必须保留。

交易发送前执行的是“重复交易校验”，不是请求幂等：在当前银行、当前业务物理表内按
`tenant_id + biz_order_no + biz_sub_order_no` 查询；存在记录即返回“交易已存在”，不重复调用银行，
也不根据请求内容比较 Hash、不返回或重放旧交易结果。
统一使用 `FrontErrorCode.TRANS_ALREADY_EXISTS`，错误码固定为 `F300001`、说明固定为
“交易已存在”；不得继续使用 `IDEMPOTENCY_CONFLICT`、请求处理中或参数冲突语义。

其他约束：
- `applyCommonFields` 方法在填 storeId 后调用
  `invokeSetter(entity, "setDataSourceId", data.getDataSourceId())` 落库；
- 每张表包含 `reserve1/reserve2/reserve3`，遵守短期扩展、稳定后建明确列的约束；
- 日志记录银行、能力、固定表路由结果、记录 ID、`frontSsn`、业务关联和状态变化。

平安 `TRANSFER_AUTH/TRANSFER_AUTH_CODE_RESEND` 与普通转账进入平安转账表，通过 `capability`
字段区分记录；该字段同时参与 Transaction Registry 的“银行 + 能力”精确路由，但不参与统一能力预校验，
也不得用于动态选择 Repository。不为银行未支持的能力创建或写入空表。退款只能关联同银行原转账或
消费表，不建立跨服务外键。

### 3.9 对象转换约束（Converter）

持久层 Entity ↔ VO/BO/Req/Res 之间的对象转换必须使用 MapStruct Converter，禁止手写 `setXxx(getXxx())`。
工程通过 `catering-common-core` 已传递引入 `mapstruct-plus-spring-boot-starter`，根 `pom.xml` 的
`annotationProcessorPaths` 全局注册了 `mapstruct-plus-processor` 与 `lombok-mapstruct-binding`，
catering-front 无需在自身 `pom.xml` 增加任何 MapStruct 依赖。

**强制范式**（参照 `catering-system` 的 `MpConfigDataVo` / `MpConfigData`）：

1. 在 VO/BO 类上标注 `@AutoMapper(target = 对应Entity.class)`，注解来自
   `io.github.linpeilie.annotations.AutoMapper`；
2. 字段名相同时无需任何 `@Mapping`；字段名不同时在该字段上补 `@Mapping`；
3. 转换调用统一使用静态工具 `com.chinaums.common.core.utils.MapstructUtils`：

```java
// Entity → VO
FrontCiticTransferVo vo = MapstructUtils.convert(entity, FrontCiticTransferVo.class);
// VO/BO → Entity
FrontCiticTransfer entity = MapstructUtils.convert(bo, FrontCiticTransfer.class);
// 列表批量
List<FrontCiticTransferVo> voList = MapstructUtils.convert(entityList, FrontCiticTransferVo.class);
```

4. VO/BO 放在 `com.chinaums.front.domain.vo` / `com.chinaums.front.domain.bo`，Entity 放在
   `com.chinaums.front.domain`，参照 `catering-system` 的 `domain/domain.vo/domain.bo` 结构；
5. 仅当 `@AutoMapper` 无法覆盖（如需多源合并、复杂表达式）时，才在
   `com.chinaums.front.domain.convert` 下新建显式 Converter 接口，使用
   `@Mapper(componentModel = SPRING, unmappedTargetPolicy = IGNORE) extends BaseMapper<Source, Target>`。

**适用范围**：本约束只约束持久层 Entity ↔ VO/BO 的转换。Handle 内部 `baseData` → 银行协议 DTO 的
转换属于银行协议组装（字段名与 baseData 不同、需加密和常量映射），不在本约束范围，仍按现有
Handle 显式组装方式。生成转换类由编译期注解处理器完成，禁止手工编辑 `target/generated-sources`。

#### 3.9.1 关于 lsym `Converter` 的定位（重要）

旧项目 lsym 的 `com.chinaums.erp.slhy.catering.consume.domain.Converter` 采用**原生 MapStruct**
（`@Mapper(componentModel="spring")` 接口 + 80+ 个 `reqToDto` 重载方法），由
`org.mapstruct:mapstruct-processor` 在编译期生成 `ConverterImpl`，零反射、性能等价手写 `set/get`。
它的核心价值是“用编译期代码生成替代手写字段拷贝、集中管理转换关系”，这一思想必须继承。

但新 SaaS 工程已统一选用 **mapstruct-plus**（`io.github.linpeilie:mapstruct-plus-spring-boot-starter`），
并在 `catering-system` 的 `MpConfigDataVo/MpConfigDataBo → MpConfigData` 上落地了
`@AutoMapper` + `MapstructUtils.convert` 范式。两种风格底层都是 MapStruct，生成的赋值代码质量一致；
区别只在声明位置（集中接口 vs. 分散注解）和调用方式（注入 Bean vs. 静态工具）。

为避免同一工程出现两套互不兼容的转换风格，catering-front 的对象转换**固定采用 mapstruct-plus 范式**：

- 不在 `catering-front/pom.xml` 引入原生 `org.mapstruct:mapstruct` / `mapstruct-processor`；
- 不新建 `@Mapper(componentModel="spring")` 风格的集中式 `Converter` 接口；
- lsym 的 `Converter` **只作为“存在哪些 Req/Res ↔ Entity/Vo 转换关系”的参考来源**，
  迁移时按目标 Entity 在 `domain/vo`、`domain/bo` 上标注 `@AutoMapper(target = XxxEntity.class)`，
  并通过 `MapstructUtils.convert(source, XxxEntity.class)` 调用；
- 当 `@AutoMapper` 无法覆盖（多源合并、复杂表达式）时，再按 §3.9 第 5 条在
  `com.chinaums.front.domain.convert` 下新建显式 `@Mapper extends BaseMapper<Source, Target>` 接口，
  此时仍使用 mapstruct-plus 提供的 `BaseMapper`，不引入原生 mapstruct 坐标。

lsym `Converter` 的源码位置（仅供查阅转换关系，不复制其依赖与写法）：

```text
/Users/limeng/workspaces/IdeaProjects_lsym_dep/slhy/fund-catering/fund-catering-consume/
  fund-catering-consume-service/src/main/java/com/chinaums/erp/slhy/catering/consume/domain/Converter.java
```

lsym 该模块依赖的原生 mapstruct 坐标（`org.mapstruct:mapstruct` + `mapstruct-processor`，版本跟随
根 pom `mapstruct.version=1.6.3`）**不引入新工程**；新工程已经通过 `mapstruct-plus-spring-boot-starter`
间接获得 mapstruct 运行时 API，并由根 pom 的 `annotationProcessorPaths` 注册
`mapstruct-plus-processor` + `lombok-mapstruct-binding`，编译期代码生成能力已具备。

### 3.10 分库与分区约束

#### 3.10.1 分库：ShardingSphere-JDBC（STANDARD 分片）

catering-front 的 10 张渠道流水表与业务表绑定，分布在多个物理数据库实例中。分库使用
**ShardingSphere-JDBC STANDARD 模式**（不是 Hint，不是 dynamic-datasource），由 SQL 中的
分片键 `data_source_id` 自动路由。

- **分片键**：`data_source_id`（每条渠道流水 SQL 自带，由业务请求方在 `baseData.dataSourceId`
  传入——缺失时域 ExecuteNode 第④步用 tenantId 从 `tenant_base_config`
  缺省回填（三域收口后无独立前置节点），显式传入优先——经 Feign 拦截器透传、`BaseDataRequestBodyAdvice` 回填到
  Entity 的 `data_source_id` 列）；
- **分片算法**：`TenantDataSourceShardingAlgorithm`（CLASS_BASED, STANDARD），流程为：
  1. 从 SQL 的 `data_source_id` 值拿到数据源编号（如 `"2"`）；
  2. `formatDataSourceName("2")` → `"ds_2"`，返回给 ShardingSphere 路由；
  3. 算法**不查配置中心、不做远程查询**，仅校验值存在且 `ds_x` 在可用数据源列表中；
- **配置位置**：`resources/shardingsphere-config-${profile}.yaml`（dev/uat/prod），
  `spring.datasource.url: jdbc:shardingsphere:classpath:shardingsphere-config-${spring.profiles.active:dev}.yaml`；
- **新增库**：在 `shardingsphere-config-*.yaml` 加 `ds_3` 数据源，业务请求方传 `data_source_id=3`
  即可路由到新库，不改代码；
- **失败策略**：域 ExecuteNode 第④步回填后 `data_source_id` 仍为空、或计算出的 `ds_x` 不在可用数据源列表时必须立即抛出
  系统异常并终止 SQL；禁止默认进入 `ds_0`、第一个数据源或广播到其他租户数据库；
- **全链路分片键覆盖（2026-08-27 修复）**：全部 SELECT（查重/原渠道回查/6073 补全/提现卡号回查）
  和 UPDATE（updateSending/updateResponse/updateOnException）的 WHERE 条件均必须包含
  `.eq(DATA_SOURCE_ID, dataSourceId)`，禁止只按 id/tenantId 触发广播路由；
  dataSourceId 由域 ExecuteNode 第④步回填保障非空，能力类从
  `slot.getRequestData().getDataSourceId()` 获取。INSERT 已由 entity.setDataSourceId 覆盖。
- **Handle 零侵入**：不需要 `FrontDataSourceHelper`、不需要手动切换数据源，
  SQL 的 `data_source_id` 自动触发分片路由；
- **不使用 dynamic-datasource**（`@DS` / `DynamicDataSourceContextHolder`）和 Hint
  （`HintManager`）；
- **`tenant_id` 的作用**：`tenant_id` 仍是每条记录的租户标识（多租户隔离、MySQL 分区键之一），
  但**不作为分库路由键**——分库由 `data_source_id` 决定。

涉及类：

| 类 | 模块 | 职责 |
|---|---|---|
| `TenantDataSourceShardingAlgorithm` | catering-front `sharding` | STANDARD 分片算法（`data_source_id` 直接拼 `ds_x`，不查配置中心） |

> 历史设计曾设想“分片键 `tenant_id` + 算法查配置中心 `tenant_base_config` 解析 `data_source_id`”，
> 并配套 `ShardingAlgorithmInjector` 注入 `RemoteConfigServiceClient`；**当前代码未采用该方案**，
> 直接以 `data_source_id` 为分片键，`ShardingAlgorithmInjector` 不存在，算法不依赖任何配置中心客户端。

#### 3.10.2 分区：MySQL LINEAR KEY

10 张渠道流水表均使用 MySQL 表分区，提升大表查询性能和数据管理能力。

- **分区方式**：`PARTITION BY LINEAR KEY (tenant_id, store_id) PARTITIONS 30`；
- **分区键**：`tenant_id` + `store_id`（VARCHAR 列，LINEAR KEY 分区原生支持任意类型列）；
- **分区数**：30 个（在创建租户时按租户门店量规划，后续可按需调整）；
- `tenant_id`/`store_id` 必须是纯数字字符串（如 "10001"），由业务系统保证；
- 分区 DDL 已内置于 [09-final-rebuild-all-tables.sql](09-final-rebuild-all-tables.sql)。

#### 3.10.3 FeignClient 拦截器（通用，4 个必要参数自动传递）

4 个必要参数（tenantId/clientId/platformCode/dataSourceId）由 `catering-common-feign` 的
拦截器链自动传递和注入。引入依赖后还必须确保发送拦截器、接收拦截器和
`BaseDataRequestBodyAdvice` 均已被 Spring 显式注册，不得仅依赖业务应用的包扫描范围：

```text
FeignClient 调用方
  → HTTP 请求头: tenantId / clientId / platformCode / dataSourceId
  → FeignRequestInterceptor（common-feign，发送端）
     从当前请求 header 读 4 个值（header 没有时从 RequestContext 兜底），转发到下游
  → RequestContextInterceptor（common-feign，接收端 MVC 拦截器）
     preHandle: 从 header 提取 4 个值 → RequestContext（ThreadLocal）
  → BaseDataRequestBodyAdvice（common-feign，RequestBodyAdvice）
     afterBodyRead: @RequestBody 反序列化后，从 RequestContext 取值
     直接请求：写入 BaseRequest 父类
     Front 嵌套请求：识别 FrontRequest<T> 并写入 request.baseData
  → Controller 收到 request（baseData 已填好）
  → Application Service（零改动）
  → RequestContextInterceptor.afterCompletion: clear() 清理 ThreadLocal
```

Handle 持久化渠道流水时，通过 `data.getDataSourceId()` 把 dataSourceId 写入 Entity 的
`dataSourceId` 字段（对应表 `data_source_id` 列）。

涉及类（全部在 `catering-common-feign` 或 `catering-common-core`，所有服务共用）：

| 类 | 模块 | 职责 |
|---|---|---|
| `RequestContext` | catering-common-core `context` | ThreadLocal 存 4 个参数 |
| `RequestConstants` | catering-common-core `constant` | header 名常量 |
| `BaseRequest` | catering-common-core `catering.base.request` | 通用请求父类（4 个字段） |
| `FeignRequestInterceptor` | catering-common-feign `interceptor` | 发送端：转发 header |
| `RequestContextInterceptor` | catering-common-feign `interceptor` | 接收端：header → ThreadLocal |
| `BaseDataRequestBodyAdvice` | catering-common-feign `advice` | ThreadLocal → 直接 `BaseRequest` 或 `FrontRequest<T>.baseData` |
| `FeignConfiguration` | catering-common-feign `config` | 显式注册发送/接收拦截器、Advice 和 WebMvcConfigurer |

注入约束：

- `supports(...)` 必须同时识别直接 `BaseRequest` 和外层 `FrontRequest<T>`；
- `afterBodyRead(...)` 对 `FrontRequest<T>` 必须取出其 `baseData` 后再注入，禁止只检查外层对象；
- header 与请求体的识别字段冲突时必须明确失败，不得一部分链路使用 header、
  另一部分使用请求体；
- header 缺失时可从 `RequestContext` 补齐；两处都缺失则按必填参数失败，
  禁止带空值进入路由或分库。

---

## 4. 请求对象约束

所有请求统一使用：

```java
FrontRequest<具体基础请求>
```

JSON 顶层固定为：

```json
{
  "baseData": {},
  "specialData": {}
}
```

### 4.1 `baseData`

`baseData` 只保存内部业务系统统一、可校验、可生成 OpenAPI 的强类型字段，包括：

- `tenantId`；
- `storeId`；
- `platformCode`；
- 当前业务通用字段。

收付款账户、会员编号、姓名、卡号等银行侧身份数据，以及银行协议专用筛选条件，统一放入
`specialData`，并使用对应银行协议原始 key。禁止放入 `baseData`，也禁止使用 `Object`、无约束 Map
代替已经确认的内部业务公共字段。

交易公共基础对象必须包含 `payStoreNo/payStoreId/recStoreNo/recStoreId` 两组收付款门店信息。
还必须包含 `bizSystemCode/bizTransactionType/bizTransactionId/bizSubTransactionId`，用于逻辑关联来源
业务交易主表和子表；字段值不得是物理表名，业务记录 ID 统一按字符串传递。
`amount/fee` 均使用 `Long` 保存人民币分，`amount` 必须大于 0，`fee` 不能小于 0；禁止使用浮点数
或在 Handle 内擅自转换为元。transfer/consume 的双方账户、会员编号和姓名必须通过
`specialData` 提供，由具体银行 Handle 按常量白名单读取和映射。
单笔状态查询基础对象必须包含 `capability/transDate/bizOrderNo/bizSubOrderNo`，并可携带
`frontSsn` 供结果回显；其中 `capability` 描述被查询的原交易能力，不是当前 API 路由 capability。
`bizOrderNo` 是业务主流水；转账、消费、退款查询必须同时提供 `bizSubOrderNo`，提现查询只向银行上送
`bizOrderNo`。中信查询所需用户编号使用协议原始 key `specialData.acctNo` 提供，不放入公共基础对象。
交易明细查询基础对象只保存 `pageNo/pageSize` 统一分页字段；待查询账户、
银行交易类型、日期和登记簿/账户类型放入 `specialData`，不得在 `PlatformDetailQueryData`/`AccountDetailQueryData` 重复定义。

### 4.2 统一业务 Slot（28 号目标覆盖旧 Context）

以下 `FrontFlowContext` 内容是已提交基线记录。28 号三域收口禁止继续使用该转换，必须由
Application Service 直接创建 `FrontTransSlot` 或 `FrontQuerySlot`，链路全程传同一 Slot。
旧基线曾使用 `FrontFlowContext.from(request, capability)` 承载：

```text
capability
baseData
specialData
accountConfig
result
executionInfo
failure
```

其中 `capability` 由当前 API 方法固定写入，不接受调用方输入；它用于对应领域 Registry 的
`(BankCode, FrontCapability)` 精确路由、日志定位和渠道流水记录。不得根据 capability 名称猜测进入哪个
领域，不得建立统一能力预校验，也不得在公共 Dispatch 中再次 `switch` 选择 Handle 方法。

以上是旧 `FrontFlowContext` 基线形态。28 号三域收口必须删除 Context 转换，改为
`FrontBaseSlot ← FrontTransSlot/FrontQuerySlot/FrontAccountSlot` 两层 Slot；不得在两层 Slot之外
再建第二套载体。

### 4.3 `specialData`

`specialData` 使用 `JSONObject`，只保存“银行 + 具体业务方法”特有字段。

**specialData 的 key 必须使用银行协议原始名**（如 `outAcctNo`/`inAcctNo`/`USER_D_NM`/`USER_C_NM`），
与银行 word 文档的请求报文字段名完全一致，**禁止自定义 key 名**。

**组装工具类双层口径（2026-08-17 起）**：业务方获取协议键 specialData 的推荐路径是
catering-api-front 的实例工具类 `FrontSpecialDataAssembler`（标准账户结构 pay/rec 入参，
本地调用 `assemble()` 输出协议键明文，矩阵与用法见 15 号 spec）；交易 API 的 wire 契约不变，
仍只收协议键 specialData，Handle `requireSpecialData` 校验保留为直传时的最后防线。
**本节"key 必须银行协议原始名"条款对交易请求继续有效**——工具类只是协议键的产生方式，不是新的契约层。

约束：

- 无特殊字段时传空对象；
- **key 用银行协议原始名**——调用方传 specialData 时 key 就是银行请求报文里的字段名，
  Handle 通过常量类（`*ContractKeys.PAY_ACCOUNT_NO = “outAcctNo”`）引用，`context.specialData().getString(常量)` 取值；
- **baseData 不含银行特有字段**——收付款账户号/名称/会员编号、提现卡号/账户名等银行协议特有字段
  一律放 specialData，不放在 `TransferBusinessData`/`ConsumeBusinessData`/`WithdrawBusinessData` 等 baseData 对象里；
- 不得覆盖 `tenantId/platformCode/channelNo/bizFunc/path` 以及
  `txnClientNo/mrchCode/stlAcctNo` 等账户配置字段；
- 不得传密钥、私钥、完整银行配置；
- 日志采用 B 方案：Capability 记录业务步骤，最终 Sender 统一且只记录一次钱包请求/响应/失败；
  删除旧 Handle 或 Capability 对同一钱包报文的重复输出。Sender 的请求/响应 body 按用户裁决记录
  **完整明文 JSON，不做字段脱敏**；`appKey`、私钥、签名材料、签名/认证 Header、`Authorization`、
  `Cookie` 等非业务报文凭证仍禁止进入日志。

**常量类命名规范**：
- Java 变量名用 `PAY_`/`REC_` 前缀（付款 PAY_/收款 REC_），如 `PAY_ACCOUNT_NO`/`REC_ACCOUNT_NO`/`PAY_NAME`/`REC_NAME`；
- 常量值用银行协议原始名，如 `PAY_ACCOUNT_NO = “outAcctNo”`/`REC_ACCOUNT_NO = “inAcctNo”`/`PAY_NAME = “USER_D_NM”`；
- **禁止**在 Java 变量名里使用 `PAYER`/`PAYEE` 变体。

transfer/consume 的已确认字段白名单、来源、单位和响应映射以
[06-transfer-consume字段契约](06-transfer-consume字段契约.md) 为准。没有进入该契约的银行字段，
不得凭旧代码猜测后直接透传。

平安 `transferAuth/resendTransferAuthCode` 的字段白名单、加密边界和响应映射以
[07-transferAuth-resendTransferAuthCode字段契约](07-transferAuth-resendTransferAuthCode字段契约.md)
为准（2026-08-21 起按 25 号 spec：两接口出参公用 `R<FrontTransResult>`，请求/响应
`specialData` 使用对外语义键 `authType/authOrderNo/authCode/payMemberCode/recMemberCode`，
银行协议键 messageOrderNo/messageCheckCode/smsIdx 只在 Handle 内部与 ContractKeys 协议常量
中出现）。中信这两个能力必须返回 `UNSUPPORTED`（未登记 capability → F200002），不得复制旧项目挡板。

两家 `withdraw/refund` 和中信 `platformPay/platformReceive` 的字段、资金方向、加密边界及响应映射以
[08-withdraw-refund-platform-transfer字段契约](08-withdraw-refund-platform-transfer字段契约.md)
为准。退款必须调用银行真退款产品：中信使用 `/refund + bizFunc=23`，平安当前使用
`/refund + bizFunc=02`；禁止反向转账模拟退款。`platformPay/platformReceive` 仅中信支持，平安必须
返回 `UNSUPPORTED`。中信退款固定使用 `orgBizOrderNo + orgBizSubOrderNo` 组装
`ORI_BUSS_ID + ORI_BUSS_SUB_ID`；其他动态银行字段由请求 `specialData` 使用银行协议原始 key 提供，
Front 不查询本地原渠道流水补齐。平安退款采用不同边界：原流水、原日期和原账户属于 Front 渠道数据，
业务系统只提供 `originalBizOrderNo + originalBizSubOrderNo`；Handle 按租户和原业务主子流水精确查询
平安原转账/消费渠道表补齐。`oriTransSsn = 原记录.frontSsn`，严禁取 `bankUserSsn`；
具体定位、顶层/reserve、加密和退款表关联列以 TODO-002 为准。
中信 2041/2042 的平台侧由商户自有资金登记簿隐式确定，不传平台银行账号，业务系统也不得伪造该账号。

中信退款的最新代码参考为 `/Users/limeng/workspaces/IdeaProjects_lsym_uat/slhy` 分支
`lsym_20260625_limeng_refundTask`、提交 `3dff8255d6`。可以参考其 `ZxRefundRequest`、
`zxRefund` 调用和 `ORI_/REFUND_` reserve 字段；其“上游显式提供原交易协议字段”的边界可以保留，
但必须改造为本项目契约。禁止复制以下行为：

- 把旧请求对象中的 `orgPay/orgRec/orgTrans*` 字段直接搬入公共 `baseData`；中信动态协议字段必须使用
  `specialData` 银行原始 key；
- 将 `platformUserRole` 直接映射为 `FUND_TP`；
- 对 `orgTransTime` 未校验长度就执行 `substring(0, 8)`；
- 记录完整退款请求、完整银行响应、账户标识、appKey 或银行 URL。

当前中信普通退款的 `FUND_TP` 读取 `accountSpecialData.default_fund_type`，缺失必须明确失败；
不查询原交易进行比对。任何 role 字段都不能代替资金类型。

中信退款的必填字段必须在调用银行前逐项校验：`baseData.orgBizOrderNo/orgBizSubOrderNo` 成组必填；
`specialData.ORI_USER_D_ID/ORI_USER_D_NM/ORI_USER_C_ID/ORI_USER_TRANS_DT` 独立必填；
`specialData.ORI_USER_C_NM` 按协议选填、有值则上送。Front 的 `orgFrontSsn/transSsn` 不等同于中信
`ORI_USER_SSN`，不得直接映射，也不得作为查询本地原交易后补字段的入口。

中信交易状态和两个交易明细查询的字段边界以
[10-transaction-query-field-contract](10-transaction-query-field-contract.md) 为准。中信平台交易资金账户
明细固定使用 `/query-trans-details + bizFunc=25 + chnlNo=0010`，登记簿交易明细固定使用同一路径的
`bizFunc=24 + chnlNo=0010`。两个 Front 方法都不得继续按提现、手续费、来账等类型拆分 Handle 方法。

中信交易状态查询固定按请求 `baseData.capability` 选择银行字段：转账、消费、退款上送
`BUSS_ID + BUSS_SUB_ID + TRANS_TYPE=01`，提现只上送 `BUSS_ID`；`transDate` 映射
`oriTransDate`，`specialData.acctNo` 加密后映射顶层 `acctNo`。状态查询不接受
`specialData.transType`，不得扫描 Front 本地渠道表补账户号或银行流水。当前 API capability 仍由
查询入口固定为 `TRANS_STATUS_QUERY`，不得拿它代替 `capability`。

中信明细查询的 `transDate/transType` 以及 `24` 查询的 `accountType` 由业务系统放入请求
`specialData`，必须通过 common-core 对应常量白名单校验。业务系统不得提交银行 `TRANS_DATE/PAGE`；
银行 24/25 一次只支持一个交易日，不支持跨日范围查询。Handle 将 `transDate` 映射为单个
`reserve.TRANS_DATE`，通过 Front `pageNo` 维护银行页码。银行文档标注忽略的
`beginDate/endDate` 不得当作有效字段透传。中信 `24` 每页固定最多 50 条，`25` 每页固定最多 20 条，
业务 `pageSize` 不得覆盖银行限制。

### 4.4 旧 Handle 三段式上下文（historical，28 号禁用）

外部 `FrontRequest<T>` 只能有两段。完成银行路由后，由 `AbstractBankHandle` 生成：

```java
public record BankRequestContext<T extends FrontBaseRequestData>(
    T baseData,
    JSONObject specialData,
    TenantBankAccountConfig accountConfig) {
}
```

三段数据来源固定：

| 字段 | 来源 | 是否允许调用方传入 |
|---|---|---|
| `baseData` | `FrontRequest.baseData` | 是 |
| `specialData` | `FrontRequest.specialData` | 是 |
| `accountConfig` | Front 配置 Provider | 否 |

`accountConfig` 是强类型通用账户配置加银行 `accountSpecialData`。
`specialData` 和 `accountSpecialData` 是两个独立 `JSONObject`：前者只保存当前交易/查询的
银行特定动态参数，后者只保存租户银行账户特定静态配置。禁止两者共享引用、
`putAll`、互相覆盖或透传。

### 4.5 对象和字段注释

所有请求、响应、配置、Context、执行信息和枚举必须包含可读的类级及字段级 JavaDoc。禁止只创建
`data/info/context/metadata` 等名称而不说明内容和用途。

字段注释至少说明适用项：

- 业务含义；
- 数据来源和写入阶段；
- 单位或格式，例如“人民币分”“yyyyMMdd”；
- 为空条件或条件必填规则；
- 是否属于敏感数据以及日志限制；
- `specialData/accountSpecialData` 的边界；
- 枚举值代表的业务状态。

record 组件使用类 JavaDoc 的 `@param` 逐项说明。`FrontBaseSlot`、`FrontTransSlot`、`FrontQuerySlot`、
`FrontAccountSlot` 的每个字段还必须说明由谁写入、由谁读取以及处于哪个阶段；非泛型 Slot 中的
`Object` 只能通过受控类型方法读取。新增字段没有注释时，不得提交。

---

## 5. 返回对象约束

### 5.1 对外 API 返回

单条交易、交易状态和账户查询必须直接返回：

```java
R<具体结果>
```

例如：

```java
R<FrontTransResult>
R<TransStatusResult>
R<AccountBalanceResult>
```

> 2026-08-21 起：授权码发送/重发（`resendTransferAuthCode`）不再有专用结果，
> 出参公用 `R<FrontTransResult>`（`FrontTransferAuthCodeResult` 已删除，见 07 号契约）。

分页明细查询必须直接返回：

```java
TableDataInfo<AccountTransDetailItem> / TableDataInfo<PlatformTransDetailItem>
```

禁止：

- 使用 `FrontResponse<T>` 再包装具体结果；
- 单条接口直接返回未使用 `R` 包装的具体结果；
- 分页接口返回 `R<TableDataInfo<...>>`、`R<FrontPageResult<...>>` 或直接对外返回
  `FrontPageResult<...>`；
- 直接返回银行响应 DTO；
- 返回 `Map<String, Object>`；
- 再创建一套 Front 专用顶层响应类替代 `R`；
- Controller、Application Service 或最终 API 对外返回 `null`。`FrontFlowExecutor` 内部返回 `null` 时，
  必须由外层 Application Service 立即转换为失败响应。

### 5.2 两层语义

| 层级 | 职责 |
|---|---|
| `R.code/msg` | 工程统一调用结果，使用公共 `R.ok/R.fail` |
| `R.data` 的强类型字段 | Front 跨银行统一业务结果和 Front 错误码 |
| `R.data.specialData` | 当前银行、当前能力的特殊返回字段；由 `FrontBaseResult` 统一定义 |

单条接口只有 Front 业务成功时才使用 `R.ok(result)`：顶层 `R.code=200`，同时
`data.frontRespCode="200"`。银行明确拒绝或钱包业务失败时，Application Service 必须使用
`R.fail(message, result)`，因此顶层也是失败码（当前公共 `R.FAIL=500`），同时保留
`data.frontRespCode/frontRespDesc/frontStatus` 供内部调用方识别具体 Front 业务原因。
请求校验、配置、路由、适配器失败及系统异常同样返回顶层失败，禁止出现“顶层成功、data 失败”。

分页接口没有顶层 `R`。分页成功或业务失败均通过 `TableDataInfo.code/msg` 表达；成功时
`code=200`、`rows/total` 正确赋值，失败时 `code=500`、`rows` 返回空集合。每条
`AccountTransDetailItem.specialData` / `PlatformTransDetailItem.specialData` 继续承接该笔明细的银行 `reserveMap` 白名单映射字段。

`FrontBaseResult` 必须统一定义 `frontRespCode/frontRespDesc/specialData`。交易明细查询中，每条
两套行 DTO（`AccountTransDetailItem`/`PlatformTransDetailItem`）还必须单独包含 `specialData`，承接该笔明细的银行 `reserveMap`。标准
`TableDataInfo` 不提供查询级 `specialData` 或游标字段，因此分页协议必须使用 `pageNo/pageSize + total`；
不得生成调用方无法从响应取回的 `continuationToken`。

成功返回示意：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "frontRespCode": "200",
    "frontRespDesc": "成功",
    "specialData": {}
  }
}
```

失败返回示意：

```json
{
  "code": 500,
  "msg": "银行适配器尚未完成接入",
  "data": {
    "frontRespCode": "F200003",
    "frontRespDesc": "银行适配器尚未完成接入",
    "specialData": {}
  }
}
```

`R.code` 是整数统一状态码，Front 的 `Fxxxxxx` 业务错误码不得写入 `R.code`，必须放在
`data.frontRespCode`。

### 5.3 各层返回职责

```text
Handle              → FrontBaseResult 的确定子类
Application Service → 单条 R<具体结果>；分页 TableDataInfo<具体行>
Controller/API      → 原样透传 Application Service 返回值
Exception Handler   → R.fail(message, FrontBaseResult)
```

Handle 和异常处理器必须通过 `FrontBaseResult.applyFrontResponse(FrontErrorCode)` 同时设置
`frontRespCode/frontRespDesc`，避免码和说明不一致。银行原始响应码不得直接作为 `R.code`、
`frontRespCode` 或 `frontRespDesc`；应先映射为 Front 公共错误码，原始码默认保存到渠道流水。
只有具备明确业务价值且进入响应白名单的银行特有字段才能进入返回 `specialData`。

---

## 6. 错误码约束

Front 公共错误码唯一位置：

```text
catering-common-core
└─ com.chinaums.common.core.error.FrontErrorCode
```

规则：

- 禁止在 API、Controller、Handle 中散落字符串错误码；
- 禁止在其他模块复制 `FrontErrorCode`；
- 新增错误码必须保证编码唯一、语义稳定；
- 错误码名称表达业务语义，不能使用银行功能码命名；
- 银行错误码必须先转换为 Front 错误码；
- `200` 只用于真实成功，复用全局 `R.SUCCESS`，禁止模拟成功。

当前编码分段：

| 范围 | 含义 |
|---|---|
| `200` | 全局统一成功码，复用 `R.SUCCESS` |
| `F1xxxxx` | 请求、配置和契约错误 |
| `F2xxxxx` | 银行、能力和适配状态错误 |
| `F3xxxxx` | 重复交易和处理中状态 |
| `F4xxxxx` | 银行通信和结果错误 |
| `F9xxxxx` | Front 内部错误 |

当前钱包结果统一码：

| 错误码 | 统一说明 | 使用边界 |
|---|---|---|
| `200` | 成功 | 钱包平台和银行渠道均满足当前接口成功条件 |
| `F400001` | 钱包通信失败 | 可确认未完成正常通信 |
| `F400002` | 钱包处理结果未知 | 可能已发送但无法确认终态，必须查询 |
| `F400003` | 钱包响应格式错误 | 缺少必需字段或格式无法解析 |
| `F400004` | 银行拒绝交易 | 平台成功但银行渠道明确失败 |
| `F400005` | 钱包平台拒绝请求 | `errCode/errInfo` 明确表示平台失败 |

中信、平安现有接入的平台成功标志均为 `D5000000 + success`；中信银行成功码为 `00000`
（5 个 0），平安为 `000000`（6 个 0）。这些值只能使用 `FrontBankResponseConstants` 判断，
禁止在 Handle 中散落字符串，更禁止直接返回业务系统。

---

## 7. 异常约束

Front 公共业务异常唯一位置：

```text
catering-common-core
└─ com.chinaums.common.core.exception.FrontException
```

### 7.1 何时抛出 `FrontException`

以下可预期业务失败在非 LiteFlow 路径必须抛出 `FrontException`；LiteFlow 节点按 §7.3 写 Slot 后中断：

- 银行不支持；
- 能力不支持；
- 银行适配器未接入；
- 请求或配置不满足业务规则；
- 重复交易；
- 已明确映射的银行拒绝或通信错误。

用法：

```java
throw new FrontException(FrontErrorCode.CAPABILITY_NOT_SUPPORTED);
```

需要保留安全的业务细节时：

```java
throw new FrontException(FrontErrorCode.INVALID_REQUEST, "可公开的错误说明");
```

禁止在异常消息中包含密钥、完整卡号、手机号、证件号、验证码、完整 `specialData`
或 `accountSpecialData`。

### 7.2 异常收口

`FrontExceptionHandler` 必须统一处理：

- `FrontException`；
- Bean Validation 参数异常；
- JSON 解析异常；
- 未知异常。

处理规则：

- `FrontException`：保留其 `FrontErrorCode` 和安全消息；
- 参数异常：映射为 `INVALID_REQUEST`；
- 未知异常：记录完整服务端堆栈，对外只返回 `INTERNAL_ERROR`；
- 所有异常响应使用 `R.fail(message, new FrontBaseResult(...))`；
- 不得将 Java 异常类名、堆栈和银行原始报文返回给调用方。

### 7.3 LiteFlow 链内节点的业务异常中断

三个域 ExecuteNode 遇到 §7.1 所列的可预期业务失败时，采用中断流程方式：

1. 把 `FrontErrorCode` 的 `code/msg` 写入当前域 Slot 的 `frontRespCode/frontRespDesc`；
2. 调用 `this.setIsEnd(true)`（LiteFlow 视为用户主动结束，`response.isSuccess` 仍为 `true`）；
3. `FrontFlowExecutor` 执行后允许返回 `null`；Application Service 必须先检查 Slot 的业务失败状态，
   再检查执行结果。Slot 已标记失败时返回对应 `R.fail`/失败页；Slot 未失败但结果为 `null` 时，返回
   `INTERNAL_ERROR`，不得形成 `R.ok(null)` 或空分页响应。

不设置统一的能力预验证。交易、交易查询、账户分别进入自己的 Registry，并按
`(BankCode, FrontCapability)` 直接取得具体 Capability；未注册当前复合键时返回
`CAPABILITY_NOT_SUPPORTED`。仍待人工确认的实现由已注册的待接入 Capability 抛出
`FrontException(ADAPTER_NOT_READY)`，所属域 ExecuteNode 捕获后写 Slot 并中断。禁止公共分派节点再次
`switch(capability)`。

系统级异常（NPE、数据库连接、JSON 解析等非业务错误）不写业务失败 Slot，继续 throw，由
`FrontExceptionHandler` 收口。`FrontException` 保留用于非 LiteFlow 路径；若具体 Capability 在本域
ExecuteNode 调用期间抛出 `FrontException`，该节点必须只捕获该类型并转写 Slot，其他异常继续抛出。

### 7.4 禁止事项

- 禁止用 `RuntimeException("字符串")` 表达已知业务失败；
- 禁止 catch 后忽略异常；
- 禁止 catch 后返回 `R.ok`；
- 禁止 Capability、Application Service 和 Controller 把 `null` 作为最终结果返回；仅允许
  `FrontFlowExecutor` 内部返回 `null`，并由外层 Application Service 当场转换为失败响应；
- 禁止把未接入能力伪造成成功；
- 资金交易超时或无响应不得直接重试，应进入 `UNKNOWN` 并通过查询确认。

---

## 8. 日志约束

本节执行用户确认的 B 方案：业务过程日志参考旧 Front Handle，放在 Capability 的真实步骤附近；
钱包报文日志统一下沉到最终 `BankWalletSender`，一次调用只允许一个 Sender 记录完整明文请求 JSON，
以及对应的完整明文响应 JSON 或通信失败。钱包 body 不脱敏；非报文调用凭证仍按下文禁止项处理。

交易链路必须记录以下阶段：

1. **API 请求入口**：保留现有入口、返回和异常定位日志，但不得重复打印钱包请求或响应报文。
2. **Capability 执行前后**：把原 Handle 的业务步骤、渠道流水和结果日志随代码移动到对应 Capability；
   Capability 不记录钱包请求/响应报文，不为日志增加 AOP、Support 或包装 Service。
3. **渠道流水变化**：INIT、SENDING、最终状态及异常日志随固定 Mapper 的业务代码一起迁移。
4. **钱包访问前后**：统一业务入口为 `BankWalletGateway.post`；最终 `BankWalletSender` 在直接执行 HTTP 时
   唯一记录 `wallet_request_sending`，并记录一次对应的 `wallet_response_received` 或
   `wallet_request_failed`。Gateway、Capability 和旧 Handle 均不得重复输出同一钱包报文。

查询链路执行同一规则：Capability 记录查询业务步骤，最终 Sender 记录唯一钱包报文日志；不为采集日志
增加反射、字段猜测或额外包装层。

上述交易 API、Capability 和钱包日志应从请求 `baseData` 提取并以独立 JSON 字段携带以下定位数据；
字段无值时也应保留 key 并记录 `null`，便于检索同一条调用链：

- `bizOrderNo`；
- `bizSubOrderNo`；
- `tenantId`；
- `platformCode`；
- `dataSourceId`；
- 实际 Java 方法名或钱包接口名；
- 银行编码；
- 有值时同时记录 `frontSsn`、`capability`、`storeId`、Front 归一化状态和耗时。

钱包请求/响应 body 按用户裁决完整明文输出，不做字段脱敏；结构化定位字段和日志级别沿用固定代码基线。

其他必须记录的信息：

- Registry 注册结果和重复注册；
- Route 选择结果；
- Capability 类型、被调用的具体业务能力及“不支持/待接入”结果；
- Front 错误码、处理结果、耗时；
- 银行调用开始、结束、耗时和归一化状态；
- 租户银行配置加载开始、完成、失败及实际使用的配置模板 key；
- 未知异常服务端堆栈。

禁止记录：

- 独立序列化的完整 `accountSpecialData` 或租户配置对象（银行请求 body 中实际上送的字段按明文报文规则记录）；
- 租户完整银行配置；
- `appKey`、私钥、签名原文（调用控制值，不进入报文日志）；
- `Authorization`、Cookie、签名头或完整银行 URL。

日志异常级别：

- 正常开始、路由和完成：`INFO`；
- 可预期业务拒绝或未接入：`WARN`；
- 重复注册、非法状态、未知异常：`ERROR`。

---

## 8.5 字段命名规范

**trans 缩写铁律（2026-08-19 用户定名规则，强制）**：字段名/JSON 键名/specialData 契约键一律用缩写
`trans`，**禁止完全体 `transaction`**——`transDate`/`transTime`/`transType`/`transAmt`/`transSsn` 等
（请求字段、返回字段、组装入参同规）；银行协议原始键按银行原文除外（如 `TRANS_DATE`/`oriTransDate`/
`transactionSsn` 按协议不改）；Java 类名（如 `TransStatusQueryData`）不受本条约束。

收付款方向统一使用以下前缀，**禁止混用 payer/payee 或其他变体**：

| 方向 | 前缀 | 示例 |
|---|---|---|
| 付款方 | `pay_` | `pay_account_id`、`pay_name`、`pay_store_no`、`pay_member_id` |
| 收款方 | `rec_` | `rec_account_id`、`rec_name`、`rec_store_no`、`rec_member_id` |
| 提现方 | `withdraw_` | `withdraw_account_id`、`withdraw_account_name`、`withdraw_member_id` |
| 银行卡 | `bank_card_` | `bank_card_no`、`bank_card_holder_name` |

Java 字段用 camelCase（`payAccountId`/`recAccountId`/`withdrawAccountId`），数据库列用 snake_case（`pay_account_id`/`rec_account_id`/`withdraw_account_id`）。

> 注意：请求 `specialData` 使用银行协议原始 key；本命名规则只约束渠道流水 Entity 和数据库列，
> 不要求把银行协议 key 改名。

---

## 9. 代码开发禁止事项

- 不漏迁已登记能力，不改变不支持/待接入状态；
- 不增加业务 `*Context`、Handle 继承树、Router、Dispatch 或 BankSupport God class；
- 不在能力包内继续拆 `client/protocol/request/service/support/assembler/mapper`；
- 不为减少少量重复把能力主流程拆成多层 Service/helper；
- 不在统一 `BankWalletGateway.post` 外增加业务钱包发送包装层；
- 不创建当前不存在的未来银行、能力或 common 空壳；
- 不复制旧项目的 `BeanPostProcessor` 路由注册；
- 不使用字符串拼接、`bizFunc/accountType` 混合维度或其他无类型约束的旧式复合 Router Key；领域
  Registry 必须使用类型安全的 `(BankCode, FrontCapability)`；
- 不使用 `capability` 猜测 Transaction/Query/Account Router，不执行统一能力预校验，也不在公共
  Dispatch 中 `switch` 选择具体 Handle 方法；
- 不使用任意 `<T> T` 返回；
- 不把银行 DTO 放入 API 或 Common Core；
- 不把银行私有字段提升为公共字段；
- 不在业务请求中开放渠道号、功能码和请求路径；
- 不让具体银行 Capability 自行重复查询租户银行配置；配置由所属域 ExecuteNode 调用具体 Loader，
  一次装配进本次 Slot；
- 不建立单一 `front_channel_transaction`，也不把不同银行或不同交易业务写入同一渠道表；
- 不允许调用方传物理表名，不使用字符串拼接动态表名；
- 不漏存业务系统、逻辑业务类型、业务主/子记录 ID 和业务/银行明确字段；
- 不允许生成 SQL 的 AI 因目标字符集不同而静默修改字段、默认值或索引；不兼容项必须先形成差异清单；
- 不把 `accountConfig` 增加到对外 `FrontRequest`；
- 不静默覆盖重复银行 Capability；
- 不在渠道流水表 Entity 或数据库列使用 `payer`/`payee` 命名——付款统一 `pay_`、收款统一 `rec_`、提现统一 `withdraw_`（见 §8.5）；
- 不返回银行原始 DTO、原始错误码或敏感报文；
- `FrontFlowExecutor` 内部 `null` 必须由 Application Service 转换为失败响应；对外不返回 `null` 或模拟成功；
- 不在未确认字段时猜测银行协议；
- 持久层 Entity ↔ VO/BO 转换不手写 `setXxx(getXxx())`，必须用 `@AutoMapper` + `MapstructUtils.convert`（见 §3.9）；
- 不在 catering-front `pom.xml` 重复声明 MapStruct 依赖，统一走 `catering-common-core` 传递；
- 不引入原生 `org.mapstruct:mapstruct` / `mapstruct-processor`，不新建 lsym 风格的
  `@Mapper(componentModel="spring")` 集中式 `Converter` 接口；对象转换固定用 mapstruct-plus 的
  `@AutoMapper` + `MapstructUtils.convert`（见 §3.9 / §3.9.1）；
- 不在子模块 `pom.xml` 写死第三方依赖 `<version>`，版本统一在根 `pom.xml` 管理（见 §2.5）；
- 不在 catering-front 使用 `dynamic-datasource`（`@DS` / `DynamicDataSourceContextHolder`）
  或 Hint（`HintManager`）做分库切换；分库固定用 ShardingSphere-JDBC STANDARD 模式，
  分片键 `data_source_id`（见 §3.10.1）；
- 不使用 `FrontDataSourceHelper`——已废弃，STANDARD 模式下 SQL 自带 `data_source_id` 自动路由，
  Handle 代码不需要任何数据源切换包裹；
- 不在 Application Service 手动读 HTTP header——参数注入由 `catering-common-feign` 的
  `RequestContextInterceptor` + `BaseDataRequestBodyAdvice` 自动完成（见 §3.10.3）；
- 分库路由键是 `data_source_id`（由业务请求方在 `baseData` 传入，回填到渠道流水 `data_source_id`
  列）；`tenant_id` 是租户标识与 MySQL 分区键，不参与分库路由决策；
- 10 张渠道流水表必须使用 `LINEAR KEY (tenant_id, store_id) PARTITIONS 30` 分区（见 §3.10.2）。

---

## 10. 当前实施顺序：三域注册收口

1. 以 `limeng_front_restruct` 已完成的初版扁平结构为当前代码起点，将全部 22 个 Capability 迁移到
   所属域的强类型接口、Slot 参数和 Registry；不得跳过任何能力，也不得重写其银行业务逻辑。
2. 确认 `catering-api-front`、domain、mapper、DDL、不明来款业务为禁改区。
3. 建立 `FrontAccountSlot`、`FrontAccountApplicationService`，把账户状态/余额从 Query 域迁到 Account 域。
4. 建立交易、查询、账户三套强类型 Capability 接口、Registry 和 ExecuteNode；删除统一接口、Registry、
   `FrontBankExecuteNode`，不保留兼容层。
5. 13 条链保持 ID：交易 8 条挂 `frontTransExecute`，查询 3 条挂 `frontQueryExecute`，账户 2 条挂
   `frontAccountExecute`。
6. 三个 ExecuteNode 各自按顺序完成公共校验、Loader 配置加载、本域路由、Capability 执行和
   `FrontException` 收口，不建立父类。
7. 本轮不新增/运行测试、不执行编译，只做静态 review；旧单 Registry 版本的编译记录不能证明三域版本。
8. 更新三域文件清单、22 项归属矩阵、13 条链和删除清单后等待用户 review。

本次只迁移现有能力，不新增银行协议或改变支持矩阵。

字段和协议未确认时，只允许创建 `PENDING_INTEGRATION` 骨架，不允许伪造银行请求或成功响应。

平安账户状态/余额两个 Account Capability 继续返回 `ADAPTER_NOT_READY`
（交易状态与两类明细已实现，2026-08-19）。用户已明确裁决这两个入口只保留挡板，
`TODO-001` 按此关闭；未有新的明确要求时，不得移除挡板、核对候选银行接口、创建字段
ContractKeys 或补写未启用分支。

---

## 10.5 DDL/数据库变更规范

任何渠道流水表的 DDL 变更（新增/修改/删除字段、索引、分区），必须**同步检查并更新全部持久层代码和配置**，
不允许只改数据库不改代码，也不允许只改代码不改数据库。

### 变更清单（每次 DDL 变更必须逐项检查）

| # | 检查项 | 文件/位置 | 说明 |
|---|---|---|---|
| 1 | **Entity** | `domain/Front*Transaction.java` | 加/改/删对应字段（camelCase），确保 `@Data` 生成 getter/setter |
| 2 | **VO** | `domain/vo/Front*TransactionVo.java` | **必须与 Entity 逐字段对齐**——用 diff 验证：`diff <(grep private Entity.java) <(grep private Vo.java)`，VO 不能缺字段也不能多字段（继承自 `BaseRequest` 的除外） |
| 3 | **Mapper XML** | `resources/mapper/Front*Mapper.xml` | `<resultMap>` 加 `<result column="xxx" property="xxx"/>`；`Base_Column_List` 加列名；去重；字段数 = Entity 字段数 |
| 4 | **Mapper 接口** | `mapper/Front*Mapper.java` | 确认 `BaseMapperPlus<Entity, Vo>` 泛型类型正确 |
| 5 | **Service / ServiceImpl** | `service/Front*Service.java` / `service/impl/` | `queryList` 等自定义查询的 `LambdaQuery` 字段引用要同步；删除已删字段的 `.eq()` 行 |
| 6 | **Handle 持久化** | `channel/*/TransactionHandle.java` | `doInsertInit` 的 `invokeSetter` 调用、`updateSending`/`updateResponse` 的 `wrapper.set` 要同步；字符串字面量改为 `FrontChannelColumnConstants` 常量 |
| 7 | **渠道列名常量类** | `common-core/constant/front/FrontChannelColumnConstants.java` | 新字段列名定义为常量；删字段时同步删常量；Handle 不写字符串字面量 |
| 8 | **银行协议常量类** | `common-core/constant/front/*ContractKeys.java` / `*QueryContractKeys.java` | Handle 里 `reserve.put()` / `response.getString()` 用的 key 必须有对应常量定义；新增银行字段时同步加常量 |
| 9 | **DDL 文档** | `09B-channel-transaction-ddl-utf8mb4.sql.md` + `09-final-rebuild-all-tables.sql` + 本次 ALTER 脚本 | 建表 SQL 同步更新（全新库执行得到最终结构）；已有库需另提供最小 ALTER 脚本 |
| 10 | **字段目录** | `09A-channel-transaction-table-field-catalog.md` | 字段表格加/删行、序号重排、§2 字段数量汇总更新 |
| 11 | **编译验证** | `mvn clean compile -DskipTests -pl catering-modules/catering-front -am` | 仅在用户明确授权时执行；未授权时在交付报告中明确写“未编译” |

### 禁止事项

- **禁止**只提供 ALTER SQL 不改 Entity/Mapper XML/Handle——运行时字段映射不上；
- **禁止**改了 Entity 不改 VO——Entity 和 VO 必须逐字段对齐（用 diff 验证）；
- **禁止**在 Handle/Service 里用字符串字面量作为列名或银行协议 key——必须用 `FrontChannelColumnConstants` 或 `*ContractKeys` 常量；
- **禁止**改了 Entity 字段名不改 Mapper XML 的 `resultMap` 和 `Base_Column_List`——查询结果会丢字段；
- **禁止**改了 DDL 不更新 `09A` 字段目录和 `09B`/`09-final` 建表 SQL——文档与代码不一致；
- 未收到用户授权时禁止执行编译；收到授权后，DDL/Entity/Mapper 联动变更应执行编译验证。

受控例外：经用户明确确认的历史兼容列可以保留在数据库中而不要求当前 Handle 回填，但必须同时满足：

- 列允许 `NULL`，不得阻断当前 INIT 记录插入；
- 字段目录、建表 SQL、ALTER 脚本和 issue 明确标注“兼容保留、当前不读写”；
- 不得因兼容列仍存在而恢复已废弃的业务查询、校验或 Handle 映射；
- 中信退款本次兼容列范围固定见 `FRONT-P1-005`，不能自动扩展到其他表。

### 变更流程

```text
1. 确认变更需求（加什么字段、什么类型、什么注释）
2. 改 09B DDL + 09-final（建表 SQL）+ 09A 字段目录（字段表格 + 数量汇总）；已有库变更同步提供最小 ALTER 脚本
3. 改 Entity（加字段）
4. 改 VO（与 Entity 对齐，diff 验证）
5. 改 Mapper XML（resultMap + Base_Column_List，字段数验证）
6. 改 FrontChannelColumnConstants（加/删常量）
7. 改 Handle（invokeSetter / wrapper.set，用常量替换字符串）
8. 改 Service/ServiceImpl（如有自定义查询）
9. 银行协议常量类检查（reserve/response key 是否都有常量）
10. 用户明确授权时执行 mvn clean compile -DskipTests -pl catering-modules/catering-front -am；
    未授权时记录为“未编译”
11. 09-final 重建脚本交用户执行
```

### 历史踩坑记录（必须避免的重复错误）

以下错误在本项目开发过程中**实际发生过**，后续变更必须特别注意：

1. **VO 漏改字段**——Entity 加了 `dataSourceId`/`payAccountId`/`payName` 等账户字段，但 10 个 VO 全部漏了。
   **教训**：改 Entity 必须同步改 VO，改完用 `diff Entity.java Vo.java` 逐字段验证。

2. **Mapper XML 字段数不一致**——Entity 有 47 个字段，Mapper XML 的 `resultMap` 和 `Base_Column_List` 只有 30 多个。
   **教训**：改完 XML 后必须检查 `resultMap` 的 `<result>` 行数和 `Base_Column_List` 的列名数 = Entity 字段数。

3. **Handle 里字符串字面量当列名**——`wrapper.set("front_status", ...)` 和 `response.getString("errCode")` 直接写字符串，
   没用常量。改字段名时 Handle 不会报错但运行时映射不上。
   **教训**：Handle 里所有列名和银行协议 key 必须用常量类，零字符串字面量。

4. **common-core 银行协议常量类遗漏**——Handle 用了 `response.getString("balance")` 但没有对应常量定义。
   **教训**：Handle 里每个 `reserve.put()` / `response.getString()` 的 key 都要在 `*ContractKeys` 常量类里有定义。

5. **字段命名不遵守规范**——用了 `payerAccountId`/`payeeAccountId` 而不是 `payAccountId`/`recAccountId`。
   **教训**：付款统一 `pay_`、收款统一 `rec_`、提现统一 `withdraw_`（见 §8.5），Entity 和数据库列名都要遵守。

6. **LiteFlow 节点重复注册**——同一 nodeId 被注册两次（`*Cmp` 和 `*Node` 各一份），启动报错。
   **教训**：一个 nodeId 只能有一个 `@LiteflowComponent`，改完 grep 确认唯一。

7. **MyBatis-Plus 版本 API 变化**——`Wrappers` 在 3.5.16 里在 `core.toolkit` 包，不是 `core.conditions`。
   **教训**：import 路径以项目其他模块的用法为准（`com.baomidou.mybatisplus.core.toolkit.Wrappers`）。

---

## 11. 提交前检查表

### A. 4 个必要参数（tenantId / clientId / platformCode / dataSourceId）

- [ ] `BaseRequest`（common-core）含 4 个字段（tenantId/clientId/platformCode/dataSourceId），由拦截器自动注入；
- [ ] clientId/platformCode/dataSourceId 缺失时由域 ExecuteNode 第④步用 tenantId 从
      `tenant_base_config` 缺省回填（三域收口后调用方最少只需传 tenantId + 业务必填字段）；
      显式传入优先；回填后仍缺失（dataSourceId/platformCode）按 INVALID_REQUEST 中断；
- [ ] `FeignRequestInterceptor`（common-feign 发送端）逐个解析 4 个值：header 优先，
      header 缺失时从 `RequestContext` 补齐；非 Web/Feign 异步线程不得因没有
      `HttpServletRequest` 就提前返回；
- [ ] `RequestContextInterceptor`（common-feign 接收端）从 header 提取 4 个值到 `RequestContext`（ThreadLocal）；
- [ ] `BaseDataRequestBodyAdvice`（common-feign）由自动配置显式注册，反序列化后同时支持
      直接 `BaseRequest` 和 `FrontRequest<T>.baseData`；
- [ ] header 与请求体识别字段冲突时明确失败，不得静默保留请求体值；
- [ ] `RequestContext.afterCompletion` 调 `clear()` 清理 ThreadLocal；
- [ ] Handle 通过 `data.getDataSourceId()` 取值，落库到渠道流水 `data_source_id` 列；
- [ ] 分库路由键是 `data_source_id`（由 `baseData.dataSourceId` 透传回填到渠道流水 `data_source_id` 列，见 §3.10.1）；`tenant_id` 是租户标识与分区键，不参与分库路由。

### B. 模块与依赖

- [ ] 代码放在正确模块和 package（front→api-front→common-core 依赖方向无反转）；
- [ ] 银行协议 DTO 不进 `catering-api-front` 或 `catering-common-core`（放到所属
      `channel/{bank}/{transaction|query|account}` 域包）；
- [ ] 子模块 `pom.xml` 不写死 `<version>`，版本统一在根 `pom.xml` 管理；
- [ ] catering-front `pom.xml` 未重复声明 MapStruct 依赖；
- [ ] catering-front 不使用 `dynamic-datasource`（`@DS`/`DynamicDataSourceContextHolder`）。

### C. API 返回结构

- [ ] 单条交易/交易状态/账户查询返回 `R<具体结果>`，分页明细查询直接返回
      `TableDataInfo<具体行>`，无返回体返回 `R<Void>`；
- [ ] 分页接口不存在 `R<TableDataInfo<...>>` 等包裹形式，且全链路（Handle/Service/API）
      不存在 `FrontPageResult` 分页中间承接对象（2026-08-19 起废除）；
- [ ] 不存在 `FrontResponse` 中间包装层；
- [ ] API/Controller/ApplicationService 三层签名一致，Controller 只透传不重复包装；
- [ ] ApplicationService 不含银行协议细节（无 `instanceof` 判断银行、无 bizFunc 字面量）。

### D. 请求对象与上下文

- [ ] 对外请求固定 `baseData + specialData` 两段（JSON：`{"baseData":{},"specialData":{}}`）；
- [ ] 内部只使用两层 Slot：Base 及 Trans/Query/Account 三个直接子类；所属域 ExecuteNode 调用 Loader
      将 `accountConfig` 写入同一 Slot，不存在业务 Context 转换；
- [ ] `specialData` 与 `accountSpecialData` 完全分离，不共享引用、不 `putAll`、不互相覆盖；
- [ ] `specialData` 不含 tenantId/platformCode/frontSsn/channelNo/bizFunc/mchntId/appId/appKey/url/密钥；
- [ ] **specialData 的 key 用银行协议原始名**（如 outAcctNo/inAcctNo/USER_D_NM），和 word 文档一致，禁止自定义；
- [ ] **baseData 只含内部业务公共字段**——收付款账户、会员编号、姓名、卡号及银行协议专用筛选条件
      均放 specialData，不放请求对象（TransferBusinessData 等）；
- [ ] Capability 从 `slot.getSpecialData().getString(常量)` 取银行特有字段，不从公共 data 猜银行字段；
- [ ] 常量类变量名用 `PAY_`/`REC_` 前缀（禁止 PAYER/PAYEE），值用银行协议原始名。

### E. 路由与能力

- [ ] API 方法内部固定 capability，请求对象和调用方不能传入或覆盖；
- [ ] 三域注册：`BankTransCapabilityRegistry`、`BankQueryCapabilityRegistry`、
      `BankAccountCapabilityRegistry` 各自存在且结构同构，不通过 capability 名称、枚举列表或前缀猜测领域；
- [ ] Registry 使用类型安全的 `(BankCode, FrontCapability)` 精确定位唯一 Capability；
- [ ] 每个 Registry 构造器只注入本域强类型 Capability 列表，重复注册相同“银行 + 能力”时启动失败；
- [ ] 未解析银行返回 `BANK_NOT_SUPPORTED`，银行下未注册能力返回 `CAPABILITY_NOT_SUPPORTED`，不维护
      额外能力状态表；
- [ ] Capability 只实现 `BankTransCapability/BankQueryCapability/BankAccountCapability` 之一，不继承业务父类；
      配置由所属域 ExecuteNode 调用具体 Loader 加载；
- [ ] 平安账户状态/余额保留明确挡板，平安平台收付款继续不注册；
- [ ] 三个 ExecuteNode 分别调用本域 Registry 选中的 Capability，不存在统一 Registry、BankRouteNode、
      Router/Dispatch 或 `switch(capability)`；
- [ ] `bizFunc/chnlNo/API path` 由具体 Capability 的带注释本地常量确定，禁止调用方覆盖；
- [ ] `*ContractKeys` 保存协议字段 key；业务系统传入/读取的 `specialData/accountSpecialData` key 必须与
      API 字段契约对齐；只保留调用方可选择的枚举值或真实跨接口值，不保存 Capability 单点使用的
      `bizFunc/chnlNo/API path`、固定类型码、标志位和默认备注；同一内部固定值不得同时存在于
      Capability 与 ContractKeys。
- [ ] Capability 本地固定参数必须存在实际调用；未实现分支不得预留草稿常量或映射；

### F. LiteFlow 编排

- [ ] `frontTransExecute/frontQueryExecute/frontAccountExecute` 三个节点注册唯一，13 条链无悬空引用；
- [ ] 交易 8 条链固定 `THEN(frontTransExecute)`，查询 3 条固定 `THEN(frontQueryExecute)`，账户 2 条固定
      `THEN(frontAccountExecute)`；
- [ ] 每个 ExecuteNode 只执行本域 Registry 选中的 Capability，不按 capability 再分派；
- [ ] 交易链不设置公共重复交易检查节点；`CiticTransferCapability` 使用固定 Mapper 检查；
- [ ] 业务异常 `markBusinessFail` + `setIsEnd(true)`，不 throw；
- [ ] 系统异常 throw 走 `FrontExceptionHandler` 收口；
- [ ] 持久化（INIT/SENDING/响应更新）在 Capability 主流程中直接可见，不需要独立链节点或 BankSupport。

### G. 持久化与渠道流水

- [ ] 10 张表按“银行 + 交易业务”拆分，由当前能力 Handler 使用固定 Repository，不接收表名、不拼接
      动态 SQL；capability 只参与 Handler 定位，不用于动态选表；
- [ ] **渠道表禁止 MEDIUMTEXT 快照字段**（`business_base_snapshot_cipher` 等 4 个已删除），所有请求/返回字段单独成列；
- [ ] **禁止落库** front_resp_code/front_resp_desc/front_remark（接口返回即可）、version/request_hash/interface_code/config_version/business_date/business_time/business_remark、send_started_at/completed_at；
- [ ] 每张表含 `reserve1/reserve2/reserve3` + 3 个时间（create_time/update_time/bank_responded_at）；
- [ ] Entity 继承 `TenantEntity`，VO 继承 `BaseRequest`，Entity ↔ VO 逐字段对齐（`diff` 验证）；
- [ ] Mapper XML `resultMap` 行数 = `Base_Column_List` 列名数 = Entity 字段数（含父类 5 个字段）；
- [ ] Handle `doInsertInit`（INSERT INIT）→ `updateSending`（UPDATE SENDING）→ 调银行 → `updateResponse`（UPDATE 终态/响应码）；
- [ ] 重复交易检查：CITIC + PingAn 交易方法在当前银行业务表按
      `tenant_id + biz_order_no + biz_sub_order_no` 查询；命中返回“交易已存在”，不调用银行、不重放旧结果；
- [ ] report 跨实例查重已按用户裁决暂缓；两家 `checkDuplicateTransaction()` 当前只查
      当前银行/能力业务表，未经新的明确要求不得增加 report Provider、Mapper、Feign 或统一表查询；
- [ ] 不存在 `frontIdempotencyCheck`、`FrontIdempotencyCheckNode` 或其他无法确定固定业务表的公共检查节点；
- [ ] 重复交易统一返回 `TRANS_ALREADY_EXISTS(F300001, "交易已存在")`，不存在旧的
      `IDEMPOTENCY_CONFLICT`、请求处理中或参数冲突语义；
- [ ] 中信退款不查询原渠道表；平安退款按 TODO-002 使用租户 + 原业务主子流水精确查询原
      transfer/consume 渠道表，统一定位结果同时用于银行报文和退款落库；
- [ ] 平安退款 `oriTransSsn` 只取原渠道记录 `frontSsn`，不得取调用方字段、`bankUserSsn` 或
      `bankQueryId`，并回填 `originalCapability/originalChannelTransactionId/originalFrontSsn`；
- [ ] 平台收付款表也存 acct（pay_account_id / rec_account_id）。

### H. 分库与分区

- [ ] ShardingSphere STANDARD 模式，分片键 `data_source_id`，算法 `TenantDataSourceShardingAlgorithm`；
- [ ] 算法直接把 `data_source_id` 值拼成 `ds_x`（不查配置中心，见 §3.10.1）；
- [ ] 配置缺失、解析失败或目标 `ds_x` 不存在时明确失败，不默认路由到 `ds_0`/第一个数据源；
- [ ] 本阶段不验收 `shardingsphere-config-{dev,uat,prod}.yaml` 的连接配置加密和安全加固；后续部署任务单独处理；
- [ ] `FrontDataSourceHelper` 已废弃不存在，Handle 无数据源切换代码；
- [ ] 10 张表 `PARTITION BY LINEAR KEY (tenant_id, store_id) PARTITIONS 30`（内置于 09-final）；
- [ ] 主键组合 `(id, tenant_id, store_id)`，唯一键降级为普通索引（满足分区约束）。

### I. 字段命名与常量

- [ ] 付款 `pay_`/收款 `rec_`/提现 `withdraw_`/银行卡 `bank_card_` 前缀（禁止 payer/payee）；
- [ ] Handle 零字符串字面量（列名用 `FrontChannelColumnConstants`，银行协议 key 用 `*ContractKeys`）；
- [ ] common-core 常量类与 Handle 实际引用对齐（`reserve.put`/`response.getString` 的 key 都有常量定义）；
- [ ] Entity ↔ VO 转换用 `@AutoMapper` + `MapstructUtils.convert`，无手写 `setXxx(getXxx())`。

### J. 异常与日志

- [ ] 新错误码只添加到 `FrontErrorCode`（编码分段 F1/F2/F3/F4/F9）；
- [ ] `FrontExceptionHandler` 统一收口，未知异常对外只返回 `INTERNAL_ERROR` 不泄漏堆栈；
- [ ] `frontRespCode/frontRespDesc` 来自同一个 `FrontErrorCode`；
- [ ] 银行原始响应码不作 `R.code/frontRespCode`；
- [ ] 交易 API 入口记录方法、traceId、定位字段和状态，不记录完整 `FrontRequest`；
- [ ] 交易 Capability 存在 `capability_started`、`capability_completed/capability_failed` 独立日志点；
- [ ] 最终 `BankWalletSender` 存在唯一的 `wallet_request_sending`、
      `wallet_response_received/wallet_request_failed` 日志点；Gateway/Capability 不重复输出同一报文；
- [ ] 交易 API、Capability 和钱包日志均携带 `bizOrderNo/bizSubOrderNo/tenantId/platformCode/dataSourceId`
      以及实际方法名、银行编码；无值时保留 key 并记录 `null`；
- [ ] 查询由最终 Sender 记录一次请求及一次响应/失败；Query Capability 不重复打印同一报文，
      不通过反射采集 metadata，不要求 `capability` 或交易型定位字段；
- [ ] 最终 Sender 唯一记录完整明文钱包请求/响应 JSON，不对 body 字段脱敏；
- [ ] `appKey`、私钥、签名原文、签名头、`Authorization`、Cookie 和完整银行 URL 不进入日志；
      Capability 开始日志不单独打印完整 `accountConfig/accountSpecialData`。

### K. DDL 变更同步（见 §10.5）

- [ ] DDL 变更已同步 11 项（Entity/VO/Mapper XML/Mapper 接口/Service/Handle/列名常量类/银行协议常量类/DDL 文档/字段目录/编译验证）；
- [ ] 本轮按用户裁决未新增/运行测试、未执行编译，只提交静态 review 证据且未声称编译通过。

### L. 文档

- [ ] 相关设计、能力矩阵和字段映射文档已更新；
- [ ] `09-final-rebuild-all-tables.sql` 与代码 Entity 字段一致。
