# lsym 平安授权转账原始流程（transferAuth / resendTransferAuthCode）

> 状态：reference（lsym 静态代码取证，2026-08-21）
>
> 来源代码：`IdeaProjects_lsym_dep/slhy/fund-catering`（fund-catering-front + fund-catering-consume）
>
> 用途：SaaS catering-front 平安授权转账能力的原始业务流程基线；只记录 lsym 事实，不含 SaaS 改造结论（改造见 24 号）。

## 1. 业务总流程（两阶段）

授权转账是**跨两次用户交互**的流程：先申请短信动态码，用户收到短信输入验证码后，再发起带验证码的转账。

```text
【阶段 1：验证码申请】consume TransferTransSendVerify 节点
  组装 BasTransVerificationReq（pay/rec 账户四要素 + 金额 + transType）
  → Feign: front sendSmsVerification
  → PaTransSendVerificationHandle：bizFunc=26（申请提现或支付短信动态码 KFEJZB6082）
  → 成功返回：queryId + transSsn + receiveMobile + smsIdx（SM2 解密后即短信指令号）
  → consume 落地：
      · TransValidLog 新增（transValidSsn/receiveMobile/receiveOrderNo=解密 smsIdx）
      · transfer_sub 表回写 transValidSsn + transValidOrderNo
      · 子流水状态 → V（待验证）

【用户交互】短信到达用户手机，用户在业务界面输入验证码

【阶段 2：授权确认转账】consume TransferTransAuth 节点
  前置校验：
    · 付款子账户可用余额充足（balance - frozenAmt ≥ transAmt）
    · 付款/收款账户同一名下（certNoEnc 相等）
  冻结交易金额（FROZEN_TYPE_F，冻结明细表）
  组装 BasTransTransferReq：
    · validOrderNo = transfer_sub.transValidOrderNo（阶段 1 存储的短信指令号）
    · verifySmsCode = 用户本次输入的验证码（verifityType=SMS）
  → Feign: front transTransferAuth
  → PaTransTransferHandle：bizFunc=45（会员间交易-验证短信动态码 6101）
  → 成功：slot.transTransferResult，流程继续（后续节点更新流水成功态）
  → 失败/异常：主/子流水置 F + bankRespCode/Desc 回写，并解冻（FROZEN_TYPE_UF）
```

## 2. front 侧流程（lsym fund-catering-front-service）

### 2.1 入口链

```text
FrontTransVerificationController.sendSmsVerification(BasTransVerificationReq)
  → TransVerificationService(Impl) → 按平台路由
  → PaTransSendVerificationHandle.sendSmsVerification(request, plaformInfo)
授权转账无独立 Verification 入口：
  FrontTransConsumeController → BasTransConsumeHandle 体系
  → PaTransTransferHandle.transTransferAuth(request, plaformInfo)
```

`plaformInfo`（BasPlatformSettleInfoQueryRes）由上游传入，承载银行接入配置：
`platformAppIdBank/platformAppKeyBank/platformUrlBank/platformMchntId/platformChannelNo`
+ `extra.platformMrchcode/platformTxnclientno/platformSummaryAccount`（reserve 三件套）。

### 2.2 Handle 内部步骤（两个接口同构）

```text
1. 回显定位：res 预填 transId/transNo/transSubId/transSubNo
2. 组装银行请求（字段映射见 23 号功能文档）：
   · 顶层：transSsn（22 位）、transTime、mchntId/mchntMbrId、chnlNo、bizFunc、
     账号类 SM2 加密、transAmt、fee（空补 "0"）、ccy=CNY、pwd=""
   · reserve：平台三件套（stlAcctNo 加密）+ 业务字段
3. saasPaInterService.paTansfer / applyWithdrawOrPaymentAuthCode 发送
4. 三层成功判定：
   errCode=D5000000 && errInfo=success（平台层）→ sysRespCode=000000（银行层）
5. 结果组装 DefaultResult：code/success/message（失败时 message=完整银行响应 JSON 字符串）
6. 异常兜底：code=FAIL，message="系统繁忙"
```

### 2.3 验证码申请的平台层成功但银行层失败分支

bizFunc=26 与 45 均为两层判断：平台层成功、银行层失败时仍返回
`sysRespCode/sysRespDesc + transSsn`（code=FAIL）——调用方可以拿到渠道流水号做后续查询。

## 3. consume 侧流程细节（fund-catering-consume-service）

### 3.1 TransferTransSendVerify（验证码申请节点，isAccess: transType=T）

```text
输入来源：TransSlot.transferTransVo（转账主/子信息）+ compayInfoMaps（企业银行要素）
Feign 调用成功后：
  createValidLog：
    1. TransValidLog 表新增：
       transValidSsn=res.transSsn（front 生成的 22 位流水）
       receiveMobile=res.receiveMobile
       receiveOrderNo=res.receiveOrderNo（= 解密后的 smsIdx，短信指令号）
       validChannelSmscode=1（SMS 类型标记）
    2. transfer_sub 表更新 transValidSsn + transValidOrderNo
    3. 任一落地失败 → 抛 BaseException 中断链
  子流水状态 → CONSUME_STATUS_V
```

### 3.2 TransferTransAuth（授权确认节点）

```text
校验：
  1. 付款子账户余额充足（balance - frozenAmt - transAmt ≥ 0，不足抛 BALANCE_NOT_ENOUGH_ERR）
  2. 付款/收款 certNoEnc 相同（同名，否则抛 TRANS_ACCOUNT_BUS_NOT_SUPPORT）
冻结：
  handleTransFrozens(F)：写冻结明细（accountId/subAccountId/transAmt/transType=T）
失败补偿：
  · BaseException（含银行拒绝）：updateFailureResult —— 主流水置 F +
    子流水回写 transSsn/bankRespCode/bankRespDesc，然后解冻(UF)
  · BaseASException（系统异常）：解冻(UF)后重抛
messageOrderNo 来源：transfer_sub.transValidOrderNo（阶段 1 落库值），不是本次请求新生成
verifySmsCode 来源：transferTransVo.verificationCode（用户本次输入）
verifityType：SMS → verifySmsCode；否则 → verifyCode（lsym 保留双通道，pa 实际只用 SMS）
```

### 3.3 trans_valid_log 表与指令号数据流（2026-08-21 补充取证）

`TransValidLog`（trans_valid_log）是**验证码发送审计日志表**，逐次追加、不覆盖：

| 字段 | 内容 |
|---|---|
| transId/transNo/transSubId/transSubNo | 业务主/子单定位 |
| receiveMobile | 本次接收手机号 |
| receiveOrderNo | 本次短信指令号（= 解密 smsIdx） |
| transValidSsn | 本次 front 生成的 22 位流水 |
| validChannelSmscode / validChannelValidcode | 通道标记（SMS=1 / CODE=1） |
| createBy/createTime | 审计 |

数据进出（申请/重发/授权三场景）：

```text
申请①  → valid_log INSERT #1（指令A，手机号） → transfer_sub.transValidSsn/ValidOrderNo ← A（覆盖式），子单状态→V
重发   → valid_log INSERT #2（指令B）        → transfer_sub.ValidOrderNo ← B（覆盖 A）
授权   → 读 transfer_sub.transValidOrderNo（=B）上送 messageOrderNo → 状态 成功/F
```

- **唯一写点**：TransferTransSendVerify.createValidLog（申请与重发共用同一节点，链
  chainTransferReSendVerification = Pack 校验（原单存在且状态=V + cardBin 决定
  verifityType）→ 六个 check → 复用 transferTransSendVerify）；
- **授权读取的是 transfer_sub 的当前值**，不查 log 表；
- log 表的 selectPage/selectList 为通用查询（主代码无活跃调用方，运营/排查预留）；
- 双层设计：**log 表=逐次历史（审计），sub 表字段=当前生效指令号（授权用）**——
  SaaS consume 侧需要等价双层存储。

## 4. 关键业务语义（SaaS 迁移必须保留的边界）

| 语义 | lsym 实现 | 职责层 |
|---|---|---|
| 短信指令号跨请求传递 | 阶段 1 返回解密 smsIdx → 业务表存储 → 阶段 2 作为 messageOrderNo 上送 | consume |
| 验证码时效/重发 | bizFunc=26 每次生成**新** transSsn + 新 smsIdx；重发即重新申请（SaaS 同口径：不传原指令号） | front |
| 资金冻结/解冻 | 授权期间冻结交易金额，失败/异常解冻 | consume（front 无冻结职责） |
| 余额/同名校验 | 授权确认前业务校验 | consume（front 不做业务资格校验） |
| 渠道流水 | front 侧无独立流水表（旧体系）；SaaS 已按渠道表补齐 | front（SaaS 增强） |
