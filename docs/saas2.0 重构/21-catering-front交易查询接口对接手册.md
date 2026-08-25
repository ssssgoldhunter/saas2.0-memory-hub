# Catering Front 交易查询接口对接手册

> 状态：current / verified-against-source
> 核验日期：2026-08-25
> 适用对象：调用 `catering-front` 查询能力的业务上游开发人员
> 覆盖范围：当前 `FrontQueryApi` 的 5 个接口（3 个 Query 域 + 2 个 Account 域）及完整请求、返回字段
> 不覆盖：银行 Capability 开发和交易发起；分别见 19、20 号手册

---

## 1. 接入结论

- 服务名：`catering-front`。
- Feign 接口：`com.chinaums.front.api.FrontQueryApi`。
- 路径前缀：`/front/v1/queries`。
- 单条查询返回 `R<具体结果>`；两类明细查询直接返回 `TableDataInfo<具体行>`，不能按 `R` 解析。
- 请求仍是 `baseData + specialData` 两段。
- 中信 5 个查询均已实现。
- 平安交易状态、平台明细、账户明细已实现；账户状态和余额固定返回 `F200003`。
- 明细金额统一返回人民币分；查询条件中的日期统一 `yyyyMMdd`。
- `frontStatus` 在交易状态查询中是内部三态 `S/P/F/null`，与交易接口的枚举不是同一类型。
- API 名称和签名不变，但内部执行域已明确：交易状态/两类明细走 Query；账户状态/余额走 Account。
  调用方无需感知 `FrontQuerySlot` 或 `FrontAccountSlot`。

### 1.1 支持矩阵

| 查询接口 | `FrontQueryApi` 方法 | 中信 `zxegj` | 平安 `pajzb` |
|---|---|---|---|
| 账户状态 | `queryAccountStatus` | 已实现，`2058` | 未接入，`ADAPTER_NOT_READY` |
| 账户余额 | `queryAccountBalance` | 已实现，`35/36/46` | 未接入，`ADAPTER_NOT_READY` |
| 单笔交易状态 | `queryTransactionStatus` | 已实现，`74` | 已实现，`02/03/04` |
| 平台交易明细 | `queryPlatformTransactionDetails` | 已实现，`25` | 已实现，`6050/6048` |
| 账户/登记簿明细 | `queryTransactionDetails` | 已实现，`24` | 已实现，`6073` |

---

## 2. 公共接入准备

### 2.1 Maven 与 Feign

```xml
<dependency>
    <groupId>com.chinaums</groupId>
    <artifactId>catering-api-front</artifactId>
    <version>${project.version}</version>
</dependency>
```

```java
private final FrontQueryApi frontQueryApi;
```

业务上游不要复制 Feign 接口、返回 DTO 或分页类。

### 2.2 公共请求头和基础字段

| 原始字段 | 类型 | 必填 | 注释 |
|---|---|---|---|
| `tenantId` | String | 是 | 租户标识，由 Header/Feign 上下文注入 |
| `clientId` | String | 否 | 客户端标识，由 Header/Feign 上下文注入 缺失时 Front 从 `tenant_base_config` 回填 |
| `platformCode` | String | 否 | `zxegj` / `pajzb`，由 Header/Feign 上下文注入；缺失时 Front 用 tenantId 从 `tenant_base_config` 回填（2026-08-20 起） |
| `dataSourceId` | String | 否 | 数据源编号；涉及平安本地渠道表回查时决定分库。缺失时从 `tenant_base_config` 回填，显式传入优先 |
| `storeId` | String | 是 | 发起本次查询的业务门店 ID |

### 2.3 查询对接步骤

1. 确认目标银行和该查询能力的支持状态。
2. 建立四个请求头上下文，并填写 `storeId`。
3. 根据接口准备强类型 `baseData`。
4. 使用 `FrontSpecialDataAssembler` 或本文原始 key 表生成 `specialData`。
5. 调用对应 Feign 方法。
6. 单条查询按 `R` 判断；分页查询按 `TableDataInfo.code` 判断。
7. 明细按 `rows` 消费，不以 `total` 作为本页行数。
8. 交易状态为 `P` 或 `null` 时继续查询，不得认定成功或直接重发交易。

---

## 3. 两种返回外壳

### 3.1 单条查询：`R<T>`

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

| 层级 | 判断 |
|---|---|
| `R.code` | 必须为整数 `200` |
| `data.frontRespCode` | 必须为字符串 `"200"` |
| 具体业务字段 | 再按接口语义判断，例如交易状态 `S/P/F/null` |

银行业务失败示例（2026-08-20 起）：钱包/银行拒绝时 `frontRespDesc` 与 `R.msg` 覆写为
银行原始错误描述原文（不转译、不拼接），优先级 `sysRespDesc` > `sysRespCode` >
`errInfo` > `errCode`；`frontRespCode` 仍为 Front 统一码，判断成败必须用它而非描述
文本。`specialData` 按约束只存放接口额外返回内容（如成功时的 `queryId`），不含错误
诊断字段；Front 内部失败（参数校验/路由/配置）保持统一文案或校验消息。

```json
{
  "code": 500,
  "msg": "[JU005]用户编号不存在",
  "data": {
    "frontRespCode": "F400004",
    "frontRespDesc": "[JU005]用户编号不存在",
    "accountId": "J04069400000302",
    "specialData": {}
  }
}
```

### 3.2 明细查询：`TableDataInfo<T>`

```json
{
  "total": 40,
  "totalPage": 2,
  "rows": [],
  "code": 200,
  "msg": "查询成功",
  "extraData": null
}
```

| 原始字段 | 类型 | 失败值 | 注释 |
|---|---|---|---|
| `total` | long | `0` | 银行返回或 Front 估算的总量，不等于本页 `rows.size()` |
| `totalPage` | Long | `0` | 总页数；无记录可为 0 |
| `rows` | `List<T>` | `[]` | 默认空集合，不返回 null |
| `code` | int | `500` | `200` 成功，`500` 查询失败 |
| `msg` | String | 安全失败说明 | 银行业务失败时直接为银行原始错误描述原文（如 `[JU005]用户编号不存在`），不拼接 Front 文案；无银行响应要素时为 `查询失败` |
| `extraData` | Map | 通常 null | 当前 Front 明细接口未使用 |

分页接口不返回 `data` 字段，也不包 `R`。

---

## 4. specialData 查询组装

### 4.1 中信账户状态

```java
FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();
assembler.setPlatformCode("zxegj");
assembler.setCapability(FrontCapability.ACCOUNT_STATUS_QUERY);
assembler.newPay().setBankEAccountId(accountNo);
JSONObject specialData = assembler.assemble(); // {"acctNo":"..."}
```

### 4.2 中信账户余额

```java
assembler.setPlatformCode("zxegj");
assembler.setCapability(FrontCapability.ACCOUNT_BALANCE_QUERY);
assembler.newPay().setBankEAccountId(accountNo);
assembler.setRegisterAttr(registerAttr); // 选填
JSONObject specialData = assembler.assemble();
```

### 4.3 单笔交易状态

```java
assembler.setCapability(FrontCapability.TRANS_STATUS_QUERY);
assembler.setPlatformCode(platformCode);
FrontSpecialDataAssembler.AccountInfo pay = assembler.newPay();
pay.setBankEAccountId(citicAccountNo);     // 中信使用
pay.setBankEMemberCode(pingAnMemberCode);  // 平安使用
JSONObject specialData = assembler.assemble();
```

### 4.4 24/25 明细

```java
assembler.setCapability(FrontCapability.TRANS_DETAIL_QUERY); // 24
assembler.setPlatformCode(platformCode);
assembler.setTransDate("20260819");
assembler.setTransType("04");
assembler.setAccountType("12"); // 仅中信 24 选填
FrontSpecialDataAssembler.AccountInfo pay = assembler.newPay();
pay.setBankEAccountId(accountNo);
pay.setBankEMemberCode(memberCode); // 平安 Assembler 要求，6073 当前不消费该字段
JSONObject specialData = assembler.assemble();
```

每次调用新建 Assembler。输出包含账户、会员号等敏感值，不得明文记录。

---

## 5. 账户状态查询

```text
POST /front/v1/queries/accounts/status
FrontRequest<AccountStatusQueryData> → R<AccountStatusResult>
```

`AccountStatusQueryData` 没有专有字段，只包含公共基础字段。

### 5.1 请求 specialData

| 银行 | 原始 key | 类型 | 必填 | 注释 |
|---|---|---|---|---|
| 中信 | `acctNo` | String | 是 | 被查询用户编号；Front 加密后调用 `2058` |
| 平安 | — | — | — | 当前适配器未接入，调用固定失败 |

旧文档中“账户状态 specialData 传空对象”的说法已经过期。中信当前 Account Capability 明确校验
`specialData.acctNo`。

### 5.2 `AccountStatusResult` 完整字段

该对象继承 `FrontBaseResult`：

| 原始字段 | 类型 | 可能为空 | 注释 |
|---|---|---|---|
| `frontRespCode` | String | 否 | `"200"` 表示查询业务成功 |
| `frontRespDesc` | String | 否 | Front 业务说明 |
| `specialData` | JSONObject | 否 | 当前成功响应通常包含钱包 `queryId`（有值才写） |
| `accountId` | String | 失败时可能为空 | 回显中信请求 `acctNo` |
| `accountStatus` | String | 是 | 当前直接取中信响应原始 `status`；代码未定义跨银行枚举 |

不要自行把 `accountStatus` 映射为“正常/冻结”等业务状态，除非上游拥有经确认的中信状态字典。

### 5.3 请求示例

```json
{
  "baseData": {
    "tenantId": "10001",
    "clientId": "query-service",
    "platformCode": "zxegj",
    "dataSourceId": "2",
    "storeId": "20001"
  },
  "specialData": {
    "acctNo": "USER0001"
  }
}
```

---

## 6. 账户余额查询

```text
POST /front/v1/queries/accounts/balance
FrontRequest<AccountBalanceQueryData> → R<AccountBalanceResult>
```

### 6.1 baseData 专有字段

| 原始字段 | 类型 | 必填 | 注释 |
|---|---|---|---|
| `accountScope` | `AccountScope` | 是 | `PLATFORM_FUNDS_ACCOUNT` / `USER_SUB_ACCOUNT` / `FUNCTIONAL_ACCOUNT` |

中信映射：

| `accountScope` | 中信 bizFunc | 含义 |
|---|---|---|
| `PLATFORM_FUNDS_ACCOUNT` | `35` | 平台交易资金账户 |
| `USER_SUB_ACCOUNT` | `46` | 用户子账户 |
| `FUNCTIONAL_ACCOUNT` | `36` | 功能/公共登记簿账户 |

### 6.2 specialData

| 原始 key | 类型 | 必填 | 注释 |
|---|---|---|---|
| `acctNo` | String | 中信必填 | 被查询用户/账户编号 |
| `registerAttr` | String | 选填 | 功能登记簿类型；有值时映射银行 `reserve.registerAttr` |

当前 Account Capability 对 `registerAttr` 不做必填或白名单校验；缺失时直接由银行决定是否拒绝。常用类型定义为：

| 值 | 注释 |
|---|---|
| `01` | 公共调账登记簿 |
| `12` | 平台自有资金登记簿 |
| `13` | 担保登记簿 |
| `17` | 待结算手续费登记簿 |

当前源码没有为 `registerAttr` 或 `accountType` 自动默认 `12`；调用方需要该语义时应显式传值。

平安账户余额适配器当前固定 `F200003`，不要依据不可达草稿字段进行对接。

### 6.3 `AccountBalanceResult` 完整字段

| 原始字段 | 类型 | 可能为空 | 注释 |
|---|---|---|---|
| `frontRespCode` | String | 否 | Front 业务码 |
| `frontRespDesc` | String | 否 | Front 业务说明 |
| `specialData` | JSONObject | 否 | 钱包 `queryId` 有值时写入 |
| `accountScope` | `AccountScope` | 失败时可能为空 | 回显查询范围 |
| `accountId` | String | 失败时可能为空 | 回显 `acctNo` |
| `balance` | Long | 是 | 账户总余额，人民币分 |
| `previousBalance` | Long | 是 | 上一日余额，人民币分；当前主要由中信 46 的 `preAmount` 映射 |
| `availableBalance` | Long | 是 | 可用余额；当前中信 Account Capability 未赋值 |
| `withdrawableBalance` | Long | 是 | 可提现余额，人民币分；中信 46 返回 |
| `frozenBalance` | Long | 是 | 冻结余额；当前中信 Account Capability 未赋值 |

中信当前金额映射：

- `46`：银行 `balance/withdrawAmt/preAmount` 单位元，Front 乘 100 转分。
- `35`：银行 `PRE_AMOUNT` 单位分，直接写 `balance`。
- `36`：银行 `balance` 单位分，直接写 `balance`。

不能假设所有余额字段同时有值。

### 6.4 请求示例

```json
{
  "baseData": {
    "tenantId": "10001",
    "clientId": "query-service",
    "platformCode": "zxegj",
    "dataSourceId": "2",
    "storeId": "20001",
    "accountScope": "FUNCTIONAL_ACCOUNT"
  },
  "specialData": {
    "acctNo": "USER0001",
    "registerAttr": "12"
  }
}
```

---

## 7. 单笔交易状态查询

```text
POST /front/v1/queries/transactions/status
FrontRequest<TransStatusQueryData> → R<TransStatusResult>
```

### 7.1 baseData 专有字段

| 原始字段 | 类型 | 中信 | 平安 | 注释 |
|---|---|---|---|---|
| `capability` | `FrontCapability` | 必填 | 必填 | 被查询的原交易能力，不是当前路由 capability |
| `transDate` | String | 必填 | 选填 | `yyyyMMdd`；平安查询三天前记录时有值即上送 |
| `frontSsn` | String | 选填，仅回显 | 必填 | 平安按原交易请求 `transSsn` 定位 |
| `bizOrderNo` | String | 必填 | 结果回显 | 原业务主订单号 |
| `bizSubOrderNo` | String | 转账/消费/退款必填 | 结果回显 | 提现/充值查询可不传 |

当前被查能力支持边界：

| 被查 capability | 中信 | 平安 |
|---|---|---|
| `TRANSFER` | 支持 | 支持，分流 `02` |
| `CONSUME` | 支持 | 支持，分流 `02` |
| `REFUND` | 支持 | 支持，当前也分流 `02` |
| `WITHDRAW` | 支持 | 支持，分流 `03` 并回查原提现卡号 |
| `RECHARGE` | 不支持 | 支持状态查询，分流 `04` |

### 7.2 specialData

| 银行 | 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|---|
| 中信 | `acctNo` | String | 是 | `pay.bankEAccountId` | 被查用户编号，Front 加密 |
| 平安 | `mchntMbrId` | String | 是 | `pay.bankEMemberCode` | 被查会员编号 |

平安提现查询所需 `cardNoEnc` 由 Front 按 `tenantId + frontSsn` 回查原提现渠道表并加密；业务上游不要传。

### 7.3 `TransStatusResult` 完整字段

| 原始字段 | 类型 | 可能为空 | 注释 |
|---|---|---|---|
| `frontRespCode` | String | 否 | Front 业务码 |
| `frontRespDesc` | String | 否 | Front 业务说明 |
| `specialData` | JSONObject | 否 | 查询响应白名单字段，见下表 |
| `frontSsn` | String | 是 | 回显请求的原 Front 流水；中信未传则为空 |
| `bizOrderNo` | String | 是 | 回显请求业务主订单号 |
| `bizSubOrderNo` | String | 是 | 回显请求业务子订单号 |
| `frontStatus` | String | 是 | `S` 成功 / `P` 处理中 / `F` 失败 / `null` 无法识别 |
| `frontQueryId` | String | 是 | 银行/钱包查询关联号 |

响应 `specialData`：

| 银行 | key | 注释 |
|---|---|---|
| 中信/平安 | `queryId` | 钱包返回，有值时写入；通常与 `frontQueryId` 相同 |
| 中信 | `USER_SSN` | 中信侧交易流水 |
| 中信 | `TRANS_DATE` | 中信侧交易日期 |
| 中信 | `TRANS_TIME` | 中信侧交易时间 |

### 7.4 状态映射

| Front 状态 | 含义 | 上游处理 |
|---|---|---|
| `S` | 成功；中信原状态 `04/05` 也按既定规则归成功 | 进入业务成功后处理 |
| `P` | 受理、待确认、待处理或处理中 | 延迟后继续查询 |
| `F` | 银行明确失败 | 进入失败处理 |
| `null` | 银行状态为空或无法识别 | 不得认定成功；保留定位信息并继续确认/排障 |

### 7.5 平安请求示例

```json
{
  "baseData": {
    "tenantId": "10001",
    "clientId": "query-service",
    "platformCode": "pajzb",
    "dataSourceId": "2",
    "storeId": "20001",
    "capability": "WITHDRAW",
    "transDate": "20260819",
    "frontSsn": "PA202608190001",
    "bizOrderNo": "WD202608190001"
  },
  "specialData": {
    "mchntMbrId": "MEMBER001"
  }
}
```

---

## 8. 平台交易明细查询（25）

```text
POST /front/v1/queries/transactions/platform-details
FrontRequest<PlatformDetailQueryData> → TableDataInfo<PlatformTransDetailItem>
```

### 8.1 baseData 专有字段

| 原始字段 | 类型 | 必填 | 注释 |
|---|---|---|---|
| `pageNo` | Integer | 选填 | 从 1 开始；空值默认 1 |
| `pageSize` | Integer | 选填 | 仅表达期望，当前不会覆盖银行原生页大小 |

### 8.2 specialData

| 原始 key | 类型 | 必填 | 注释 |
|---|---|---|---|
| `transDate` | String | 是 | 单个交易日 `yyyyMMdd`；Front 对外不提供跨日范围 |
| `transType` | String | 是 | `01` 转账入金 / `02` 退汇 / `03` 支付渠道入金 |

中信和平安使用相同 Front 对外 key，Query Capability 再映射各自银行协议。

### 8.3 银行分页行为

| 银行/类型 | 银行接口 | 页大小 | `total/totalPage` 行为 |
|---|---|---|---|
| 中信 01/02/03 | `25` | 固定 20 | `totalPage` 取银行 `TOTAL_PAGE`；`total=totalPage*20`，是估算值 |
| 平安 01/03 | `6050` | 固定 20 | `total` 取银行 `totalNum`；01/03 共用结果后按 `inAcctType` 过滤，故 `rows.size()` 可小于 total |
| 平安 02 | `6048` | 无分页，一次全返 | `total=rows.size()`，`totalPage=1` |

平安 `02` 虽然银行接口不使用日期和分页，Front 当前仍统一要求 `transDate`；调用方必须传。

### 8.4 `PlatformTransDetailItem` 完整主字段

| 原始字段 | 类型 | 中信来源 | 平安来源 | 为空条件/注释 |
|---|---|---|---|---|
| `mchntMbrId` | String | 响应壳 `MCHNT_ID` | 租户配置 `stlAcctNo` | 平台账号 |
| `bankAccountCode` | String | `USER_ID`，主要 01 有值 | 6050 `subAcctNo` / 6048 `acctNo` 解密 | 02/03 中信可空 |
| `userName` | String | `USER_NM`，主要 01 有值 | 6050 `inAcctName` 解密；6048 无名称 | 6048 为空 |
| `transType` | String | 银行 `TRANS_TP` | 按请求回填 `01/02/03` | 对外类型 |
| `transDate` | String | `TRANS_DT` | 6050 `accountingDate` / 6048 `returnDate` | `yyyyMMdd` |
| `transTime` | String | `TRANS_TM` | 当前平安置空 | `HHmmss` |
| `transAmt` | Long | `TRANS_AMT` 元×100 | `tranAmt` 分直传 | 人民币分，可因格式异常为空 |
| `payAcctNo` | String | `PAY_ACCNO` | 6050 `inAcctNo` / 6048 `cardNoEnc` 解密 | 敏感账号，谨慎使用 |
| `payAcctName` | String | `PAY_ACCNAME` | 6050 `inAcctName` / 6048 `nameEnc` 解密 | 敏感户名 |
| `remark` | String | `REMARK` | 6050 `remark` / 6048 `transNote` | 可空 |
| `frontSeqNo` | String | `REARK2`，主要 01 有值 | 6050 `frontSeqNo` / 6048 `termSsn` | 上游/见证流水 |
| `bankMemberCode` | String | 当前空字符串 | 6050 `tranNetMemberCode`；6048 为空 | 可空 |
| `specialData` | JSONObject | 白名单原始字段 | 白名单原始字段 | 默认 `{}` |

### 8.5 行级 specialData 完整白名单

中信 25：

| key | 注释 |
|---|---|
| `MCHNT_ID` | 平台商户号 |
| `C_D_FLAG` | 资金方向：`C` 入金 / `D` 出金 |
| `JRNO` | 银行交易日志号 |
| `BKNO` | 银行号 |
| `ACSQ` | 账户序号 |
| `ACTN` | 账户交易序号 |
| `FTFL` | 金融交易标识 |
| `TSTM` | 银行时间戳 |
| `REMARK` | 银行备注 |
| `REARK1` | 联行号/银行备用字段 1 |
| `REARK3` | 银行备用字段 3 |
| `CUR_AMT` | 银行原始当前余额，单位元 |
| `currentAmountCent` | `CUR_AMT` 精确换算后的人民币分 |
| `DIGEST` | 摘要 |

平安 6050（类型 01/03）：

| key | 注释 |
|---|---|
| `ccy` | 币种 |
| `bankName` | 付款账户银行名称 |
| `inAcctType` | 银行入账类型：`02` 会员充值 / `03` 资金挂账 |
| `endFlag` | 结束标识 |
| `resultNum` | 本次返回记录数 |
| `startRecordNo` | 起始记录号 |
| `reserve` | 银行补充域，有值时原样保留 |

平安 6048（类型 02）：

| key | 注释 |
|---|---|
| `termSsn` | 收款方见证系统流水，同时映射主字段 `frontSeqNo` |
| `termSsnOut` | 原提现交易流水，退票当天可能为空 |
| `oriTermSsn` | 原提现见证系统流水 |
| `oriPlatSsn` | 原提现市场流水 |
| `returnReason` | 退票原因 |
| `bankNo` | 付款方行号 |
| `bankName` | 银行名称 |
| `platSsn` | 退票入账交易流水 |
| `ssn` | 业务流水号 |

### 8.6 请求示例

```json
{
  "baseData": {
    "tenantId": "10001",
    "clientId": "query-service",
    "platformCode": "pajzb",
    "dataSourceId": "2",
    "storeId": "20001",
    "pageNo": 1,
    "pageSize": 20
  },
  "specialData": {
    "transDate": "20260819",
    "transType": "01"
  }
}
```

---

## 9. 账户/登记簿交易明细查询（24）

```text
POST /front/v1/queries/transactions/details
FrontRequest<AccountDetailQueryData> → TableDataInfo<AccountTransDetailItem>
```

### 9.1 baseData 专有字段

| 原始字段 | 类型 | 必填 | 注释 |
|---|---|---|---|
| `pageNo` | Integer | 选填 | 从 1 开始；空值默认 1 |
| `pageSize` | Integer | 选填 | 仅表达期望；中信固定 50，平安固定 20 |

### 9.2 specialData

| 原始 key | 类型 | 中信 | 平安 | 注释 |
|---|---|---|---|---|
| `acctNo` | String | 必填 | 必填 | 被查用户/见证子账户号 |
| `mchntMbrId` | String | 不使用 | Assembler 必填 | 平安会员编号；6073 当前 Query Capability 不消费，但标准组装器保留 |
| `transDate` | String | 必填 | 必填 | 单日 `yyyyMMdd` |
| `transType` | String | 必填 | 必填 | 对外只允许 `04` 提现手续费 |
| `accountType` | String | 选填 | 忽略且不输出 | 中信映射银行 `registerAttr` |

`accountType` 允许值：

| 值 | 注释 |
|---|---|
| `01` | 公共调账登记簿 |
| `12` | 平台自有资金登记簿 |
| `13` | 担保登记簿 |
| `17` | 待结算手续费登记簿 |

当前源码没有默认 `accountType=12`；不传时中信请求不带 `registerAttr`。平安 6073 没有该概念。

### 9.3 银行分页和过滤

| 银行 | 银行接口 | 页大小 | 行过滤与 total |
|---|---|---|---|
| 中信 | `24` | 固定 50 | `totalPage` 取银行值，`total=totalPage*50`，不是精确记录数 |
| 平安 | `6073` | 固定 20 | 只保留 `tranStatus=0` 成功记录；`total` 仍取银行 `totalNum`，所以可能大于过滤后 rows 数 |

平安 6073 历史查询把 `beginDate=endDate=transDate`，仍是单日查询。手续费取 `commission`，单位分；
空或 0 返回 `fee=0`，不会过滤该条成功记录。

### 9.4 `AccountTransDetailItem` 完整主字段

| 原始字段 | 类型 | 中信来源 | 平安来源 | 为空条件/注释 |
|---|---|---|---|---|
| `mchntMbrId` | String | 响应壳 `MCHNT_ID` | 租户配置 `stlAcctNo` | 平台账号 |
| `bankAccountCode` | String | 响应壳 `USER_ID` | `subAcctNo` 解密 | 被查账户 ID |
| `userName` | String | 行 `USER_NAME` | `subAcctName` 解密 | 用户名称 |
| `transType` | String | 固定回填 `04` | 固定回填 `04` | 提现手续费 |
| `bizOrderNo` | String | `MCHNT_ORDER_ID` | 按 `tenantId + bankQueryId(frontSeqNo)` 回查提现渠道表 | 平安查不到时为空 |
| `bizSubOrderNo` | String | `MCHNT_ORDER_SUB_ID` | 同上 | 可空 |
| `bankMemberCode` | String | 当前空字符串 | `tranNetMemberCode` | 可空 |
| `frontTransSsn` | String | `REQ_JRN` | `frontSeqNo` | 渠道/银行明细流水 |
| `fee` | Long | `TRANS_AMT` 元×100 | `commission` 分直传 | 人民币分 |
| `transDate` | String | `TRANS_DT` | `tranDate` | `yyyyMMdd` |
| `transTime` | String | `TRANS_TM` | `tranTime` | `HHmmss` |
| `specialData` | JSONObject | 白名单字段 | 白名单字段 | 默认 `{}` |

### 9.5 行级 specialData 完整白名单

中信 24：

| key | 注释 |
|---|---|
| `MCHNT_ID` | 平台商户编号 |
| `C_D_FLAG` | 资金方向：`C` 入金 / `D` 出金 |
| `DIGEST` | 摘要 |
| `REGISTER_SSN` | 登记簿系统流水号 |
| `CUR_AMT` | 银行原始交易后余额，单位元 |
| `currentAmountCent` | `CUR_AMT` 换算后的人民币分 |
| `GOAC` | 对手方账号，敏感字段 |
| `OANM` | 对手方户名，敏感字段 |

平安 6073：

| key | 注释 |
|---|---|
| `tranStatus` | 银行交易状态；返回 rows 已过滤为 `0` 成功 |
| `tranAmt` | 银行原始交易金额，单位分；主字段手续费不取它 |
| `bookingFlag` | 记账标志 |
| `bookingMsg` | 记账说明 |
| `remark` | 银行备注 |
| `endFlag` | 结束标识 |
| `resultNum` | 本次返回记录数 |
| `startRecordNo` | 起始记录号 |

### 9.6 请求示例

```json
{
  "baseData": {
    "tenantId": "10001",
    "clientId": "query-service",
    "platformCode": "zxegj",
    "dataSourceId": "2",
    "storeId": "20001",
    "pageNo": 1,
    "pageSize": 50
  },
  "specialData": {
    "acctNo": "USER0001",
    "transDate": "20260819",
    "transType": "04",
    "accountType": "12"
  }
}
```

---

## 10. Java 调用案例

### 10.1 单笔交易状态查询

```java
TransStatusQueryData data = new TransStatusQueryData();
data.setStoreId(storeId);
data.setCapability(originalCapability);
data.setTransDate(originalTransDate);
data.setFrontSsn(originalFrontSsn);
data.setBizOrderNo(originalOrderNo);
data.setBizSubOrderNo(originalSubOrderNo);

FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();
assembler.setPlatformCode(platformCode);
assembler.setCapability(FrontCapability.TRANS_STATUS_QUERY);
FrontSpecialDataAssembler.AccountInfo pay = assembler.newPay();
pay.setBankEAccountId(citicAccountNo);
pay.setBankEMemberCode(pingAnMemberCode);

FrontRequest<TransStatusQueryData> request = new FrontRequest<>();
request.setBaseData(data);
request.setSpecialData(assembler.assemble());

R<TransStatusResult> response = frontQueryApi.queryTransactionStatus(request);
TransStatusResult result = response == null ? null : response.getData();
if (response == null || response.getCode() != R.SUCCESS || result == null
    || !"200".equals(result.getFrontRespCode())) {
    handleQueryFailure(response, result);
    return;
}

if (FrontInternalTransStatus.SUCCESS.equals(result.getFrontStatus())) {
    markBusinessSuccess();
} else if (FrontInternalTransStatus.FAILED.equals(result.getFrontStatus())) {
    markBusinessFailed();
} else {
    scheduleNextQuery(); // P 或 null
}
```

### 10.2 按日分页查询平台明细

```java
PlatformDetailQueryData data = new PlatformDetailQueryData();
data.setStoreId(storeId);
data.setPageNo(pageNo);
data.setPageSize(20);

FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();
assembler.setPlatformCode(platformCode);
assembler.setCapability(FrontCapability.PLATFORM_TRANS_DETAIL_QUERY);
assembler.setTransDate(queryDate.format(DateTimeFormatter.BASIC_ISO_DATE));
assembler.setTransType(PlatformDetailType.TRANSFER_IN.getCode());

FrontRequest<PlatformDetailQueryData> request = new FrontRequest<>();
request.setBaseData(data);
request.setSpecialData(assembler.assemble());

TableDataInfo<PlatformTransDetailItem> page =
    frontQueryApi.queryPlatformTransactionDetails(request);
if (page == null || page.getCode() != 200) {
    throw new IllegalStateException(page == null ? "Front无响应" : page.getMsg());
}

for (PlatformTransDetailItem row : page.getRows()) {
    consumeRow(row);
}
if (page.getTotalPage() != null && pageNo < page.getTotalPage()) {
    scheduleNextPage(pageNo + 1);
}
```

跨日查询必须由上游按日期逐日调用；不要向 Front 传 `beginDate/endDate`。

---

## 11. 分页与数据消费规范

1. `pageNo` 从 1 开始；空值由 Front 当作 1。
2. `pageSize` 只表达上游期望，当前银行原生页大小不能被覆盖。
3. 使用 `rows` 作为本页真实记录；不要用 `total` 推导本页行数。
4. 中信 `total` 是 `totalPage × 固定页大小` 的估算值，最后一页可能不足固定条数。
5. 平安 6050/6073 有响应后过滤，`rows.size()` 可能小于银行 `totalNum`。
6. 平安 6048 一次全返，`totalPage=1`；空结果是否仍为 1 以当前实现为准。
7. 分页失败时 `rows=[]`，不能把空集合直接理解成“查询成功但无记录”，必须先判断 `code`。
8. 每条行记录的 `specialData` 是银行白名单扩展，不保证两家银行 key 相同。

---

## 12. 敏感字段规则

以下字段可能包含账号、户名、会员号或银行流水：

- 请求 `acctNo/mchntMbrId`；
- 返回 `bankAccountCode/userName/payAcctNo/payAcctName`；
- 中信行级 `GOAC/OANM`；
- 任意完整 `specialData`。

调用方不得把这些值明文写日志、异常消息或监控标签。调用方日志只保留必要定位字段，例如租户、业务订单号、
`frontSsn`、查询类型、日期、页码、Front 错误码和耗时。Front 最终 Sender 按内部统一口径记录完整明文
钱包请求/响应 body；上游不得复制该日志。

---

## 13. 错误和重试

| 场景 | 上游处理 |
|---|---|
| `F100001` | 修正请求字段、日期、类型或必填账户信息 |
| `F100003/F100004` | 检查租户银行配置和 `platformCode` |
| `F200002` | 当前银行明确不支持该查询或被查交易类型 |
| `F200003` | 适配器未接入；当前固定用于平安账户状态/余额 |
| `F400001` | 查询通信失败，可按查询退避策略重试 |
| `F400002` | 查询结果未知，保留定位号并再次查询 |
| `F400003` | 银行响应缺字段或格式错误，停止翻页并排障 |
| 明细 `code=500` | 本页失败，不能继续当成功页消费 |
| 状态 `P` | 延迟后继续查询 |
| 状态 `null` | 无法识别，不能认定成功或失败；继续确认/告警 |

查询重试必须有退避、最大次数和人工兜底；不能形成无间隔无限循环。

---

## 14. 联调检查表

- [ ] 使用 `FrontQueryApi` 当前 DTO，没有使用旧 `TransactionDetailItem/FrontPageResult`。
- [ ] 四个 Header 上下文和 `storeId` 完整。
- [ ] 单条查询按 `R<T>` 解析，明细直接按 `TableDataInfo<T>` 解析。
- [ ] 中信账户状态已传 `specialData.acctNo`。
- [ ] 平安账户状态/余额没有被当作可用能力。
- [ ] 交易状态查询的被查 `capability`、日期、订单号和 `frontSsn` 满足银行条件。
- [ ] 平安提现状态查询使用原交易 `frontSsn`，且原提现渠道记录存在。
- [ ] 24/25 使用单日 `transDate`，未传日期范围。
- [ ] 25 的 `transType` 只使用 `01/02/03`；24 只使用 `04`。
- [ ] 中信 24 的 `accountType` 只使用 `01/12/13/17`，未假设系统自动默认 12。
- [ ] 业务金额按分读取，没有再次乘 100。
- [ ] 先判断 `code`，再消费 `rows`；未用 `total` 代替本页行数。
- [ ] `S/P/F/null` 四种状态均有处理分支。
- [ ] 未记录查询请求或返回中的账号、姓名、卡号、会员号和完整 specialData。
