# 平安授权转账接口改造 spec（transferAuth / resendTransferAuthCode）

> 状态：implemented（2026-08-21 用户逐项确认：出参公用化、payMemberCode、authType、authOrderNo/authCode 统一；同日按 26 号 plan T1-T16 实施完毕，待用户 review 后提交）
>
> 依据：22/23 号 lsym 取证、24 号迁移方案（本文是其可实施契约化）
>
> 范围：仅平安 pajzb；中信不实现（F200002，用户裁决）

## 1. 对外契约定稿

### 1.1 接口一 resendTransferAuthCode（授权码申请/重发，bizFunc=26）

**组装输入（先转换——FrontSpecialDataAssembler 标准结构 + authType）**

| 输入 | 必填 | 说明 |
|---|---|---|
| authType | 是 | `AuthType` 枚举：`SMS`（本期）/ `APP`（预留，当前组装即拒绝） |
| pay.bankEMemberCode / pay.bankEAccountId | 是/是 | 付款会员/账户 |
| rec.bankEAccountId | 是 | 收款账户（reserve intAcctNo） |

**请求 specialData（组装器输出）**

| 键 | 值来源 | 上送银行 |
|---|---|---|
| payMemberCode | pay.bankEMemberCode | mchntMbrId 明文 |
| payAccountNo | pay.bankEAccountId | 顶层 acctNo，SM2 |
| recAccountNo | rec.bankEAccountId | reserve intAcctNo，SM2 |

**返回 `R<FrontTransResult>`（公用，无专用结果对象）成功时 specialData：**

| 键 | 说明 |
|---|---|
| authType | 本次签发的授权码类型（SMS/APP） |
| authOrderNo | 授权指令号（银行响应 reserve.smsIdx 解密；**原样回传接口二**） |
| receiveMobile | 接收手机号（authType=SMS 时返回；解密口径见 §4.1） |

失败时 specialData 为空对象，msg/frontRespDesc=银行原文（全局失败直返规则）。

### 1.2 接口二 transferAuth（授权转账，bizFunc=45）

**组装输入：pay/rec 标准结构（同 transfer）+ auth 扩展**

| auth 字段 | 必填 | 说明 |
|---|---|---|
| authType | 是 | 同接口一 |
| authOrderNo | 是 | 接口一返回的 authOrderNo 原样回传 |
| authCode | 是 | 用户本次输入的验证码 |

**请求 specialData（组装器输出，统一语义键）：**

| 键 | 值来源 | 上送银行 |
|---|---|---|
| payMemberCode / recMemberCode | pay/rec.bankEMemberCode | reserve outMemberCode/inMemberCode 明文 |
| payAccountNo / recAccountNo | pay/rec.bankEAccountId | 顶层 outAcctNo/inAcctNo，SM2 |
| payName / recName | pay/rec.bankAccountName | reserve 户名，SM2 |
| authType | auth.authType | Front 内部判定（不上送银行） |
| authOrderNo | auth.authOrderNo | reserve messageOrderNo 明文 |
| authCode | auth.authCode | reserve messageCheckCode，SM2 |

**银行协议键只在 Handle 内部出现**（reserve `messageOrderNo/messageCheckCode`、响应
`smsIdx`），调用方不感知。

**返回 `R<FrontTransResult>`**：与 transfer 完全一致；成功 specialData 为空对象。

## 2. 键名与枚举规范

### 2.1 对外语义键（唯一命名，两接口闭环）

```text
authType / authOrderNo / authCode / payMemberCode / recMemberCode
```

### 2.2 协议键常量分层（ContractKeys）

| 常量类 | 对外键（新增/更名） | 银行协议键（保留原名，Handle 内部） |
|---|---|---|
| PingAnTransferAuthContractKeys | PAY_MEMBER_CODE/REC_MEMBER_CODE、AUTH_ORDER_NO("authOrderNo")、AUTH_CODE("authCode")、AUTH_TYPE("authType") | RESERVE_MESSAGE_ORDER_NO("messageOrderNo")、RESERVE_MESSAGE_CHECK_CODE("messageCheckCode") |
| PingAnTransferAuthCodeContractKeys | AUTH_ORDER_NO、AUTH_TYPE | RESPONSE_SMS_INDEX("smsIdx")、RESPONSE_RECEIVE_MOBILE |
| PingAnTransferContractKeys | PAY_MEMBER_CODE/REC_MEMBER_CODE（更名自 PAY_MEMBER_ID/REC_MEMBER_ID，transfer/consume 同步） | — |

### 2.3 AuthType 枚举（api-front model.enums，新增）

| 值 | 含义 | 状态 |
|---|---|---|
| SMS | 短信动态码（平安 bizFunc=26/45） | 本期 |
| APP | App 授权 | 预留；组装/Handle 双层拒绝 |

## 3. 流程（两接口与 transfer/consume 一致，先转换后请求）

```text
收集标准结构（pay/rec/auth + authType）
→ FrontSpecialDataAssembler.assemble()（转换：标准结构 → specialData 语义键）
→ 确认
→ FrontTransApi.transferAuth / resendTransferAuthCode
→ LiteFlow 链（校验 → tenantBaseConfigResolve → 路由 → 配置 → dispatch → Handle）
→ Handle 内部：语义键 → 银行协议键映射 + SM2 加密 → 银行
→ R<FrontTransResult>（接口一成功 specialData 带 authType/authOrderNo/receiveMobile）
```

## 3A. 重复交易检查策略（2026-08-21 用户确认场景后新增）

授权场景含两次渠道操作（发码 → 授权转账），共表后 `checkDuplicateTransaction` 的
`tenantId + bizOrderNo + bizSubOrderNo` 查重会跨 capability 误伤，必须按能力区分：

| 能力 | 查重策略 | 理由 |
|---|---|---|
| 验证码发送（TRANSFER_AUTH_CODE_RESEND） | **豁免查重**：每次发码直接插新记录（新 frontSsn），DEDUP_LOCKS 一并豁免 | 非资金操作，重发合法（用户未收到短信）；渠道表多行记录即发送历史日志（等价 lsym trans_valid_log 的审计层） |
| 授权转账（TRANSFER_AUTH） | 查重**限定 capability=TRANSFER_AUTH** | 资金交易保持幂等（重复授权请求 F300001 拦截）；不被发码记录误伤 |
| transfer / consume | 查重限定本 capability（共表误伤隐患顺手修正） | 同一业务键不同能力互不干扰 |

改后行为：首次发码✅ → 重发✅（新行）→ 授权转账✅（只看 TRANSFER_AUTH 行）→
重复授权请求❌F300001。

## 4. 待确认项（不阻塞实施，实施时按默认处理）

### 4.1 receiveMobile 解密口径

lsym 明文直取、SaaS 当前解密。**默认保持解密**（若联调发现银行返回明文导致解密失败，
按 §4.1 修正并同步 07 号）。

### 4.2 验证码申请 tranType 固定 2（支付）

SaaS 平安提现不接短信验证码（当前结论），保持固定 2。

## 5. 验收标准

1. 两接口返回类型均为 `R<FrontTransResult>`，`FrontTransferAuthCodeResult` 删除；
2. specialData 键全部为 §2.1 语义键；代码中无 `payMemberId/recMemberId/messageOrderNo/
   messageCheckCode/smsIdx` 作为对外 specialData 键的残留（协议键常量除外）；
3. 接口一返回 authOrderNo 与接口二请求 authOrderNo 同名闭环（值原样回传）；
4. authType=SMS 全链路贯通；APP 组装与 Handle 双层明确拒绝（F200002 或 INVALID_REQUEST）；
5. transfer/consume 的 specialData 会员键同步更名 payMemberCode/recMemberCode，组装器、
   Handle、20 号手册同步；
6. 中信两接口 F200002 不变；
7. 重复交易检查按 §3A 策略：验证码可重复发送（每次新 frontSsn 新行）、授权转账
   幂等拦截、跨 capability 不误伤；
8. 渠道流水、错误原文直返等既有行为不回退；
9. 未授权不编译、不测试、不提交。

## 6. 渠道表 authType 落库（2026-08-21 用户裁决，修订 26 号 plan T10「front 侧零 DDL」结论）

> 裁决背景：原 T10 结论「本期恒 SMS，auth_type 列无信息量」不再成立——authType 后续需支持
> SMS/APP 区分，渠道表现在就加列记录（2026-08-21 用户裁决，推翻零 DDL 结论）。

- **列定义**（存量库 ALTER 见 `09D-pingan-auth-type.sql`；09A/09B/09-final 已同步）：

  ```sql
  `auth_type` VARCHAR(8) DEFAULT NULL COMMENT '授权类型（AuthType枚举：SMS/APP；仅 TRANSFER_AUTH、TRANSFER_AUTH_CODE_RESEND 行写入，普通转账行与历史行为 NULL）'
  -- 位置：capability 列之后
  ```

- **写入规则**（INIT 即定型，updateResponse 不回写）：
  - `TRANSFER_AUTH` 行：`entity.authType = specialData.authType（已校验 SMS）`，缺省 `"SMS"`；
  - `TRANSFER_AUTH_CODE_RESEND` 行：`entity.authType = requestAuthType(specialData)`（缺省 `"SMS"`）；
  - `TRANSFER`/`CONSUME`/`WITHDRAW` 行：不写该列（NULL）；
- **存量历史行不回填**（NULL 即代表 SMS-only 历史时期）；**APP 开放前新行恒为 `'SMS'`**；
- **不加索引**（低基数列）；渠道表零快照、只存明确业务字段的既有约束不变。
