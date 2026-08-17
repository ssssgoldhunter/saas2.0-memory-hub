# SaaS 2.0 Front 多银行渠道接口文档（外部业务系统用）

> 版本：v1.0
> 生效日期：2026-08-10
> 适用读者：接入 Front 的业务系统开发人员
> 关联项目：`catering-api-front`（Feign 接口契约）

---

## 1. 概述

Front 是 SaaS 2.0 的多银行渠道支付适配层，对内部业务系统提供统一交易和查询能力。当前支持：

| 银行 | 编码 | 能力 |
|---|---|---|
| 中信银行 | `zxegj` | 转账、消费、退款、提现、平台付款、平台收款、查询 |
| 平安银行 | `pajzb` | 转账、消费、退款、提现、短信鉴权转账、授权码发送、查询 |

业务系统通过 **Feign 客户端** 调用 Front 服务（服务名 `catering-front`）。

---

## 2. 公共请求结构

所有接口统一使用以下 JSON 结构：

```json
{
  "baseData": { ... },
  "specialData": {}
}
```

说明：

- `baseData`：**强类型对象**，保存业务系统公共字段（租户、门店、订单、金额等），
  每种交易/查询使用不同的 Java 类型；
- `specialData`：**JSONObject**，保存当前银行、当前接口特有的动态字段，
  key 使用 **银行协议原始字段名**。

### 2.0 specialData 组装工具类（推荐业务方使用，2026-08-17 起）

业务方**不需要手写协议键**：`catering-api-front` 提供实例工具类
`com.chinaums.front.api.assemble.FrontSpecialDataAssembler`，填银行无关的标准账户结构
（pay/rec/oriPay/oriRec + bankCard/auth），本地调用 `assemble()` 即得当前银行+能力的协议键明文
specialData，原样放入交易请求即可。用法与能力矩阵见
[15-交易额外数据标准化-spec](15-交易额外数据标准化-spec.md) §3/§4。

```java
FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();   // 每次组装新建,禁止复用
assembler.setCapability(FrontCapability.TRANSFER);
assembler.setPlatformCode("zxegj");
assembler.newPay().setBankEAccountId("…").setBankAccountName("…");       // @Data setter
JSONObject specialData = assembler.assemble();                          // → {"outAcctNo":…,"USER_D_NM":…,…}
```

注意：交易/查询 API 的 wire 契约不变，specialData 仍收协议键原文；直传协议键仍合法
（Handle `requireSpecialData` 逐键校验保留），工具类只是协议键的推荐产生方式。

### 2.1 公共定位字段

以下字段是所有 `baseData` 的基类 `FrontBaseRequestData` 统一包含：

| 字段 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| `tenantId` | String | 是 | 租户 ID | `"10001"` |
| `storeId` | String | 否 | 门店 ID | `"20001"` |
| `platformCode` | String | 是 | 银行编码，`zxegj` 或 `pajzb` | `"zxegj"` |
| `clientId` | String | 否 | 客户端 ID（自动注入） | `"web"` |
| `dataSourceId` | String | 是 | 数据源标识，由请求方在 baseData 中传入 | `"2"` |

| 注意：
| - `tenantId` / `clientId` / `platformCode` / `dataSourceId` 四个参数由 Feign 拦截器自动传递，
|   业务系统只需在请求头或 Feign 配置中正确设置；
| - 请求体中的 `baseData.tenantId` / `baseData.platformCode` / `baseData.dataSourceId` 必须由请求方传入，
|   `clientId` 由 Feign 拦截器自动注入，可不传。

### 2.2 公共交易业务字段

`BaseTransactionBusinessData` 包含以下交易公共字段：

| 字段 | 类型 | 必填 | 说明 | 最大长度 |
|---|---|---|---|---|
| `bizSystemCode` | String | 是 | 来源业务系统编码 | 32 |
| `bizTransactionType` | String | 是 | 业务交易逻辑类型 | 32 |
| `bizTransactionId` | String | 是 | 业务交易主记录 ID | 64 |
| `bizSubTransactionId` | String | 否 | 业务交易子记录 ID | 64 |
| `bizRequestNo` | String | 是 | 业务请求号 | 64 |
| `bizOrderNo` | String | 是 | 业务主订单号 | 64 |
| `bizSubOrderNo` | String | 否 | 业务子订单号 | 64 |
| `payStoreNo` | String | 否 | 付款门店编号 | 32 |
| `payStoreId` | String | 否 | 付款门店 ID | 32 |
| `recStoreNo` | String | 否 | 收款门店编号 | 32 |
| `recStoreId` | String | 否 | 收款门店 ID | 32 |
| `amount` | Long | 是 | 交易金额，**人民币分**，必须大于 0 |  |
| `fee` | Long | 否 | 手续费，人民币分，不能小于 0 |  |
| `currency` | String | 否 | 币种，默认 CNY | 3 |
| `businessDate` | String | 否 | 业务日期 yyyyMMdd | 8 |
| `businessTime` | String | 否 | 业务时间 HHmmss | 6 |
| `remark` | String | 否 | 业务备注 | 见各接口定义 |

| 关键约束：
| - 所有金额以 **人民币分** 为单位（Long 类型），禁止使用浮点数；
| - `amount` 必须大于 0，`fee` 不能小于 0；
| - `bizOrderNo` / `bizSubOrderNo` 用于业务关联和重复交易检查。

---

## 3. 公共响应结构

### 3.1 单条返回（交易、状态、余额）

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "frontRespCode": "200",
    "frontRespDesc": "交易成功",
    "frontSsn": "F2026081012345678901234567890",
    "frontStatus": "SUCCESS",
    "frontQueryId": "F2026081012345678901234567890",
    "frontRemark": null,
    "frontTransDate": "20260810",
    "frontTransTime": "123456",
    "specialData": {}
  }
}
```

| 顶层字段 | 说明 |
|---|---|
| `code` | **200** = 调用成功；非 200 = 调用失败（参数校验、系统异常等） |
| `msg` | 对应 `code` 的描述信息 |
| `data` | `FrontBaseResult` 子类，包含业务结果 |

| `data` 内字段 | 说明 |
|---|---|
| `frontRespCode` | **"200"** = 业务成功；非 "200" = 银行业务拒绝 |
| `frontRespDesc` | 业务结果描述 |
| `frontSsn` | Front 渠道流水号 |
| `frontStatus` | 交易状态：`SUCCESS` / `FAILED` / `PROCESSING` / `UNKNOWN` |
| `frontQueryId` | 查询标识（部分接口使用） |
| `frontTransDate` | Front 受理日期 yyyyMMdd |
| `frontTransTime` | Front 受理时间 HHmmss |
| `specialData` | JSONObject，银行特殊返回字段 |

| 判断逻辑：
| - `code == 200 && data.frontRespCode == "200"` → 业务成功
| - `code == 200 && data.frontRespCode != "200"` → 银行业务拒绝，以 `frontRespDesc` 为准
| - `code != 200` → 调用异常（参数错误、系统繁忙等）

### 3.2 分页返回（明细查询）

```json
{
  "code": 200,
  "msg": "查询成功",
  "total": 42,
  "rows": [
    { ... }
  ]
}
```

| 字段 | 说明 |
|---|---|
| `code` | 200 = 查询成功，500 = 业务失败 |
| `msg` | 查询结果描述 |
| `total` | 总记录数 |
| `rows` | 当前页数据列表 |

分页查询**不包 `R` 外层**，直接返回 `TableDataInfo` 对象。

---

## 4. 交易接口（8 个）

Feign 接口：`FrontTransactionApi`，服务名 `catering-front`，前缀 `/front/v1/transactions`

### 4.1 普通转账

**`POST /front/v1/transactions/transfer`**

**baseData 类型：** `TransferBusinessData`（继承 `BaseTransactionBusinessData`）

**specialData 字段：**

| key | 类型 | 必填 | 中信 | 平安 | 说明 |
|---|---|---|---|---|---|
| `outAcctNo` | String | 是 | 付款账号 | 付款账号 | 银行协议原始 key |
| `inAcctNo` | String | 是 | 收款账号 | 收款账号 | 银行协议原始 key |
| `USER_D_NM` | String | 中信 | 付款用户名 | - | 中信必填 |
| `USER_C_NM` | String | 中信 | 选填 | 收款用户名 | - |
| `outAcctId` | String | 平安 | - | 付款账户 ID | 平安必填 |
| `outAcctName` | String | 平安 | - | 付款账户名 | 平安必填 |
| `inAcctId` | String | 平安 | - | 收款账户 ID | 平安必填 |
| `inAcctName` | String | 平安 | - | 收款账户名 | 平安必填 |

`baseData.remark` 最大长度：中信 256 / 平安 256

**请求示例（中信）：**

```json
{
  "baseData": {
    "tenantId": "10001",
    "storeId": "20001",
    "platformCode": "zxegj",
    "bizSystemCode": "SCM",
    "bizTransactionType": "PURCHASE",
    "bizTransactionId": "TX20260810001",
    "bizSubTransactionId": null,
    "bizRequestNo": "REQ20260810001",
    "bizOrderNo": "ORD20260810001",
    "bizSubOrderNo": "SUB20260810001",
    "payStoreNo": "STORE001",
    "payStoreId": "20001",
    "recStoreNo": "STORE002",
    "recStoreId": "20002",
    "amount": 10000,
    "fee": 0,
    "currency": "CNY",
    "remark": "采购货款"
  },
  "specialData": {
    "outAcctNo": "6217000012345678",
    "inAcctNo": "6217000098765432",
    "USER_D_NM": "张三",
    "USER_C_NM": "李四"
  }
}
```

**响应示例：**

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "frontRespCode": "200",
    "frontRespDesc": "交易成功",
    "frontSsn": "F2026081012345678901234567890",
    "frontStatus": "SUCCESS",
    "frontQueryId": "F2026081012345678901234567890",
    "frontRemark": null,
    "frontTransDate": "20260810",
    "frontTransTime": "123456",
    "specialData": {
      "USER_SSN": "US20260810123456789"
    }
  }
}
```

---

### 4.2 短信鉴权转账（仅平安）

**`POST /front/v1/transactions/transfer/auth`**

**baseData 类型：** `AuthTransferBusinessData`（继承 `TransferBusinessData`）

**specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `outAcctNo` | String | 是 | 付款账号 |
| `inAcctNo` | String | 是 | 收款账号 |
| `outMemberCode` | String | 是 | 付款会员编号 |
| `outSubAcctName` | String | 是 | 付款会员名称 |
| `inMemberCode` | String | 是 | 收款会员编号 |
| `inSubAcctName` | String | 是 | 收款会员名称 |
| `messageOrderNo` | String | 是 | 验证码订单号（先调授权码发送获取） |
| `messageCheckCode` | String | 是 | 短信验证码（SM2 加密后再 Base64） |

`baseData.remark` 最大长度：120

---

### 4.3 发送/重发转账授权码（仅平安）

**`POST /front/v1/transactions/transfer/auth-code/resend`**

**baseData 类型：** `TransferAuthCodeBusinessData`（继承 `BaseTransactionBusinessData`）

baseData 无额外字段（继承 `BaseTransactionBusinessData`）。

**specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `acctNo` | String | 是 | 提现/转账账号 |
| `outAcctId` | String | 是 | 付款账户 ID |
| `intAcctNo` | String | 是 | 收款账号 |

**响应 `specialData`：**

| key | 类型 | 说明 |
|---|---|---|
| `smsIdx` | String | 短信索引号 |
| `receiveMobile` | String | 接收手机号（脱敏） |

---

### 4.4 消费

**`POST /front/v1/transactions/consume`**

**baseData 类型：** `ConsumeBusinessData`（继承 `BaseTransactionBusinessData`）

| baseData 额外字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `consumeScene` | String | 否 | 消费场景 |
| `orderInfo` | String | 否 | 订单信息 |

**specialData 字段：** 同普通转账（参考 4.1）

`baseData.remark` 最大长度：中信 256 / 平安 256

---

### 4.5 退款

**`POST /front/v1/transactions/refund`**

**baseData 类型：** `RefundBusinessData`（继承 `BaseTransactionBusinessData`）

| baseData 额外字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `orgBizOrderNo` | String | 是 | 原业务主订单号，最大 64 |
| `orgBizSubOrderNo` | String | 否 | 原业务子订单号，最大 64 |
| `refundReason` | String | 否 | 退款原因 |

`baseData.amount` = 退款金额（人民币分）

**中信 specialData 字段（必须）：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `ORI_USER_D_ID` | String | 是 | 原付款用户 ID |
| `ORI_USER_D_NM` | String | 是 | 原付款用户名称 |
| `ORI_USER_C_ID` | String | 是 | 原收款用户 ID |
| `ORI_USER_TRANS_DT` | String | 是 | 原交易日期 yyyyMMdd |
| `ORI_USER_C_NM` | String | 否 | 原收款用户名称 |

| 中信退款约束：
| - Front 使用真实退款接口 `/refund` + `bizFunc=23`，**不是**反向转账；
| - `orgBizOrderNo` / `orgBizSubOrderNo` 映射银行 `ORI_BUSS_ID` / `ORI_BUSS_SUB_ID`；
| - `FUND_TP` 由 Front 从租户配置读取，业务系统无需传。

**平安 specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `outAcctNo` | String | 是 | 付款账号 |
| `inAcctNo` | String | 是 | 收款账号 |
| `outMemberCode` | String | 是 | 付款会员编号 |
| `inMemberCode` | String | 是 | 收款会员编号 |

---

### 4.6 提现

**`POST /front/v1/transactions/withdraw`**

**baseData 类型：** `WithdrawBusinessData`（继承 `BaseTransactionBusinessData`）

`baseData.remark` 最大长度：中信 512 / 平安 512

**中信 specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `acctNo` | String | 是 | 提现账号 |
| `cardNoEnc` | String | 是 | 银行卡号（加密） |
| `WITH_ACCNAME` | String | 是 | 银行账户户名（加密） |

**平安 specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `acctNo` | String | 是 | 提现子账户号（加密） |
| `outAcctId` | String | 是 | 提现会员编号（进 mchntMbrId） |
| `cardNoEnc` | String | 是 | 绑定卡号（加密） |
| `nameEnc` | String | 是 | 客户户名（加密） |
| `userNameEnc` | String | 是 | 持卡人户名（加密） |
| `certNo` | String | 否 | 证件号，选填：有值才加密为 `certNoEnc` 上送，不传不上送（提现为"不验证"模式 6033，当前非必填；标准结构中已预留，暂不组装上送） |

---

### 4.7 平台付款（仅中信）

**`POST /front/v1/transactions/platform-pay`**

**baseData 类型：** `PlatformTransferBusinessData`

| baseData 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `amount` | Long | 是 | 平台付款金额，人民币分 |
| `bizOrderNo` | String | 是 | 业务主订单号 |
| `bizSubOrderNo` | String | 否 | 业务子订单号 |

**specialData 字段：**（平台侧账号由商户自有资金登记簿隐式确定，只上送用户收款侧字段）

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `inAcctNo` | String | 是 | 收款账号（用户侧） |
| `inAcctNm` | String | 是 | 收款账户名（用户侧） |
| `dealType` | String | 是 | 交易类型 |
| `fundTp` | String | 是 | 资金类型 |
| `contractId` | String | 否 | 协议编号 |

---

### 4.8 平台收款（仅中信）

**`POST /front/v1/transactions/platform-receive`**

**baseData 类型：** `PlatformTransferBusinessData`

字段同 4.7。

**specialData 字段：** 同 4.7。

---

## 5. 查询接口（5 个）

Feign 接口：`FrontQueryApi`，服务名 `catering-front`，前缀 `/front/v1/queries`

### 5.1 账户状态查询

**`POST /front/v1/queries/accounts/status`**

**baseData 类型：** `AccountStatusQueryData`

| baseData 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `frontSsn` | String | 平安必填 | 原 Front 渠道流水号：平安按其定位原交易；中信仅回显 |

**specialData 字段：** 无（传空对象 `{}`）

---

### 5.2 账户余额查询

**`POST /front/v1/queries/accounts/balance`**

**baseData 类型：** `AccountBalanceQueryData`

**baseData 专有字段：** `accountScope`（`AccountScope` 枚举：`PLATFORM_FUNDS_ACCOUNT` 平台交易资金账户 /
`USER_SUB_ACCOUNT` 用户子账户 / `FUNCTIONAL_ACCOUNT` 功能登记簿账户；中信按此映射 bizFunc 35/46/36，
平安暂未接入）

**specialData 字段：**

| key | 类型 | 必填 | 中信 | 平安 |
|---|---|---|---|---|
| `acctNo` | String | 中信 | 用户编号 | - |
| 无 |  | 平安 | - | 无需特殊字段，返回资金汇总账号余额 |

---

### 5.3 单笔交易状态查询

**`POST /front/v1/queries/transactions/status`**

**baseData 类型：** `TransactionStatusQueryData`

| baseData 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `capability` | String | 是 | 原交易能力枚举名（如 `TRANSFER`、`CONSUME`） |
| `transactionDate` | String | 是 | 原交易日期 yyyyMMdd |
| `frontSsn` | String | 否 | 前端流水号（用于回显） |
| `bizOrderNo` | String | 是 | 业务主订单号（转账/消费/退款必带子订单号） |
| `bizSubOrderNo` | String | 否 | 业务子订单号 |

| 约束：
| - 转账、消费、退款查询必须同时提供 `bizOrderNo` + `bizSubOrderNo`；
| - 提现查询只传 `bizOrderNo`；
| - `capability` 用于确定银行查询的 `bizFunc`，不参与当前 API 路由。

**中信 specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `acctNo` | String | 是 | 用户编号 |

---

### 5.4 平台交易明细查询

**`POST /front/v1/queries/transactions/platform-details`**

> 返回 `TableDataInfo<TransactionDetailItem>`，不包 `R`。

**baseData 类型：** `TransactionDetailQueryData`

| baseData 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `pageNo` | Integer | 是 | 页码，从 1 开始 |
| `pageSize` | Integer | 是 | 每页条数（中信 ≤ 20） |

**中信 specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `transactionDate` | String | 是 | 查询日期 yyyyMMdd，**不支持跨日** |
| `transactionType` | String | 是 | 交易类型：`01` 转账入金 / `02` 退汇 / `03` 支付渠道入金 / `04` 提现 / `05` 退款(预留) / `99` 所有 |

| 注意：
| - 中信 `bizFunc=25` 不支持跨日查询，业务系统需按日期多次调用；
| - `bizFunc`、`chnlNo`、`PAGE` 由 Front 内部处理，业务系统不允许传入。

---

### 5.5 账户/登记簿交易明细查询

**`POST /front/v1/queries/transactions/details`**

> 返回 `TableDataInfo<TransactionDetailItem>`，不包 `R`。

**baseData 类型：** `TransactionDetailQueryData`

| baseData 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `pageNo` | Integer | 是 | 页码，从 1 开始 |
| `pageSize` | Integer | 是 | 每页条数（中信 ≤ 50） |

**中信 specialData 字段：**

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `acctNo` | String | 是 | 用户编号 |
| `transactionDate` | String | 是 | 查询日期 yyyyMMdd，**不支持跨日** |
| `transactionType` | String | 是 | 交易类型：`01` 入金分账 / `02` 交易划转 / `03` 提现 / `04` 提现手续费 / `05` 提现退汇 / `06` 渠道来账 / `98` 所有明细 / `99` 所有汇总 |
| `accountType` | String | 是 | 登记簿/账户类型：`01` 公共调账登记簿 / `12` 平台自有资金登记簿 / `13` 担保登记簿 / `17` 待结算手续费登记簿 |

---

## 6. 响应行明细项结构（`TransactionDetailItem`）

```json
{
  "transactionDate": "20260810",
  "transactionTime": "123456",
  "transactionType": "01",
  "transactionTypeName": "转账入金",
  "amount": 10000,
  "fee": 0,
  "currency": "CNY",
  "oppositeAccountNo": "6217000098765432",
  "oppositeName": "李四",
  "remark": "采购货款",
  "frontStatus": "SUCCESS",
  "specialData": {}
}
```

---

## 7. 错误码参考

| 顶层 `code` | 说明 | 处理方式 |
|---|---|---|
| 200 | 调用成功 | 检查 `data.frontRespCode` |
| 400 | 参数校验失败 | 修正请求参数 |
| 500 | 系统内部错误 | 联系运维 |
| 503 | 服务暂不可用 | 稍后重试 |

| `data.frontRespCode` | 说明 |
|---|---|
| `"200"` | 业务成功 |
| `"F100001"` | 请求参数非法（参数校验失败） |
| `"F100003"` | 租户银行配置不存在/未启用 |
| `"F100004"` | 请求银行与租户配置不一致 |
| `"F200001"` | 银行不支持 |
| `"F200002"` | 当前银行不支持该能力 |
| `"F200003"` | 适配器尚未接入（如平安查询） |
| `"F300001"` | 交易已存在（重复交易） |
| `"F400001"` | 钱包通信失败（可确认未送达） |
| `"F400002"` | 钱包结果未知，需查询确认 |
| `"F400003"` | 钱包响应格式错误 |
| `"F400004"` | 银行渠道拒绝（查看 `frontRespDesc`） |
| `"F400005"` | 钱包平台层拒绝 |
| `"F900001"` | Front 内部异常 |

---

## 8. 调用方式

### 8.1 Maven 依赖

```xml
<dependency>
    <groupId>com.chinaums</groupId>
    <artifactId>catering-api-front</artifactId>
    <version>${project.version}</version>
</dependency>
```

### 8.2 Feign 客户端配置

```java
@FeignClient(contextId = "frontTransactionApi", value = "catering-front")
public interface FrontTransactionApi {
    // ...
}
```

服务发现使用 Nacos，业务系统确保已启用 `@EnableFeignClients` 和 Nacos 服务发现。

### 8.3 必要请求头

Front 自动从请求头读取以下参数并注入 `FrontRequest.baseData`：

| 请求头 | 说明 |
|---|---|
| `tenantId` | 租户 ID |
| `clientId` | 客户端 ID |
| `platformCode` | 银行编码（`zxegj` / `pajzb`） |
| `dataSourceId` | 数据源标识 |

如果业务系统通过 Feign 调用，`catering-common-feign` 的拦截器会自动转发这些参数。

---

## 9. 当前限制

1. 平安 5 个查询接口（状态/余额/明细等）当前返回 `ADAPTER_NOT_READY`，
   待后续逐接口确认后启用；
2. 中信明细查询 `bizFunc=24/25` **不支持跨日**查询，业务系统按日期多次调用；
3. 退款关联原交易使用 `orgBizOrderNo + orgBizSubOrderNo` 逻辑关联，
   Front **不查询**本地原交易记录补字段；
4. 平安退款边界（是否需要本地原交易关联）待确认；
5. 所有金额单位为人民币分，禁止浮点数。