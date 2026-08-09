# FRONT-P1-013 baseData 缺少按银行具体能力的必填和格式校验

- 状态：FIXED_PENDING_REVIEW
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
7. 平安查询和退款未确认部分继续遵守 `FRONT-TODO-001/002`，不得借本问题提前启用或猜测协议。

## 建议修改范围

- `CiticTransactionHandle`：仅补已启用交易能力的 baseData 请求有效性校验；
- `PingAnTransactionHandle`：仅补已启用且协议已确认能力的 baseData 请求有效性校验；
- 06、07、08 字段契约：只在现有口径不明确时同步必填、格式和长度；
- 不修改 Router、Registry、Dispatch、Mapper、DDL 或查询 TODO。

## 当前核验结果（2026-08-09）

1. 两个交易 Handle 新增了同一个 `validateRequiredBaseData()`，无差别要求所有交易能力必须提供
   `bizOrderNo/amount/businessDate/businessTime`；这违反"银行 + 具体接口"校验边界，可能拒绝协议并不需要
   日期或时间的平安接口。
2. `fee == null` 被统一回写为 0，尚未逐接口确认"必填"还是"允许缺省为 0"，并且修改了请求 DTO。
3. 平安 `resendTransferAuthCode()` 未调用该校验，仍直接执行 `String.valueOf(data.getAmount())`，null 会进入银行报文。
4. `remark` 等银行长度限制仍未按具体接口核对和实现。

以下问题已在前两轮修复中关闭，本轮的侧重点不同：
5. ~~中信退款 `businessDate/businessTime` 仅非空校验，缺少 `yyyyMMdd/HHmmss` 格式校验。~~ → 2026-08-09 已修复。

## 已有修改（已完成，2026-08-09）

1. 删除 `CiticTransactionHandle.validateRequiredBaseData()` 和
   `PingAnTransactionHandle.validateRequiredBaseData()` 两个跨能力统一校验方法。
2. `CiticTransactionHandle` 新增 `requireField`/`requirePositive`/`requireDateyyyyMMdd`/`requireTimeHHmmss`
   四个静态辅助方法；`transfer()`/`consume()`/`withdraw()`/`doPlatformTransfer()` 各自调用校验，
   并增加 `businessDate` 的 `yyyyMMdd` 格式和 `businessTime` 的 `HHmmss` 格式校验。
3. `PingAnTransactionHandle` 新增 `requireField`/`requirePositive` 两个静态辅助方法；
   `transfer()`/`consume()`/`transferAuth()`/`withdraw()` 各自验证 `bizOrderNo` + `amount`，
   不校验 `businessDate/businessTime`（平安协议不使用 baseData 中的日期时间）。
4. `PingAnTransactionHandle.resendTransferAuthCode()` 新增 `bizOrderNo` + `amount` 必填校验，
   消除 `String.valueOf(null)` → `"null"` 进入银行报文的风险。
5. `fee` 为 null 时默认设为 0L 的逻辑在每个方法独立处理，不再修改请求 DTO。

## 本次修复（2026-08-09 第二轮）

1. **`CiticTransactionHandle.refund()` 日期格式补全**：businessDate 追加 `requireDateyyyyMMdd`，businessTime 追加 `requireTimeHHmmss`，替代原仅非空校验。
2. **平安四方法 fee 局部变量化**：`transfer()`/`consume()`/`transferAuth()`/`withdraw()` 将 `if (data.getFee() == null) data.setFee(0L)` 替换为局部变量 `Long fee = data.getFee() != null ? data.getFee() : 0L`；fee < 0 时抛 `INVALID_REQUEST`；使用局部变量组装银行请求和持久化，不再修改请求 DTO。
3. **remark 长度校验**（平安已确认、中信本轮确认）：
   - 两个 Handle 新增 `validateMaxLength(value, maxLength, fieldName)` 静态辅助方法。
   - 平安 transfer/consume：**256**（Word 协议 C 256 O），本地常量 `REMARK_MAX_LENGTH_PINGAN_TRANSFER`。
   - 平安 withdraw：**512**（Word 协议 C 512 O），本地常量 `REMARK_MAX_LENGTH_PINGAN_WITHDRAW`。
   - 平安 transferAuth/resendTransferAuthCode：**256**（用户确认保留发送并校验）。
4. **bizSubOrderNo 按接口逐一定性**（只在银行 reserve 有映射的接口调整）：
   - 中信 transfer/consume `BUSS_SUB_ID`：选填，改用 `putIfNotBlank` 条件写入。
   - 平安 transfer/consume `ORDER_ID`：选填（银行协议 Optional），不为空时写入。
   - 中信 refund 的 bizSubOrderNo 已确认为必填（保持原有校验）。
   - 其余能力维持既有写入方式，不做统一提升。

### 本轮修复（2026-08-09 第三轮）

5. **中信 `data.setFee(0L)` 改为局部变量**：`transfer()`/`consume()`/`withdraw()`/`doPlatformTransfer()`
   的 `if (data.getFee() == null) data.setFee(0L)` 改为
   `Long fee = data.getFee() != null ? data.getFee() : 0L`，不再修改请求 DTO。
6. **平安 insert 方法 entity fee 用局部计算值**：`buildTransferInitRecord()`/`insertConsumeInitRecord()`/
   `insertWithdrawInitRecord()`/`insertRefundInitRecord()` 的 `entity.setFee(data.getFee())` 改为
   `entity.setFee(data.getFee() != null ? data.getFee() : 0L)`，使渠道流水 fee 与银行请求 fee 一致
   （调用方未传时银行请求为 `"0"`，数据库不再存 null）。
7. **transferAuth/resend remark 加 `validateMaxLength`**：用户确认平安 transferAuth 和
   resendTransferAuthCode 的 remark 保留发送并校验 256 字符。已在对应 RESERVE_REMARK 写入前
   增加 `validateMaxLength(data.getRemark(), REMARK_MAX_LENGTH_PINGAN_TRANSFER, "baseData.remark")`。
8. **平安 refund `data.getFee()` → 局部变量**：`refund()` 的 `request.setFee(String.valueOf(data.getFee()))`
   改为局部变量 `Long refundFee = data.getFee() != null ? data.getFee() : 0L`，消除 null 时发送
   字符串 `"null"` 的风险。

### 本轮修复（2026-08-09 第四轮）

9. **中信 remark 长度校验**：根据 Word 协议确认各接口 remark 长度限制并添加 `validateMaxLength`：
   - transfer/consume/platformPay/platformReceive：**256**
   - withdraw：**512**
   - refund（refundReason/MEMO）：**100**

### 本轮修复（2026-08-09 第五轮）

10. **中信 transfer/consume bizSubOrderNo 必填 + 长度**：Word 协议 BUSS_ID/BUSS_SUB_ID 均为 C64 必填。
    `transfer()`/`consume()` 增加 `requireField(data.getBizSubOrderNo())`，长度校验 64；
    `fillTransferReserveFields()` 将 `putIfNotBlank` 改为`put`，确保始终写入。
11. **中信各接口业务订单字段长度校验**：transfer/consume/withdraw/refund/platformPay/platformReceive
    的 `bizOrderNo`、`bizSubOrderNo`、`originalBizOrderNo`/`originalBizSubOrderNo` 增加 `validateMaxLength` 为 64。
12. **平安 transferAuth/resend remark 修正**：从 256 改为 Word 协议实际的 **120**；orderNo 增加 **30** 长度校验。
13. **平安 transfer/consume ORDER_ID 长度校验**: fillTransferReserve 的 `bizSubOrderNo` 写入 ORDER_ID 前加 **30** 长度校验。
14. **平安 refund fee 撤回 P1-013 第三轮猜测**：fee 为 null 时不设为 "0"，遵守 TODO-002 "不猜测协议"原则。

### 逐接口校验总表

| 能力 | 银行 | bizSubOrderNo | order/bizOrderNo/bizSubOrderNo 长度 | businessDate/businessTime | fee | remark 长度 |
|---|---|---|---|---|---|---|
| transfer | 中信 | **必填(requireField → put)** | 64（C64 必填） | requireDateyyyyMMdd + requireTimeHHmmss | 局部变量，null→0 | 256 |
| consume | 中信 | **必填(requireField → put)** | 64（C64 必填） | requireDateyyyyMMdd + requireTimeHHmmss | 局部变量，null→0 | 256 |
| withdraw | 中信 | 不写入 reserve | 64（C64 必填） | requireDateyyyyMMdd + requireTimeHHmmss | 局部变量，null→0 | 512 |
| refund | 中信 | 必填(requireField) + 原交易必填 | 64（C64，含原交易主子流水） | requireDateyyyyMMdd + requireTimeHHmmss | 不适用 | 100（refundReason/MEMO） |
| platformPay | 中信 | 选填(putIfNotBlank) | 64 | requireDateyyyyMMdd + requireTimeHHmmss | 局部变量，null→0 | 256 |
| platformReceive | 中信 | 选填(putIfNotBlank) | 64 | requireDateyyyyMMdd + requireTimeHHmmss | 局部变量，null→0 | 256 |
| transfer | 平安 | 选填(不为空写 ORDER_ID) | ORDER_ID/bizSubOrderNo **30** | 不校验 | 局部变量，null→0，负拒绝 | 256 |
| consume | 平安 | 选填(不为空写 ORDER_ID) | ORDER_ID/bizSubOrderNo **30** | 不校验 | 局部变量，null→0，负拒绝 | 256 |
| transferAuth | 平安 | 使用 bizOrderNo(orderNo) | ORDER_NO/bizOrderNo **30** | 不校验 | 局部变量，null→0，负拒绝 | **120** |
| resendTransferAuthCode | 平安 | 使用 bizOrderNo(orderNo) | ORDER_NO/bizOrderNo **30** | 不校验 | 不适用 | **120** |
| withdraw | 平安 | 不写入 reserve | 不校验 | 不校验 | 局部变量，null→0，负拒绝 | 512 |
| refund | 平安(TODO-002) | 待确认 | 待确认 | 待确认 | **不猜测（null 时不设 fee）** | 待确认 |
