# Catering Front 框架与后续开发手册

> **结构状态（2026-08-25）**：本文主体记录当前已提交基线，便于 P0 核对业务行为；28 号扁平化设计已经
> 用户批准但尚未实施，2026-08-25 的未提交全面改造已放弃。下一轮执行中信、平安 22 个通用能力与
> 13 条链的全量迁移，步骤见 29 号 plan。凡本文 Router/Handle/Context/银行 Client 的开发模板与 28 号冲突，
> 结构上以 28 号、29 号和 05 §0 为准。
> 本次结构迁移日志执行用户确认的 B 方案：Capability 记录业务步骤，最终 `BankWalletSender` 统一且只
> 记录一次钱包请求/响应/失败，删除旧 Handle/Capability 的重复钱包报文日志；其余字段范围和安全边界以
> `cateringsass/limeng_front@99e696f4e7ab78a1b307b5a2fd3c911698c143fb` 为准。

> 状态：current / verified-against-source
> 核验日期：2026-08-24
> 适用对象：后续维护 `catering-front` 的开发人员与 AI
> 最终目的：让没有历史上下文的开发者能够定位代码、理解边界，并按现有框架继续增加银行交易、查询和账户功能
> 源码优先：本文与代码不一致时，以当前 `limeng_front` 分支源码为准，并将差异视为文档或代码缺陷

---

## 1. 使用方式

进入任务后按以下顺序工作：

1. 先确认当前分支、工作区改动和任务边界，不覆盖他人未提交代码。
2. 从 `catering-api-front` 的 API、DTO、枚举确认对外契约。
3. 从具体银行 `*TransHandle` / `*QueryHandle` 确认真实必填字段、固定值、协议路径和结果映射。
4. 从 `capabilityDefinitions()` 确认某银行是否真实注册该能力；不能只看枚举或 Word 文档。
5. 从 `resources/liteflow/front-flow.xml` 确认入口链和公共节点。
6. 从 `BankWalletGateway`、银行 `WalletHttpClient` 和 `ResponseChecker` 确认真实发送及成功判定。
7. 涉及渠道流水时同时核对 Entity、VO、Mapper、Mapper XML、Service、Handle 和 DDL。
8. 只有得到明确授权时才新增或运行测试、执行编译；代码仓 commit/push 必须先确认。

### 1.1 事实优先级

```text
当前源码与运行配置
→ 本手册（开发入口与约束）
→ 交易/查询对接手册（对外契约）
→ 字段契约、issue、spec
→ 中信/平安原始 Word 协议
→ 旧项目代码（只作参考）
```

旧项目不得作为兼容基线。不得因为旧 DTO 存在字段，就把该字段加入当前活动契约。

### 1.2 四种能力状态

| 状态 | 判断依据 | 对外行为 |
|---|---|---|
| 已实现 | Registry 有复合键，Handle 有真实报文、网关调用和响应映射 | 调用真实银行能力 |
| 明确不支持 | 当前银行未注册该 capability | `F200002 CAPABILITY_NOT_SUPPORTED` |
| 适配器未接入 | 已注册挡板，入口显式抛 `ADAPTER_NOT_READY` | `F200003 ADAPTER_NOT_READY` |
| 仅开发示例 | 本文用于说明扩展步骤，不在当前 Registry 中 | 不得写入支持矩阵 |

`FrontCapability` 枚举中存在某值，不等于银行已经支持；Registry 中的
`(BankCode, FrontCapability)` 才是运行时事实。

---

## 2. 模块边界

| 模块 | 允许内容 | 禁止内容 |
|---|---|---|
| `catering-common-core` | `R`、`FrontErrorCode`、`FrontException`、跨模块常量、银行协议字段 key 常量 | Controller、Handle、银行协议 DTO、HTTP、加密实现 |
| `catering-api-front` | Feign API、请求/响应 DTO、枚举、Bean Validation、`FrontSpecialDataAssembler` | Router、Registry、数据库、HTTP、银行运行时实现 |
| `catering-front` | Controller、Application Service、LiteFlow、Router、Registry、Handle、Gateway、银行协议、配置、持久化、异常与日志 | 再建 `api/common/service` 子模块，复制公共返回体系 |
| `catering-common-feign` | 请求头转发、`RequestContext` 注入、`BaseDataRequestBodyAdvice` | 具体银行业务逻辑 |

依赖方向固定为：

```text
catering-front ──→ catering-api-front ──→ catering-common-core
       └───────────────────────────────→ catering-common-core

catering-common-core 不能反向依赖 API 或 Front 实现。
```

关键源码入口：

| 目的 | 源码入口 |
|---|---|
| 交易 API | `catering-api/.../FrontTransApi.java` |
| 查询 API | `catering-api/.../FrontQueryApi.java` |
| 中信不明来款专项 API | `catering-api/.../CiticUnidentifiedRemittanceApi.java` |
| 请求/响应 | `catering-api/.../model/request`、`model/response` |
| specialData 标准组装 | `catering-api/.../assemble/FrontSpecialDataAssembler.java` |
| 交易应用服务 | `catering-front/.../application/FrontTransApplicationService.java` |
| 查询应用服务 | `catering-front/.../application/FrontQueryApplicationService.java` |
| 中信不明来款专项应用服务 | `catering-front/.../application/CiticUnidentifiedRemittanceApplicationService.java` |
| LiteFlow | `catering-front/src/main/resources/liteflow/front-flow.xml` |
| 路由与注册 | `catering-front/.../route` |
| Handle SPI | `catering-front/.../handle` |
| 中信实现 | `catering-front/.../channel/citic` |
| 中信不明来款专项 Channel | `catering-front/.../channel/citic/unidentified` |
| 平安实现 | `catering-front/.../channel/pingan` |
| 钱包公共网关 | `catering-front/.../channel/gateway` |
| 租户银行配置 | `catering-front/.../config` |
| 渠道流水 | `catering-front/.../domain`、`mapper`、`service` |
| 分库算法 | `catering-front/.../sharding/TenantDataSourceShardingAlgorithm.java` |

---

## 3. 当前业务能力

### 3.1 交易能力

| Front API | Capability | 中信 `zxegj` | 平安 `pajzb` |
|---|---|---|---|
| `transfer` | `TRANSFER` | 已实现，`/transfer`，`bizFunc=27` | 已实现，`/transfer`，`bizFunc=01` |
| `transferAuth` | `TRANSFER_AUTH` | 明确不支持 | 已实现，`/transfer`，`bizFunc=45` |
| `resendTransferAuthCode` | `TRANSFER_AUTH_CODE_RESEND` | 明确不支持 | 已实现，`/gen-auth-code`，`bizFunc=26` |
| `consume` | `CONSUME` | 已实现，复用转账产品 `bizFunc=27` | 已实现，复用会员间交易 `bizFunc=01` |
| `refund` | `REFUND` | 已实现真退款，`/refund`，`bizFunc=23` | 已实现真退款，`/refund`，`bizFunc=02` |
| `withdraw` | `WITHDRAW` | 已实现，`/withdrawal`，`bizFunc=26` | 已实现，`/withdrawal`，`bizFunc=01`，成功为受理态 |
| `platformPay` | `PLATFORM_PAY` | 已实现，`bizFunc=2041` | 明确不支持 |
| `platformReceive` | `PLATFORM_RECEIVE` | 已实现，`bizFunc=2042` | 明确不支持 |

交易成功状态不是完全一致：中信大多数同步成功映射 `SUCCESS`；平安提现和退款同步成功映射
`ACCEPTED`，后续应通过交易状态查询确认终态。

### 3.2 查询能力

| Front API | Capability | 中信 | 平安 |
|---|---|---|---|
| `queryAccountStatus` | `ACCOUNT_STATUS_QUERY` | 已实现，`2058` | 适配器未接入，固定 `F200003` |
| `queryAccountBalance` | `ACCOUNT_BALANCE_QUERY` | 已实现，`35/36/46` | 适配器未接入，固定 `F200003` |
| `queryTransactionStatus` | `TRANS_STATUS_QUERY` | 已实现，`74` | 已实现，按原交易分流 `02/03/04` |
| `queryPlatformTransactionDetails` | `PLATFORM_TRANS_DETAIL_QUERY` | 已实现，`25` | 已实现，分流 `6050/6048` |
| `queryTransactionDetails` | `TRANS_DETAIL_QUERY` | 已实现，`24` | 已实现，`6073` |

不得启用 `PingAnQueryHandle` 中账户状态/余额挡板后的不可达草稿。收到新的明确需求后，应重新核对
平安协议并独立设计，而不是删除 `pendingIntegration()` 就宣称完成。

### 3.3 中信不明来款专项能力

中信不明来款属于任务明确裁决的特殊能力，已提供独立 API，不加入通用 `FrontCapability`，也不经过
Transaction/Query Router、Registry 或 LiteFlow。这样可避免把仅中信存在的业务字段提升为跨银行模型。

| 专项方法 | 对外路径 | 银行接口 | 固定协议 |
|---|---|---|---|
| `queryPages` | `/front/v1/citic/unidentified-remittances/pages` | `query-trans-details` | `bizFunc=2033/chnlNo=0010` |
| `process` | `/front/v1/citic/unidentified-remittances/process` | `refund` 或 `recharge` | 退款 `2025`；重新匹配/实时清分 `2023` |
| `queryStatus` | `/front/v1/citic/unidentified-remittances/status` | `query-trans-status` | `bizFunc=2087/chnlNo=0010` |

专项调用链固定为：

```text
CiticUnidentifiedRemittanceApi
→ CiticUnidentifiedRemittanceController
→ CiticUnidentifiedRemittanceApplicationService
→ TenantBankConfigProvider（当前基线；目标替换为 TenantBankConfigLoader）
→ CiticUnidentifiedRemittanceChannel
→ RequestMapper / ResponseMapper
→ BankWalletGateway
```

设计边界：

- 请求 DTO 直接继承 `BaseRequest`，复用 `tenantId/clientId/platformCode/dataSourceId` 注入与租户配置回填；
- 请求和返回均为全字段强类型 DTO，不使用 `FrontRequest`、`FrontBaseResult` 或 `specialData`；
- `appId/appKey/url/mchntId/mchntMbrId/bizFunc/chnlNo` 只在 Front 内部获取或固定；
- 银行协议以《中信E管家产品V2_不明来账》专项文档为最终基线，lsym UAT 用于核对实际调用形态；
- 综合文档的 `recharge+24/query-trans-status+123` 不属于该实现，禁止混用；
- 列表账号和户名按银行原始值返回；调用方不得记录这些敏感字段明文；
- 处理与状态查询必须复用列表原行定位字段，`2087` 使用 `transJrno/transDate`，不使用处理请求的 `frontSsn`。

对接细节见 [27-中信不明来款业务接入手册](27-中信不明来款业务接入手册.md)。

---

## 4. 当前已提交基线调用链（P0 对照）

下图描述跨银行通用交易/查询能力；中信不明来款使用 §3.3 的专项调用链。

```mermaid
flowchart LR
    A["业务上游 / Feign"] --> B["Front API Controller"]
    B --> C["Application Service"]
    C --> D["FrontFlowContext"]
    D --> E["LiteFlow 请求校验"]
    E --> F["Transaction / Query Router"]
    F --> G["Registry: BankCode + Capability"]
    G --> H["BankCapabilityHandle"]
    H --> I["AbstractBankHandle.prepareContext"]
    I --> J["TenantBankConfigProvider"]
    J --> K["BankRequestContext"]
    K --> L["银行 TransHandle / QueryHandle"]
    L --> M["BankWalletGateway"]
    M --> N["银行 WalletHttpClient"]
    N --> O["钱包 / 银行"]
    O --> P["ResponseChecker + 结果归一化"]
    P --> Q["R<T> 或 TableDataInfo<T>"]
```

### 4.1 外部两段式请求

```json
{
  "baseData": {},
  "specialData": {}
}
```

- `baseData`：跨银行公共强类型业务字段。
- `specialData`：当前银行、当前能力的动态协议字段，key 使用当前 Front 契约规定的原始字段名。
- 对外请求禁止出现 `accountConfig`、`bizFunc`、`chnlNo`、钱包路径、密钥或银行静态配置。

### 4.2 内部三段式上下文

```text
BankRequestContext
├─ baseData
├─ specialData
└─ accountConfig
   ├─ appId / appKey / url / mchntId / mchntMbrId
   └─ accountSpecialData
```

`specialData` 与 `accountSpecialData` 不能合并：前者来自单次业务请求；后者由 Front 按租户和银行加载。
禁止共享引用、`putAll`、互相覆盖或向业务上游返回完整账户配置。

### 4.3 请求头注入

`tenantId/clientId/platformCode/dataSourceId` 的标准链路：

```text
FeignRequestInterceptor
→ HTTP header
→ RequestContextInterceptor
→ RequestContext(ThreadLocal)
→ BaseDataRequestBodyAdvice
→ FrontRequest.baseData
```

`storeId` 是 Front 请求体自身必填字段。业务异步线程若没有原 HTTP 上下文，必须显式建立正确的
`RequestContext`，不能让四个定位字段变为空。

---

## 5. LiteFlow、路由与执行器

> 本节首先记录当前已提交基线。全量迁移后的 13 条目标链固定为
> `THEN(frontValidate, tenantResolve, bankRoute)`，使用两层 Slot 和
> `BankRouteNode → BankCapabilityRegistry → CiticTransferCapability`；不得继续复制下述旧节点层级。

当前 `front-flow.xml` 有 13 条具名链：8 条交易、5 条查询。每条链复用同一组节点：

```text
交易：frontRequestValidate
   → tenantBaseConfigResolve
   → frontTransactionRoute
   → bankHandleContextPrepare
   → frontTransactionDispatch
   → frontResponseNormalize

查询：frontRequestValidate
   → tenantBaseConfigResolve
   → frontQueryRoute
   → bankHandleContextPrepare
   → frontQueryDispatch
   → frontResponseNormalize
```

`tenantBaseConfigResolve`（2026-08-20 增）是租户基础信息获取与缺省回填节点：每个
front api 请求都用 tenantId 从 `tenant_base_config` 一次查询取出
`clientId/platformCode/dataSourceId/supportBankConfig` 写入 Slot，并回填 baseData
缺失的 `clientId/platformCode/dataSourceId`（调用方最少只需传 tenantId；
显式传入优先）。`bankHandleContextPrepare` 加载银行账户配置时复用 Slot 中的
`supportBankConfig`，不再重复查询 `tenant_base_config`。

关键纪律：

- API 方法决定领域和固定 capability；调用方不能覆盖。
- Transaction、Query 分别进入独立 Registry。
- Registry 使用类型安全的 `(BankCode, FrontCapability)` 复合键。
- 重复注册在启动阶段失败，不能后注册覆盖前注册。
- Dispatch 只执行已经选中的 `BankCapabilityHandle`，不得再写 `switch(capability)`。
- `BankCapabilityDefinition.execute()` 要求返回非空，Handle 禁止返回 `null`。
- 可预期业务失败写入 Slot 并结束；系统异常继续抛出，由异常处理器收口。

新增能力通常不需要修改 Router；真正需要修改的是 API 契约、对应银行的能力定义和协议实现。

---

## 6. 当前基线的租户银行配置

> 下述 Provider/Assembler 是待迁移基线，不是新增代码模板。28/29 号目标只保留
> `TenantResolveNode → TenantBankConfigLoader → RemoteConfigServiceClient`；Loader 具体类直接查询并
> 扁平组装，只暴露 `loadTenantBaseInfo` 与 `loadBankAccountConfig`。中信不明来款 Application Service
> 同样改用该 Loader，不改变专项业务链。

`AbstractBankHandle.prepareContext()` 固定执行：

1. 从 `baseData.platformCode` 解析 `BankCode`。
2. 校验请求银行与当前 Handle 的 `bankCode()` 一致。
3. 调用唯一的 `TenantBankConfigProvider.load(tenantId, bankCode)`。
4. 组装 `TenantBankAccountConfig`。
5. 生成 `BankRequestContext`。

通用账户配置字段固定为：`appId/appKey/url/mchntId/mchntMbrId`。

| 银行 | 当前 `accountSpecialData` |
|---|---|
| 中信 | `default_role/default_fund_type/self_role/self_fund_type/self_dealType/self_store_no/self_store_id` |
| 平安 | `txnClientNo/mrchCode/stlAcctNo` |

新增银行时：

1. 在 `BankCode` 增加银行编码。
2. 新建 `XxxBankAccountConfigKeys`，只放真实配置原始 key。
3. 新建 `XxxBankAccountConfigAssembler extends AbstractBankAccountConfigAssembler`。
4. `bankCode()` 返回新银行；`assembleAccountSpecialData()` 只复制该银行白名单字段。
5. 不修改 `BankAccountConfigAssemblerRouter` 的中央分支；Spring 列表注入会自动注册。
6. 同一银行组装策略重复时必须启动失败。

---

## 7. 银行钱包网关

> 28 号目标中，Capability 直接调用 `BankWalletGateway.post` 这一唯一业务发送出口；Gateway 只再分派到
> 直接完成 HTTP 调用的银行 `BankWalletSender`，禁止 Sender 后继续增加 WalletHttpClient、Invoker、Facade
> 或 `BankSupport.invokeBank`。下文其余内容用于核对既有行为。

所有新增银行接口统一走：

```java
JSONObject response = walletGateway.post(
    bankCode(),
    API_NAME,
    requestJson,
    context.accountConfig(),
    metadata
);
```

五步 SOP：

1. `*ContractKeys` 定义实际使用的字段 key；`apiName/bizFunc/chnlNo` 等单接口固定值留在 Handle。
2. Handle 使用常量逐字段组装报文，禁止 `specialData.putAll()`。
3. 通过 `BankWalletGateway.post()` 发送。
4. 使用该银行 `ResponseChecker` 将原始响应映射为 `FrontErrorCode`。
5. 在对应 Handle 的 `capabilityDefinitions()` 注册精确能力。

不得重新建立 `SaasXxxInterService` 式的“每个银行接口一个公共方法”封装层，也不得为新银行再增加一层
业务 WalletSender；银行选择、连接和 HTTP 细节统一收口在现有 Gateway 内。

---

## 8. 返回、状态与异常

### 8.1 返回签名

| 类型 | 固定返回 |
|---|---|
| 交易 | `R<FrontTransResult>` |
| 授权码发送/重发 | `R<FrontTransResult>`（2026-08-21 起公用，`FrontTransferAuthCodeResult` 已删除） |
| 账户状态/余额/交易状态 | `R<具体结果>` |
| 两类明细 | `TableDataInfo<具体行>`，不得再包 `R` |

API、Controller、Application Service 三层签名必须一致；Controller 只透传。

### 8.2 两层成功语义

- 单条真实成功：`R.code=200` 且 `data.frontRespCode="200"`。
- 银行业务失败：顶层 `R.code=500`，同时保留 `data.frontRespCode/frontRespDesc`。
- 明细成功：`TableDataInfo.code=200`。
- 明细失败：`TableDataInfo.code=500`、`rows=[]`、`total=0`、`totalPage=0`。

### 8.3 统一错误码

| 错误码 | 含义 |
|---|---|
| `F100001` | 请求参数非法 |
| `F100003` | 租户银行配置不存在或未启用 |
| `F100004` | 租户银行配置与请求不一致 |
| `F200001` | 银行不支持 |
| `F200002` | 当前银行不支持该能力 |
| `F200003` | 银行适配器尚未完成接入 |
| `F300001` | 相同业务订单渠道交易已存在 |
| `F400001` | 钱包通信失败 |
| `F400002` | 钱包结果未知，必须查询确认 |
| `F400003` | 钱包响应格式错误 |
| `F400004` | 银行拒绝交易 |
| `F400005` | 钱包平台拒绝请求 |

钱包 HttpClient 纪律（2026-08-20 起，中信/平安对称）：响应体完整读取并记录
`wallet_response_received` 日志后，资源关闭等收尾异常不得丢弃银行结果（仅告警，
继续解析返回）；响应体开头 BOM 去除后再解析；`JSONObject.parse` 独立捕获
`JSONException` 映射 `F400002`。银行业务失败时 `frontRespDesc`/`R.msg` 覆写为银行
原始错误描述原文（`sysRespDesc` > `sysRespCode` > `errInfo` > `errCode`，
如 `[JU005]用户编号不存在`），分页失败 `msg` 同规则；`frontRespCode` 保持 Front
统一码。
| `F900001` | Front 内部异常 |

原始 `errCode/sysRespCode` 不能直接作为 Front 错误码。

---

## 9. 渠道流水、幂等与分库

### 9.1 当前 10 张交易表

| 银行 | 表对应业务 |
|---|---|
| 中信 | transfer、consume、refund、withdraw、platformPay、platformReceive |
| 平安 | transfer、consume、refund、withdraw |

平安 `TRANSFER_AUTH` 和 `TRANSFER_AUTH_CODE_RESEND` 共用平安转账表，通过 `capability` 区分。
平安转账表另含 `auth_type` 列（2026-08-21 用户裁决新增，`VARCHAR(8) DEFAULT NULL`，位于
`capability` 之后）：仅授权两能力行写入 AuthType 枚举名（SMS/APP，INIT 即定型、缺省 SMS），
普通转账行与存量历史行为 NULL（NULL 即代表 SMS-only 历史时期）；不加索引。

### 9.2 生命周期

```text
检查当前业务表重复记录
→ INSERT INIT
→ UPDATE SENDING
→ 调银行
→ UPDATE SUCCESS / ACCEPTED / FAILED / UNKNOWN
```

查重键为当前银行、当前业务表内的
`tenant_id + biz_order_no + biz_sub_order_no`。当前 `synchronized` 只保护单实例窗口，跨实例 report
查重尚未接入；不得在文档中写成分布式强幂等。

### 9.3 分库与分区

- ShardingSphere-JDBC STANDARD。
- 分片键：`data_source_id`。
- `dataSourceId="2"` 路由到 `ds_2`。
- 缺失或目标数据源不存在时立即失败，禁止默认进入 `ds_0`。
- 不使用 `@DS`、`DynamicDataSourceContextHolder`、`HintManager`。
- 表分区：`LINEAR KEY (tenant_id, store_id) PARTITIONS 30`。

DDL 变更必须联动 Entity、VO、Mapper XML、Mapper、Service、Handle、列名常量、协议常量、最终 DDL
和字段目录；不能只改 SQL 或只改 Java。

---

## 10. 后续开发标准流程

> 当前执行 28/29 号全量结构迁移，但不新增银行或改变能力支持状态。

### 10.1 新增银行

1. 核对真实银行协议、签名、加密、成功码和错误语义。
2. 增加 `BankCode`。
3. 增加账户配置 key、配置组装策略。
4. 增加银行 `BankWalletSender` 实现，并在该实现中直接完成 HTTP 调用，不再委托第二层 Client。
5. 增加银行 `ResponseChecker`、序列号和加密组件。
6. 按实际支持能力实现 `BankTransHandle` / `BankQueryHandle`。
7. 每项能力在 `capabilityDefinitions()` 中单独注册。
8. `FrontSpecialDataAssembler` 新增银行组装实现和工厂 case。
9. 只为真实交易能力增加渠道表；不支持能力不建空表。
10. 同步能力矩阵、对接手册和联调案例。

### 10.2 新增交易或查询能力

1. 明确它属于 Transaction 还是 Query；不要靠 capability 名称推断领域。
2. 在 API 模块增加强类型请求/响应和 API 方法。
3. API 方法内部固定新的 `FrontCapability`。
4. 明确 `specialData` 白名单、字段来源、必填条件、格式、单位和敏感级别。
5. 为支持银行增加能力定义和 Handle 方法；不支持银行不注册。
6. 增加 LiteFlow 具名链，但复用公共节点。
7. 明确单条或分页返回，保证全链签名一致。
8. 交易能力补齐渠道流水和状态更新；纯查询不新建交易流水。
9. 增加联调示例与完成标准。

### 10.3 新增或完善银行账户功能

账户状态、余额、开户、绑卡、账户维护等功能开发前先回答：

- 是查询还是维护；是否需要独立 Account 领域 Registry。
- 公共字段能否进入强类型 `baseData`，哪些必须留在银行 `specialData`。
- 哪些是租户静态账户配置，必须来自 `accountConfig`。
- 银行响应哪些字段有跨银行公共语义，哪些只能进入响应白名单 `specialData`。
- 是否产生可审计流水；若产生，使用哪类表和状态机。
- 同步成功是否代表终态。

现有账户查询属于 Query 领域。后续账户维护能力如果形成独立领域，应新增独立 Account Registry，不能把
它塞进 Transaction/Query 后再用 capability 猜类型。

---

## 11. 已提交基线案例：中信账户状态查询（historical template）

以下代码来自当前已提交路径，用于 P0 理解业务行为；其 Handle/Registry 结构不是 28 号新能力模板。

### 11.1 注册能力

```java
@Override
public List<BankCapabilityDefinition<BankQueryHandle>> capabilityDefinitions() {
    return List.of(
        BankCapabilityDefinition.<BankQueryHandle>of(
            FrontCapability.ACCOUNT_STATUS_QUERY,
            (handle, context) -> handle.queryAccountStatus(
                context.requireBankRequestContext(AccountStatusQueryData.class)))
        // 同一 Handle 的其他真实查询能力省略
    );
}
```

注册后 `QueryHandleRegistry` 自动建立
`(BankCode.CITIC, FrontCapability.ACCOUNT_STATUS_QUERY)`，Router 无需新增 `if/switch`。

### 11.2 组装业务 `specialData`

```java
FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();
assembler.setPlatformCode(BankCode.CITIC.getCode());
assembler.setCapability(FrontCapability.ACCOUNT_STATUS_QUERY);
assembler.newPay().setBankEAccountId(accountNo);

JSONObject specialData = assembler.assemble();
// 当前结果：{"acctNo":"..."}
```

### 11.3 Handle 真实实现

```java
@Override
public AccountStatusResult queryAccountStatus(
    BankRequestContext<AccountStatusQueryData> context) {

    String acctNo = requireSpecialData(
        context.specialData(), CiticAccountQueryContractKeys.ACCOUNT_NO);

    CiticQueryAcctInfoRequest request =
        buildAcctInfoRequest(context, BIZ_FUNC_ACCOUNT_STATUS, acctNo);

    JSONObject response =
        invokeQuery(context, API_QUERY_ACCT_INFO, request);

    AccountStatusResult result = new AccountStatusResult();
    result.setAccountId(acctNo);
    applyResponse(response, result);
    if (isSuccess(response)) {
        result.setAccountStatus(
            response.getString(CiticAccountQueryContractKeys.RESPONSE_STATUS));
    }
    return result;
}
```

这段实现体现的固定规则：

- 动态账户号来自 `specialData`，租户静态配置来自 `accountConfig`。
- `bizFunc` 和 API 路径由 Handle 固定，调用方不能传。
- 发送通过公共 Gateway。
- 银行原始响应先经 ResponseChecker，再写公共结果。
- 结果对象非空，失败也必须有明确 Front 错误码。

### 11.4 新银行复制此模式时必须替换的内容

- 银行编码和 `capabilityDefinitions()` 注册主体。
- 该银行协议 request DTO、字段常量、加密和 apiName。
- 账户配置中该银行真实需要的字段。
- ResponseChecker 的成功码和错误映射。
- 账户状态归一化规则。

不得复制中信的 `2058`、字段名或状态值到其他银行。

---

## 12. 上游 `consume` 接入骨架现状

`catering-consume` 已存在：

- `SpecialDataAssembleCheck` 模板；
- `Consume/Transfer/Refund/Withdraw/TransferAuth/TransferAuthCodeResend/DeductionAssembleCheck`；
- `TransSlot.assembledSpecialData`。

但截至 2026-08-19：

- 各子类 `buildRequest()` 仍显式抛出 `BaseException("TODO: ...数据源待账户体系定型后接入")`；
- 在 `catering-consume` 资源规则中未发现这些 check 的挂接；
- 未发现 `catering-consume` 对 `FrontTransApi` 的正式调用点。

因此这些类是“实际接入落点骨架”，不是已完成的上游对接。后续完成时应：

1. 从现有账户/企业 check 结果取得标准账户数据。
2. 填充 `FrontSpecialDataAssembler`。
3. 把 `assemble()` 结果写入 `TransSlot.assembledSpecialData`。
4. 在调用 Front 之前挂入对应 LiteFlow 链。
5. 组装强类型 `FrontRequest` 并调用 `FrontTransApi`。
6. 同时处理顶层 `R.code`、`data.frontRespCode` 和交易状态。

不得在 `consume` 中绕过 Assembler 手写两家银行的协议 key 分支。

---

## 13. 强制开发规则

### 13.1 必须遵守

- 金额全部使用 `Long` 人民币分，禁止浮点数。
- `specialData` 逐键白名单映射，禁止整体 `putAll` 到银行报文。
- 中信不明来款按专项强类型 DTO 显式映射，不得为了复用通用链重新包装成 `specialData`。
- 银行协议 DTO 留在 `catering-front/channel/{bank}/{capability}`，与使用它的能力相邻；真实跨能力 DTO 才进入银行 `common`。
- 银行调用统一直接走 `BankWalletGateway.post`，Gateway 只再分派到直接执行 HTTP 的银行 Sender，
  不增加 Sender 后的 WalletHttpClient/Invoker/Facade 包装层。
- 路由只允许 `BankRouteNode → BankCapabilityRegistry → BankCapability`，按
  `(BankCode, FrontCapability)` 定位，不增加 Router、Dispatch 或第二份能力矩阵。
- Slot 只允许 `FrontBaseSlot ← FrontTransSlot/FrontQuerySlot` 两层，禁止新业务 Context。
- 能力代码按真实执行顺序展开，允许少量重复；禁止 Handle 继承链和 BankSupport God class。
- 不支持、未接入、结果未知要使用不同错误或状态明确表达。
- 渠道表字段命名使用 `pay/rec/withdraw/bank_card`，禁止 `payer/payee`。
- Entity ↔ VO/BO 转换使用项目 mapstruct-plus 范式。
- 配置和分片缺失立即失败，禁止兜底到其他租户或数据源。
- 敏感字段、密钥、验证码、完整账号/卡号/手机号/证件号/姓名不得明文写日志、异常或响应；若历史代码仍打印原始报文，后续开发不得复制该模式。

### 13.2 禁止事项

- 返回 `null`、空壳或模拟成功。
- 用反向转账冒充退款。
- 在 Controller 或 Application Service 写银行判断、功能码和报文组装。
- 为结构复用建立业务父类、多层 helper、Router/Dispatch 或 BankSupport God class。
- 让调用方传 `bizFunc/chnlNo/url/appKey/accountConfig`。
- 直接返回银行 DTO、完整 reserve 或原始错误码。
- 将中信不明来款注册为跨银行 `FrontCapability`，或套用通用 `FrontRequest` 两段式模型。
- 因 Word 文档存在字段就一次性扩展常量和 DTO。
- 新建统一渠道交易表、动态表名或跨业务公共 Mapper。
- 交易超时后自动重发；结果未知必须查询确认。
- 未获授权时新增/运行测试或执行编译。

---

## 14. Definition of Done

### 14.0 全量扁平化迁移完成标准

- [ ] 中信 11 个、平安 11 个通用能力与 13 条链全部迁移。
- [ ] `catering-api-front` 零 diff，domain/mapper/DDL/不明来款未改。
- [ ] `flow` 只按 slot/node/route 分组，Slot 继承严格两层。
- [ ] 所有银行能力按 `channel/{bank}/{capability}` 分包；银行 common 只有真实复用。
- [ ] 任一 Capability 均可按顺序读完本能力主流程。
- [ ] 无新增业务 Context、Handle 父类、Router、Dispatch、BankSupport 或多层 Wallet Client。
- [ ] 租户配置调用链固定为 `TenantResolveNode → TenantBankConfigLoader → RemoteConfigServiceClient`；
      旧 `Provider → AssemblerRouter → Assembler` 及抽象/继承层级已删除，Loader 直接查询并扁平组装。
- [ ] 钱包业务发送只直接调用 `BankWalletGateway.post`。
- [ ] Capability 业务日志位于真实步骤附近；最终 Sender 唯一记录钱包请求/响应/失败，无重复报文日志。
- [ ] 本轮未新增/运行测试、未执行编译；静态 review 结果未被表述为测试或编译通过。
- [ ] 旧 Context/Router/Dispatch/Handle 已删除，完成后等待用户 review。

### 14.1 新银行完成标准

- [ ] `BankCode`、账户配置组装器、WalletSender、ResponseChecker 已实现。
- [ ] 每个宣称支持的能力都有 Registry 复合键和真实 Gateway 调用。
- [ ] 不支持的能力未注册，待接入能力明确返回 `F200003`。
- [ ] API DTO 和银行协议 DTO 位于正确模块。
- [ ] specialData 与 accountSpecialData 未混用。
- [ ] 成功、拒绝、超时、响应格式错误均有明确映射。
- [ ] 文档没有把开发示例写成已支持能力。

### 14.2 新账户功能完成标准

- [ ] 领域归属、API 返回类型和 capability 已明确。
- [ ] 请求/响应每个字段均有类型、来源、格式、单位、必填和空值说明。
- [ ] 银行动态字段、租户静态配置和 Front 固定值三类来源已分离。
- [ ] 注册、路由、上下文装配、网关、响应检查链路完整。
- [ ] 账户状态/余额等银行原值已有明确归一化策略或明确保留为 specialData。
- [ ] 不返回原始敏感报文，不模拟银行成功。

### 14.3 中信不明来款专项能力完成标准

- [x] 独立 API、Controller、Application Service、Channel 和银行协议 DTO 边界完整。
- [x] `2033/2025/2023/2087` 与 `chnlNo=0010` 按专项协议固定，不接受调用方覆盖。
- [x] 请求和返回使用强类型全字段 DTO，不包含 `specialData`。
- [x] `tenantId` 必填，其他租户公共字段支持上下文注入和 `tenant_base_config` 回填。
- [x] 退款、重新匹配、实时清分、客户账条件必填和状态枚举均有测试。
- [x] `acctNo/userId` 上送前 SM2 加密；列表账号/户名按银行原值返回但不写入日志。
- [x] `2087` 明确使用列表 `transJrno/transDate` 定位，不误用处理请求 `frontSsn`。
- [x] Maven Reactor、Checkstyle 和专项单元测试通过。

### 14.4 提交前静态核验

```bash
git status --short
rg "FrontCapability\.目标能力" catering-modules/catering-front catering-api/catering-api-front
rg "BankCapabilityDefinition" catering-modules/catering-front/src/main/java/com/chinaums/front/channel
rg "walletGateway\.post" catering-modules/catering-front/src/main/java/com/chinaums/front/channel
rg "return null|putAll\(" catering-modules/catering-front/src/main/java/com/chinaums/front
```

编译和测试命令仅在用户明确授权后执行；未授权时交付说明必须写明“未编译、未运行测试”。
