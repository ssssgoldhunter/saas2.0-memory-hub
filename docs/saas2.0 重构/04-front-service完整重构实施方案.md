# SaaS 2.0 多银行渠道 Front Service 实施方案

> 状态：historical-plan / superseded-by-28-29（三域注册已实施完成，本文仅作历史方案记录）
> 更新日期：2026-08-25
> 实施起点：`cateringsass/limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2`
> 最终设计：[28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)
> 可执行任务：[29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)
> 最终实现校准（2026-08-31）：本文的 13 条单节点链仅是历史安排；当前 21 条链及租户准备/分库结构
> 以 19、31 号文档和 `limeng_front@dbd9fad5` 为准。

本文是 28/29 号三域迁移的历史实施安排，22 个实现类 / 13 条链不是当前源码数量；当前状态以
WIKI-START §4、§7.1 和 19 号手册为准。旧版大 Handle、业务 Context、Router/Dispatch、
Provider/Assembler 和多节点 LiteFlow 实施清单已删除，不再作为开发参考。三域改造只调整内部组装和路由，
不修改 API 与银行业务。

## 1. 实施目标

在已完成第一阶段扁平化的代码上，把单一 `frontBankExecute + BankCapabilityRegistry` 收口为三个执行域：

```text
Transaction：FrontTransApplicationService
→ frontTransExecute
→ FrontTransExecuteNode
→ BankTransCapabilityRegistry
→ BankTransCapability

Query：FrontQueryApplicationService
→ frontQueryExecute
→ FrontQueryExecuteNode
→ BankQueryCapabilityRegistry
→ BankQueryCapability

Account：FrontAccountApplicationService
→ frontAccountExecute
→ FrontAccountExecuteNode
→ BankAccountCapabilityRegistry
→ BankAccountCapability
```

所有 Capability 继续通过：

```text
BankWalletGateway.post → BankWalletSender → HTTP
```

## 2. 禁改范围

三域改造不得修改：

- `catering-api-front`、Feign、Controller 对外路径和签名；
- 请求/响应 DTO、`R<T>` / `TableDataInfo<T>` 外壳；
- 银行路径、bizFunc、chnlNo、字段白名单、加密和成功码；
- 10 张渠道表、Entity、VO、Mapper、XML、Service、DDL 和分片规则；
- 上游 `FrontSpecialDataAssembler` 组装方式；
- 中信不明来款专项 API、请求/响应和 Channel 业务；
- 能力支持状态和现有挡板语义。

## 3. 模块职责

| 模块 | 内容 |
|---|---|
| `catering-api-front` | API、Feign、请求/响应 DTO、枚举、对外组装工具 |
| `catering-common-core` | `R`、FrontErrorCode、FrontException、公共请求上下文 |
| `catering-front` | Controller、Application Service、LiteFlow、三域 Registry、Capability、Loader、Gateway、持久化 |

禁止增加新的 `front-api/common/service` 中间模块或反向依赖。

## 4. API 与 Application Service

Controller 继续原样透传，不做银行判断。API 方法内部固定 capability，调用方不能传入或覆盖。

Application Service 分工：

- `FrontTransApplicationService`：8 个交易方法，创建 `FrontTransSlot`。
- `FrontQueryApplicationService`：3 个交易查询方法，创建 `FrontQuerySlot`。
- `FrontAccountApplicationService`：账户状态、账户余额，创建 `FrontAccountSlot`。
- `FrontFlowExecutor`：统一执行 chain id、检查 LiteFlow 执行结果、完成返回兜底；不做银行路由。

账户方法只是内部从 Query Service 迁至 Account Service，Controller/API 方法签名保持不变。

## 5. 13 条 LiteFlow 链

### 5.1 Transaction：8 条

均使用 `THEN(frontTransExecute)`：

1. `chainFrontTransfer`
2. `chainFrontTransferAuth`
3. `chainFrontTransferAuthCodeResend`
4. `chainFrontConsume`
5. `chainFrontRefund`
6. `chainFrontWithdraw`
7. `chainFrontPlatformPay`
8. `chainFrontPlatformReceive`

### 5.2 Query：3 条

均使用 `THEN(frontQueryExecute)`：

1. `chainFrontQueryTransStatus`
2. `chainFrontQueryPlatformTransDetails`
3. `chainFrontQueryTransDetails`

### 5.3 Account：2 条

均使用 `THEN(frontAccountExecute)`：

1. `chainFrontQueryAccountStatus`
2. `chainFrontQueryAccountBalance`

LiteFlow v2.16.X 的 `THEN(node)` 可以只包含一个节点。本项目不再建立公共 Validate/Resolve/Route/Prepare/Dispatch/Normalize 组件。

## 6. Slot

```text
FrontBaseSlot
├─ FrontTransSlot
├─ FrontQuerySlot
└─ FrontAccountSlot
```

- 三个域 Slot 直接继承 Base，禁止第三层。
- 一次请求只使用一个 Slot，不做 Context 转换。
- Slot 只承载数据和结果，不注入 Service/Mapper/Gateway，不执行银行业务。
- `FrontQuerySlot` 不保存账户状态/余额结果；账户结果只在 `FrontAccountSlot`。

## 7. ExecuteNode

三个节点允许保留少量重复，禁止 `AbstractExecuteNode`。每个节点按以下顺序直接展开：

```text
无参 getFirstContextBean()
→ 显式检查本域 Slot 类型
→ 校验公共请求和 tenantId
→ TenantBankConfigLoader.loadTenantBaseInfo
→ 回填/核对 clientId、platformCode、dataSourceId
→ 解析 BankCode
→ TenantBankConfigLoader.loadBankAccountConfig
→ 本域 Registry.get(bankCode, capability)
→ 本域 Capability.execute(强类型 Slot)
```

节点只捕获 `FrontException`，把统一错误写入 Slot 并 `setIsEnd(true)`；其他系统异常继续抛出，由全局异常处理器收口。

## 8. 三个 Registry

| Registry | 注入列表 | 返回类型 |
|---|---|---|
| `BankTransCapabilityRegistry` | `List<BankTransCapability>` | `BankTransCapability` |
| `BankQueryCapabilityRegistry` | `List<BankQueryCapability>` | `BankQueryCapability` |
| `BankAccountCapabilityRegistry` | `List<BankAccountCapability>` | `BankAccountCapability` |

共同规则：

- Key 固定为 `(BankCode, FrontCapability)`。
- 构造阶段生成不可变二级 Map。
- 同域重复 Key 启动失败，禁止后注册覆盖。
- Registry 不写具体银行 `if/switch`，不猜 capability 属于哪个域。
- 删除统一 `BankCapability`、统一 Registry 和 `FrontBankExecuteNode`，不保留兼容层。

## 9. 22 个 Capability 归域

| 银行 | Transaction | Query | Account |
|---|---|---|---|
| 中信 | transfer、consume、refund、withdraw、platformPay、platformReceive | transStatus、platformDetail、transDetail | accountStatus、accountBalance |
| 平安 | transfer、consume、refund、withdraw、transferAuth、resendAuthCode | transStatus、platformDetail、transDetail | accountStatus、accountBalance（保持既有挡板） |

合计 Transaction 12、Query 6、Account 4。平安 platformPay/platformReceive 不注册；中信 transferAuth/resend 不注册。

## 10. Capability 实施方式

每个 Capability 只实现一个域接口，一个类只处理一个 `(bank, capability)`。交易主流程固定为：

1. 读取并校验 baseData/specialData/accountConfig。
2. 直接组装当前银行请求 DTO 和固定控制值。
3. 在当前固定表执行重复交易检查。
4. 插入 `INIT`，更新 `SENDING`。
5. 调 `BankWalletGateway.post`。
6. 判断银行成功/拒绝/未知，更新渠道终态。
7. 映射统一结果并写回 Slot。

查询与账户能力省略流水步骤，但仍在能力类中直接展示校验、组装、发送、判断、映射。

允许同一银行不同能力保留 10～30 行相似代码。只允许当前类一层私有 helper；禁止业务父类、
BankSupport、Assembler、Invoker 或多层 Client 隐藏执行顺序。

## 11. 租户配置实现

```text
三个 ExecuteNode
→ TenantBankConfigLoader
→ RemoteConfigServiceClient
```

`TenantBankConfigLoader` 是具体类：

1. 通过 tenantId 查询 `tenant_base_config`。
2. 得到并回填 `clientId/platformCode/dataSourceId/supportBankConfig`。
3. 使用 `supportBankConfig` 解析当前银行配置模板 key。
4. 查询租户银行账户配置。
5. 在 Loader 内用一个平级银行私有方法扁平组装 `TenantBankAccountConfig`。

只保留两个公共方法：`loadTenantBaseInfo`、`loadBankAccountConfig`。删除 Provider 接口、AssemblerRouter、
Assembler 接口/父类和银行 Assembler；不得换名保留同样层级。

## 12. Gateway、Sender 与日志

业务代码唯一发送入口是 `BankWalletGateway.post`。Gateway 只负责根据 BankCode 选择最终 Sender；Sender 直接完成签名、HTTP 和响应读取。

日志职责：

| 位置 | 内容 |
|---|---|
| API/Application Service | 请求入口、完成、异常收口 |
| ExecuteNode | 配置加载、域路由、未注册和失败 |
| Capability | 业务开始、校验、流水状态、结果和异常 |
| Sender | 一次完整明文请求 JSON、一次完整明文响应 JSON 或通信失败 |

钱包 body 不脱敏。Capability/Gateway 不重复打印同一报文。`appKey`、私钥、签名材料、签名/认证 Header、
`Authorization`、`Cookie` 等非业务报文凭证仍禁止进入日志。

## 13. 中信不明来款

中信不明来款继续是独立专项，不进入三域 Registry 或 LiteFlow：

```text
专项 Application Service
→ TenantBankConfigLoader
→ CiticUnidentifiedRemittanceChannel
→ BankWalletGateway
```

只允许将配置依赖统一到 Loader；API、全字段强类型请求/返回、交易码、校验、Channel 和业务流程均不改。

## 14. 文件级实施顺序

1. 新增 Account Slot/Application Service。
2. 建立三个域 Capability 接口。
3. 建立三个 Registry。
4. 建立三个 ExecuteNode。
5. 将 22 个 Capability 改为所属域接口。
6. 将账户两个内部入口迁至 Account Application Service。
7. 切换 13 条 chain 表达式。
8. 删除单一 Capability/Registry/ExecuteNode 和残余 Context/Router/Dispatch/Handle。
9. 核对 Sender 日志唯一性和明文 body 口径。
10. 只做静态验收并提交用户 review。

## 15. 静态验收

- `catering-api-front` 相对实施基线零 diff。
- 三个 Slot 直接继承 Base。
- Capability 接口、Registry、ExecuteNode 各 3 个。
- 22 个 Capability 分布为 12/6/4。
- 13 条链分布为 8/3/2，每条只含一个节点。
- 账户状态/余额没有注册到 Query 域。
- 统一 Capability/Registry/ExecuteNode、业务 Context、Router、Dispatch、Handle、Provider/Assembler 零残留。
- `HttpRequest.post` 只存在于最终银行 Sender。
- 完整明文请求/响应 body 只由 Sender 输出一次，认证凭证不入日志。
- API、数据层和中信不明来款无业务 diff。

本轮按用户裁决不新增/运行测试、不执行编译。旧版本编译记录不能作为三域版本证据。代码 commit/push 需用户另行授权。
