# Front 代码开发约束

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：current
> 生效日期：2026-08-04
> 适用模块：`catering-api-front`、`catering-front` 及其使用的 `catering-common-core`
> 约束级别：后续 Front 代码开发必须遵守

---

## 1. 核心结论

1. `catering-api-front` 只保存 API 契约、请求响应模型、常量和枚举。
2. `catering-front` 保存全部功能实现，不再建立 `api/common/service` 子模块。
3. 跨模块公共返回、Front 错误码和 Front 公共异常统一放在 `catering-common-core`。
4. 所有对外 API 必须直接返回 `R<具体结果>`，禁止增加 `FrontResponse` 中间包装层；例如交易返回
   `R<FrontTransactionResult>`。
5. Controller 负责包装 `R`；Application、Router、Handle 不返回 `R`。
6. 业务可预期异常统一抛出 `FrontException`，由 `FrontExceptionHandler` 收口。
7. 不支持、未接入和结果未知必须显式表达，禁止返回 `null` 或模拟成功。
8. 对外请求固定为 `baseData + specialData` 两段；进入 Handle 后由统一父类增加
   `tenantBankConfig`，形成三段式内部上下文。
9. 租户银行配置只能由 Front 使用 `tenantId + bankCode` 查询，禁止由调用方传入或由具体银行
   Handle 各自重复查询。
10. 银行账户配置必须按“通用强类型对象 + 银行 `accountSpecialData` 策略”组装；
    交易 `specialData` 与账户 `accountSpecialData` 必须完全分离。

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
- Bean Validation 和 OpenAPI 契约注解。

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
- LiteFlow、渠道流水、幂等、状态机；
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

---

## 3. 运行时层级结构

```text
Feign/API 接口
→ Controller
→ Application Service
→ Router
→ Bank Handle
→ channel/{bank} 协议客户端
→ 银行或钱包平台
```

异常统一沿调用栈抛出，由 `FrontExceptionHandler` 转换为 `R<FrontBaseResult>`。

### 3.1 Controller

Controller 必须：

- 实现 `catering-api-front` 中的 API 接口；
- 接收已经定义好的强类型 `FrontRequest<T>`；
- 调用 Application Service；
- 使用 `R.ok(applicationService.xxx(...))` 包装正常返回。

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
- 调用 Router；
- 能力校验；
- 调用已选 Handle 的 `prepareContext()` 完成内部上下文装配；
- 幂等、渠道流水和状态机协调；
- 记录业务分派、结果与耗时日志。

Application Service 返回确定类型的 `FrontBaseResult` 子类，禁止返回 `R`。

Application Service 禁止：

- 写死中信或平安功能码；
- 直接组装银行报文；
- 直接执行签名、加密或 HTTP 调用；
- 使用 `instanceof` 判断具体银行实现。

### 3.3 Router 与 Registry

Router 只负责根据 `BankCode/platformCode` 选择银行 Handle。

Registry 必须：

- 通过构造器注入 `List<Handle>`；
- 启动时创建不可变映射；
- 发现同一 Registry 内同一银行重复实现时立即启动失败；
- 未找到银行时抛出 `FrontException(FrontErrorCode.BANK_NOT_SUPPORTED)`；
- 记录注册、重复注册、查找失败和路由结果日志。

禁止使用 `BeanPostProcessor` 隐式注册，也禁止静默覆盖已有 Handle。

Transaction Handle 与 Query Handle 是两个 Registry，同一银行分别注册一次不属于重复。

### 3.4 Handle

Handle 负责：

- 声明银行编码；
- 声明能力状态；
- 通过统一父类加载并校验当前租户的银行账户配置；
- 解析本银行、本能力的 `specialData`；
- 选择功能码、路径和协议；
- 组装银行请求；
- 调用银行客户端；
- 把银行结果转换为确定类型的 `FrontBaseResult` 子类。

Handle 方法必须使用明确请求和明确返回类型，禁止使用无法约束的 `<T> T`。

能力状态处理：

- `SUPPORTED`：进入真实银行处理；
- `UNSUPPORTED`：抛出 `CAPABILITY_NOT_SUPPORTED`；
- `PENDING_INTEGRATION`：抛出 `ADAPTER_NOT_READY`；
- 非法或未知状态：记录错误并抛出明确异常。

### 3.5 Handle 统一父类与配置端口

中信、平安的 Transaction/Query Handle 必须继承统一的 `AbstractBankHandle`。统一父类负责：

1. 使用当前 Handle 的 `bankCode()`，禁止信任调用方传入另一个银行编码；
2. 通过 `TenantBankConfigProvider.load(tenantId, bankCode)` 查询配置；
3. 校验配置存在、已启用、内容非空；
4. 校验配置中的 `tenantId/bankCode` 与请求一致；
5. 组装三段式 `BankRequestContext`；
6. 记录配置加载开始、完成、失败日志，但不记录配置内容。

配置端口和快照固定放在 `catering-front`：

```java
public interface TenantBankConfigProvider {
    TenantBankConfigSnapshot load(String tenantId, BankCode bankCode);
}
```

```text
TenantBankConfigSnapshot
├─ tenantId
├─ bankCode
├─ configVersion
├─ enabled
└─ accountConfig: TenantBankAccountConfig
   ├─ appId
   ├─ appKey
   ├─ url
   ├─ mchntId
   ├─ mchntMbrId
   └─ accountSpecialData: JSONObject
```

只允许存在一个 `TenantBankConfigProvider` 实现；多个实现必须在启动阶段失败。当前真实配置系统协议
尚未确定时，可以只保留端口、不提供伪造配置实现；一旦某项银行能力标记为 `SUPPORTED`，部署环境
必须提供真实 Provider。

具体银行 Handle 禁止：

- 直接调用租户配置服务；
- 自行用 `tenantId/storeId` 或其他组合重新定位配置；
- 接受调用方通过 `specialData` 覆盖配置；
- 输出完整配置或密钥字段日志。

### 3.6 银行账户配置组装

账户配置组装固定使用以下分层：

```text
BankAccountConfigAssemblerRouter
└─ AbstractBankAccountConfigAssembler       # 只组装跨银行通用字段
   ├─ PingAnBankAccountConfigAssembler       # 只组装平安 accountSpecialData
   └─ CiticBankAccountConfigAssembler        # 只组装中信 accountSpecialData
```

通用对象只包含 `appId/appKey/url/mchntId/mchntMbrId`。
`transSsn` 由具体银行 Handle 按银行规则生成，`transTime` 是每笔请求运行时字段，
`bizFunc/chnlNo` 由具体银行和能力使用常量确定，禁止将这四个字段固化为账户配置。

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
| `FrontBankConfigQueryKeys` | 配置查询原始 key：`zx_bank_config`、`pa_bank_config` |
| `FrontBankAccountConfigKeys` | `appId/appKey/url/mchntId/mchntMbrId` |
| `PingAnBankAccountConfigKeys` | `txnClientNo/mrchCode/stlAcctNo` |
| `CiticBankAccountConfigKeys` | 中信 7 个 `accountSpecialData` 字段 |
| `FrontBankRequestConstants` | 钱包公共请求字段名及 `transSsn/transTime/bizFunc/chnlNo` 来源约束 |
| `FrontBankResponseConstants` | 钱包原始响应字段、平台成功标志、中信 5 位和平安 6 位银行成功码 |
| `CiticTransferContractKeys` | 中信 transfer/consume 固定协议值、请求、reserve、响应特殊字段 |
| `PingAnTransferContractKeys` | 平安 transfer/consume 固定协议值、请求和 reserve 字段 |

配置查询 key 的常量名称只表达配置系统中的原始值，不在 `catering-common-core` 内绑定具体银行。
真实 `TenantBankConfigProvider` 接入时必须根据最终确认的银行与配置 key 对应关系显式选择，禁止根据
`zx/pa` 前缀自行推断。

策略路由必须通过构造器注入 `List<BankAccountConfigAssembler>` 建立不可变映射，
同一银行出现两个策略时必须启动失败，不得静默覆盖。组装日志只记录银行、策略、
结果和耗时，不得记录原始配置、`appKey`、`accountSpecialData` 内容。

### 3.7 `channel/{bank}`

银行差异实现统一放在对应银行包下：

```text
channel/citic
├─ CiticTransactionHandle
├─ CiticQueryHandle
├─ protocol
├─ config
├─ client
├─ mapper
└─ crypto

channel/pingan
├─ PingAnTransactionHandle
├─ PingAnQueryHandle
├─ protocol
├─ config
├─ client
├─ mapper
└─ crypto
```

银行协议 DTO 不得进入 `catering-api-front` 或 `catering-common-core`。

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

`baseData` 保存跨银行统一、可校验、可生成 OpenAPI 的强类型字段，包括：

- `tenantId`；
- `storeId`；
- `platformCode`；
- 当前业务通用字段。

禁止把银行私有字段放入 `baseData`，也禁止使用 `Object`、无约束 Map 代替已经确认的公共字段。

交易公共基础对象必须包含 `payStoreNo/payStoreId/recStoreNo/recStoreId` 两组收付款门店信息。
`amount/fee` 均使用 `Long` 保存人民币分，`amount` 必须大于 0，`fee` 不能小于 0；禁止使用浮点数
或在 Handle 内擅自转换为元。transfer/consume 必须提供双方 `accountId/memberId/name` 公共字段，
不得把这些已有公共语义的字段塞入 `specialData`。
单笔状态查询基础对象必须包含 `frontSsn/bizOrderNo/bizSubOrderNo`；其中 `bizOrderNo` 是业务主流水，
`bizSubOrderNo` 是业务子流水。

### 4.2 统一业务 Slot

Application Service 必须使用 `FrontFlowContext.from(request, capability)` 完成
`FrontRequest → FrontFlowContext` 转换。该 Context 固定承载：

```text
capability
baseData
specialData
tenantBankConfig
result
executionInfo
failure
```

`baseData/result` 在非泛型 Slot 中以公共父类型保存，组件必须通过
`requireBaseData/requireResult/requireBankRequestContext` 受控读取，禁止散落强制类型转换。
当前仅完成 Context 和执行阶段维护，尚未接入 LiteFlow 执行器、节点及规则链。后续 AI 必须复用
`FrontFlowContext`，禁止另建第二套 Slot。

### 4.3 `specialData`

`specialData` 使用 `JSONObject`，只保存“银行 + 能力”特有字段。

约束：

- 无特殊字段时传空对象；
- 后续按银行和能力定义 schema；
- 不得覆盖 `tenantId/platformCode/channelNo/bizFunc/path` 以及
  `txnClientNo/mrchCode/stlAcctNo` 等账户配置字段；
- 不得传密钥、私钥、完整银行配置；
- 日志不得直接打印完整内容。

transfer/consume 的已确认字段白名单、来源、单位和响应映射以
[06-transfer-consume字段契约](06-transfer-consume字段契约.md) 为准。没有进入该契约的银行字段，
不得凭旧代码猜测后直接透传。

### 4.4 Handle 内部三段式上下文

外部 `FrontRequest<T>` 只能有两段。完成路由和能力校验后，由 `AbstractBankHandle` 生成：

```java
public record BankRequestContext<T extends FrontBaseRequestData>(
    T baseData,
    JSONObject specialData,
    TenantBankConfigSnapshot tenantBankConfig) {
}
```

三段数据来源固定：

| 字段 | 来源 | 是否允许调用方传入 |
|---|---|---|
| `baseData` | `FrontRequest.baseData` | 是 |
| `specialData` | `FrontRequest.specialData` | 是 |
| `tenantBankConfig` | Front 配置 Provider | 否 |

`tenantBankConfig.accountConfig` 是强类型通用账户配置加银行 `accountSpecialData`。
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

record 组件使用类 JavaDoc 的 `@param` 逐项说明。`FrontFlowContext` 的每个字段还必须说明由谁写入、
由谁读取以及处于哪个阶段；非泛型 Slot 中的 `Object` 只能通过受控类型方法读取。新增字段没有注释时，
不得提交。

---

## 5. 返回对象约束

### 5.1 对外 API 返回

所有对外接口必须直接返回：

```java
R<具体结果>
```

例如：

```java
R<FrontTransactionResult>
R<TransactionStatusResult>
R<AccountBalanceResult>
R<FrontPageResult<TransactionDetailItem>>
```

禁止：

- 使用 `FrontResponse<T>` 再包装具体结果；
- 直接返回未使用 `R` 包装的具体结果；
- 直接返回银行响应 DTO；
- 返回 `Map<String, Object>`；
- 再创建一套 Front 专用顶层响应类替代 `R`；
- 返回 `null`。

### 5.2 两层语义

| 层级 | 职责 |
|---|---|
| `R.code/msg` | 工程统一调用结果，使用公共 `R.ok/R.fail` |
| `R.data` 的强类型字段 | Front 跨银行统一业务结果和 Front 错误码 |
| `R.data.specialData` | 当前银行、当前能力的特殊返回字段；由 `FrontBaseResult` 统一定义 |

`FrontBaseResult` 必须统一定义 `frontRespCode/frontRespDesc/specialData`。交易明细查询中，每条
`TransactionDetailItem` 还必须单独包含 `specialData`，承接该笔明细的银行 `reserveMap`；分页结果自身
继承的 `specialData` 只保存查询级银行扩展字段。

成功返回示意：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "frontRespCode": "F000000",
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
Application Service → FrontBaseResult 的确定子类
Controller          → R.ok(具体结果)
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
- `F000000` 只用于真实成功，禁止模拟成功。

当前编码分段：

| 范围 | 含义 |
|---|---|
| `F000000` | 成功 |
| `F1xxxxx` | 请求、配置和契约错误 |
| `F2xxxxx` | 银行、能力和适配状态错误 |
| `F3xxxxx` | 幂等和处理中状态 |
| `F4xxxxx` | 银行通信和结果错误 |
| `F9xxxxx` | Front 内部错误 |

当前钱包结果统一码：

| 错误码 | 统一说明 | 使用边界 |
|---|---|---|
| `F000000` | 成功 | 钱包平台和银行渠道均满足当前接口成功条件 |
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

以下可预期业务失败必须抛出 `FrontException`：

- 银行不支持；
- 能力不支持；
- 银行适配器未接入；
- 请求或配置不满足业务规则；
- 幂等冲突；
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

### 7.3 禁止事项

- 禁止用 `RuntimeException("字符串")` 表达已知业务失败；
- 禁止 catch 后忽略异常；
- 禁止 catch 后返回 `R.ok`；
- 禁止返回 `null`；
- 禁止把未接入能力伪造成成功；
- 资金交易超时或无响应不得直接重试，应进入 `UNKNOWN` 并通过查询确认。

---

## 8. 日志约束

必须记录：

- `tenantId`、`storeId`、`platformCode`、`capability`；
- Registry 注册结果和重复注册；
- Router 选择结果；
- Handle 类型和能力状态；
- Front 错误码、处理结果、耗时；
- 银行调用开始、结束、耗时和归一化状态；
- 租户银行配置加载开始、完成、失败及 `configVersion`；
- 未知异常服务端堆栈。

禁止记录：

- 完整 `specialData`；
- 完整 `accountSpecialData`；
- 租户完整银行配置；
- 密钥、私钥、签名原文；
- 完整卡号、手机号、证件号、短信验证码；
- 未脱敏的银行请求和响应报文。

日志异常级别：

- 正常开始、路由和完成：`INFO`；
- 可预期业务拒绝或未接入：`WARN`；
- 重复注册、非法状态、未知异常：`ERROR`。

---

## 9. 代码开发禁止事项

- 不复制旧项目的 `BeanPostProcessor` 路由注册；
- 不使用复合 Router Key；
- 不使用任意 `<T> T` 返回；
- 不把银行 DTO 放入 API 或 Common Core；
- 不把银行私有字段提升为公共字段；
- 不在业务请求中开放渠道号、功能码和请求路径；
- 不让具体银行 Handle 绕过 `AbstractBankHandle` 自行加载租户银行配置；
- 不把 `tenantBankConfig` 增加到对外 `FrontRequest`；
- 不静默覆盖重复银行 Handle；
- 不返回银行原始 DTO、原始错误码或敏感报文；
- 不返回 `null` 或模拟成功；
- 不在未确认字段时猜测银行协议。

---

## 10. 新增能力实施顺序

每新增一个 Front 能力，按以下顺序实施：

1. 确认业务语义及中信、平安支持状态；
2. 在 API 模块定义强类型请求、响应和能力枚举；
3. 确认 `specialData` schema；
4. 在 Handle SPI 增加明确方法；
5. 在具体银行 Handle 声明能力状态并实现；
6. 增加 Front 错误映射；
7. 增加全链路日志和脱敏；
8. 增加 API、Router、Handle、异常和序列化测试；
9. 更新能力矩阵、方法映射和本文档相关章节。

字段和协议未确认时，只允许创建 `PENDING_INTEGRATION` 骨架，不允许伪造银行请求或成功响应。

---

## 11. 提交前检查表

- [ ] 代码放在正确模块和 package；
- [ ] 依赖方向没有反转或循环；
- [ ] API 返回类型是 `R<具体结果>`，不存在 `FrontResponse` 中间包装层；
- [ ] `specialData` 由 `FrontBaseResult` 统一提供；
- [ ] Controller 只做入口和 `R` 包装；
- [ ] Application Service 不包含银行协议细节；
- [ ] Router 只按银行路由；
- [ ] Handle 请求和返回类型明确；
- [ ] 对外请求仍只有 `baseData/specialData` 两段；
- [ ] Handle 内部上下文包含由统一父类装配的 `tenantBankConfig`；
- [ ] 租户银行配置只按 `tenantId + bankCode` 查询且请求与配置一致；
- [ ] 账户通用配置已进入 `TenantBankAccountConfig` 强类型字段；
- [ ] 银行账户特定配置只进入 `accountSpecialData`；
- [ ] 交易 `specialData` 与账户 `accountSpecialData` 没有合并、共享引用或互相覆盖；
- [ ] 新增对象、字段、record 组件和枚举值均有业务注释；
- [ ] 银行账户配置组装策略按 `bankCode` 唯一注册；
- [ ] 具体银行 Handle 没有重复实现配置查询；
- [ ] 未接入/不支持没有返回 `null` 或模拟成功；
- [ ] 新错误码只添加到 `FrontErrorCode`；
- [ ] 已知业务失败只抛出 `FrontException`；
- [ ] 未知异常不会泄漏堆栈给调用方；
- [ ] 日志不包含完整 `specialData`、`accountSpecialData`、账户配置和敏感字段；
- [ ] 银行原始响应码没有直接作为 `R.code/frontRespCode`；
- [ ] `frontRespCode/frontRespDesc` 同时来自同一个 `FrontErrorCode`；
- [ ] 返回 `specialData` 只包含当前银行、当前能力的响应白名单字段；
- [ ] 如用户明确要求测试，请求、成功响应和异常响应契约已覆盖测试；
- [ ] 相关设计、能力矩阵和字段映射文档已更新。

当前骨架在最近一次模块、返回主体和异常迁移后按用户要求未执行编译或测试；后续获得允许时需按本检查表补充验证。
