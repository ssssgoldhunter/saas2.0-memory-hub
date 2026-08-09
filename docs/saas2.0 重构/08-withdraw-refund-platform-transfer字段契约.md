# withdraw、refund、platformPay、platformReceive 字段契约

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：中信退款字段来源已修订
> 最近确认日期：2026-08-09
> 范围：中信、平安提现；内部系统长短款真退款；中信平台付款、平台收款

## 1. 先给结论

| Front 能力 | 中信 | 平安 | 新 Front 约束 |
|---|---|---|---|
| `withdraw` | 真实 `/withdrawal`，当前 `bizFunc=26` | 真实 `/withdrawal`，当前 `bizFunc=01` | 两家均保留，金额单位为分 |
| `refund` | 银行有真实 `/refund`，应使用 `bizFunc=23` | 真实 `/refund`，当前 `bizFunc=02` | 当前只服务内部长短款，必须真退款，禁止反向转账 |
| `platformPay` | 真实 `/transfer`，`bizFunc=2041` | 无等价实现 | 仅中信，平安 `UNSUPPORTED` |
| `platformReceive` | 真实 `/transfer`，`bizFunc=2042` | 无等价实现 | 仅中信，平安 `UNSUPPORTED` |

中信退款存在两个代码版本，必须区分：

- 旧 mdl `ZxTransConsumeCancelHandle` 组装 `ZxTransferRequest`、写入 `bizFunc=27` 并调用
  `zxTransfer`，本质是反向转账，只能作为反例；
- 最新 `/Users/limeng/workspaces/IdeaProjects_lsym_uat/slhy` 分支
  `lsym_20260625_limeng_refundTask`、提交 `3dff8255d6` 已改为构造 `ZxRefundRequest`，固定
  `bizFunc=23/chnlNo=0010`，调用 `SaasZxInterService.zxRefund()` 和真实 `/refund`。

最新 lsym UAT 是当前中信退款字段的代码参考；新 Front 按自己的 `baseData + specialData`、账户配置和
脱敏日志边界实现，不查询本地原渠道流水补齐中信退款银行字段。

## 2. 新 Front 方法与参考实现映射

| 新方法 | 参考入口/Service | 中信具体类 | 平安具体类 | 核对结果 |
|---|---|---|---|---|
| `refund()` | `FrontTransConsumeFacadeApi.transConsumeCancel()` → `TransConsumeServiceImpl.transConsumeCancel()` | 最新 lsym UAT `ZxTransConsumeCancelHandle` | mdl `PaTransConsumeCancelHandle` | 两家都是真退款；中信最新实现调用 `zxRefund/bizFunc=23` |
| `withdraw()` | `FrontTransConsumeFacadeApi.transWithDraw()` → `TransConsumeServiceImpl.transWithDraw()` | `ZxTransWithDrawHandle` | `PaTransWithDrawHandle` | 两家都调用真实提现接口 |
| `platformPay()` | `FrontTransConsumeFacadeApi.platformPay()` → `TransConsumeServiceImpl.platformPay()` | `ZxTransTransferHandle.platformPay()` | `PaTransTransferHandle` 未覆盖父类空实现 | 只有中信真实支持 |
| `platformReceive()` | `FrontTransConsumeFacadeApi.platformReceive()` → `TransConsumeServiceImpl.platformReceive()` | `ZxTransTransferHandle.platformReceive()` | `PaTransTransferHandle` 未覆盖父类空实现 | 只有中信真实支持 |

中信真退款协议链路应关联为：

```text
BankTransactionHandle.refund
→ CiticTransactionHandle.refund
→ ZxRefundRequest 等价的新协议 DTO
→ SaasZxInterService.zxRefund 等价客户端
→ POST /cwap/account/send/refund
```

不得关联为：

```text
refund → ZxTransferRequest → zxTransfer → /transfer
```

## 3. 对外请求对象

所有接口仍使用统一两段式请求：

```text
FrontRequest<T>
├─ baseData: 强类型公共业务数据
└─ specialData: JSONObject，当前银行和当前能力的动态扩展字段
```

Handle 内部继续使用：

```text
BankRequestContext<T>
├─ baseData
├─ specialData
└─ accountConfig
   ├─ appId/appKey/url/mchntId/mchntMbrId
   └─ accountSpecialData
      ├─ 平安 txnClientNo/mrchCode/stlAcctNo
      └─ 中信 default/self 角色、资金类型和自有资金映射配置
```

### 3.1 `RefundBusinessData`

| 字段 | 说明 | 来源约束 |
|---|---|---|
| `orgBizOrderNo` | 原交易业务主流水号 | 中信退款必填；与子流水成组 |
| `orgBizSubOrderNo` | 原交易业务子流水号 | 中信退款必填；与主流水成组 |
| `bizOrderNo/bizSubOrderNo` | 本次退款业务主/子流水号 | 继承公共交易对象 |
| `amount` | 本次退款金额 | 人民币分 |
| `fee` | 本次退款手续费 | 人民币分；无手续费传 0 |
| `refundReason` | 退款原因 | 中信映射 `MEMO`，平安映射 `reserve.remark` |

中信退款不使用 `orgFrontSsn/originalFrontSsn` 定位，也不把 Front `transSsn` 映射为银行
`ORI_USER_SSN`。原付款方、原收款方和原交易日期属于中信动态协议数据，由调用方使用请求
`specialData` 的银行原始 key 提供；Front 只做协议必填、格式、加密及报文组装校验，不查询本地原交易，
不校验原交易状态、原金额、累计退款金额或退款资格。平安退款边界尚未确认，不得从本节中信结论推导。

### 3.2 `WithdrawBusinessData`

`WithdrawBusinessData` 只保留继承自 `BaseTransactionBusinessData` 的内部业务公共字段。银行使用的提现
账户、会员、银行卡和姓名统一放入请求 `specialData`：

| specialData key | 说明 | 银行映射 |
|---|---|---|
| `acctNo` | 发起提现的银行用户/见证子账户 | 中信、平安 `acctNo`，按协议加密 |
| `outAcctId` | 发起提现的银行会员编号 | 平安 `mchntMbrId` |
| `cardNoEnc` | 收款银行卡号原始输入 | 两家请求 `cardNoEnc`，按协议加密且禁止写日志 |
| `nameEnc` | 提现会员/见证账户名称原始输入 | 平安 `reserve.nameEnc`，按协议加密 |
| `WITH_ACCNAME` | 中信银行卡持卡人姓名原始输入 | 中信 `reserve.WITH_ACCNAME`，按协议加密 |
| `userNameEnc` | 平安银行卡持卡人姓名原始输入 | 平安 `reserve.userNameEnc`，按协议加密 |
| `certNo` | 平安证件号码 | 平安 `reserve.certNoEnc`，按协议加密 |

`amount/fee/remark` 仍属于内部业务公共数据，保留在 `baseData`。上述 specialData 值可以按明确字段
保存到内部渠道表，本期不要求数据库字段加密；进入银行请求时仍必须按协议加密，且不得记录日志。

### 3.3 `PlatformTransferBusinessData`

该对象仅用于中信，基础对象只保留内部业务公共字段：

| 字段 | 说明 |
|---|---|
| `amount` | 平台收付款金额，人民币分 |
| `bizOrderNo/bizSubOrderNo` | 业务主/子流水号 |
| `businessDate/businessTime` | 业务日期和时间 |
| `remark` | 交易备注 |

中信动态协议字段进入请求 `specialData`：

| key | 说明 | 约束 |
|---|---|---|
| `outAcctNo` | 2042 用户付款账户 | 仅 platformReceive 使用，进入银行请求前加密 |
| `inAcctNo` | 2041 用户收款账户 | 仅 platformPay 使用，进入银行请求前加密 |
| `outAcctNm` | 2042 用户付款账户名称 | 仅 platformReceive 使用，进入银行请求前加密 |
| `inAcctNm` | 2041 用户收款账户名称 | 仅 platformPay 使用，进入银行请求前加密 |
| `dealType` | 交易类型 | 按 `2041/2042` 分别校验银行枚举 |
| `fundTp` | 资金类型 | 必须是租户中信已配置的资金类型，不允许任意值 |
| `contractId` | 合同编号 | 仅业务场景要求时选填 |

业务系统不得传入平台银行账号。中信 2041/2042 的平台一侧由商户自有资金登记簿隐式确定，银行
请求无需提供平台账户号；Handle 只上送用户侧账号和方向对应的用户名称。

## 4. 提现请求映射

### 4.1 中信 withdraw

```text
POST /cwap/account/send/withdrawal
bizFunc = 26
chnlNo  = 0010
```

| 银行字段 | 数据来源 | 说明 |
|---|---|---|
| `transSsn` | 中信 Handle 每次生成 | 保存渠道流水并可返回 `frontSsn` |
| `transTime` | 中信 Handle 每次生成 | 运行时字段 |
| `mchntId/mchntMbrId` | 租户银行通用账户配置 | 调用方不可覆盖 |
| `acctNo` | `specialData.acctNo` | 加密 |
| `cardNoEnc` | `specialData.cardNoEnc` | 加密 |
| `transAmt` | `baseData.amount` | 人民币分 |
| `remark` | `baseData.remark` | 按银行长度校验；长度待从 Word 协议确认 |
| `reserve.WITH_TYPE` | Handle 固定 `00` | 当前只开放用户提现，不开放平台提现 `01` |
| `reserve.BUSS_ID` | `baseData.bizOrderNo` | 业务主流水 |
| `reserve.TRANS_DT/TRANS_TM` | `baseData.businessDate/businessTime` | `yyyyMMdd/HHmmss` |
| `reserve.FEE_TYPE` | Handle 固定 `2` | 当前用户承担手续费 |
| `reserve.WITH_ACCNAME` | `specialData.WITH_ACCNAME` | 加密 |
| `reserve.laasSsn` | Handle 生成 | 外联平台流水 |

### 4.2 平安 withdraw

```text
POST /cwap/account/send/withdrawal
bizFunc = 01
chnlNo  = 0001
ccy     = CNY
```

| 银行字段 | 数据来源 | 说明 |
|---|---|---|
| `transSsn/transTime` | 平安 Handle 每次生成 | 规则可与中信不同 |
| `mchntId` | 租户银行通用账户配置 | 调用方不可覆盖 |
| `mchntMbrId` | `specialData.outAcctId` | 提现会员编号 |
| `acctNo` | `specialData.acctNo` | 加密 |
| `cardNoEnc` | `specialData.cardNoEnc` | 加密 |
| `transAmt` | `baseData.amount` | 人民币分 |
| `fee` | `baseData.fee` | 人民币分 |
| `remark` | `baseData.remark` | 旧 mdl 存在自赋值缺陷，新实现必须显式赋值；平安最大 512（C 512 O） |
| `reserve.tranWebName` | Handle 固定 `0001` | 调用方不可覆盖 |
| `reserve.certType` | Handle 固定 `24` | 只表达现有协议值，不擅自解释证件类型语义 |
| `reserve.certNoEnc` | `specialData.certNo` | 加密，禁止日志 |
| `reserve.nameEnc` | `specialData.nameEnc` | 加密 |
| `reserve.userNameEnc` | `specialData.userNameEnc` | 加密 |
| `reserve.stlAcctNo` | 平安 `accountSpecialData.stlAcctNo` | 加密 |
| `reserve.mrchCode/txnClientNo` | 平安账户配置 | 调用方不可覆盖 |

平安文档还存在 `bizFunc=36` 的短信及手续费提现，但现有真实业务 Handle 使用 `01`。首版只激活
`01`，不得未经确认自动切换到 `36`。

## 5. 真退款请求映射

### 5.1 中信 refund

```text
POST /cwap/account/send/refund
bizFunc = 23
chnlNo  = 0010
```

| 银行字段 | 数据来源 | 说明 |
|---|---|---|
| `transSsn/transTime` | 中信 Handle 每次生成 | 保存本次退款渠道流水 |
| `mchntId/mchntMbrId` | 租户银行通用账户配置 | 调用方不可覆盖 |
| `transAmt` | `baseData.amount` | 独立必填，人民币分且大于 0 |
| `ORI_USER_D_ID` | `specialData.ORI_USER_D_ID` | 独立必填；原付款用户编号 |
| `ORI_USER_D_NM` | `specialData.ORI_USER_D_NM` | 独立必填；原付款用户名称 |
| `ORI_USER_C_ID` | `specialData.ORI_USER_C_ID` | 独立必填；原收款用户编号 |
| `ORI_USER_C_NM` | `specialData.ORI_USER_C_NM` | 银行协议选填，有值时上送 |
| `ORI_USER_C_AMT` | `baseData.amount` | 原收款方本次退款金额，人民币分 |
| `P_SELF_FLAG/P_DEAL_AMT` | Handle 固定 `N/0` | 首版普通退款不含平台自有资金 |
| `REFUND_BUSS_ID/SUB_ID` | 本次 `bizOrderNo/bizSubOrderNo` | 两者独立必填，退款业务流水 |
| `ORI_BUSS_ID/SUB_ID` | `orgBizOrderNo/orgBizSubOrderNo` | 当前 Front 固定采用，成组必填 |
| `ORI_USER_SSN` | 当前 Front 不使用 | 银行协议支持的替代定位项；不得用 `orgFrontSsn/transSsn` 冒充 |
| `ORI_USER_TRANS_DT` | `specialData.ORI_USER_TRANS_DT` | 独立必填，格式 `yyyyMMdd` |
| `TRANS_DT/TRANS_TM` | 本次 `businessDate/businessTime` | 两者独立必填，格式 `yyyyMMdd/HHmmss` |
| `FUND_TP` | `accountSpecialData.default_fund_type` | 独立必填配置；不得取 `platformUserRole/default_role/self_role`，不查询原交易比对 |
| `MEMO` | `baseData.refundReason` | 退款原因 |
| `laasSsn` | Handle 生成 | 外联平台流水 |

当前退款仅供内部系统长短款修复，不激活 Word 中的 `ORI_USER_SHARE_*` 分润退款、平台出资退款、
普通业务退款扩展和 `REQ_RESERVED`；这些内容不属于当前需求，不进入常量类或请求白名单。

银行原协议允许 `ORI_BUSS_ID + ORI_BUSS_SUB_ID` 或 `ORI_USER_SSN` 二选一定位，但当前 Front 对外只
开放前者：调用方必须提供 `orgBizOrderNo + orgBizSubOrderNo`。这一定位选择不影响其他字段的必填性；
`ORI_USER_D_ID/ORI_USER_D_NM/ORI_USER_C_ID/ORI_USER_TRANS_DT` 仍必须完整提供。

渠道表中 `original_capability/original_channel_transaction_id/original_front_ssn/
original_biz_transaction_id/original_biz_sub_transaction_id` 是可空兼容保留列，不属于当前中信退款请求契约，
Handle 不读取、不回填。它们的存在不得改变上述“只使用原业务主子流水”的定位边界。

### 5.2 平安 refund

```text
POST /cwap/account/send/refund
bizFunc = 02
chnlNo  = 0001
```

| 银行字段 | 数据来源 | 说明 |
|---|---|---|
| `transSsn/transTime` | 平安 Handle 每次生成 | 保存本次退款渠道流水 |
| `mchntId/mchntMbrId` | 租户银行通用账户配置 | 调用方不可覆盖 |
| `oriTransSsn` | 原渠道交易记录 | 原银行交易流水 |
| `oriTransDate` | 原渠道交易记录 | 按银行时限规则条件传入 |
| `transAmt` | `baseData.amount` | 人民币分，包含退款手续费 |
| `fee` | `baseData.fee` | 人民币分 |
| `reserve.stlAcctNo` | 平安账户配置 | 加密 |
| `reserve.outAcctNo/outAcctId` | 原渠道交易记录 | 原付款账户/会员，账户号加密 |
| `reserve.inAcctNo/inAcctId` | 原渠道交易记录 | 原收款账户/会员，账户号加密 |
| `reserve.oriOrderId` | 原渠道交易记录 | 原订单号 |
| `reserve.mrchCode/txnClientNo` | 平安账户配置 | 调用方不可覆盖 |
| `reserve.remark` | `baseData.refundReason` | 退款原因 |

lsym 当前长短款代码通过 `transConsumeCancel` 调用平安真实 `/refund`，生产 Handle 固定
`bizFunc=02`，退款请求没有 `functionFlag`。当前范围不激活 `bizFunc=06`，也不扩展普通业务退款；
旧 `functionFlag=7` 交易的其他退款规则等待平安接口重新核对。

## 6. 中信平台付款和平台收款映射

两项均调用中信 `/transfer`，但资金方向和 `bizFunc` 不同：

```text
platformPay     2041: 平台自有资金登记簿 → 用户账户
platformReceive 2042: 用户账户 → 平台自有资金登记簿
chnlNo = 0010
ccy = CNY
```

| 银行字段 | platformPay 2041 | platformReceive 2042 |
|---|---|---|
| `outAcctNo` | 不传，平台侧由商户自有资金登记簿隐式确定 | `specialData.outAcctNo` |
| `inAcctNo` | `specialData.inAcctNo` | 不传，平台侧由商户自有资金登记簿隐式确定 |
| `outAcctNm` | 不取用户名称 | `specialData.outAcctNm`，加密 |
| `inAcctNm` | `specialData.inAcctNm`，加密 | 不取用户名称 |
| `transAmt` | `baseData.amount`，人民币分 | `baseData.amount`，人民币分 |
| `bussId/bussSubId` | `bizOrderNo/bizSubOrderNo` | `bizOrderNo/bizSubOrderNo` |
| `payDate/payTime` | `businessDate/businessTime` | `businessDate/businessTime` |
| `dealType` | `specialData.dealType`，按 2041 枚举校验 | `specialData.dealType`，按 2042 枚举校验 |
| `fundTp` | `specialData.fundTp`，且必须命中租户中信配置 | 同左 |
| `contractId` | `specialData.contractId`，条件选填 | 同左 |
| `reserve.laasSsn` | Handle 生成 | Handle 生成 |

`2041` 交易类型按文档包括补贴、垫资、奖励、其他、返佣；`2042` 包括分润服务费、违约金、
罚款、其他。Handle 必须按资金方向使用不同白名单，不能接受一个无约束字符串。

## 7. 统一返回映射

所有 API 直接返回：

```text
R<FrontTransactionResult>
```

不得再包 `FrontResponse`。只有 Front 业务成功时顶层使用 `R.code=200/R.msg=操作成功`；银行业务
拒绝或钱包业务失败必须使用顶层失败码（当前 `R.code=500`），并在
`data.frontRespCode/frontRespDesc/frontStatus` 中保留统一 Front 业务结果。

| 银行返回 | Front 返回 |
|---|---|
| Handle 生成并保存的 `transSsn` | `frontSsn` |
| 公共 `queryId` | `frontQueryId` |
| 中信 `USER_TRANS_DT/USER_TRANS_TM` | `frontTransDate/frontTransTime` |
| 中信 `USER_SSN` | `specialData.USER_SSN` |
| 银行差异但已确认允许返回的字段 | 显式白名单写入 `specialData` |

不得把完整银行 `reserve`、`errCode/errInfo/sysRespCode/sysRespDesc` 原样返回业务系统。

状态至少遵守：

- 平安提现同步成功只是受理，返回 `ACCEPTED`，最终结果由交易状态查询确认；
- 平安退款可能存在异步入账窗口，受理后先返回 `ACCEPTED`；
- 银行明确终态成功才映射 `SUCCESS`；
- 超时或无法判定时映射 `UNKNOWN`，不得伪造成功。

## 8. 常量和开发位置

代码常量位于：

```text
catering-common/catering-common-core/src/main/java/
com/chinaums/common/core/constant/front/
├─ CiticRefundContractKeys.java
├─ PingAnRefundContractKeys.java
├─ CiticWithdrawContractKeys.java
├─ PingAnWithdrawContractKeys.java
└─ CiticPlatformTransferContractKeys.java
```

只允许保留当前真实 Handle 已使用或本契约已明确确认的字段。Word 中未启用的分润、平台出资、
短信提现等字段不得提前搬入常量。

## 9. 实现和日志约束

1. `bizFunc/chnlNo/path/transSsn/transTime` 只能由具体银行 Handle 决定；
2. 中信退款只检查本次退款流水是否重复，并校验能否组装有效银行报文；不加载或锁定原渠道交易，
   不计算累计退款金额；平安退款边界仍按 `FRONT-TODO-002` 等待确认；
3. `specialData` 和 `accountSpecialData` 分开读取，禁止整体 `putAll`；
4. 每个字段显式映射、显式校验、显式加密；
5. 平安平台付款、平台收款直接返回 `CAPABILITY_NOT_SUPPORTED`；
6. 记录入口、路由、能力、原业务主子流水的脱敏定位值、渠道流水创建、银行调用开始/结束、耗时、
   响应归一化和异常；
7. 请求和银行响应按全链路日志约束输出字段、层级完整且已脱敏的 JSON；银行卡号、账户姓名、证件号、
   密钥等敏感值不得输出明文；
8. 未经用户明确要求，不写测试类、不执行编译或测试。

落库表固定为：

```text
中信 refund/withdraw/platformPay/platformReceive
→ front_citic_refund_transaction
→ front_citic_withdraw_transaction
→ front_citic_platform_pay_transaction
→ front_citic_platform_receive_transaction

平安 refund/withdraw
→ front_pingan_refund_transaction
→ front_pingan_withdraw_transaction
```

中信退款表只保存本次退款、原业务主子流水和银行请求/响应所需明确字段，不保存原渠道记录主键、
原能力或累计退款金额，也不更新中信转账、消费原表。平安退款持久化边界按 `FRONT-TODO-002` 等待确认。
平安平台收付款不支持，不得落入其他表。详细 DDL 见
[09-channel-transaction-ddl](09-channel-transaction-ddl.md)。

最新 lsym UAT 实现只作为字段参考。其“调用方提供原交易银行字段”的边界可以保留，但旧
`orgPay/orgRec/orgTrans*` 字段不能直接搬进公共 `baseData`，必须改为上表规定的银行原始
`specialData` key；`FUND_TP` 取 `platformUserRole`、未校验日期格式和输出敏感明文等实现不得迁移。

## 10. 仍需业务或银行确认

1. 平安旧 `functionFlag=7` 交易是否纳入当前长短款退款及对应协议；
2. 平安是否后续增加 `bizFunc=36` 短信提现；
3. 中信平台收付款 `dealType/fundTp` 的租户级可选值和业务系统字段枚举。

中信部分退款已确认支持；分润退款、平台自有资金退款及平安 `bizFunc=06` 不属于当前长短款需求，
不得提前实现。
