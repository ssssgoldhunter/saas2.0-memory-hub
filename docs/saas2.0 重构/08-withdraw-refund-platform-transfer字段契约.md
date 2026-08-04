# withdraw、refund、platformPay、platformReceive 字段契约

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：首版契约已确认
> 确认日期：2026-08-04
> 范围：中信、平安提现与真退款；中信平台付款、平台收款

## 1. 先给结论

| Front 能力 | 中信 | 平安 | 新 Front 约束 |
|---|---|---|---|
| `withdraw` | 真实 `/withdrawal`，当前 `bizFunc=26` | 真实 `/withdrawal`，当前 `bizFunc=01` | 两家均保留，金额单位为分 |
| `refund` | 银行有真实 `/refund`，应使用 `bizFunc=23` | 真实 `/refund`，当前 `bizFunc=02` | 必须是真退款，禁止反向转账 |
| `platformPay` | 真实 `/transfer`，`bizFunc=2041` | 无等价实现 | 仅中信，平安 `UNSUPPORTED` |
| `platformReceive` | 真实 `/transfer`，`bizFunc=2042` | 无等价实现 | 仅中信，平安 `UNSUPPORTED` |

最重要的迁移差异：mdl 的 `ZxTransConsumeCancelHandle` 虽然方法名是退款，但实际组装
`ZxTransferRequest`、写入 `bizFunc=27` 并调用 `zxTransfer`，本质是反向转账。该实现不得复制。
mdl 已经存在 `ZxRefundRequest`、`SaasZxInterService.zxRefund()` 和 `/refund` 客户端入口，
但业务 Handle 没有接上。新 Front 中信退款必须接真实 `/refund + bizFunc=23`。

## 2. 新 Front 方法与 mdl 具体实现映射

| 新方法 | mdl 入口/Service | mdl 中信类 | mdl 平安类 | 核对结果 |
|---|---|---|---|---|
| `refund()` | `FrontTransConsumeFacadeApi.transConsumeCancel()` → `TransConsumeServiceImpl.transConsumeCancel()` | `ZxTransConsumeCancelHandle` | `PaTransConsumeCancelHandle` | 平安是真退款；中信旧业务 Handle 是反向转账，禁止迁移 |
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
└─ tenantBankConfig
   └─ accountConfig
      ├─ appId/appKey/url/mchntId/mchntMbrId
      └─ accountSpecialData
         ├─ 平安 txnClientNo/mrchCode/stlAcctNo
         └─ 中信 default/self 角色、资金类型和自有资金映射配置
```

### 3.1 `RefundBusinessData`

| 字段 | 说明 | 来源约束 |
|---|---|---|
| `originalFrontSsn` | 原交易 Front 渠道流水号 | 必填，用于加载原渠道交易记录 |
| `originalBizOrderNo` | 原交易业务主流水号 | 必填，与原渠道记录交叉校验 |
| `originalBizSubOrderNo` | 原交易业务子流水号 | 必填，与原渠道记录交叉校验 |
| `bizOrderNo/bizSubOrderNo` | 本次退款业务主/子流水号 | 继承公共交易对象 |
| `amount` | 本次退款金额 | 人民币分 |
| `fee` | 本次退款手续费 | 人民币分；无手续费传 0 |
| `refundReason` | 退款原因 | 中信映射 `MEMO`，平安映射 `reserve.remark` |

原银行流水、原账户、原交易日期、原资金类型和原资金分配不允许由请求 `specialData` 传入。
Front 必须通过 `originalFrontSsn` 加载原渠道流水，校验租户、银行、订单、原交易成功状态、
可退款金额和累计退款金额后再组装银行请求。

### 3.2 `WithdrawBusinessData`

| 字段 | 说明 | 银行映射 |
|---|---|---|
| `withdrawAccountId` | 发起提现的银行用户/见证子账户 | 中信、平安 `acctNo`，加密 |
| `withdrawMemberId` | 发起提现的银行会员编号 | 平安 `mchntMbrId` |
| `bankCardNo` | 收款银行卡号 | 两家 `cardNoEnc`，加密且禁止写日志 |
| `withdrawAccountName` | 提现会员/见证账户名称 | 平安 `nameEnc`，加密 |
| `bankCardHolderName` | 银行卡持卡人姓名 | 中信 `WITH_ACCNAME`、平安 `userNameEnc`，加密 |
| `amount` | 提现金额 | 两家 `transAmt`，人民币分 |
| `fee` | 提现手续费 | 平安 `fee`，人民币分；中信当前由手续费承担类型控制 |
| `remark` | 提现备注 | 两家 `remark` |

平安证件号码属于银行特有动态输入，只能使用 `specialData.certNo`，进入银行请求前映射并加密为
`reserve.certNoEnc`；证件号明文、密文都不得记录日志。

### 3.3 `PlatformTransferBusinessData`

该对象仅用于中信：

| 字段 | 说明 |
|---|---|
| `userAccountId` | 与平台发生收付款的用户账户 |
| `userAccountName` | 用户账户名称，进入银行请求前加密 |
| `platformAccountType` | Front 内部平台账户类型，用于解析租户平台自有资金账户 |
| `amount` | 平台收付款金额，人民币分 |
| `bizOrderNo/bizSubOrderNo` | 业务主/子流水号 |
| `businessDate/businessTime` | 业务日期和时间 |
| `remark` | 交易备注 |

中信动态协议字段进入请求 `specialData`：

| key | 说明 | 约束 |
|---|---|---|
| `dealType` | 交易类型 | 按 `2041/2042` 分别校验银行枚举 |
| `fundTp` | 资金类型 | 必须是租户中信已配置的资金类型，不允许任意值 |
| `contractId` | 合同编号 | 仅业务场景要求时选填 |

业务系统不得传入平台银行账号。平台账号必须由 Front 根据 `tenantId + 中信 + platformAccountType`
和账户配置解析。

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
| `acctNo` | `baseData.withdrawAccountId` | 加密 |
| `cardNoEnc` | `baseData.bankCardNo` | 加密 |
| `transAmt` | `baseData.amount` | 人民币分 |
| `remark` | `baseData.remark` | 按银行长度校验 |
| `reserve.WITH_TYPE` | Handle 固定 `00` | 当前只开放用户提现，不开放平台提现 `01` |
| `reserve.BUSS_ID` | `baseData.bizOrderNo` | 业务主流水 |
| `reserve.TRANS_DT/TRANS_TM` | `baseData.businessDate/businessTime` | `yyyyMMdd/HHmmss` |
| `reserve.FEE_TYPE` | Handle 固定 `2` | 当前用户承担手续费 |
| `reserve.WITH_ACCNAME` | `baseData.bankCardHolderName` | 加密 |
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
| `mchntMbrId` | `baseData.withdrawMemberId` | 提现会员编号 |
| `acctNo` | `baseData.withdrawAccountId` | 加密 |
| `cardNoEnc` | `baseData.bankCardNo` | 加密 |
| `transAmt` | `baseData.amount` | 人民币分 |
| `fee` | `baseData.fee` | 人民币分 |
| `remark` | `baseData.remark` | 旧 mdl 存在自赋值缺陷，新实现必须显式赋值 |
| `reserve.tranWebName` | Handle 固定 `0001` | 调用方不可覆盖 |
| `reserve.certType` | Handle 固定 `24` | 只表达现有协议值，不擅自解释证件类型语义 |
| `reserve.certNoEnc` | `specialData.certNo` | 加密，禁止日志 |
| `reserve.nameEnc` | `baseData.withdrawAccountName` | 加密 |
| `reserve.userNameEnc` | `baseData.bankCardHolderName` | 加密 |
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
| `transAmt` | `baseData.amount` | 人民币分 |
| `ORI_USER_D_ID/NM` | 原渠道交易记录 | 原付款用户及名称 |
| `ORI_USER_C_ID/NM` | 原渠道交易记录 | 原收款用户及名称 |
| `ORI_USER_C_AMT` | `baseData.amount` | 原收款方本次退款金额，人民币分 |
| `P_SELF_FLAG/P_DEAL_AMT` | Handle 固定 `N/0` | 首版普通退款不含平台自有资金 |
| `REFUND_BUSS_ID/SUB_ID` | 本次 `bizOrderNo/bizSubOrderNo` | 退款业务流水 |
| `ORI_BUSS_ID/SUB_ID` | `originalBizOrderNo/originalBizSubOrderNo` | 与原渠道记录交叉校验 |
| `ORI_USER_SSN/ORI_USER_TRANS_DT` | 原渠道交易记录 | 使用银行流水定位方案时写入 |
| `TRANS_DT/TRANS_TM` | 本次 `businessDate/businessTime` | 退款业务时间 |
| `FUND_TP` | 原交易或租户中信配置 | 不允许请求任意覆盖 |
| `MEMO` | `baseData.refundReason` | 退款原因 |
| `laasSsn` | Handle 生成 | 外联平台流水 |

首版不激活 Word 中的 `ORI_USER_SHARE_*` 分润退款、平台出资退款和 `REQ_RESERVED`。这些字段必须等
业务模型、原交易资金分配和累计退款算法确认后单独增加，不能整体复制进常量类。

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

当前只确认直接支付退款 `bizFunc=02`。银行文档中的会员资金支付退款 `bizFunc=06` 暂不激活；
`functionFlag=7` 原交易是否允许按当前接口退款也仍需银行确认。

## 6. 中信平台付款和平台收款映射

两项均调用中信 `/transfer`，但资金方向和 `bizFunc` 不同：

```text
platformPay     2041: 平台账户 → 用户账户
platformReceive 2042: 用户账户 → 平台账户
chnlNo = 0010
ccy = CNY
```

| 银行字段 | platformPay 2041 | platformReceive 2042 |
|---|---|---|
| `outAcctNo` | Front 内部解析的平台账户 | `baseData.userAccountId` |
| `inAcctNo` | `baseData.userAccountId` | Front 内部解析的平台账户 |
| `outAcctNm` | 不取用户名称 | `baseData.userAccountName`，加密 |
| `inAcctNm` | `baseData.userAccountName`，加密 | 不取用户名称 |
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

不得再包 `FrontResponse`。银行调用和结果判断正常完成时，即使银行业务拒绝，顶层仍使用
`R.code=200/R.msg=操作成功`；业务结果放在 `data.frontRespCode/frontRespDesc/frontStatus`。

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
2. 退款必须加载并锁定原渠道交易，校验累计可退款金额和幂等；
3. `specialData` 和 `accountSpecialData` 分开读取，禁止整体 `putAll`；
4. 每个字段显式映射、显式校验、显式加密；
5. 平安平台付款、平台收款直接返回 `CAPABILITY_NOT_SUPPORTED`；
6. 记录入口、路由、能力、原 Front 流水的脱敏定位值、渠道流水创建、银行调用开始/结束、耗时、
   响应归一化和异常；
7. 日志禁止输出完整请求、完整银行响应、银行卡号、账户姓名、证件号、密钥和完整 specialData；
8. 未经用户明确要求，不写测试类、不执行编译或测试。

## 10. 仍需业务或银行确认

1. 中信是否首期开放部分退款，以及部分退款累计上限；
2. 中信分润退款和平台自有资金退款是否纳入后续版本；
3. 平安 `bizFunc=06` 会员资金支付退款是否需要首期支持；
4. 平安 `functionFlag=7` 原交易的退款协议；
5. 平安是否后续增加 `bizFunc=36` 短信提现；
6. 中信平台收付款 `dealType/fundTp` 的租户级可选值和业务系统字段枚举。
