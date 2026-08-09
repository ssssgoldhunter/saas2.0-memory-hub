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

## 本轮修复（2026-08-09 第三轮）

5. **`isClearlyNotSent()` 增加 `FrontException` 判断**：HttpClient 已将原始异常包装为
   `FrontException(WALLET_COMMUNICATION_FAILED)`，导致 Handle 收到后无法识别为"明确未发送"。
   现已增加 `FrontException` instanceof 判断，`getErrorCode() == WALLET_COMMUNICATION_FAILED`
   视为明确未发送写 FAILED，其余 FrontException 写 UNKNOWN。
6. **HttpClient JSON 解析异常分类修正**：两家 `WalletHttpClient` 都在 try-with-resources 中
   `return JSONObject.parse(respStr)`；若 HTTP 已响应（200/非空 body）但 JSON 解析失败，
   之前落入通用 `catch (Exception)` 写 `WALLET_COMMUNICATION_FAILED`。
   现已在 `catch (FrontException)` 之后优先捕获 `com.alibaba.fastjson2.JSONException`
   并包装为 `WALLET_RESULT_UNKNOWN`，表示"请求已发出、响应已收到但无法解析"。
7. **`resendTransferAuthCode()` try 块完整扩展**：该方法的 try 之前只包了 `doInvoke`，
   请求序列化/响应校验/解密/`updateAuthCodeResponse`/日志都在外部。现已扩展为
   `invokeBank()` 相同模式——从 requestJson 组装到响应日志全部在 try 内，
   catch 统一走 `updateResponseOnException(isClearlyNotSent(e))`。

## 本轮修复（2026-08-09 第四轮）

8. **`resendTransferAuthCode()` requestJson 序列化和日志移入 try**：前一轮将 try 扩展后，
   `JSON.parseObject(JSON.toJSONString(request))` 序列化和 `bank_request_assembled` 日志
   仍在 try 外且出现在 `updateSending()` 之后；若序列化失败，渠道流水仍停留在 SENDING。
   现已将这两步移入 try 块内，与 `invokeBank()` 模式完全对齐。
9. **HttpClient 一般异常 fallback 改为 WALLET_RESULT_UNKNOWN**：两家 `WalletHttpClient` 的
   `catch (Exception)` 中，已验证为连接级异常（`ConnectException`/`NoRouteToHostException`/
   `UnknownHostException`）或 hutool 无状态码异常时走 `WALLET_COMMUNICATION_FAILED`；
   **其余所有异常**（状态码非 0 的 HTTP 异常、IO 异常等）改为 `WALLET_RESULT_UNKNOWN`，
   遵循"无法确认是否已发送则 UNKNOWN"的保守原则。
10. **CiticWalletHttpClient 异常分类改用根异常判断（第五轮）**：原来通过 `statusCodeOf()` 统一提取
   hutool 状态码，非 hutool 异常返回 -1 后也被归为连接异常→`COMMUNICATION_FAILED`。改为先按
   根异常类型判断：`SocketTimeoutException`→UNKNOWN，`ConnectException`/`NoRouteToHostException`/
   `UnknownHostException`→`COMMUNICATION_FAILED`，`HttpException` 且无状态码→`COMMUNICATION_FAILED`，
   其余所有异常→`WALLET_RESULT_UNKNOWN`，与平安 HttpClient 模式一致。

## 关闭条件

- 按"请求明确未发送/明确失败"和"请求可能已经发送"分别落 `FAILED/UNKNOWN`；
- 覆盖从银行 DTO 组装完成后到响应持久化完成前的全部异常窗口；
- 状态更新失败只记录安全日志或作为 suppressed 信息保留，不覆盖原始异常；
- 系统异常继续抛出，不转换成普通银行业务失败。
