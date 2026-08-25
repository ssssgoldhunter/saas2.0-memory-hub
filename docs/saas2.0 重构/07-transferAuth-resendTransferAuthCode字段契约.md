# transferAuth / resendTransferAuthCode 字段契约

> 状态：**已按 25 号 spec 重写（2026-08-21，两接口出参公用化 + 语义键 + AuthType + §3A 查重）**
>
> 契约唯一事实来源：25-平安授权转账接口改造-spec（本文是其展开说明，口径以 25 号为准）
>
> 范围：短信鉴权转账 `transferAuth`、转账授权码发送或重发 `resendTransferAuthCode`
>
> 银行：仅平安 `pajzb`；中信 `zxegj` 明确不支持（未登记 capability → F200002，用户裁决）

> 当前结构：两项能力均属于 Transaction 域，分别由平安强类型 Capability 实现，经
> `FrontTransExecuteNode → BankTransCapabilityRegistry` 路由；不再使用 `PingAnTransHandle` 或
> `BankRequestContext`。

## 1. 能力结论

| Front 方法 | 平安银行接口 | 固定用途 | 中信状态 |
|---|---|---|---:|---|
| `transferAuth` | `POST /cwap/account/send/transfer` | `bizFunc=45` | `UNSUPPORTED`（F200002） |
| `resendTransferAuthCode` | `POST /cwap/account/send/gen-auth-code` | `bizFunc=26` | `UNSUPPORTED`（F200002） |

平安 v5.5 定义的是"申请短信动态码"，没有另一个"重发"银行接口。Front 的首次发送和重发使用同一
`resendTransferAuthCode` 方法：每次都生成新的 `transSsn/transTime` 并重新申请，不把旧指令号传给银行。

## 2. 对外契约（25 号 spec §1）

### 2.1 两段式请求

两个方法统一使用 `FrontRequest<T>`：`baseData` 跨银行公共业务字段 + `specialData` 动态特殊字段。
`AuthTransferBusinessData extends TransferBusinessData`、`TransferAuthCodeBusinessData extends
BaseTransactionBusinessData`，**均不增加新字段**。

### 2.2 接口一 resendTransferAuthCode（授权码申请/重发，bizFunc=26）

**组装输入**（`FrontSpecialDataAssembler` 标准结构 + authType）：

| 输入 | 必填 | 说明 |
|---|---|---|
| auth.authType | 是 | `AuthType` 枚举：`SMS`（本期）/ `APP`（预留，组装即拒绝 INVALID_REQUEST） |
| pay.bankEMemberCode / pay.bankEAccountId | 是/是 | 付款会员/账户 |
| rec.bankEAccountId | 是 | 收款账户 |

**请求 specialData（组装器输出，3 个对外语义键）**：

| 键 | 值来源 | 上送银行 |
|---|---|---|
| `payMemberCode` | pay.bankEMemberCode | 顶层 mchntMbrId 明文 |
| `payAccountNo` | pay.bankEAccountId | 顶层 acctNo，SM2 |
| `recAccountNo` | rec.bankEAccountId | reserve intAcctNo，SM2 |

**返回 `R<FrontTransResult>`**（公用，无专用结果对象）。成功时 specialData：

| 键 | 说明 |
|---|---|
| `authType` | 本次签发的授权码类型（本期固定 SMS；请求带 authType 则原样回显） |
| `authOrderNo` | 授权指令号（银行响应 reserve.smsIdx 解密；**原样回传接口二**） |
| `receiveMobile` | 接收手机号（authType=SMS 时返回；默认按 SM2 解密，见 §8） |

失败时 specialData 为空对象，msg/frontRespDesc=银行原文（全局失败直返规则）。

### 2.3 接口二 transferAuth（授权转账，bizFunc=45）

**组装输入**：pay/rec 标准结构（同 transfer）+ auth 扩展：

| auth 字段 | 必填 | 说明 |
|---|---|---|
| auth.authType | 是 | 同接口一 |
| auth.authOrderNo | 是 | 接口一返回的 authOrderNo **原样回传** |
| auth.authCode | 是 | 用户本次输入的验证码 |

**请求 specialData（组装器输出，9 个对外语义键）**：

| 键 | 值来源 | 上送银行 |
|---|---|---|
| `payMemberCode` / `recMemberCode` | pay/rec.bankEMemberCode | reserve outMemberCode/inMemberCode 明文 |
| `payAccountNo` / `recAccountNo` | pay/rec.bankEAccountId | 顶层 outAcctNo/inAcctNo，SM2 |
| `payName` / `recName` | pay/rec.bankAccountName | reserve 户名，SM2 |
| `authType` | auth.authType | Front 内部判定（不上送银行） |
| `authOrderNo` | auth.authOrderNo | reserve messageOrderNo 明文 |
| `authCode` | auth.authCode | reserve messageCheckCode，SM2 |

**返回 `R<FrontTransResult>`**：与 transfer 完全一致；成功 specialData 为空对象。

## 3. 键名与枚举规范（25 号 spec §2）

### 3.1 对外语义键（唯一命名，两接口闭环）

```text
authType / authOrderNo / authCode / payMemberCode / recMemberCode
```

- 请求/响应 `specialData` 键一律使用语义键，**禁止**出现银行协议键（outMemberCode/inMemberCode/
  outAcctNo/inAcctNo/outSubAcctName/inSubAcctName/messageOrderNo/messageCheckCode/smsIdx）；
- `authOrderNo` 同名闭环：接口一返回值由接口二原样回传，不得改写；
- `transfer/consume` 的 specialData 会员键同步更名 `payMemberCode/recMemberCode`
  （原 `outAcctId/inAcctId`，不留兼容别名）。

### 3.2 协议键常量分层（ContractKeys）

| 常量类 | 对外键（语义键） | 银行协议键（Capability 内部） |
|---|---|---|
| `PingAnTransferAuthContractKeys` | `PAY_MEMBER_CODE/REC_MEMBER_CODE`、`PAY_ACCOUNT_NO("payAccountNo")/REC_ACCOUNT_NO("recAccountNo")/PAY_NAME("payName")/REC_NAME("recName")`、`AUTH_ORDER_NO("authOrderNo")/AUTH_CODE("authCode")/AUTH_TYPE("authType")` | `RESERVE_OUT_MEMBER_CODE("outMemberCode")/RESERVE_IN_MEMBER_CODE("inMemberCode")/RESERVE_OUT_SUB_ACCT_NAME("outSubAcctName")/RESERVE_IN_SUB_ACCT_NAME("inSubAcctName")/RESERVE_MESSAGE_ORDER_NO("messageOrderNo")/RESERVE_MESSAGE_CHECK_CODE("messageCheckCode")` |
| `PingAnTransferAuthCodeContractKeys` | `PAY_MEMBER_CODE/PAY_ACCOUNT_NO("payAccountNo")/REC_ACCOUNT_NO("recAccountNo")`、响应键 `AUTH_ORDER_NO/AUTH_TYPE` | `RESERVE_IN_ACCT_NO("intAcctNo")`、响应银行键 `RESPONSE_SMS_INDEX("smsIdx")/RESPONSE_RECEIVE_MOBILE("receiveMobile")` |
| `PingAnTransferContractKeys` | `PAY_MEMBER_CODE("payMemberCode")/REC_MEMBER_CODE("recMemberCode")`（transfer/consume 会员键） | `RESERVE_OUT_ACCT_ID("outAcctId")/RESERVE_IN_ACCT_ID("inAcctId")` |

### 3.3 AuthType 枚举（api-front `model.enums`，新增）

| 值 | 含义 | 状态 |
|---|---|---|
| `SMS` | 短信动态码（平安 bizFunc=26/45） | 本期 |
| `APP` | App 授权 | 预留；组装器与 Capability 双层拒绝（INVALID_REQUEST） |

## 4. Capability 内部映射（语义键 → 银行协议键 + SM2）

### 4.1 transferAuth（bizFunc=45）

| 银行字段 | 来源 | 规则 |
|---|---|---|
| 顶层 mchntMbrId | `specialData.payMemberCode` | 明文 |
| 顶层 outAcctNo / inAcctNo | `specialData.payAccountNo/recAccountNo` | SM2 |
| 顶层 transAmt / fee / pwd | baseData.amount/fee、固定空串 | 人民币分 |
| reserve mrchCode/txnClientNo/stlAcctNo | accountSpecialData | stlAcctNo SM2 |
| reserve functionFlag / tranType | Capability 常量 `9` / `01` | 固定 |
| reserve outMemberCode / inMemberCode | `specialData.payMemberCode/recMemberCode` | 明文 |
| reserve outSubAcctName / inSubAcctName | `specialData.payName/recName` | SM2 |
| reserve orderNo / remark | baseData.bizOrderNo / baseData.remark | orderNo ≤30、remark ≤120 |
| reserve messageOrderNo | `specialData.authOrderNo` | 明文（接口一闭环值） |
| reserve messageCheckCode | `specialData.authCode` | SM2 |

**authType 校验**：`specialData.authType` 必填且必须为 `SMS`；缺失或 APP → `INVALID_REQUEST`（Capability 层
双层拒绝，直传协议键绕过组装器时仍生效）。

### 4.2 resendTransferAuthCode（bizFunc=26）

| 银行字段 | 来源 | 规则 |
|---|---|---|
| 顶层 mchntMbrId | `specialData.payMemberCode` | 明文 |
| 顶层 acctNo | `specialData.payAccountNo` | SM2 |
| 顶层 transAmt | baseData.amount | 人民币分 |
| reserve mrchCode/txnClientNo/stlAcctNo | accountSpecialData | stlAcctNo SM2 |
| reserve tranType | Capability 常量 `2`（支付） | 固定 |
| reserve orderNo / remark | baseData.bizOrderNo / baseData.remark | orderNo ≤30、remark ≤120 |
| reserve intAcctNo | `specialData.recAccountNo` | SM2；**协议原始拼写 intAcctNo，禁止改成 inAcctNo** |

**authType 校验**：请求 wire specialData 不要求 authType（组装器仅入参校验、不输出该键），缺失按 SMS
默认放行；一旦出现且非 SMS（APP）→ `INVALID_REQUEST`（双层拒绝）。

## 5. 重复交易检查策略（25 号 spec §3A，2026-08-21 用户确认）

授权场景含两次渠道操作（发码 → 授权转账），共表后 `checkDuplicateTransaction` 按能力区分：

| 能力 | 查重策略 | 理由 |
|---|---|---|
| 验证码发送（TRANSFER_AUTH_CODE_RESEND） | **豁免查重**：每次发码直接插新记录（新 frontSsn），`DEDUP_LOCKS` 一并豁免 | 非资金操作，重发合法（用户未收到短信）；渠道表多行记录即发送历史日志 |
| 授权转账（TRANSFER_AUTH） | 查重**限定 capability=TRANSFER_AUTH** | 资金交易保持幂等（重复授权请求 F300001 拦截）；不被发码记录误伤 |
| transfer / consume | 查重限定本 capability（共表误伤隐患顺手修正） | 同一业务键不同能力互不干扰 |

改后行为：首次发码✅ → 重发✅（新行）→ 授权转账✅（只看 TRANSFER_AUTH 行）→ 重复授权请求❌F300001。

## 6. 响应判定与映射

两个接口成功都必须同时满足：

```text
errCode == D5000000 && errInfo == success && sysRespCode == 000000
```

- `frontRespCode/frontRespDesc` 统一取 `FrontErrorCode`，银行原始码只用于 Capability 判定与渠道流水；
- `frontStatus`：SUCCESS / UNKNOWN（WALLET_RESULT_UNKNOWN）/ FAILED（其余）；
- 失败时顶层 `R.code` 也为失败码，`frontRespDesc`/`R.msg` 覆写为银行原始错误描述原文（取值优先级
  sysRespDesc > sysRespCode > errInfo > errCode），specialData 为空对象；
- `frontSsn` = Capability 生成的 22 位 transSsn；`frontQueryId` = 银行 queryId；
- 接口一成功 `specialData`：`authType/authOrderNo/receiveMobile`（见 §2.2）；接口二成功
  `specialData`：空对象。

## 7. 常量入口

```text
catering-common/catering-common-core/src/main/java/com/chinaums/common/core/constant/front
├─ PingAnTransferAuthContractKeys.java
├─ PingAnTransferAuthCodeContractKeys.java
└─ PingAnTransferContractKeys.java
```

- `bizFunc=45/26`、`chnlNo=0001`、`functionFlag/tranType` 等调用控制值由两个平安 Transaction Capability 的
  带注释本地常量确定，不进入 ContractKeys；
- ContractKeys 只保存协议字段 key（对外语义键 + Capability 内部协议键），键名分层见 §3.2；
- 银行协议 DTO、加密实现和 HTTP 客户端仍放在 `catering-front/channel/pingan`。

## 8. receiveMobile 解密口径（25 号 spec §4.1）

lsym 明文直取、SaaS 当前解密。**默认保持解密**（若联调发现银行返回明文导致解密失败，按 §4.1 修正
并同步本文）；验证码申请 tranType 固定 2（支付，§4.2 保持）。

## 9. 渠道流水（零 DDL）

- 两能力均写入 `front_pingan_transfer_transaction`，通过 `capability`（TRANSFER_AUTH /
  TRANSFER_AUTH_CODE_RESEND）与普通 TRANSFER 区分；中信不支持，不创建空记录；
- **authOrderNo 不落渠道列**（specialData 返回 + frontSsn/bankQueryId 已足够关联）；
- 每条记录保留业务主/子记录关联和明确业务字段，不保存报文快照；验证码不得进入任何数据库字段。

## 10. 实施约束

1. 两个平安能力只实现 `BankTransCapability`，中信保持未登记（F200002）；
2. 从同一个 `FrontTransSlot` 读取 baseData、specialData 和已加载 accountConfig，不创建第二上下文；
3. 逐字段组装钱包基础字段和 `reserve`，禁止 `putAll`；
4. 银行调用固定走 `BankWalletGateway.post(bank, …)`，禁止直连 HttpClient；
5. `transSsn/transTime` 每次生成；`bizFunc/chnlNo/functionFlag/tranType` 使用 Capability 本地常量；
6. Capability 不重复输出钱包报文；最终 Sender 唯一记录完整明文请求/响应 body，不脱敏；
   `appKey`、私钥、签名材料、认证 Header、`Authorization`、`Cookie` 不进入日志；
7. 超时或无法确认银行是否受理时返回 `UNKNOWN/F400002`，资金交易不得盲目重试；
8. 未经用户明确授权，不新增测试类、不运行测试、不执行编译。
