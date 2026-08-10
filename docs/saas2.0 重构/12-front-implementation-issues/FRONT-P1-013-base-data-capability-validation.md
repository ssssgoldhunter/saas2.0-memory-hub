# FRONT-P1-013 baseData 缺少按银行具体能力的必填和格式校验

- 状态：CLOSED
- 优先级：P1
- 影响：Bean Validation 允许部分银行必填字段为 null，Handle 可能把 null 或字符串 `"null"` 组装进银行请求。

## 边界

- Front 只校验能否组装有效银行请求，不增加原交易状态、余额、退款资格或其他上游业务规则。
- 校验必须按“银行 + 具体能力”放在具体 Handle 方法内，不建立 capability 公共校验矩阵。
- `specialData` 必填 key 继续由 `FRONT-P1-002` 的既有规则负责；本问题只补 baseData 的接口级必填、格式和长度。

## 验收标准

1. 逐个银行、逐个已启用能力列出实际银行请求所需的 baseData 必填字段、格式和长度。
2. 校验发生在 INSERT INIT 和钱包调用之前；缺失或格式错误抛
   `FrontException(INVALID_REQUEST)`，由 LiteFlow 写 Slot 后中断。
3. 平安需要手续费的接口在未提供 fee 时明确失败或按已确认契约使用 0，不得发送字符串 `"null"`。
4. 需要业务日期、时间的接口必须拒绝 null，并继续校验 `yyyyMMdd/HHmmss`。
5. 不把某银行、某接口的规则上升为所有交易的公共业务规则。
6. 不改变 `baseData/specialData/accountSpecialData` 边界，不新增 capability 输入字段。
7. 平安查询和退款未确认部分继续遵守 `TODO-001/002`，不得借本问题提前启用或猜测协议。

## 建议修改范围

- `CiticTransactionHandle`：仅补已启用交易能力的 baseData 请求有效性校验；
- `PingAnTransactionHandle`：仅补已启用且协议已确认能力的 baseData 请求有效性校验；
- 06、07、08 字段契约：只在现有口径不明确时同步必填、格式和长度；
- 不修改 Router、Registry、Dispatch、Mapper、DDL 或查询 TODO。

## 当前代码证据（2026-08-10）

1. 两个 Transaction Handle 已删除跨银行、跨能力的 `validateRequiredBaseData()`，校验放在具体银行能力方法内。
2. 中信 transfer/consume 的 `BUSS_ID + BUSS_SUB_ID` 均为必填且最大 64；withdraw、refund、
   platformPay/platformReceive 的订单字段也按协议校验最大 64。
3. 中信需要业务日期、时间的接口均在 INSERT INIT 和钱包调用前校验非空及 `yyyyMMdd/HHmmss` 格式。
4. 平安 transfer/consume 的可选 `orderId` 最大 30；transferAuth/resendTransferAuthCode 的
   `orderNo` 最大 30、`reserve.remark` 最大 120；普通交易备注最大 256、提现备注最大 512。
5. 平安已确认接口使用局部 fee 值，未提供时按协议传 0，负数拒绝，且不修改请求 DTO。
6. 平安退款仍由 `TODO-002` 管理；本问题未猜测默认 fee，也未扩大退款协议范围。
7. 06、07、08 字段契约已同步本问题涉及的必填、格式和长度；未改变
   `baseData/specialData/accountSpecialData` 边界。

## 逐接口校验总表

| 能力 | 银行 | bizSubOrderNo | order/bizOrderNo/bizSubOrderNo 长度 | businessDate/businessTime | fee | remark 长度 |
|---|---|---|---|---|---|---|
| transfer | 中信 | **必填(requireField → put)** | 64（C64 必填） | requireDateyyyyMMdd + requireTimeHHmmss | 银行协议忽略，不上送 | 256 |
| consume | 中信 | **必填(requireField → put)** | 64（C64 必填） | requireDateyyyyMMdd + requireTimeHHmmss | 银行协议忽略，不上送 | 256 |
| withdraw | 中信 | 不写入 reserve | 64（C64 必填） | requireDateyyyyMMdd + requireTimeHHmmss | 银行协议忽略，不上送 | 512 |
| refund | 中信 | 必填(requireField) + 原交易必填 | 64（C64，含原交易主子流水） | requireDateyyyyMMdd + requireTimeHHmmss | 不适用 | 100（refundReason/MEMO） |
| platformPay | 中信 | 选填(putIfNotBlank) | 64 | requireDateyyyyMMdd + requireTimeHHmmss | 银行协议忽略，不上送 | 256 |
| platformReceive | 中信 | 选填(putIfNotBlank) | 64 | requireDateyyyyMMdd + requireTimeHHmmss | 银行协议忽略，不上送 | 256 |
| transfer | 平安 | 选填(不为空写 ORDER_ID) | ORDER_ID/bizSubOrderNo **30** | 不校验 | 局部变量，null→0，负拒绝 | 256 |
| consume | 平安 | 选填(不为空写 ORDER_ID) | ORDER_ID/bizSubOrderNo **30** | 不校验 | 局部变量，null→0，负拒绝 | 256 |
| transferAuth | 平安 | 使用 bizOrderNo(orderNo) | ORDER_NO/bizOrderNo **30** | 不校验 | 局部变量，null→0，负拒绝 | **120** |
| resendTransferAuthCode | 平安 | 使用 bizOrderNo(orderNo) | ORDER_NO/bizOrderNo **30** | 不校验 | 不适用 | **120** |
| withdraw | 平安 | 不写入 reserve | 不校验 | 不校验 | 局部变量，null→0，负拒绝 | 512 |
| refund | 平安(TODO-002) | 待确认 | 待确认 | 待确认 | **不猜测（null 时不设 fee）** | 待确认 |

## 关闭记录

- 当前代码和 06、07、08 字段契约保持一致；
- 所有已启用接口在 INSERT INIT 和钱包调用前完成银行报文所需的 baseData 校验；
- 平安查询和退款未确认部分继续由 TODO 管理，不借本问题扩展；
- 2026-08-10 用户确认静态验收没有问题，关闭本问题。
