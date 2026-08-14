# Front 交易查询字段契约

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：current
> 最后核对：2026-08-05，中信 v4.7 Word
> 平安状态：全部查询运行时返回 `ADAPTER_NOT_READY`，后续接入登记为
> [平安查询接入待办](13-front后续待办.md)，等待人工逐接口核对

## 1. 范围和固定方法

本文只约束三个交易查询方法：

```java
R<TransactionStatusResult> queryTransactionStatus(
    FrontRequest<TransactionStatusQueryData> request);

TableDataInfo<TransactionDetailItem> queryPlatformTransactionDetails(
    FrontRequest<TransactionDetailQueryData> request);

TableDataInfo<TransactionDetailItem> queryTransactionDetails(
    FrontRequest<TransactionDetailQueryData> request);
```

三个 API 都是内部调用，API、Controller、Application Service 使用相同的方法签名；不得增加
`FrontResponse`。单笔状态查询返回 `R<TransactionStatusResult>`；两个分页明细查询直接返回
`TableDataInfo<TransactionDetailItem>`，禁止再使用 `R` 包裹分页结果。

## 2. 两段请求与三段 Handle 上下文

对外始终是：

```text
FrontRequest
├─ baseData    跨银行公共强类型字段
└─ specialData 当前银行 + 当前查询能力的额外字段（JSONObject）
```

进入 Handle 后统一父类增加租户银行配置：

```text
BankRequestContext
├─ baseData
├─ specialData
└─ accountConfig 通用账户配置
   └─ accountSpecialData 银行账户特殊配置
```

业务 `specialData` 与账户 `accountSpecialData` 禁止合并或整体 `putAll`。Handle 只能按常量白名单逐字段
映射到银行 `reserve`。

## 3. 单笔交易状态查询

### 3.1 Front 基础对象

`TransactionStatusQueryData` 固定包含：

| 字段 | 说明 |
|---|---|
| `tenantId/storeId/platformCode` | 租户、门店和银行路由字段 |
| `originalCapability` | 被查询原交易能力，只允许 `TRANSFER/CONSUME/REFUND/WITHDRAW` |
| `originalTransactionDate` | 原交易日期，格式 `yyyyMMdd` |
| `frontSsn` | 可选的原 Front 流水；当前中信查询不使用，只在结果中原样保留 |
| `bizOrderNo` | 原交易业务主流水，四类查询均必填 |
| `bizSubOrderNo` | 原交易业务子流水；转账、消费、退款必填，提现不向银行上送 |

当前 API capability 仍由交易状态查询入口固定为 `TRANSACTION_STATUS_QUERY`，用于定位当前查询 Handle；
`originalCapability` 只描述被查询原交易类型，用于该 Handle 选择银行查询字段，两者不得混用。
Front 只完成银行报文装配，不校验 `frontSsn` 与业务流水在上游业务系统中是否属于同一笔交易。

### 3.2 中信请求映射

```text
POST /cwap/account/send/query-trans-status
bizFunc = 74
chnlNo  = 0010
```

中信银行协议支持三种原交易定位条件三选一：

1. `ORI_USER_SSN`：原中信流水；
2. `oriTransSsn`（银行语义 `ORI_REQ_SSN`）：原 Front 发起流水；
3. `BUSS_ID + BUSS_SUB_ID`：业务主、子流水。

当前 Front 明确采用业务流水定位，不扫描本地渠道表，也不在三种定位方式间自动猜测。映射固定为：

| 中信字段 | Front 数据来源 | 约束 |
|---|---|---|
| `oriTransDate` | `baseData.originalTransactionDate` | 必填，格式 `yyyyMMdd` |
| `BUSS_ID` | `baseData.bizOrderNo` | 四类原交易能力均必填 |
| `BUSS_SUB_ID` | `baseData.bizSubOrderNo` | `TRANSFER/CONSUME/REFUND` 必填；`WITHDRAW` 不上送 |
| `acctNo` | `specialData.acctNo` | 必填；协议原始 key，由中信 Handle 加密后上送 |
| `TRANS_TYPE` | 中信查询 Handle 本地固定值 `01` | `TRANSFER/CONSUME/REFUND` 上送；`WITHDRAW` 不上送 |
| `laasSsn` | 中信 Handle 生成 | 唯一，调用方不可覆盖 |

状态查询不接受 `specialData.transactionType`。银行字段 key `TRANS_TYPE` 放在
`CiticTransactionStatusQueryContractKeys`，值 `01` 是该接口当前实现的固定报文参数，放在
`CiticQueryHandle`。这一取值依据 lsym 生产/uat 实现中转账、消费查询的现网报文行为；退款按中信 Word
协议同样使用 `01`。在取得真实银行联调证据前不得擅自把转账、消费改为 `00`。

返回中，`frontSsn/bizOrderNo/bizSubOrderNo` 原样保留查询定位值；银行 `status` 映射
`TransactionStatusResult.frontStatus`，`queryId` 映射 `frontQueryId`；确认允许透出的中信流水、日期、
时间等银行差异字段进入返回 `specialData`，不得返回
完整 `reserve`、`errCode/errInfo/sysRespCode/sysRespDesc`。

## 4. 中信平台交易资金账户明细

```text
POST /cwap/account/send/query-trans-details
bizFunc = 25
chnlNo  = 0010
银行固定页大小 = 20
```

### 4.1 Front 请求

`TransactionDetailQueryData` 公共字段：

| 字段 | 说明 |
|---|---|
| `pageNo` | Front 页码，从 1 开始 |
| `pageSize` | 仅表达调用方期望，不能覆盖银行固定 20 条 |

Front 分页协议固定使用 `pageNo/pageSize`，请求和响应都不暴露
`continuationToken`。Handle 仅在内部将 `pageNo` 映射为银行 `PAGE`。

`specialData`：

```json
{
  "transactionDate": "20260805",
  "transactionType": "99"
}
```

| key | 必填 | 说明 |
|---|---|---|
| `transactionDate` | 是 | 单个交易日，`yyyyMMdd`；不支持起止日期 |
| `transactionType` | 是 | `01/02/03/04/99` |

交易类型：`01` 转账入金、`02` 退汇、`03` 支付渠道入金、`04` 提现、`99` 全部。
Word 中 `05` 标为“退款（预留）”，联调确认前常量可保留说明，但 Handle 不接受该值。

映射：

| Front | 中信 reserve |
|---|---|
| `specialData.transactionDate` | `TRANS_DATE` |
| Front 当前页 | `PAGE` |
| `specialData.transactionType` | `TRANS_TYPE` |
| Handle 生成流水 | `laasSsn` |

### 4.2 返回

每条银行明细映射一个 `TransactionDetailItem`：公共日期、时间、类型、金额、资金方向、摘要进入强类型
字段；`JRNO/BKNO/ACSQ/ACTN/FTFL/TSTM/REARK*` 等确认允许返回的银行差异字段逐项进入该条记录的
`specialData`。`TRANS_AMT/CUR_AMT` 的银行单位是元，进入 Front 公共金额字段必须使用十进制精确转分，
禁止浮点运算。

## 5. 中信登记簿交易明细

```text
POST /cwap/account/send/query-trans-details
bizFunc = 24
chnlNo  = 0010
银行固定页大小 = 50
```

`specialData`：

```json
{
  "acctNo": "待查询用户/子账户业务标识",
  "transactionDate": "20260805",
  "transactionType": "98",
  "accountType": "12"
}
```

| key | 必填 | 说明 |
|---|---|---|
| `acctNo` | 是 | 待查询用户/子账户业务标识；Handle 按银行协议加密后映射顶层 `acctNo` |
| `transactionDate` | 是 | 单个交易日，`yyyyMMdd` |
| `transactionType` | 是 | `01/02/03/04/05/06/98/99` |
| `accountType` | 否 | `01/12/13/17`，映射 `registerAttr` |

交易类型：`01` 入金分账、`02` 交易划转、`03` 提现、`04` 提现手续费、`05` 提现退汇、`06` 渠道
来账、`98` 全部明细、`99` 全部汇总。账户类型：`01` 公共调账、`12` 自有资金、`13` 担保、`17`
待结算手续费。

映射：

| Front | 中信 reserve/顶层 |
|---|---|
| `specialData.acctNo` | 顶层 `acctNo`，按银行协议加密 |
| `specialData.transactionDate` | `TRANS_DATE` |
| Front 当前页 | `PAGE` |
| `specialData.transactionType` | `TRANS_TYPE` |
| `specialData.accountType` | `registerAttr` |
| Handle 生成流水 | `laasSsn` |

每条返回的 `REQ_JRN/REGISTER_SSN` 等银行差异字段进入该条 `TransactionDetailItem.specialData`。
`TRANS_AMT/CUR_AMT` 的银行单位是元，进入 Front 公共金额字段必须精确转分。

## 6. 单日和分页约束

中信 v4.7 Word 已明确：公共请求中的 `beginDate/endDate/queryNum/startNum/endNum` 全部“忽略”；
24/25 有效补充域只提供单个 `TRANS_DATE` 和 `PAGE`。因此固定约束为：

- Front specialData 使用 `transactionDate`，不再使用 `startDate/endDate`；
- 中信 Handle 不做跨日期展开，不生成跨日游标；
- 业务系统需要多日数据时，按日期多次调用 Front，由业务层自行聚合；
- 对外统一用 `pageNo/pageSize` 翻页，不返回 `continuationToken`；Handle 将 `pageNo` 映射为银行 `PAGE`；
- `24` 每页 50 条，`25` 每页 20 条，不能被 `pageSize` 覆盖。

## 7. 返回结构

```java
R<TransactionStatusResult>
TableDataInfo<TransactionDetailItem>
```

`TableDataInfo` 固定使用 `code/msg/total/rows`；每一笔明细自己的银行扩展字段必须放在
`TransactionDetailItem.specialData`，不得把多笔明细的 reserve 合并到分页级。银行返回
`TOTAL_NUM/totalNum` 时必须映射为 `total`，不得把总页数冒充总记录数。

业务成功示例：

```json
{
  "code": 200,
  "msg": "查询成功",
  "rows": [],
  "total": 0
}
```

业务失败示例：

```json
{
  "code": 500,
  "msg": "银行拒绝交易",
  "rows": [],
  "total": 0
}
```

## 8. common-core 常量

字段名、枚举值和注释统一放在：

```text
com.chinaums.common.core.constant.front
├─ CiticTransactionStatusQueryContractKeys
├─ CiticPlatformTransactionDetailQueryContractKeys
└─ CiticTransactionDetailQueryContractKeys
```

业务系统可依赖这些常量组装 specialData，但银行原始字段只能由 Handle 使用。禁止直接提交
`TRANS_DATE/PAGE/TRANS_TYPE/ORI_USER_SSN/acctNo` 等银行字段。

## 8.1 中信账户余额查询（35/36/46，2026-08-14 核对）

接口：`POST /cwap/account/send/query-acct-info`，`chnlNo=0010`。

账户范围 → bizFunc：

| Front accountScope | bizFunc | 语义 | registerAttr |
|---|---|---|---|
| `PLATFORM_FUNDS_ACCOUNT` | 35 | 交易资金账户余额 | 不要求 |
| `USER_SUB_ACCOUNT` | 46 | 用户余额 | **必填** |
| `FUNCTIONAL_ACCOUNT` | 36 | 公共登记簿余额 | **必填** |

`specialData`：

| key | 必填 | 说明 |
|---|---|---|
| `acctNo` | 是 | 用户/账户编号，Handle 加密后映射顶层 `acctNo` |
| `registerAttr` | 46/36 协议必填 | 登记簿类型：`00` 公共计息收费、`12` 自有资金、`13` 担保、`17` 待结算手续费、`14` 用户登记簿（lsym UAT 实测有效，Word 枚举未列）、`TA` 交易资金账户、`RO` 平台剩余透支额度 |

> 协议必填但 **front 不强制校验**（2026-08-14 用户确认）：`registerAttr` 缺失时直接透传给银行，
> 由银行返回 `D5951105 请求参数校验失败`。

响应金额单位（Word v4.7 + lsym UAT 实测）：

| bizFunc | 字段 | 单位 |
|---|---|---|
| 35 | `PRE_AMOUNT`（上一日余额） | 分 |
| 36 | `balance` | 分 |
| 46 | `balance` / `withdrawAmt` / `preAmount` | 元（Handle 统一元转分） |

46 成功响应实测（lsym UAT 2026-08-14）：

```json
{"sysRespCode":"00000","withdrawAmt":699690.17,"preAmount":699690.17,
 "balance":699690.17,"remark1":0,"remark3":"699690.17|0.00|0","errCode":"D5000000","errInfo":"success"}
```

注意：46 查询的 `acctNo`（用户编号）必须属于请求 `mchntMbrId`（商户编号），否则返回
`P0030 用户编号需与商户编号一致`；用户编号不存在返回 `JU005 用户编号不存在`。

常量：`CiticAccountQueryContractKeys`（`RESPONSE_BALANCE/PRE_AMOUNT/WITHDRAW_AMOUNT/FROZEN_BALANCE/
FUNCTIONAL_ACCOUNT_TYPE`）。

## 9. 当前实现状态和 TODO

- 中信 74/24/25 的路径、bizFunc、chnlNo、specialData 白名单和单日规则已确认；
- 中信 35/36/46 账户余额查询已按 Word v4.7 + lsym UAT 实测核对：46/36 的
  `specialData.registerAttr` 必填，35 不要求；35/36 响应金额单位分、46 单位元（2026-08-14）；
- 中信 74 的 `acctNo`、原中信流水需要持久层按原渠道记录补齐；
- 中信 24/25 当前只做单日分页，不支持跨日；
- 平安账户状态、账户余额、交易状态、平台明细、交易明细全部先标
  `PENDING_INTEGRATION`；现有代码仅作为分析草稿，不得进入真实路由；
- 平安查询字段、多个 bizFunc 聚合和不同返回数组结构由人工逐接口核对后再更新本文档。
