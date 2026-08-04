# Front 交易查询字段契约

## 1. 文档范围

本文约束以下三个 Front 查询能力：

```text
queryTransactionStatus
queryPlatformTransactionDetails
queryTransactionDetails
```

当前阶段已经确认中信单笔状态查询和两个明细查询；本文重点固定中信明细查询的接口边界、
`baseData/specialData` 归属、功能码、分页及返回映射。具体银行 HTTP、签名、加密和按日分页尚未实现。

银行协议依据：

```text
cateringsass/docs/中信E管家产品客户钱包应用平台_接口文档-内部集成平台v4.7.doc
```

旧代码只用于定位历史调用，不作为新接口结构：

```text
mdl ZxTransQueryHandle
mdl ZxTransQueryServiceImpl
lsym UAT ZxTransQueryHandle
```

---

## 2. 固定的 Front 接口

```java
R<TransactionStatusResult> queryTransactionStatus(
    FrontRequest<TransactionStatusQueryData> request);

R<FrontPageResult<TransactionDetailItem>> queryPlatformTransactionDetails(
    FrontRequest<TransactionDetailQueryData> request);

R<FrontPageResult<TransactionDetailItem>> queryTransactionDetails(
    FrontRequest<TransactionDetailQueryData> request);
```

明细查询只保留上述两个业务入口：

- 平台账户交易明细使用 `queryPlatformTransactionDetails()`；
- 用户/子账户/登记簿交易明细使用 `queryTransactionDetails()`；
- 不再按提现、手续费、退汇、来账等交易类型增加 Handle 方法；
- 不再增加 `queryWithDrawFee()`，提现手续费由明细查询的交易类型筛选覆盖；
- `bizFunc/chnlNo` 是 Handle 固定协议值，不进入请求 `specialData`。

---

## 3. 统一明细请求对象

### 3.1 `baseData`

```json
{
  "tenantId": "tenant-001",
  "storeId": "store-001",
  "platformCode": "CITIC",
  "accountId": "业务账户标识",
  "pageNo": 1,
  "pageSize": 50,
  "continuationToken": null
}
```

字段规则：

| 字段 | 平台明细 | 账户明细 | 说明 |
|---|---|---|---|
| `tenantId` | 必填 | 必填 | 加载租户银行配置 |
| `storeId` | 必填 | 必填 | 请求门店定位 |
| `platformCode` | 必填 | 必填 | 银行路由 |
| `accountId` | 不使用 | 必填 | 用户/子账户业务标识，由 Handle 转换并加密为中信 `acctNo` |
| `pageNo` | 可选 | 可选 | Front 逻辑页码，不等于跨日期时的银行页码 |
| `pageSize` | 可选 | 可选 | Front 期望值；不能覆盖银行固定页大小 |
| `continuationToken` | 续查必填 | 续查必填 | 只能回传上次 Front 返回值，业务方不得拼接银行页码 |

`TransactionDetailQueryData` 不再定义以下字段：

```text
startDate
endDate
transactionType
direction
```

日期范围和交易类型是当前银行、当前查询能力的动态筛选条件，放入请求 `specialData`。
中信协议没有请求方向筛选字段，不能在公共对象中声明一个银行无法正确分页实现的方向条件。

### 3.2 `specialData`

中信平台账户交易明细示例：

```json
{
  "startDate": "20260801",
  "endDate": "20260804",
  "transactionType": "03"
}
```

中信登记簿交易明细示例：

```json
{
  "startDate": "20260801",
  "endDate": "20260804",
  "transactionType": "04",
  "accountType": "17"
}
```

字段规则：

| specialData Key | 平台明细 `25` | 登记簿明细 `24` | 说明 |
|---|---|---|---|
| `startDate` | 必填 | 必填 | yyyyMMdd，包含当天 |
| `endDate` | 必填 | 必填 | yyyyMMdd，包含当天，不能早于开始日期 |
| `transactionType` | 必填 | 必填 | 必须按对应 `bizFunc` 的枚举校验，两种接口的相同值含义不同 |
| `accountType` | 禁止 | 可选 | 登记簿/账户类型，映射银行 `registerAttr` |

业务系统不得传入或覆盖：

```text
bizFunc
chnlNo
acctNo
TRANS_DATE
PAGE
laasSsn
appId/appKey/url/mchntId/mchntMbrId
```

---

## 4. 中信平台账户交易明细

### 4.1 协议固定值

```text
Front方法  = queryPlatformTransactionDetails
银行路径   = /cwap/account/send/query-trans-details
bizFunc    = 25
chnlNo     = 0010
银行产品   = 交易资金账户明细查询（21000039）
银行页大小 = 每页最多20条
```

请求映射：

| 来源 | 银行字段 | 规则 |
|---|---|---|
| Handle | `transSsn` | 每次银行调用重新生成 |
| Handle | `transTime` | 每次银行调用重新生成 |
| 账户通用配置 | `mchntId/mchntMbrId` | 禁止业务系统覆盖 |
| Handle 常量 | `bizFunc/chnlNo` | 固定 `25/0010` |
| `specialData.startDate/endDate` | `reserve.TRANS_DATE` | 按日展开，每次只传一天 |
| 当前续查位置 | `reserve.PAGE` | 当前日期的银行页码 |
| `specialData.transactionType` | `reserve.TRANS_TYPE` | 按下表校验 |
| Handle | `reserve.laasSsn` | 每次银行调用生成 |

交易类型：

| `transactionType` | 银行含义 | 注意点 |
|---:|---|---|
| `01` | 转账入金 | 返回用户名称、用户编号 |
| `02` | 退汇 | 与退款不是同一语义 |
| `03` | 支付渠道入金 | 旧平台充值任务实际使用该类型 |
| `04` | 提现 | 平台资金账户出金明细 |
| `05` | 退款 | 中信 v4.7 标注预留，联调确认前不得假定可用 |
| `99` | 所有 | 平台资金账户全部支持类型 |

### 4.2 返回映射

查询级 `totalNum/TOTAL_PAGE` 只描述当前银行交易日。`TOTAL_PAGE` 用于判断当前日期是否还有下一页；
跨日期续查无法直接把单日 `totalNum` 当作全范围总数，未完成全日期计数时 `FrontPageResult.total` 留空。
`LIST.ROWS` 单条时可能是对象、多条时可能是数组，响应解析器必须统一转换为列表。

| 中信字段 | Front 字段 | 规则 |
|---|---|---|
| `TRANS_DT` | `transactionDate` | yyyyMMdd |
| `TRANS_TM` | `transactionTime` | HHmmss |
| `TRANS_TP` | `transactionType` | 归一化后写公共字段，原值可进入明细 `specialData` |
| `C_D_FLAG` | `direction` | `C → INCOME`，`D → EXPENSE` |
| `TRANS_AMT` | `amount` | 银行单位元，精确换算为人民币分 |
| `DIGEST/REMARK` | `remark` | 优先选择有业务意义且非空的字段 |
| 无稳定字段 | `frontSsn` | 允许为空，禁止用银行流水冒充 Front 流水 |
| 无 | `bizOrderNo/bizSubOrderNo` | 允许为空 |

每条明细的响应 `specialData` 白名单候选：

```text
MCHNT_ID
USER_ID
USER_NM
TRANS_TP
CUR_AMT
JRNO
BKNO
ACSQ
ACTN
FTFL
TSTM
REARK1
REARK2
REARK3（明确业务用途后才返回）
```

`PAY_ACCNO/PAY_ACCNAME` 是敏感对手方信息，默认只保存脱敏渠道快照，不原样返回、不写日志。
`CUR_AMT` 银行单位为元；若保留在 `specialData`，必须通过字段说明或规范化 Key 明确单位，不能让业务方
误认为分。

---

## 5. 中信登记簿/账户交易明细

### 5.1 协议固定值

```text
Front方法  = queryTransactionDetails
银行路径   = /cwap/account/send/query-trans-details
bizFunc    = 24
chnlNo     = 0010
银行产品   = 登记簿交易明细查询（21000029）
银行页大小 = 每页最多50条
```

请求映射：

| 来源 | 银行字段 | 规则 |
|---|---|---|
| Handle | `transSsn/transTime` | 每次银行调用生成 |
| 账户通用配置 | `mchntId/mchntMbrId` | 禁止业务系统覆盖 |
| Handle 常量 | `bizFunc/chnlNo` | 固定 `24/0010` |
| `baseData.accountId` | `acctNo` | 中信用户编号，按协议加密 |
| `specialData.startDate/endDate` | `reserve.TRANS_DATE` | 按日展开，每次只传一天 |
| 当前续查位置 | `reserve.PAGE` | 当前日期的银行页码 |
| `specialData.transactionType` | `reserve.TRANS_TYPE` | 按下表校验 |
| `specialData.accountType` | `reserve.registerAttr` | 可选，按登记簿/账户类型表校验 |
| Handle | `reserve.laasSsn` | 每次银行调用生成 |

交易类型：

| `transactionType` | 银行含义 | 注意点 |
|---:|---|---|
| `01` | 入金分账 | 担保白名单商户查询支付渠道入金时使用 |
| `02` | 交易划转 | 登记簿之间资金划转 |
| `03` | 提现 | 用户或平台提现相关登记簿明细 |
| `04` | 提现手续费 | 覆盖旧 `queryWithDrawFee()` 独立方法 |
| `05` | 提现退汇 | 提现退回相关明细 |
| `06` | 渠道来账 | 不得与 `01` 未经业务确认地合并成“实收” |
| `98` | 所有，返回明细类型 | 返回银行细分交易类型，例如 `JJXF/JJTK` |
| `99` | 所有，返回汇总类型 | 与 `98` 语义不同，不得合并 |

登记簿/账户类型：

| `accountType` | 银行含义 |
|---:|---|
| `01` | 公共调账登记簿 |
| `12` | 平台自有资金登记簿 |
| `13` | 担保登记簿 |
| `17` | 待结算手续费登记簿 |

旧 UAT 示例出现过 `registerAttr=00`，但中信 v4.7 Word 当前定义为 `01/12/13/17`。新契约先以 Word 为准；
如银行联调确认仍要求 `00`，必须更新常量、注释和本文后再开放，不能让调用方自由传任意值。

### 5.2 返回映射

查询级 `totalNum/TOTAL_PAGE` 只描述当前银行交易日。`TOTAL_PAGE` 用于判断当前日期是否还有下一页；
跨日期续查无法直接把单日 `totalNum` 当作全范围总数，未完成全日期计数时 `FrontPageResult.total` 留空。
`LIST.ROWS` 单条时可能是对象、多条时可能是数组，响应解析器必须统一转换为列表。

| 中信字段 | Front 字段 | 规则 |
|---|---|---|
| `MCHNT_ORDER_ID` | `bizOrderNo` | 业务主订单号 |
| `MCHNT_ORDER_SUB_ID` | `bizSubOrderNo` | 业务子订单号 |
| `TRANS_DT` | `transactionDate` | yyyyMMdd |
| `TRANS_TM` | `transactionTime` | HHmmss |
| `TRANS_TYPE` | `transactionType` | 归一化后写公共字段，原值可进入明细 `specialData` |
| `C_D_FLAG` | `direction` | `C → INCOME`，`D → EXPENSE` |
| `TRANS_AMT` | `amount` | 银行单位元，精确换算为人民币分 |
| `DIGEST` | `remark` | 公共摘要 |
| 无稳定字段 | `frontSsn` | 允许为空，禁止用 `REQ_JRN` 冒充 Front 流水 |

每条明细的响应 `specialData` 白名单候选：

```text
MCHNT_ID
USER_ID
USER_NAME
TRANS_TYPE
REQ_JRN
REGISTER_SSN
CUR_AMT
```

`GOAC/OANM` 是敏感对手方账号和户名，默认只保存脱敏渠道快照，不原样返回、不写日志。

---

## 6. 日期范围与分页

中信 `bizFunc=24/25` 的正式业务请求都只接受单日 `reserve.TRANS_DATE`。银行公共请求对象中的
`beginDate/endDate` 被文档明确标注为忽略，因此新 Front 的处理方式固定为：

```text
业务 specialData.startDate/endDate
→ Handle 校验日期范围
→ 按 yyyyMMdd 逐日展开
→ 当前日期调用银行 TRANS_DATE + PAGE
→ 当前日期查完后移动到下一日期 PAGE=1
→ continuationToken 保存当前日期和下一银行页码
```

约束：

- 调用方不能直接提交 `TRANS_DATE/PAGE`；
- 调用方只能原样回传 Front 生成的 `continuationToken`；
- `continuationToken` 不得包含明文密钥、账户号或完整请求；
- `pageSize` 不能改变中信 `24=50条/页`、`25=20条/页` 的银行固定值；
- 跨日期结果必须定义稳定排序，建议按交易日期、交易时间、银行流水升序；
- 真实实现前还需要确认允许的最大日期跨度，不能无限日期范围同步扫库。

---

## 7. 公共分页返回

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "frontRespCode": "200",
    "frontRespDesc": "操作成功",
    "records": [
      {
        "frontSsn": null,
        "bizOrderNo": "BIZ-001",
        "bizSubOrderNo": "BIZ-SUB-001",
        "transactionType": "WITHDRAW_FEE",
        "direction": "EXPENSE",
        "amount": 100,
        "transactionDate": "20260804",
        "transactionTime": "153000",
        "remark": "提现手续费",
        "specialData": {
          "REQ_JRN": "银行流水",
          "REGISTER_SSN": "登记簿流水"
        }
      }
    ],
    "total": null,
    "pageNo": 1,
    "pageSize": 50,
    "continuationToken": "Front生成的续查游标",
    "specialData": {}
  }
}
```

分页结果自身的 `specialData` 只保存查询级扩展；每笔银行明细的差异字段必须放在该条
`TransactionDetailItem.specialData` 中。禁止把所有行的 reserve 合并到分页结果的一个 JSON 中。

---

## 8. common-core 常量

业务系统和中信 Handle 必须引用：

```text
CiticPlatformTransactionDetailQueryContractKeys
CiticTransactionDetailQueryContractKeys
```

常量类已经明确：

- `bizFunc/chnlNo`；
- 请求 `specialData` Key；
- 银行 reserve Key；
- 两套互不混用的交易类型；
- `bizFunc=24` 的登记簿/账户类型；
- 已确认的响应映射字段；
- 元转分和敏感数据注意事项。

业务系统只使用请求 `specialData` Key 和枚举值；银行 reserve Key、响应 Key 供 Handle 实现使用。
禁止业务系统引用 `BANK_*` 常量后伪造银行报文。

---

## 9. 与旧实现的映射及禁止复制项

| 新方法 | 中信协议 | 旧参考 | 新结论 |
|---|---|---|---|
| `queryPlatformTransactionDetails()` | `25/0010` | `queryPlatformTransPages()`、`ZxTransQueryServiceImpl` | 保留一个平台明细入口，交易类型来自 specialData |
| `queryTransactionDetails()` | `24/0010` | `queryWithDrawFee()`、`queryTransPages()`及 UAT 示例 | 保留一个登记簿明细入口，手续费等由交易类型筛选 |

禁止复制：

- `queryWithDrawFee()` 独立方法；
- 旧代码固定 `TRANS_TYPE=03/04`；
- 旧代码只支持单个 `transDate` 且让调用方传银行页码；
- 把文档标注忽略的 `beginDate/endDate` 当成银行有效字段；
- 旧代码 `result.getString("LIST")` 后对单条/多条结构的脆弱判断；
- 输出完整银行响应或敏感对手方账号；
- 直接使用字符串金额或浮点数完成元转分；
- 用 `<T> T` 或返回 `null` 表达银行能力。

另外，单笔交易状态查询只映射中信 `bizFunc=74`；`bizFunc=73` 是文件处理状态查询，不属于当前
`queryTransactionStatus()`，不得继续写成两个旧入口合并。

---

## 10. 当前实现状态

已完成：

- 两个 Front 明细查询接口骨架；
- `TransactionDetailQueryData` 的公共字段边界；
- `TransactionDetailItem.bizSubOrderNo`；
- 中信 `24/25` 字段常量和完整注释；
- `baseData/specialData/reserveMap` 映射约束。

待实现：

- 中信协议请求/响应 DTO；
- `CiticQueryHandle` 的两个真实方法；
- 日期范围按日展开和安全 `continuationToken`；
- 金额元转分、类型归一化和响应白名单；
- 查询审计流水及日志落库；
- 最大日期跨度、稳定排序及空结果联调规则。

未收到用户明确要求前，不写测试类，不执行测试和编译。
