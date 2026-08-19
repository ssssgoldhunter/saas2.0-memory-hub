# TODO-002 平安退款原渠道定位与协议字段

> 状态：`CLOSED`（2026-08-19，静态验收通过并经用户确认关闭）
>
> 最后裁决：2026-08-19
>
> 适用范围：平安真实退款 `/cwap/account/send/refund + bizFunc=02`

## 1. 用户最终裁决

渠道信息保存在 Front 渠道表，业务系统不知道银行原流水、原交易日期和原银行账户字段。

固定边界：

1. 业务系统提供原业务主子流水，不提供原渠道流水和原银行账户快照；
2. Front 按 `tenantId + originalBizOrderNo + originalBizSubOrderNo` 精确查询平安原转账/消费渠道表；
3. `oriTransSsn = 原渠道记录.frontSsn`，不得取 `bankUserSsn` 或 `bankQueryId`；
4. 原交易日期、付款/收款账户、会员编号和名称全部从同一条原渠道记录取得；
5. Front 查表只负责补齐银行协议数据，不判断原交易业务资格、累计可退金额，也不更新原交易表；
6. 当前只启用 `bizFunc=02`，不得顺带启用 `bizFunc=06`。

本 Issue 是当前唯一有效的平安退款边界。历史“业务系统通过 specialData 提供原渠道字段”方案已废止。

## 2. 对外请求边界

### 2.1 `baseData`

`FrontRequest<RefundBusinessData>.baseData`：

| 字段 | 平安要求 | 用途 |
|---|---|---|
| `tenantId` | 必填 | 原渠道表租户条件 |
| `originalBizOrderNo` | 必填 | 原交易业务主流水定位 |
| `originalBizSubOrderNo` | 必填 | 原交易业务子流水定位 |
| `bizOrderNo/bizSubOrderNo` | 必填 | 本次退款业务唯一标识 |
| `amount` | 必填，正数，单位分 | 顶层 `transAmt` |
| `fee` | 选填，单位分 | 顶层 `fee`；null 时发送 `0` |
| `originalBizTransactionId/originalBizSubTransactionId` | 选填 | 退款记录业务关联，不用于银行字段定位 |
| `refundReason` | 业务字段 | 不直接作为平安银行字段；银行备注走 `specialData.remark` |

`RefundBusinessData.originalFrontSsn` 不属于业务系统可知字段，应删除；兼容期暂留时也必须忽略，
不得作为平安查表条件或银行报文来源。

### 2.2 `specialData`

平安退款请求不得要求业务系统提供以下渠道字段：

```text
oriTransSsn
oriTransDate
outAcctNo / outAcctId
inAcctNo / inAcctId
oriOrderId
```

当前只允许业务系统通过组装器提供可选 `remark`。`PingAnSpecialDataAssembler.refund()` 不得校验或生成
原流水、原日期和原账户字段。

### 2.3 `accountSpecialData`

租户银行配置继续提供：

```text
mrchCode
txnClientNo
stlAcctNo
```

业务系统不得覆盖；`stlAcctNo` 上送前由 Handle 做 SM2 加密。

## 3. 原渠道定位

一次退款请求只执行一次定位，并把结果同时用于银行报文和退款 INIT 落库。

查询规则：

```text
transfer 表：tenantId + originalBizOrderNo + originalBizSubOrderNo + capability=TRANSFER
consume  表：tenantId + originalBizOrderNo + originalBizSubOrderNo（表能力固定 CONSUME）
```

结果规则：

| transfer 命中 | consume 命中 | 处理 |
|---:|---:|---|
| 0 | 0 | `FrontException(INVALID_REQUEST)`，明确说明原平安渠道交易不存在 |
| 1 | 0 | 原能力 `TRANSFER` |
| 0 | 1 | 原能力 `CONSUME` |
| 1 | 1 | `FrontException(INVALID_REQUEST)`，明确说明原渠道交易定位歧义 |

禁止：

- 只按主订单号查询；
- 使用调用方传入的 `originalFrontSsn` 绕过业务主子流水定位；
- 静默优先 transfer 或 consume；
- 使用 `bankUserSsn/bankQueryId` 作为 `oriTransSsn`；
- 为报文和退款落库分别查询一次原表。

建议使用明确内部对象（如 `PingAnOriginalTransactionData`）承接：

```text
capability / channelTransactionId / frontSsn
transDate / transTime
payMemberId / payAccountId / payName
recMemberId / recAccountId / recName
```

## 4. 原交易日期持久化

平安 `transTime` 在每次 transfer/consume 请求中由 Handle 生成，格式 `yyyyMMddHHmmssSSS`。

为保证退款能从渠道表取得原日期：

1. transfer/consume INIT 落库时，将请求 `transTime.substring(0, 8)` 保存为 `bankTransDate`；
2. 将 `transTime.substring(8, 14)` 保存为 `bankTransTime`；
3. 退款优先读取原记录 `bankTransDate`；
4. 历史记录该列为空时，使用原记录 `createTime` 格式化为 `yyyyMMdd` 兼容；
5. 不要求业务系统传 `oriTransDate`，也不从 `frontSsn` 的 `MMdd` 片段猜年份。

## 5. 平安退款银行请求映射

```text
PingAnRefundRequest 顶层
├─ bizFunc      = 02
├─ chnlNo       = 0001
├─ oriTransSsn  = original.frontSsn
├─ oriTransDate = original.bankTransDate（历史空值按 §4 兼容）
├─ transAmt     = baseData.amount（分）
└─ fee          = baseData.fee == null ? 0 : baseData.fee（分）

PingAnRefundRequest.reserve
├─ mrchCode    = accountSpecialData.mrchCode
├─ txnClientNo = accountSpecialData.txnClientNo
├─ stlAcctNo   = SM2(accountSpecialData.stlAcctNo)
├─ outAcctNo   = SM2(original.payAccountId)
├─ outAcctId   = original.payMemberId
├─ inAcctNo    = SM2(original.recAccountId)
├─ inAcctId    = original.recMemberId
└─ remark      = specialData.remark（可选，有值才发送）
```

`oriOrderId` 当前没有确认的专用渠道列；不得用 `bankQueryId` 猜测。未来若银行确认必须上送，先新增或确认
具有明确语义的持久化字段，再更新本契约。

## 6. 退款渠道落库

`front_pingan_refund_transaction` 必须保存：

| 字段 | 来源 |
|---|---|
| `original_capability` | 定位结果 `TRANSFER/CONSUME` |
| `original_channel_transaction_id` | 原 transfer/consume 记录主键 |
| `original_front_ssn` | 原记录 `frontSsn`，与实际上送 `oriTransSsn` 完全一致 |
| `original_biz_order_no/original_biz_sub_order_no` | `baseData` |
| `pay_member_id/pay_account_id/pay_name` | 原渠道记录付款方 |
| `rec_member_id/rec_account_id/rec_name` | 原渠道记录收款方 |
| 本次业务、金额、手续费、当前 `frontSsn` | `baseData + 当前请求` |
| `bank_query_id` | 当前退款响应 `queryId` |
| `bank_user_ssn` | 当前退款响应明确存在的 `USER_SSN/ssn` |

目标 DDL 中 `original_capability/original_channel_transaction_id/original_front_ssn` 为非空列，
Handle 不得遗漏。当前范围不更新原 transfer/consume 表的 `refunded_amount` 或状态。

## 7. 已修复问题

2026-08-19 最终静态验收确认，第二轮发现的阻断项均已解决：

1. `PingAnSpecialDataAssembler.withdraw()` 已恢复，退款组装器仅生成可选 `remark`；
2. transfer/consume/withdraw/refund INIT 已恢复完整业务关联和门店字段；
3. 原记录 `frontSsn` 与四个账户/会员银行必填字段已在加密、组报文前校验；
4. 非空 `bankTransDate` 严格校验为有效 `yyyyMMdd`，只有历史空值才回退 `createTime`；
5. `insertInitRecord()` 已恢复 `DEDUP_LOCKS + synchronized` 单实例 `check + insert` 临界区；
6. `originalBizTransactionId` 保持选填，09A/09B/09-final 的 `original_biz_transaction_id` 已统一为可空；
7. 相反 Javadoc 和旧 `applyRefundAccountFields()` 已清理，`oriOrderId` 当前不发送的边界已明确。

旧 `loadOriginalRefundFields()` 的按主订单号、静默优先表及读取 `bankUserSsn` 方案已删除，不得恢复。

## 8. 文档同步范围

修复必须同步：

```text
03-平安银行接口能力汇总.md
05-front代码开发约束.md
08-withdraw-refund-platform-transfer字段契约.md
09-channel-transaction-ddl.md
09A-channel-transaction-table-field-catalog.md
13-front-api-external.md
13-front后续待办.md
15-交易额外数据标准化-spec.md
16-交易额外数据标准化-plan.md
WIKI-START.md
catering-modules/catering-front/README.md
```

## 9. 验收标准

1. 平安退款仍只使用 `bizFunc=02`；
2. 业务请求不再要求原渠道流水、日期、账户和会员 specialData；
3. 原渠道定位严格使用租户 + 原业务主子流水，并处理未命中/双命中；
4. `oriTransSsn` 只取原记录 `frontSsn`；代码不得从 `bankUserSsn/bankQueryId` 赋值；
5. `oriTransDate` 从渠道记录取得，新交易已保存请求日期，历史数据有明确兼容规则；
6. 原账户号加密上送，会员编号明文上送；
7. 退款记录完整保存三项原渠道关联列和原账户字段；
8. 不新增原交易资格、累计金额校验，不更新原交易表；
9. 第 8 节文档不存在相反口径；
10. 未经用户明确要求，不新增测试类、不运行测试、不编译、不 commit、不 push。

## 10. 关闭条件

代码与第 8 节文档全部满足第 9 节后改为 `FIXED_PENDING_REVIEW`；只有用户确认后才能改为 `CLOSED`。

## 11. 2026-08-19 第二轮验收记录（历史）

本轮只做静态验收，未编译、未运行测试、未新增测试类、未 commit、未 push。

### 11.1 已满足

1. 只调用 `/refund + bizFunc=02`，未启用 `06`；
2. 业务方只提供原业务主子流水，`originalFrontSsn` 已从 DTO 删除；
3. 平安退款组装器只生成可选 `specialData.remark`；
4. 原渠道定位严格使用租户 + 原业务主子流水，transfer 额外限制 `capability=TRANSFER`；
5. 未命中、单表多条、两表同时命中都有明确失败；
6. `oriTransSsn` 取原记录 `frontSsn`，未读取 `bankUserSsn/bankQueryId`；
7. 原账号 SM2 加密、会员编号明文，租户三件套来源正确；
8. 一次定位结果同时用于银行报文和退款 INIT；未校验退款资格、累计金额，也未更新原交易表；
9. transfer/consume 已把请求 `transTime` 拆为 `bankTransDate/bankTransTime`。

### 11.2 当时未满足（历史阻断，现已按第 12 节全部修复）

1. `PingAnSpecialDataAssembler.withdraw()` 缺失，源码存在不可解析调用；
2. transfer/consume/withdraw/refund INIT 丢失既有业务关联字段，退款目标表非空列会导致插入失败；
3. 原记录银行必填字段缺少显式校验；
4. 非空非法 `bankTransDate` 未严格失败；
5. 原有单实例并发查重临界区被删除；
6. `originalBizTransactionId` 选填契约与目标 DDL 非空约束冲突；
7. 三处相反 Javadoc 和一个旧 `applyRefundAccountFields()` 尚未清理。

当时结论：TODO-002 尚未关闭，第二轮退款修复未通过验收。本结论仅记录当时状态，
当前状态以第 12 节最终验收为准。

## 12. 2026-08-19 最终验收记录

本轮继续采用静态验收，未编译、未运行测试、未新增测试类、未 commit、未 push。

1. 平安退款固定使用 `/refund + bizFunc=02`，未启用 `06`；
2. 原渠道信息由 Front 按租户和原业务主子流水查询，业务系统不提供渠道字段；
3. `oriTransSsn` 固定取原记录 `frontSsn`，原日期、账户和会员字段来源符合本 Issue；
4. 原渠道定位、日期兼容、账号加密、INIT 落库、单实例并发查重和 DDL 选填口径均已闭环；
5. 第 8 节列出的当前设计、约束和入口文档已统一，不再存在相反实现口径；
6. 用户确认平安退款验收通过。

结论：`TODO-002` 已满足关闭条件，状态更新为 `CLOSED`。第 11 节仅保留为第二轮失败验收的历史记录，
不得再作为当前实现状态。
