# transfer / consume 字段契约

> 状态：中信、平安首版字段边界已确认，可作为后续 Handle 实现基线  
> 范围：普通转账 `transfer`、消费 `consume`  
> 银行：中信 `zxegj`、平安 `pajzb`

## 1. 依据和结论

本契约依据：

- 《中信E管家产品客户钱包应用平台接口文档-内部集成平台 v4.7》；
- 《客户钱包应用平台接口文档-平安项目 v5.5》；
- mdl `ZxTransTransferHandle/ZxTransConsumeHandle`；
- mdl `PaTransTransferHandle/PaTransConsumeHandle`。

已确认：

1. 中信 `transfer/consume` 都使用 `/cwap/account/send/transfer`、`bizFunc=27`、`chnlNo=0010`；
2. 平安 `transfer/consume` 当前都按会员间交易 `/cwap/account/send/transfer`、`bizFunc=01`、
   `chnlNo=0001` 设计；
3. 请求仍只有 `baseData + specialData` 两段；租户银行配置由 Front 内部加载；
4. 所有金额使用人民币分，Java 公共对象使用 `Long`；
5. 钱包原始响应码只用于 Handle 判定，业务系统只接收统一
   `frontRespCode/frontRespDesc`；
6. 银行特殊返回字段进入返回对象的 `specialData: JSONObject`。

## 2. Front 请求公共对象

### 2.1 顶层对象

```text
FrontRequest<T>
├─ baseData: T
└─ specialData: JSONObject
```

`specialData` 是当前“银行 + 能力”的动态业务扩展字段，不是钱包 `reserve` 本身。Handle 必须按
白名单逐字段解析并映射，禁止 `walletReserve.putAll(specialData)`。

### 2.2 transfer 基础对象

```text
TransferBusinessData extends BaseTransactionBusinessData
├─ tenantId / storeId / platformCode
├─ bizRequestNo / bizOrderNo / bizSubOrderNo
├─ amount / fee / currency
├─ businessDate / businessTime / remark
├─ payStoreNo / payStoreId / recStoreNo / recStoreId
├─ payerAccountId / payerMemberId / payerName
└─ payeeAccountId / payeeMemberId / payeeName
```

### 2.3 consume 基础对象

```text
ConsumeBusinessData extends BaseTransactionBusinessData
├─ 与 transfer 相同的交易公共字段及收付款账户、会员、名称字段
├─ consumeScene
└─ orderInfo
```

消费和普通转账在银行侧可以复用同一支付能力，但 Front 保留两个入口和两个对象，确保渠道交易表
能够保存正确的业务类型。

### 2.4 金额约束

| Front 字段 | 单位 | 银行映射 | 注意点 |
|---|---|---|---|
| `baseData.amount` | 人民币分 | 中信 `transAmt` | 必须大于 0 |
| `baseData.amount` | 人民币分 | 中信 `reserve.USER_C_AMT` | 收款用户入账金额，必须大于 0 |
| `baseData.amount` | 人民币分 | 平安 `transAmt` | 金额包含手续费 |
| `baseData.fee` | 人民币分 | 平安 `fee` | 无手续费传 0；不能小于 0 |

不得在某个 Handle 内把分转换成元，也不得使用浮点数保存金额。

## 3. Handle 内部上下文

```text
BankRequestContext<T>
├─ baseData
├─ specialData
└─ tenantBankConfig
   ├─ accountConfig
   │  ├─ appId / appKey / url / mchntId / mchntMbrId
   │  └─ accountSpecialData
   └─ configVersion / enabled / tenantId / bankCode
```

字段来源固定：

| 数据 | 来源 | 能否由业务请求覆盖 |
|---|---|---:|
| 钱包地址、应用标识、密钥、接入商户号 | 租户银行通用配置 | 否 |
| 银行账户静态特殊字段 | `accountSpecialData` | 否 |
| 收付款、金额、订单、门店 | `baseData` | 按公共 DTO 提交 |
| 当前银行、当前能力的动态扩展 | `specialData` | 只能按契约白名单解析 |
| `transSsn/transTime/laasSsn` | 当前银行 Handle 生成 | 否 |
| `bizFunc/chnlNo` | 当前银行 Handle 常量 | 否 |

## 4. 中信 transfer / consume

### 4.1 钱包基础字段

| 钱包字段 | 来源 | 说明 |
|---|---|---|
| `appId/appKey/url` | 租户银行通用配置 | `appKey` 禁止写日志 |
| `mchntId/mchntMbrId` | 租户银行通用配置 | 中信平台商户配置 |
| `transTime` | 中信 Handle | 每次请求生成 |
| `transSsn` | 中信 Handle | 按中信规则生成、落渠道交易表并回传 `frontSsn` |
| `bizFunc` | Handle 常量 `27` | 禁止业务系统覆盖 |
| `chnlNo` | Handle 常量 `0010` | 禁止业务系统覆盖 |
| `transAmt` | `baseData.amount` | 单位为分，必须大于 0 |
| `outAcctNo` | `baseData.payerAccountId` | 按中信协议加密 |
| `inAcctNo` | `baseData.payeeAccountId` | 按中信协议加密 |
| `remark` | `baseData.remark` | Handle 校验银行长度 |

### 4.2 中信 reserve 映射

| reserve 字段 | 来源 | 解释和注意点 |
|---|---|---|
| `USER_D_NM` | `baseData.payerName` | 付款用户名称 |
| `USER_C_NM` | `baseData.payeeName` | 收款用户名称 |
| `USER_C_AMT` | `baseData.amount` | 收款用户入账金额，单位为分，必须大于 0 |
| `USER_SHARE_ID1..4` | `specialData` 白名单 | 分润用户编号；不用分润时不传或按协议传空值 |
| `USER_SHARE_NM1..4` | `specialData` 白名单 | 分润用户名称；有分润编号时配套提交 |
| `USER_SHARE_AMT1..4` | `specialData` 白名单 | 分润金额，单位为分，不能为负 |
| `P_SELF_FLAG` | 中信账户策略 + `specialData` | `D` 平台优惠、`C` 平台分成、`N` 无资金动账 |
| `P_SELF_AMT` | `specialData` 白名单 | 单位为分；`P_SELF_FLAG=N` 时必须为 0 |
| `BUSS_ID` | `baseData.bizOrderNo` | 商户业务主订单号 |
| `BUSS_SUB_ID` | `baseData.bizSubOrderNo` | 商户业务子订单号 |
| `TRANS_DT` | `baseData.businessDate` | `yyyyMMdd` |
| `TRANS_TM` | `baseData.businessTime` | `HHmmss` |
| `FUND_TP` | 中信账户配置策略 | 默认取 `default_fund_type`；自有资金场景由策略选择 `self_fund_type` |
| `MEMO` | `baseData.remark` | 不再硬编码“API转账”；按银行长度校验 |
| `REQ_RESERVED` | `specialData` 白名单 | 银行预留业务字段，未定义契约时不得透传 |
| `laasSsn` | 中信 Handle | 外联平台流水号，Handle 生成并保证不重复 |

中信账户配置中的 `default_role/default_fund_type/self_role/self_fund_type/self_dealType/`
`self_store_no/self_store_id` 是账户静态特定配置。它们不属于单次交易 `specialData`，由中信策略结合
门店和本次自有资金标志选择最终请求字段。

### 4.3 中信响应

中信同步成功必须同时满足：

```text
errCode == D5000000
&& errInfo == success
&& sysRespCode == 00000       # 5 个 0
```

公共映射：

| 中信字段 | Front 字段 |
|---|---|
| `queryId` | `frontQueryId` |
| `USER_TRANS_DT` | `frontTransDate` |
| `USER_TRANS_TM` | `frontTransTime` |
| `USER_SSN` | `specialData.USER_SSN` |

`USER_SSN` 是中信分配的银行交易流水，不能覆盖 Handle 已生成并落渠道流水的 `frontSsn`。

## 5. 平安 transfer / consume

### 5.1 钱包基础字段

| 钱包字段 | 来源 | 说明 |
|---|---|---|
| `appId/appKey/url` | 租户银行通用配置 | `appKey` 禁止写日志 |
| `mchntId` | 租户银行通用配置 | 接入方编号 |
| `mchntMbrId` | `baseData.payerMemberId` | 当前会员间交易的付款方商户会员编号 |
| `transTime` | 平安 Handle | 每次请求生成，格式按协议 |
| `transSsn` | 平安 Handle | 按平安规则生成、落渠道交易表并回传 `frontSsn` |
| `bizFunc` | Handle 常量 `01` | 禁止业务系统覆盖 |
| `chnlNo` | Handle 常量 `0001` | 禁止业务系统覆盖 |
| `outAcctNo` | `baseData.payerAccountId` | 付款见证子账户，按协议加密 |
| `inAcctNo` | `baseData.payeeAccountId` | 收款见证子账户，按协议加密 |
| `transAmt` | `baseData.amount` | 单位为分，包含手续费 |
| `fee` | `baseData.fee` | 单位为分，无手续费传 0 |
| `ccy` | `baseData.currency` | 当前默认 CNY |
| `remark` | `baseData.remark` | Handle 校验银行长度 |

### 5.2 平安 reserve 映射

| reserve 字段 | 来源 | 解释和注意点 |
|---|---|---|
| `mrchCode` | `accountSpecialData.mrchCode` | 平台号，禁止业务系统覆盖 |
| `txnClientNo` | `accountSpecialData.txnClientNo` | 客户号，禁止业务系统覆盖 |
| `stlAcctNo` | `accountSpecialData.stlAcctNo` | 资金汇总账号，进入请求前加密，禁止记录明文 |
| `functionFlag` | 平安 Handle 场景策略 | `6` 直接支付 T+1、`7` 免密支付、`9` 直接支付 T+0 |
| `outAcctId` | `baseData.payerMemberId` | 转出方商户会员编号 |
| `outAcctName` | `baseData.payerName` | 转出方户名，按协议加密 |
| `inAcctId` | `baseData.payeeMemberId` | 转入方商户会员编号 |
| `inAcctName` | `baseData.payeeName` | 转入方户名，按协议加密 |
| `transType` | Handle 常量 `01` | 普通交易 |
| `orderId` | `baseData.bizSubOrderNo` | 订单号；按业务规则保证唯一 |
| `orderInfo` | consume 的 `baseData.orderInfo` 或 transfer 专用白名单 | 订单内容，可选 |
| `smsIdx` | 短信流程 `specialData` 白名单 | 非短信 transfer/consume 不传 |
| `sign` | 短信流程 `specialData` 白名单 | 非短信 transfer/consume 不传 |

`functionFlag` 不能由业务系统随意提交一个银行原值。Handle 应根据已确认的 Front 业务场景选择，
无法映射时返回契约错误，不使用默认值掩盖业务差异。

### 5.3 平安响应

平安同步成功必须同时满足：

```text
errCode == D5000000
&& errInfo == success
&& sysRespCode == 000000      # 6 个 0
```

公共 `queryId` 映射为 `frontQueryId`。当前 Word 文档和 mdl 实现没有确认 transfer/consume 需要向业务
系统返回的平安特有字段，因此成功时 `specialData` 默认是空 `JSONObject`。以后若银行 `reserve`
新增有业务价值的字段，必须先加入契约白名单和常量，再逐字段写入 `specialData`，禁止整体透传。

## 6. 统一响应码与响应说明

### 6.1 两层响应

```text
R.code / R.msg
└─ 工程调用层结果

R.data.frontRespCode / frontRespDesc
└─ Front 统一业务结果

R.data.specialData
└─ 银行特有且允许业务系统使用的响应字段
```

所有具体结果都继承 `FrontBaseResult`。Handle 应调用：

```java
result.applyFrontResponse(FrontErrorCode.SUCCESS);
```

或传入相应失败枚举，保证 `frontRespCode` 与 `frontRespDesc` 来自同一枚举，不允许分别拼接字符串。

### 6.2 原始码转换

| 原始结果 | Front 统一结果 | 状态建议 |
|---|---|---|
| 平台成功且银行成功 | `F000000 / 成功` | `SUCCESS` |
| 明确未完成正常钱包通信 | `F400001 / 钱包通信失败` | `FAILED` |
| 请求可能已发送但无可靠终态 | `F400002 / 钱包处理结果未知` | `UNKNOWN`，随后查询 |
| 响应缺少必需字段或格式错误 | `F400003 / 钱包响应格式错误` | `UNKNOWN` 或 `FAILED`，按是否已发送判断 |
| 平台成功但银行 `sysRespCode` 明确失败 | `F400004 / 银行拒绝交易` | `FAILED` |
| `errCode/errInfo` 明确表示钱包平台失败 | `F400005 / 钱包平台拒绝请求` | `FAILED` |

中信 `00000`、平安 `000000`、钱包 `D5000000/success` 均不得成为 `frontRespCode`。

### 6.3 原始响应的保存边界

- `errCode/errInfo/sysRespCode/sysRespDesc`：写渠道交易流水，用于审计和排障；
- `queryId`：写渠道交易流水，并映射公共 `frontQueryId`；
- 具备公共语义的银行字段：映射强类型结果字段；
- 只有某家银行存在且业务系统确实需要的字段：按常量白名单写入 `specialData`；
- 完整 `reserve`、密钥、账户明文、签名和敏感信息：禁止返回，也禁止完整写日志。

### 6.4 成功响应示例

中信：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "frontRespCode": "F000000",
    "frontRespDesc": "成功",
    "frontSsn": "FRONT生成的渠道交易流水",
    "frontStatus": "SUCCESS",
    "frontQueryId": "钱包queryId",
    "frontTransDate": "20260804",
    "frontTransTime": "120000",
    "specialData": {
      "USER_SSN": "中信银行侧交易流水"
    }
  }
}
```

平安：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "frontRespCode": "F000000",
    "frontRespDesc": "成功",
    "frontSsn": "FRONT生成的渠道交易流水",
    "frontStatus": "SUCCESS",
    "frontQueryId": "钱包queryId",
    "specialData": {}
  }
}
```

示例中的 `frontSsn` 是 Handle 生成并保存的 Front 渠道交易流水；`queryId` 和中信 `USER_SSN`
分别保留自己的语义，不能互相覆盖。

## 7. common-core 常量入口

路径：

```text
catering-common/catering-common-core/src/main/java/com/chinaums/common/core/constant/front
├─ FrontBankResponseConstants.java
├─ FrontBankRequestConstants.java
├─ CiticTransferContractKeys.java
├─ PingAnTransferContractKeys.java
├─ FrontBankAccountConfigKeys.java
├─ CiticBankAccountConfigKeys.java
└─ PingAnBankAccountConfigKeys.java
```

用途：

| 常量类 | 用途 |
|---|---|
| `FrontBankResponseConstants` | 公共原始响应字段、钱包平台成功标志、两家银行不同成功码 |
| `FrontBankRequestConstants` | 钱包公共请求字段名及运行时字段来源约束 |
| `CiticTransferContractKeys` | 中信 transfer/consume 固定值、请求字段、reserve 和响应特殊字段 |
| `PingAnTransferContractKeys` | 平安 transfer/consume 固定值、请求字段和 reserve 字段 |
| `FrontBankAccountConfigKeys` | 跨银行通用租户账户配置字段 |
| `CiticBankAccountConfigKeys` | 中信账户静态特殊配置 |
| `PingAnBankAccountConfigKeys` | 平安账户静态特殊配置 |

业务系统如需实现自己的银行组装策略，应引用这些常量和注释，不得在业务模块重新定义同名字符串。

## 8. 后续 Handle 实现要求

每次只实现“一个银行 + 一个能力”。提交实现前必须确认：

1. `baseData` 必填字段和单位；
2. `specialData` 白名单、必填条件和长度；
3. 账户配置字段与单次业务扩展没有混用；
4. `bizFunc/chnlNo/transSsn/transTime/laasSsn` 全部由 Handle 控制；
5. 请求发送前已落渠道交易流水；
6. 中信 5 位成功码和平安 6 位成功码没有混用；
7. `frontRespCode/frontRespDesc` 只取 `FrontErrorCode`；
8. 返回 `specialData` 只含响应白名单字段；
9. 日志覆盖开始、路由、配置加载、请求发送、响应判定、落库、结束和异常，但不输出敏感报文。

本阶段只建立契约和代码框架，不在未确认全部字段前实现真实银行 HTTP、签名、加密和交易落库逻辑。
