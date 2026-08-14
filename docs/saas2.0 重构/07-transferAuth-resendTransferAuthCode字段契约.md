# transferAuth / resendTransferAuthCode 字段契约

> 状态：平安首版字段边界已确认，可作为后续 Handle 实现基线
>
> 范围：短信鉴权转账 `transferAuth`、转账授权码发送或重发 `resendTransferAuthCode`
>
> 银行：仅平安 `pajzb`；中信 `zxegj` 明确不支持

## 1. 依据和能力结论

本契约同时核对了：

- 《客户钱包应用平台接口文档-平安项目 v5.5》；
- mdl `PaTransTransferHandle.transTransferAuth()`；
- mdl `PaTransSendVerificationHandle.sendSmsVerification()`；
- 旧 Front API、Service、Handle 调用链；
- 中信 v4.7 文档及旧中信挡板代码。

最终能力边界：

| Front 方法 | 平安银行接口 | 固定用途 | 中信状态 |
|---|---|---:|---|
| `transferAuth` | `POST /cwap/account/send/transfer` | `bizFunc=45` | `UNSUPPORTED` |
| `resendTransferAuthCode` | `POST /cwap/account/send/gen-auth-code` | `bizFunc=26` | `UNSUPPORTED` |

平安 v5.5 定义的是“申请短信动态码”，没有另一个“重发”银行接口。Front 的首次发送和重发使用同一
`resendTransferAuthCode` 方法：每次都生成新的 `transSsn/transTime` 并重新申请，不把旧 `smsIdx`
传给银行。重复申请限流、旧验证码失效和有效期仍需以联调结果为准。

旧 `ZxTransTransferHandle.transTransferAuth()` 只在本地构造成功结果，旧
`ZxTransSendVerificationHandle.sendSmsVerification()` 只返回模拟手机号和验证码，均未调用中信银行，
不能作为中信支持这两项能力的证据。新 Front 禁止复制这些挡板。

## 2. 新旧方法与具体实现类映射

### 2.1 `transferAuth`

```text
新 FrontTransactionApi.transferAuth
→ FrontTransactionController.transferAuth
→ FrontTransactionApplicationService.transferAuth
→ BankTransactionHandle.transferAuth
→ PingAnTransactionHandle.transferAuth（后续真实实现位置）

旧 FrontTransConsumeFacadeApi.transTransferAuth
→ TransConsumeServiceImpl.transTransferAuth
→ BasTransTransferHandle.transTransferAuth
→ PaTransTransferHandle.transTransferAuth
→ SaasPaInterService.paTansfer
→ 平安 /cwap/account/send/transfer，bizFunc=45
```

### 2.2 `resendTransferAuthCode`

```text
新 FrontTransactionApi.resendTransferAuthCode
→ FrontTransactionController.resendTransferAuthCode
→ FrontTransactionApplicationService.resendTransferAuthCode
→ BankTransactionHandle.resendTransferAuthCode
→ PingAnTransactionHandle.resendTransferAuthCode（后续真实实现位置）

旧 FrontTransVerificationFacadeApi.sendSmsVerification
→ TransVerificationServiceImpl.sendSmsVerification
→ BasTransSendVerificationHandle.sendSmsVerification
→ PaTransSendVerificationHandle.sendSmsVerification
→ SaasPaInterService.applyWithdrawOrPaymentAuthCode
→ 平安 /cwap/account/send/gen-auth-code，bizFunc=26
```

## 3. Front 对外对象

### 3.1 两段式请求

两个方法继续统一使用：

```text
FrontRequest<T>
├─ baseData: T
└─ specialData: JSONObject
```

银行账户配置不由业务系统传入。平安 Handle 通过统一父类获得：

```text
accountConfig
├─ appId / appKey / url / mchntId / mchntMbrId
└─ accountSpecialData
   ├─ mrchCode
   ├─ txnClientNo
   └─ stlAcctNo
```

`accountSpecialData` 是租户银行静态配置；请求 `specialData` 是单次业务动态数据。禁止合并、覆盖或
整体 `putAll` 到银行 `reserve`。

### 3.2 `transferAuth` 基础对象

```text
AuthTransferBusinessData extends TransferBusinessData
├─ tenantId / storeId / platformCode
├─ bizRequestNo / bizOrderNo / bizSubOrderNo
├─ amount / fee / currency
├─ businessDate / businessTime / remark
└─ payStoreNo / payStoreId / recStoreNo / recStoreId
```

银行使用的账户号、会员编号、姓名、短信指令号和验证码均不放入 `AuthTransferBusinessData`。
请求 `specialData` 固定为：

```json
{
  "outAcctNo": "转出见证子账户",
  "inAcctNo": "转入见证子账户",
  "outMemberCode": "转出方交易网会员代码",
  "outSubAcctName": "转出方户名",
  "inMemberCode": "转入方交易网会员代码",
  "inSubAcctName": "转入方户名",
  "messageOrderNo": "上一步响应 specialData.smsIdx 的明文值",
  "messageCheckCode": "用户收到的短信验证码"
}
```

两个字段在当前短信鉴权转账场景均必填。`messageCheckCode` 由平安 Handle 在组装银行请求时 SM2 加密；
两者均禁止写日志、异常消息或普通接口响应；渠道表也不得保存完整请求快照。

### 3.3 `resendTransferAuthCode` 基础对象

```text
TransferAuthCodeBusinessData extends BaseTransactionBusinessData
├─ tenantId / storeId / platformCode
├─ bizRequestNo / bizOrderNo / bizSubOrderNo
├─ amount / fee / currency
├─ businessDate / businessTime / remark
└─ payStoreNo / payStoreId / recStoreNo / recStoreId
```

银行请求实际使用 `bizRequestNo/bizOrderNo/amount/remark` 和请求 `specialData` 的三项动态字段；
其余交易公共字段只用于业务审计和渠道流水，不得无依据映射到平安报文。

该方法请求 `specialData` 固定包含：

```json
{
  "acctNo": "转出见证子账户",
  "outAcctId": "付款方交易网会员代码",
  "intAcctNo": "转入见证子账户"
}
```

以下旧字段已删除：

| 旧框架字段 | 删除原因 |
|---|---|
| `mobileNo` | 平安用途 26 不接收调用方手机号，短信发送到银行预留手机号 |
| `originalAuthRequestNo` | 重发是重新申请，不上送原短信指令号 |

### 3.4 授权码专用返回

授权码发送或重发直接返回：

```java
R<FrontTransferAuthCodeResult>
```

```text
FrontTransferAuthCodeResult extends FrontBaseResult
├─ frontRespCode / frontRespDesc
├─ frontSsn
├─ frontQueryId
└─ specialData
   ├─ smsIdx
   └─ receiveMobile
```

`smsIdx/receiveMobile` 都是平安特有响应字段，不提升为公共强类型字段。

## 4. `transferAuth` 请求映射

### 4.1 钱包基础字段

| 钱包字段 | 来源 | 规则和注意点 |
|---|---|---|
| `appId/appKey/url` | 租户银行通用配置 | `appKey` 禁止写日志 |
| `mchntId` | 租户银行通用配置 | 接入方编号 |
| `mchntMbrId` | `specialData.outMemberCode` | 当前付款方交易网会员代码 |
| `transTime` | 平安 Handle | 每次请求生成，格式 `yyyyMMddHHmmss` |
| `transSsn` | 平安 Handle | 按平安 22 位规则生成、保存渠道流水并回传 `frontSsn` |
| `bizFunc` | Handle 常量 `45` | 会员间交易-验证短信动态码，禁止业务系统覆盖 |
| `chnlNo` | Handle 常量 `0001` | 平安见证宝渠道号，禁止业务系统覆盖 |
| `outAcctNo` | `specialData.outAcctNo` | 转出见证子账户，SM2 加密 |
| `inAcctNo` | `specialData.inAcctNo` | 转入见证子账户，SM2 加密 |
| `pwd` | Handle 固定空字符串 | 协议标注忽略 |
| `transAmt` | `baseData.amount` | 人民币分，包含手续费，必须大于 0 |
| `fee` | `baseData.fee` | 人民币分，无手续费传 0 |
| `ccy` | Handle 常量 `CNY` | 当前固定人民币 |
| `remark` | `baseData.remark` | Handle 校验协议长度；最大 120，已从 Word 协议确认 |

金额全链路使用 `Long` 人民币分，不得转换为元或使用浮点数。

### 4.2 `reserve` 映射

| reserve 字段 | 来源 | 规则和注意点 |
|---|---|---|
| `mrchCode` | `accountSpecialData.mrchCode` | 平台号，禁止业务请求覆盖 |
| `txnClientNo` | `accountSpecialData.txnClientNo` | 客户号，禁止业务请求覆盖 |
| `stlAcctNo` | `accountSpecialData.stlAcctNo` | 资金汇总账号，SM2 加密 |
| `functionFlag` | Handle 固定 `9` | 当前 mdl 实际场景为直接支付 T+0 |
| `outMemberCode` | `specialData.outMemberCode` | 转出方交易网会员代码 |
| `outSubAcctName` | `specialData.outSubAcctName` | 转出方见证子账户户名，SM2 加密 |
| `inMemberCode` | `specialData.inMemberCode` | 转入方交易网会员代码 |
| `inSubAcctName` | `specialData.inSubAcctName` | 转入方见证子账户户名，SM2 加密 |
| `tranType` | Handle 固定 `01` | 当前普通鉴权转账 |
| `orderNo` | `baseData.bizOrderNo` | 必填，最大 30，必须满足平安全局唯一约束 |
| `remark` | `baseData.remark` | 最大 120；旧 mdl 写死 `Remark`，新实现改为真实业务备注 |
| `messageOrderNo` | `request.specialData.messageOrderNo` | 上一步返回的短信指令号明文 |
| `messageCheckCode` | `request.specialData.messageCheckCode` | 短信验证码，SM2 加密 |

平安 v5.5 还定义了可选 `orderContent` 等字段，但当前 mdl Handle 未实际映射，本阶段不声明活动常量，
也不允许业务系统提前透传。

## 5. `resendTransferAuthCode` 请求映射

### 5.1 钱包基础字段

| 钱包字段 | 来源 | 规则和注意点 |
|---|---|---|
| `appId/appKey/url` | 租户银行通用配置 | `appKey` 禁止写日志 |
| `mchntId` | 租户银行通用配置 | 接入方编号 |
| `mchntMbrId` | `specialData.outAcctId` | 付款方交易网会员代码 |
| `transTime` | 平安 Handle | 每次申请或重发都重新生成 |
| `transSsn` | 平安 Handle | 每次重新生成、保存渠道流水并回传 `frontSsn` |
| `bizFunc` | Handle 常量 `26` | 申请提现或支付短信动态码 |
| `chnlNo` | Handle 常量 `0001` | 平安见证宝渠道号 |
| `acctNo` | `specialData.acctNo` | 转出见证子账户，SM2 加密 |
| `transAmt` | `baseData.amount` | 当前支付场景交易金额，人民币分 |

### 5.2 `reserve` 映射

| reserve 字段 | 来源 | 规则和注意点 |
|---|---|---|
| `mrchCode` | `accountSpecialData.mrchCode` | 平台号，禁止业务请求覆盖 |
| `txnClientNo` | `accountSpecialData.txnClientNo` | 客户号，禁止业务请求覆盖 |
| `stlAcctNo` | `accountSpecialData.stlAcctNo` | 资金汇总账号，SM2 加密 |
| `tranType` | Handle 固定 `2` | 当前 Front 只使用“支付”分支 |
| `orderNo` | `baseData.bizOrderNo` | 业务主订单号；最大 30 |
| `remark` | `baseData.remark` | 业务备注；最大 120 |
| `intAcctNo` | `specialData.intAcctNo` | 转入见证子账户，SM2 加密 |

`intAcctNo` 是平安 v5.5 和现有接口的原始拼写。实现时不得凭习惯改成 `inAcctNo`。

重发时读取上述账户 `specialData`，但不传旧 `smsIdx/messageOrderNo`。发送前仍按当前平安转账表的
`tenantId + bizOrderNo + bizSubOrderNo` 执行重复交易检查；命中返回“交易已存在”。用户主动再次发送
必须使用新的主/子业务流水。

## 6. 响应判定与映射

### 6.1 两层银行响应

两个接口成功都必须同时满足：

```text
errCode == D5000000
&& errInfo == success
&& sysRespCode == 000000
```

`000000` 是平安 6 位成功码。钱包原始 `errCode/errInfo/sysRespCode/sysRespDesc` 只用于 Handle
判定和渠道流水审计，不直接成为 `frontRespCode/frontRespDesc`。

### 6.2 `transferAuth` 返回映射

| 平安或 Front 字段 | Front 返回字段 | 说明 |
|---|---|---|
| Handle 生成的 `transSsn` | `frontSsn` | 不使用银行 `queryId` 覆盖 |
| 平安 `queryId` | `frontQueryId` | 渠道方查询流水 |
| 归一化成功 | `frontRespCode=200/frontRespDesc=成功/frontStatus=SUCCESS` | 使用 `FrontErrorCode.SUCCESS` |
| 明确银行失败 | 统一 `F4xxxxx/frontStatus=FAILED` | 顶层 `R.code` 也为失败码 |
| 平安特有响应 | `specialData={}` | 当前文档和 mdl 未确认需返回其他字段 |

### 6.3 `resendTransferAuthCode` 返回映射

| 平安或 Front 字段 | Front 返回字段 | 说明 |
|---|---|---|
| Handle 生成的 `transSsn` | `frontSsn` | 保存授权码申请渠道流水 |
| 平安 `queryId` | `frontQueryId` | 渠道方查询流水 |
| 平安 `smsIdx` | `specialData.smsIdx` | 银行返回 SM2 密文，Handle 解密后写入；下步映射 `messageOrderNo` |
| 平安 `receiveMobile` | `specialData.receiveMobile` | lsym 生产 Handle 按银行返回值直接复制；禁止日志输出，是否需要解密以联调为准 |
| 归一化结果 | `frontRespCode/frontRespDesc` | 使用 `FrontErrorCode`，不透传银行码 |

lsym 生产 Handle 只解密 `smsIdx`，`receiveMobile` 按银行返回值直接复制；当前新代码同时解密两者，
与生产参考实现不一致。修复前应以银行联调结果确认 `receiveMobile` 的实际形态；确认前不得强制解密，
也不得在日志中输出该值。

### 6.4 成功响应示例

授权码发送或重发：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "frontRespCode": "200",
    "frontRespDesc": "成功",
    "frontSsn": "平安Handle生成的22位交易流水",
    "frontQueryId": "钱包queryId",
    "specialData": {
      "smsIdx": "解密后的短信指令号",
      "receiveMobile": "解密后的银行预留手机号"
    }
  }
}
```

银行明确拒绝时，Application Service 返回 `R.fail(message, result)`：

```json
{
  "code": 500,
  "msg": "银行拒绝交易",
  "data": {
    "frontRespCode": "F400004",
    "frontRespDesc": "银行拒绝交易",
    "specialData": {}
  }
}
```

## 7. common-core 常量入口

```text
catering-common/catering-common-core/src/main/java/com/chinaums/common/core/constant/front
├─ FrontBankRequestConstants.java
├─ FrontBankResponseConstants.java
├─ PingAnBankAccountConfigKeys.java
├─ PingAnTransferAuthContractKeys.java
└─ PingAnTransferAuthCodeContractKeys.java
```

- `bizFunc=45/26` 由 `PingAnTransactionHandle` 的带注释本地常量确定；
- `PingAnTransferAuthContractKeys`、`PingAnTransferAuthCodeContractKeys` 只保存当前支付分支实际使用的
  银行原始字段 key、协议枚举固定值和响应白名单；
- Word 有定义但当前 Handle 不使用的字段只留在本文说明，不提前搬进 Java 常量；
- 银行协议 DTO、加密实现和 HTTP 客户端仍放在 `catering-front/channel/pingan`，不能放入
  `catering-common-core`。

## 8. 后续 Handle 实现约束

后续 AI 实现这两个方法时必须：

1. 只覆盖 `PingAnTransactionHandle` 的目标方法，中信保持 `UNSUPPORTED`；
2. 从现有 `BankRequestContext` 读取 `baseData/specialData/accountConfig`，不得重新查询账户配置；
3. 逐字段组装钱包基础字段和 `reserve`，禁止 `putAll`；
4. `transSsn/transTime` 每次由平安 Handle 生成，`bizFunc/chnlNo/functionFlag/tranType` 使用常量；
5. 渠道流水保存能力、业务请求号、业务订单、明确账户字段、`frontSsn/queryId`、原始响应码和归一化状态；
6. 验证码、短信指令号、手机号、账户号、户名等字段值按明文输出到日志（2026-08-14 用户确认取消
   日志敏感值掩码）；`appKey`、签名头和完整银行 URL 不进入日志；
7. API、Handler、报文组装和钱包调用前后均记录结构完整的 JSON，并携带 `tenantId`、
   `storeId`、`bankCode`、`capability`、`bizRequestNo`、`bizOrderNo`、`bizSubOrderNo`、`platformCode`、
   `dataSourceId`、`frontSsn`、`frontRespCode`、`elapsedMs` 等定位字段；
8. 超时或无法确认银行是否受理时返回 `UNKNOWN/F400002`，资金交易不得盲目重试；
9. 未经用户明确要求，不新增测试类、不运行测试、不执行编译。

`transferAuth` 和 `resendTransferAuthCode` 每次真实调用均写入
`front_pingan_transfer_transaction`，通过 `capability` 与普通 `TRANSFER` 区分；中信不支持这两个能力，
不得创建中信授权空记录。每条记录必须保留业务主/子记录关联和明确业务字段，不保存整段请求快照；
验证码不得进入任何数据库字段。详细 DDL 见 [09-channel-transaction-ddl](09-channel-transaction-ddl.md)。

这里的 `capability` 由当前 API 方法内部固定，不接受请求输入；它既是平安共享转账表的记录字段，也是
Transaction Registry 中 `(BankCode, FrontCapability)` 精确路由的一部分。`transferAuth` 必须定位到
`(PING_AN, TRANSFER_AUTH)` 的单能力 Handler；中信未注册该复合键时返回
`CAPABILITY_NOT_SUPPORTED`。不得建立统一能力预校验，也不得在公共 Dispatch 中再按 capability
选择方法。

## 9. 仍需联调确认

以下内容不阻塞框架和字段契约，但生产接入前必须确认：

1. 平安连续申请验证码的限流规则；
2. 新申请是否立即使旧验证码和旧 `smsIdx` 失效；
3. 验证码和短信指令号的精确有效期；
4. `functionFlag=9` 是否覆盖全部当前鉴权转账业务，是否还需 T+1 分支；
5. `orderNo` 的业务唯一性范围及重试复用规则；
6. `receiveMobile` 对业务系统应返回完整值还是统一脱敏值。
