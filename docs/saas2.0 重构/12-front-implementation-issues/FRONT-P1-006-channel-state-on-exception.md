# FRONT-P1-006 银行异常后渠道记录停留在 SENDING

- 状态：CLOSED
- 优先级：P1
- 影响：通信超时、解析失败或系统异常后渠道流水没有可用于补偿的可靠状态。

## 当前代码证据

- 两家 Handle 均先 INSERT INIT、UPDATE SENDING，并由完整 try/catch 覆盖请求序列化、钱包调用、
  响应校验、结果组装和响应持久化；异常不再直接遗留 `SENDING`。
- `ConnectException`、`NoRouteToHostException`、`UnknownHostException` 被认定为明确未发送，渠道记录写 `FAILED`；
  超时、响应解析失败和其他发送结果不明的异常写 `UNKNOWN`。
- `CiticWalletHttpClient` 已删除“`HttpException` 且无有效 HTTP 状态码即视为明确未发送”的分支；
  连接重置、EOF、TLS 中断等发送结果不明异常统一映射为 `WALLET_RESULT_UNKNOWN`。

## 验收标准

1. 明确未发送或明确通信失败更新为 FAILED。
2. 可能已经发送但没有可靠终态更新为 UNKNOWN。
3. 保存允许持久化的错误分类和响应时间，不保存异常堆栈或完整报文。
4. 更新渠道状态失败不能覆盖原始系统异常，应保留主异常并记录安全日志。
5. 后续可通过交易状态查询补偿 UNKNOWN 记录。

## 当前核验结果（2026-08-10）

已完成：

1. 两家 Transaction Handle 的异常窗口已覆盖到响应持久化完成；
2. `resendTransferAuthCode()` 已纳入相同异常保护；
3. 状态更新失败不会覆盖原始异常；
4. JSON 响应解析失败、超时及一般发送结果不明异常具备写 `UNKNOWN` 的路径。

5. 中信只在根异常明确为 `ConnectException`、`NoRouteToHostException`、`UnknownHostException` 时映射
   `WALLET_COMMUNICATION_FAILED`；其余 Hutool/IO/SSL/连接中断异常统一映射为 `WALLET_RESULT_UNKNOWN`。

## 关闭条件

- 按"请求明确未发送/明确失败"和"请求可能已经发送"分别落 `FAILED/UNKNOWN`；
- 覆盖从银行 DTO 组装完成后到响应持久化完成前的全部异常窗口；
- 状态更新失败只记录安全日志或作为 suppressed 信息保留，不覆盖原始异常；
- 系统异常继续抛出，不转换成普通银行业务失败。

## 关闭记录

- 2026-08-10：用户明确确认由当前会话修复并关闭；代码与文档完成静态核验后状态改为 `CLOSED`。
