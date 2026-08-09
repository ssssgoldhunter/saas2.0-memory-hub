# FRONT-P1-006 银行异常后渠道记录停留在 SENDING

- 状态：FIXED_PENDING_REVIEW
- 优先级：P1
- 影响：通信超时、解析失败或系统异常后渠道流水没有可用于补偿的可靠状态。

## 证据

- 两家 Handle 均先 INSERT INIT、UPDATE SENDING。
- `invokeBank` 已在请求序列化或 HTTP 异常时尝试写 `UNKNOWN`，但不区分“明确未发送”和“可能已发送”。
- `responseChecker`、结果组装、响应日志和 `updateResponse` 位于异常收口 try 外，任一步骤异常仍可能保留 `SENDING`。

## 验收标准

1. 明确未发送或明确通信失败更新为 FAILED。
2. 可能已经发送但没有可靠终态更新为 UNKNOWN。
3. 保存允许持久化的错误分类和响应时间，不保存异常堆栈或完整报文。
4. 更新渠道状态失败不能覆盖原始系统异常，应保留主异常并记录安全日志。
5. 后续可通过交易状态查询补偿 UNKNOWN 记录。

## 当前核验结果（2026-08-09）

已完成：

- 两家交易 Handle 在钱包调用异常时会尝试更新渠道记录，不再所有异常都直接遗留 `SENDING`；
- 可能已经发送但无可靠终态的场景具备写入 `UNKNOWN` 的基础方法。

## 已有修改（已完成，2026-08-09）

1. `CiticTransactionHandle.invokeBank()` 和 `PingAnTransactionHandle.invokeBank()`：try 块扩展覆盖
   `responseChecker.check()`、结果组装、`bank_response_received` 日志及 `updateResponse()`，
   从银行 DTO 组装完成到响应持久化完成全部在 try 内，消除异常窗口。
2. 两家 Handle 新增 `isClearlyNotSent(Exception)` 静态方法：JSON 组装失败、`ConnectException`、
   `NoRouteToHostException`、`UnknownHostException` 判定为明确未发送；其余异常（超时、IO 异常等）
   判定为可能已发送。
3. `updateResponseOnException()` 签名增加 `boolean isFailed` 参数：明确未发送写 `FAILED`，
   可能已发送写 `UNKNOWN`。状态更新失败只记安全日志，不覆盖原始异常。
4. `PingAnTransactionHandle.resendTransferAuthCode()` 已复用相同保护路径。

## 关闭条件

- 按"请求明确未发送/明确失败"和"请求可能已经发送"分别落 `FAILED/UNKNOWN`；
- 覆盖从银行 DTO 组装完成后到响应持久化完成前的全部异常窗口；
- 状态更新失败只记录安全日志或作为 suppressed 信息保留，不覆盖原始异常；
- 系统异常继续抛出，不转换成普通银行业务失败。
