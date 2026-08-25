# Front 交易查询字段契约

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：current
> 最后核对：2026-08-25（字段沿用既有确认；内部结构同步三域 Capability）
> 平安状态：交易状态查询与两类明细查询已实现（17 号 spec，2026-08-19：明细 24-04→6073、
> 25-01/03→6050、25-02→6048）；账户状态/余额按用户裁决固定返回 `ADAPTER_NOT_READY`，
> `TODO-001` 已关闭

## 1. 范围和固定方法

本文只约束三个交易查询方法：

```java
R<TransStatusResult> queryTransactionStatus(
    FrontRequest<TransStatusQueryData> request);

TableDataInfo<PlatformTransDetailItem> queryPlatformTransactionDetails(
    FrontRequest<PlatformDetailQueryData> request);

TableDataInfo<AccountTransDetailItem> queryTransactionDetails(
    FrontRequest<AccountDetailQueryData> request);
```

三个 API 都是内部调用，API、Controller、Application Service 使用相同的方法签名；不得增加
`FrontResponse`。单笔状态查询返回 `R<TransStatusResult>`；两个分页明细查询直接返回
`TableDataInfo<PlatformTransDetailItem>`（25）与 `TableDataInfo<AccountTransDetailItem>`（24），禁止再使用 `R` 包裹分页结果。

## 2. 两段请求与 Query/Account Slot

对外始终是：

```text
FrontRequest
├─ baseData    跨银行公共强类型字段
└─ specialData 当前银行 + 当前查询能力的额外字段（JSONObject）
```

进入 Front 后由所属域 ExecuteNode 加载租户银行配置：

```text
交易状态/两类明细 → FrontQuerySlot
账户状态/账户余额 → FrontAccountSlot

域 Slot
├─ request/baseData/specialData
├─ capability
└─ accountConfig/accountSpecialData
```

业务 `specialData` 与账户 `accountSpecialData` 禁止合并或整体 `putAll`。Capability 只能按常量白名单逐字段
映射到银行 `reserve`。

## 3. 单笔交易状态查询

> 2026-08-17 用户裁决：baseData 字段去 original 前缀（capability/transDate）——
> 本对象本身就是状态查询请求；与查询入口的 API capability（TRANS_STATUS_QUERY，路由用）
> 不得混用的原则不变。

**查询统一路线（用户裁决 2026-08-17）**：全部查询能力最终统一为"银行无关统一请求 +
各银行 Capability 常量构建 wire"模式。交易状态查询已完成（`QueryTransStatusRequest`）；
平台明细/账户明细已完成迁移；账户状态/余额按用户裁决保留挡板，不再作为待迁移项。
`PingAnQueryRequest` 仅作为挡板后的历史草稿类保留，未经用户重新打开不得启用。

### 3.1 Front 基础对象

`TransStatusQueryData` 固定包含：

| 字段 | 说明 |
|---|---|
| `tenantId/storeId/platformCode` | 租户、门店和银行路由字段 |
| `capability` | 被查询原交易能力，允许 `TRANSFER/CONSUME/REFUND/WITHDRAW/RECHARGE`（RECHARGE 仅平安 04） |
| `transDate` | 原交易日期，格式 `yyyyMMdd` |
| `frontSsn` | 原 Front 渠道流水号（交易响应 `FrontTransResult.frontSsn` 回传、渠道表 `front_ssn` 落库）；**平安必填**（按其定位原交易，映射 `oriTransSsn`），中信可选（仅结果回显）（2026-08-17 修订） |
| `bizOrderNo` | 原交易业务主流水，四类查询均必填 |
| `bizSubOrderNo` | 原交易业务子流水；转账、消费、退款必填，提现不向银行上送 |

当前 API capability 仍由交易状态查询入口固定为 `TRANS_STATUS_QUERY`，用于定位当前 Query Capability；
`baseData.capability` 只描述被查询原交易类型，用于该 Capability 选择银行查询字段，两者不得混用。
Front 只完成银行报文装配，不校验 `frontSsn` 与业务流水在上游业务系统中是否属于同一笔交易。

平安单笔状态查询的流水规则固定为：

```text
baseData.frontSsn
    = 原交易请求 transSsn
    = 原渠道记录 front_ssn
    → 平安查询报文 oriTransSsn
```

不得改用原交易应答 `queryId/bank_query_id` 或 `USER_SSN/bank_user_ssn`。该规则只约束单笔状态查询，
与 §5.1 的 6073 明细关联是两条不同链路。

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
| `oriTransDate` | `baseData.transDate` | 必填，格式 `yyyyMMdd` |
| `BUSS_ID` | `baseData.bizOrderNo` | 四类原交易能力均必填 |
| `BUSS_SUB_ID` | `baseData.bizSubOrderNo` | `TRANSFER/CONSUME/REFUND` 必填；`WITHDRAW` 不上送 |
| `acctNo` | `specialData.acctNo` | 必填；协议原始 key，由中信 Query Capability 加密后上送 |
| `TRANS_TYPE` | 中信 Query Capability 本地固定值 `01` | `TRANSFER/CONSUME/REFUND` 上送；`WITHDRAW` 不上送 |
| `laasSsn` | 中信 Query Capability 生成 | 唯一，调用方不可覆盖 |

状态查询不接受 `specialData.transType`。银行字段 key `TRANS_TYPE` 放在
`CiticTransStatusQueryContractKeys`，值 `01` 是该接口当前实现的固定报文参数，放在
lsym `CiticQueryHandle`。这一取值依据 lsym 生产/uat 实现中转账、消费查询的现网报文行为；退款按中信 Word
协议同样使用 `01`。在取得真实银行联调证据前不得擅自把转账、消费改为 `00`。

返回中，`frontSsn/bizOrderNo/bizSubOrderNo` 原样保留查询定位值；银行 `status` 映射
`TransStatusResult.frontStatus`，`queryId` 映射 `frontQueryId` 并同时透传进入返回
`specialData`；确认允许透出的中信流水、日期、时间等银行差异字段进入返回 `specialData`，不得返回
完整 `reserve`、`errCode/errInfo/sysRespCode/sysRespDesc`。

## 4. 中信平台交易资金账户明细

> **2026-08-19 对外契约重构（17 号 spec）**：对外类型枚举收窄为 `PlatformDetailType`（01/02/03），
> 返回 `TableDataInfo<PlatformTransDetailItem>`（12 主字段 + specialData，transAmt 单位分），
> `TableDataInfo` 新增 `totalPage`（total 即 totalNum，中信按 TOTAL_PAGE×20 估算）；
> 平安侧 01/03→6050（共用请求按 inAcctType 过滤回填）、02→6048（无日期无分页一次全返，
> frontSeqNo=termSsn）。字段映射见 17 号 §1.2/§1.3。

```text
POST /cwap/account/send/query-trans-details
bizFunc = 25
chnlNo  = 0010
银行固定页大小 = 20
```

### 4.1 Front 请求

`PlatformDetailQueryData` 公共字段：

| 字段 | 说明 |
|---|---|
| `pageNo` | Front 页码，从 1 开始 |
| `pageSize` | 仅表达调用方期望，不能覆盖银行固定 20 条 |

Front 分页协议固定使用 `pageNo/pageSize`，请求和响应都不暴露
`continuationToken`。Capability 仅在内部将 `pageNo` 映射为银行 `PAGE`。

`specialData`：

```json
{
  "transDate": "20260805",
  "transType": "01"
}
```

| key | 必填 | 说明 |
|---|---|---|
| `transDate` | 是 | 单个交易日，`yyyyMMdd`；不支持起止日期 |
| `transType` | 是 | 对外仅 `01/02/03`（`PlatformDetailType` 枚举，04/99 在 Capability 协议层保留不对外） |

交易类型：`01` 转账入金、`02` 退汇、`03` 支付渠道入金、`04` 提现、`99` 全部。
Word 中 `05` 标为“退款（预留）”，联调确认前常量可保留说明，但 Capability 不接受该值。

映射：

| Front | 中信 reserve |
|---|---|
| `specialData.transDate` | `TRANS_DATE` |
| Front 当前页 | `PAGE` |
| `specialData.transType` | `TRANS_TYPE` |
| Capability 生成流水 | `laasSsn` |

### 4.2 返回

每条银行明细映射一个 `PlatformTransDetailItem`（25，12 主字段 + specialData）：
`mchntMbrId / bankAccountCode / userName / transType / transDate / transTime / transAmt(分) /
payAcctNo / payAcctName / remark / frontSeqNo / bankMemberCode` + `specialData`。
中信 TRANS_AMT（元）×100 精确转分为 `transAmt`；`CUR_AMT`（原值+currentAmountCent 双保留）、
`C_D_FLAG`（资金方向）、`JRNO/BKNO/ACSQ/ACTN/FTFL/TSTM/REARK1/REARK3` 等银行差异字段逐项进入
`specialData` 兜底。禁止浮点运算。

## 5. 中信登记簿交易明细

> **2026-08-19 对外契约重构（17 号 spec）**：对外类型枚举收窄为 `AccountDetailType`（仅 04 提现手续费），
> 返回 `TableDataInfo<AccountTransDetailItem>`（11 主字段 + specialData，fee=commission 单位分、空/0 返回 0
> 不过滤）；`TableDataInfo` 新增 `totalPage`（中信按 TOTAL_PAGE×50 估算）；请求对象拆分为
> `AccountDetailQueryData`。平安侧 04→6073（queryFlag=2 + functionFlag 当日/历史 + tranStatus=0 过滤 +
> frontSeqNo 按 `tenantId + bankQueryId` 查原提现渠道表补订单号）。字段映射见 17 号 §0.9/§1.2/§1.3。

### 5.1 平安 6073 流水关联契约（2026-08-19 裁决）

| 阶段 | 平安协议字段 | Front 保存/使用 | 约束 |
|---|---|---|---|
| 原提现请求 | `transSsn` | 渠道表 `front_ssn` | Front 生成并发送给银行，不参与 6073 `frontSeqNo` 关联 |
| 原提现应答 | `queryId` | `bank_query_id`，同时作为对外 `frontQueryId` | 用途 36 在平安 v5.5 中明确标注为 `FrontSeqNo/见证系统流水号` |
| 银行显式应答流水 | `USER_SSN/ssn`（如实际应答存在） | `bank_user_ssn` | 与 `queryId` 分字段保存，不作 6073 回查的文档默认依据 |
| 6073 明细行 | `frontSeqNo` | `AccountTransDetailItem.frontTransSsn` | 按 `tenant_id + bank_query_id = frontSeqNo` 回查原提现记录 |

中信可以直接使用 `USER_SSN` 类银行侧流水；平安提现的协议字段名不同，
必须保留 `queryId` 的原始字段语义，只在 6073 关联规则中使用文档明确的
`queryId = FrontSeqNo = recordList.frontSeqNo` 关系。禁止为了对齐中信而把平安 `queryId`
全局改名为 `ssn`。

特别注意：平安文档在此使用的 `FrontSeqNo` 是应答 `queryId` 的业务说明，不是请求
`transSsn/front_ssn`。因此：单笔状态查询查 `front_ssn`，6073 订单补全查 `bank_query_id`；
二者禁止互换。

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
  "transDate": "20260805",
  "transType": "04",
  "accountType": "12"
}
```

| key | 必填 | 说明 |
|---|---|---|
| `acctNo` | 是 | 待查询用户/子账户业务标识；Capability 按银行协议加密后映射顶层 `acctNo` |
| `transDate` | 是 | 单个交易日，`yyyyMMdd` |
| `transType` | 是 | 对外仅 `04`（`AccountDetailType` 枚举；01/02/03/05/06/98/99 在 Capability 协议层保留不对外） |
| `accountType` | 否 | `01/12/13/17`，映射 `registerAttr` |

交易类型：`01` 入金分账、`02` 交易划转、`03` 提现、`04` 提现手续费、`05` 提现退汇、`06` 渠道
来账、`98` 全部明细、`99` 全部汇总。账户类型：`01` 公共调账、`12` 自有资金、`13` 担保、`17`
待结算手续费。

映射：

| Front | 中信 reserve/顶层 |
|---|---|
| `specialData.acctNo` | 顶层 `acctNo`，按银行协议加密 |
| `specialData.transDate` | `TRANS_DATE` |
| Front 当前页 | `PAGE` |
| `specialData.transType` | `TRANS_TYPE` |
| `specialData.accountType` | `registerAttr` |
| Capability 生成流水 | `laasSsn` |

每条返回的 `REQ_JRN/REGISTER_SSN/MCHNT_ID/C_D_FLAG/CUR_AMT/GOAC/OANM/DIGEST` 等银行差异字段进入该条 `AccountTransDetailItem.specialData`（`CUR_AMT` 原值 + `currentAmountCent` 换算值均保留）。
中信 TRANS_AMT（元）×100 精确转分为 `fee`。

## 6. 单日和分页约束

中信 v4.7 Word 已明确：公共请求中的 `beginDate/endDate/queryNum/startNum/endNum` 全部“忽略”；
24/25 有效补充域只提供单个 `TRANS_DATE` 和 `PAGE`。因此固定约束为：

- Front specialData 使用 `transDate`，不再使用 `startDate/endDate`；
- 中信 Query Capability 不做跨日期展开，不生成跨日游标；
- 业务系统需要多日数据时，按日期多次调用 Front，由业务层自行聚合；
- 对外统一用 `pageNo/pageSize` 翻页，不返回 `continuationToken`；Capability 将 `pageNo` 映射为银行 `PAGE`；
- `24` 每页 50 条，`25` 每页 20 条，不能被 `pageSize` 覆盖。

## 7. 返回结构

```java
R<TransStatusResult>
TableDataInfo<PlatformTransDetailItem>  // 25 平台明细
TableDataInfo<AccountTransDetailItem>   // 24 账户明细
```

`TableDataInfo` 固定使用 `code/msg/total/totalPage/rows`；每一笔明细自己的银行扩展字段必须放在
`PlatformTransDetailItem.specialData`（25）/ `AccountTransDetailItem.specialData`（24），不得把多笔明细的 reserve 合并到分页级。银行返回
`TOTAL_NUM/totalNum` 时必须映射为 `total`（总记录数），`TOTAL_PAGE` 映射为 `totalPage`（总页数），不得把总页数冒充总记录数。

业务成功示例：

```json
{
  "code": 200,
  "msg": "查询成功",
  "rows": [],
  "total": 0,
  "totalPage": 0
}
```

业务失败示例：

```json
{
  "code": 500,
  "msg": "银行拒绝交易",
  "rows": [],
  "total": 0,
  "totalPage": 0
}
```

## 8. common-core 常量

字段名、枚举值和注释统一放在：

```text
com.chinaums.common.core.constant.front
├─ CiticTransStatusQueryContractKeys
├─ CiticPlatformTransDetailQueryContractKeys
└─ CiticTransDetailQueryContractKeys
```

业务系统可依赖这些常量组装 specialData，但银行原始字段只能由 Capability 使用。禁止直接提交
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
| `acctNo` | 是 | 用户/账户编号，Account Capability 加密后映射顶层 `acctNo` |
| `registerAttr` | 46/36 协议必填 | 登记簿类型：`00` 公共计息收费、`12` 自有资金、`13` 担保、`17` 待结算手续费、`14` 用户登记簿（lsym UAT 实测有效，Word 枚举未列）、`TA` 交易资金账户、`RO` 平台剩余透支额度 |

> 协议必填但 **front 不强制校验**（2026-08-14 用户确认）：`registerAttr` 缺失时直接透传给银行，
> 由银行返回 `D5951105 请求参数校验失败`。该透传对 35 同样生效：35 协议不要求 `registerAttr`，
> 但 specialData 提供时 Capability 一并上送。

返回字段映射（2026-08-17 核对）：46 的 `balance`→`balance`、`withdrawAmt`→`withdrawableBalance`、
`preAmount`→`previousBalance`（三者单位元，Account Capability 统一元转分）；35 的 `PRE_AMOUNT`→`balance`
（单位分，直取）；36 的 `balance`→`balance`（单位分，直取）。

响应金额单位（Word v4.7 + lsym UAT 实测）：

| bizFunc | 字段 | 单位 |
|---|---|---|
| 35 | `PRE_AMOUNT`（上一日余额） | 分 |
| 36 | `balance` | 分 |
| 46 | `balance` / `withdrawAmt` / `preAmount` | 元（Account Capability 统一元转分） |

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
- **两类明细查询纳入组装工具（2026-08-18）**：PLATFORM_TRANS_DETAIL_QUERY（25）与
  TRANS_DETAIL_QUERY（24）进入 15 号 spec §4.3 查询格——25 输出
  {transDate, transType}，24 输出 {acctNo, transDate, transType[, accountType]}；
  明细条件为 Front 契约键（Capability 再映射 TRANS_DATE/TRANS_TYPE/registerAttr），取值枚举在组装器
  用 ContractKeys 值常量校验（25 的 05 预留值仍拒绝）；平安侧明细查询已启用（24→6073、25→6050/6048），6073 订单按 tenantId+bankQueryId(frontSeqNo) 回查渠道表；
- 中信 35/36/46 账户余额查询已按 Word v4.7 + lsym UAT 实测核对：46/36 的
  `specialData.registerAttr` 必填，35 不要求；35/36 响应金额单位分、46 单位元（2026-08-14）；
- 中信 74 的 `acctNo`、原中信流水需要持久层按原渠道记录补齐；
- **交易状态查询三件套（2026-08-17 用户裁决后落地）**：
  1. 组装：TRANS_STATUS_QUERY 纳入组装工具（中信 `pay.bankEAccountId→acctNo`、
     平安 `pay.bankEMemberCode→mchntMbrId`，各 1 要素，Capability 内 SM2；
     **提现查询（03）专用的 cardNoEnc 为原提现发起时的银行卡号，Capability 从平安提现渠道表
     按 (tenantId, frontSsn) 回查**——lsym 生产规则 + 用户指出修正，见 15 号 §4.3）；
  1b. **银行请求合并（用户裁决 2026-08-17，同日按用户五点修正定稿）**：
     - 统一请求 `channel/protocol/QueryTransStatusRequest` **银行无关**，只含
       ①定位基础参数（capability/transDate/bizOrderNo/bizSubOrderNo/
       frontSsn，原样来自 baseData，全部需要传入）＋②组装 specialData（账户要素协议键原样）；
       由 `QueryTransStatusRequest` 实例构造（无 static，每次查询新建、用完即弃），两家银行 Query Capability 共用；
     - 报文信封（transSsn/transTime/mchntId/laasSsn/bizFunc/chnlNo 等）**不在请求上**：
       各 Capability 用自身常量（bizFunc/chnlNo 配置死）、租户账户配置（mchntId/tenantId）与
       序列生成器生成；wire 直接以 JSONObject 构建，键全部走常量（FrontBankRequestConstants
       补 ORIGINAL_TRANSACTION_SSN/ORIGINAL_TRANSACTION_DATE/EXTERNAL_PLATFORM_SSN）；
     - 中信 `CiticQueryTransStatusRequest` 删除，平安 `PingAnQueryRequest` 移除状态查询
       专用字段（仅账户状态/余额/明细使用）；差异消化点：账户要素=组装 specialData、
       类型=capability 常量转译、定位=baseData 映射；
  2. 平安 Query Capability 已实现（去掉 PENDING_INTEGRATION）：bizFunc 按被查原交易能力选择
     （WITHDRAW→03，转账/消费/退款→02，lsym 生产规则）；`frontSsn` 平安必填（平安按原交易银行
     流水号 oriTransSsn 定位，中信按日期+订单号定位不需要）；`oriTransDate` 有值即上送；
     `cardNoEnc` 由 Capability 从平安提现渠道表按 (tenantId, frontSsn) 回查后 SM2 上送（不经调用方/specialData，2026-08-17 用户裁决）；reserve 仅 mrchCode/txnClientNo 走账户配置；
     联调待验；
  3. 状态映射改内部三态：`TransStatusResult.frontStatus` → String，常量
     `FrontInternalTransStatus`（S 成功/P 处理中/F 失败），银行状态码在各 Query Capability 内以
     带注释常量维护，未知/空码返回 null。映射表：
     - 中信：00 受理→P；01 成功→S；02 失败→F；03 处理中→P；**04 已退款/05 已退汇→S
       （资金经充值接口退回，后续由其他流程处理，用户确认）**；其他/空→null
     - 平安：0 成功→S；1 失败→F；2 待确认/5 待处理/6 处理中→P；其他/空→null
     - 交易接口 `FrontTransResult.frontStatus` 的 FrontTransactionStatus 枚举口径不变，两者并存；
  4. 交易类型区分（用户指出补充，lsym 核对；2026-08-17 晚按用户裁决接入充值）：
     - `FrontCapability` 新增 `RECHARGE`（充值，不带 org 前缀——充值本身是交易能力，
       状态查询经 `capability=RECHARGE` 直接路由，不另设查询能力）；
     - **RECHARGE 当前仅平安状态查询使用（bizFunc=04）**；中信不接入，`capability=
       RECHARGE` 在中信走 default 分支返回"不支持原交易能力"（用户确认 2026-08-17）；
     - 中信按 `reserve.TRANS_TYPE` 两模式：转账/消费送 TRANS_TYPE=01+BUSS_SUB_ID；
       提现只送 BUSS_ID（lsym 生产规则）；REFUND 沿用 01 为推断值，lsym 无退款查询先例，
       **待协议核对**；
     - 平安按 bizFunc 三模式：WITHDRAW→03、RECHARGE→04、转账/消费/退款→02；
     - 充值交易能力接入时再注册 Transaction Capability 并补中信分支；
- 中信 24/25 当前只做单日分页，不支持跨日；
- 平安交易状态、平台明细、账户明细已实现；账户状态/余额按用户裁决固定保留
  `PENDING_INTEGRATION/ADAPTER_NOT_READY` 挡板，不再作为待核对项。
