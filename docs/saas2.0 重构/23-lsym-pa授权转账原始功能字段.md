# lsym 平安授权转账原始功能与字段（transferAuth / resendTransferAuthCode）

> 状态：reference（lsym 静态代码取证，2026-08-21）
>
> 来源：`PaTransTransferHandle.transTransferAuth`（L59-182）、
> `PaTransSendVerificationHandle.sendSmsVerification`（L57-161）、
> `BasTransVerificationReq/Res`、`BasTransTransferReq/Res`（fund-catering-front-api）
>
> 用途：字段级功能基线，供 SaaS 对照核验（对照结论见 24 号）。

## 1. 验证码申请 sendSmsVerification（bizFunc=26）

### 1.1 对外输入（BasTransVerificationReq 实际使用字段）

| 字段 | 用途 |
|---|---|
| payBankEAccountId | 付款见证子账户号 → 顶层 acctNo（SM2 加密） |
| payBankEMemberCode | 付款会员编号 → mchntMbrId |
| recBankEAccountId | 收款账户号 → reserve intAcctNo（SM2 加密） |
| transAmount | 交易金额（字符串分）→ 顶层 transAmt |
| transType | `WD` 提现 → reserve tranType=1；其他（T 支付/转账）→ tranType=2 |
| transNo | 业务主单号 → reserve orderNo |
| transId/transNo/transSubId/transSubNo | 回显定位（响应原样带回） |
| remark | 备注（本次实现固定上送空串） |

### 1.2 银行报文映射

```text
顶层（PaWithdrawAuthCodeRequest）：
  mchntId / mchntMbrId / transSsn(22位) / transTime(yyyyMMddHHmmss)
  chnlNo=0001 / bizFunc=26
  acctNo = SM2(payBankEAccountId)      ← 注意顶层字段名是 acctNo
  transAmt = transAmount

reserve：
  mrchCode / txnClientNo               ← 平台配置明文
  stlAcctNo = SM2(资金汇总账号)         ← 平台配置加密
  tranType = 1(提现) | 2(支付)
  orderNo  = transNo
  intAcctNo = SM2(recBankEAccountId)   ← 平安协议原始拼写
  remark = ""
```

### 1.3 返回（BasTransVerificationRes + DefaultResult）

| 字段 | 来源 | 说明 |
|---|---|---|
| queryId | 响应 queryId（明文） | 银行渠道流水 |
| transSsn | front 生成 | 阶段 2 前的业务关联号 |
| receiveMobile | `result.getString("receiveMobile")` **明文直取，未解密** | 接收手机号 |
| receiveOrderNo | **SM2 解密 `smsIdx`** | 短信指令号（阶段 2 的 messageOrderNo） |
| sysRespCode/sysRespDesc | 响应 | 银行层码/描述 |
| status | ——（本次未设置） | —— |

DefaultResult：成功 `code/success=true`；平台层成功但银行层失败 `code=FAIL`（仍带 transSsn/sysResp*）；平台层失败 `message=完整银行响应 JSON 字符串`；异常 `message=系统繁忙`。

## 2. 授权转账 transTransferAuth（bizFunc=45）

### 2.1 对外输入（BasTransTransferReq 实际使用字段）

| 字段 | 用途 |
|---|---|
| payBankEAccountId / payBankAccountName / payBankEMemberCode | 付款账户三要素 |
| recBankEAccountId / recBankAccountName / recBankEMemberCode | 收款账户三要素 |
| transAmount / transFee | 金额/手续费（分；fee 空 → "0"） |
| remark | 备注 |
| **validOrderNo** | 短信指令号 → reserve messageOrderNo（**阶段 1 的解密 smsIdx**） |
| **verifityType** | `SMS` → verifySmsCode；其他 → verifyCode |
| **verifySmsCode / verifyCode** | 用户输入验证码 → reserve messageCheckCode（SM2 加密） |
| transId/transNo/transSubId/transSubNo | 回显定位 |

### 2.2 银行报文映射

```text
顶层（PaTransferRequest）：
  mchntId / mchntMbrId(=payBankEMemberCode) / transSsn(22位) / transTime
  chnlNo=0001 / bizFunc=45
  outAcctNo = SM2(payBankEAccountId)
  inAcctNo  = SM2(recBankEAccountId)
  transAmt / fee(空补"0") / ccy=CNY / remark / pwd=""

reserve：
  mrchCode / txnClientNo / stlAcctNo=SM2(...)
  functionFlag = "9"
  outMemberCode = payBankEMemberCode（明文）
  inMemberCode  = recBankEMemberCode（明文）
  outSubAcctName = SM2(payBankAccountName)
  inSubAcctName  = SM2(recBankAccountName)
  tranType = "01"
  orderNo  = transNo（业务主单号）
  remark   = "Remark"（固定字符串，非请求 remark）
  messageOrderNo  = validOrderNo（明文）
  messageCheckCode = SM2(verifySmsCode | verifyCode)
```

### 2.3 返回（BasTransTransferRes）

| 字段 | 来源 | 说明 |
|---|---|---|
| queryId | 响应 queryId | 银行渠道流水 |
| userSsn | **= queryId**（lsym 将两者同赋 queryId，未取响应 USER_SSN 字段） | 银行用户流水 |
| transSsn | front 生成 | 渠道请求流水 |
| sysRespCode/sysRespDesc | 响应 | 平台层失败时取 errCode/errInfo |
| status | 未设置 | —— |
| transId/transNo/transSubId/transSubNo | 回显 | —— |

## 3. 成功判定与错误通道（两接口一致）

```text
平台层：errCode == "D5000000" && errInfo == "success"
银行层：sysRespCode == "000000"
成功   ：两层全过 → code=SUCCESS
平台成功+银行失败：code=FAIL，保留 transSsn + sysRespCode/sysRespDesc
平台失败：code=FAIL，sysRespCode/sysRespDesc ← errCode/errInfo，
          message = 完整银行响应 JSON 字符串（调用方可读原始错误）
系统异常：code=FAIL，message=系统繁忙
```

## 4. 常量取值（CommonConstants）

| 常量 | 值 |
|---|---|
| CONSUME_VERIFICATION_TYPE_SMS | "SMS" |
| CONSUME_VERIFICATION_TYPE_CODE | "CODE" |
| TRANS_TYPE_WD | "WD"（提现） |
| TRANS_TYPE_T | "T"（转账/支付） |
| Pa_RESP_UMS_SUCCESS_FLAG | "success" |
| Pa_RESP_UMS_SUCCESS_CODE_D5000000 | "D5000000" |
| Pa_RESP_SUCCESS_000000 | "000000" |
