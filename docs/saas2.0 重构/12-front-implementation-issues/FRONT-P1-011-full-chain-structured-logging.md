# FRONT-P1-011 查询链路存在重复日志和无效反射采集

- 状态：FIXED_PENDING_REVIEW
- 优先级：P1
- 影响：查询 API 不需要交易链路级别的全阶段定位日志；当前 Query Handle 又增加一层请求日志并通过反射采集
  业务字段，造成重复输出和无效复杂度。

## 最新边界（2026-08-09 用户确认）

- 交易链路继续遵守完整的 API、Handle、报文组装、钱包访问前后日志要求。
- 查询链路不要求日志携带 `capability`，也不要求 API 查询入口额外提取完整业务主子流水。
- 查询链路渠道侧唯一强制的请求报文日志是：钱包 HTTP Client 真正发送前打印完整、已脱敏的银行请求 JSON。
- 查询日志保留银行编码和实际钱包方法名即可；不得为日志引入反射、字段猜测或其他业务逻辑。
- 已有框架通用 API 访问/失败日志可以保留，但不得为了查询补充交易型 metadata。

## 当前代码证据

- `CiticWalletHttpClient` 和 `PingAnWalletHttpClient` 已在 HTTP `execute()` 前记录
  `wallet_request_sending`，payload 为最终请求 `bodyJson`，满足查询钱包发送前日志要求。
- 两个 Query Handle 已删除 `queryMetadata()` 反射字段采集方法。
- 两个 Query Handle 的 `invokeQuery()` 已删除 `bank_request_assembled` 日志，查询请求仅通过
  `wallet_request_sending` 记录一次。metadata 只含 `bankCode` 和银行接口 `apiName`，不含
  `capability`、`bizOrderNo/bizSubOrderNo` 等交易型字段。
- 查询链路日志不含 `capability`；按最新边界这是正确的，不得再增加。

## 验收标准

1. 查询请求在钱包 HTTP Client 真正发送前记录一次 `wallet_request_sending`。
2. 日志包含银行编码、实际钱包接口名，以及字段和层级完整、完成脱敏的最终银行请求 JSON。
3. 删除 Query Handle 的 `queryMetadata()` 反射字段提取，不改为另一套查询 metadata 映射。
4. 删除 Query Handle 对同一请求重复输出的 `bank_request_assembled`；查询不复制交易链路的全阶段日志矩阵。
5. 查询日志不要求 `capability`、`bizOrderNo/bizSubOrderNo` 等固定 metadata；这些字段若存在于最终银行报文，
   只作为已脱敏 payload 的正常字段输出。
6. 日志简化不改变银行请求、响应处理、错误语义或平安查询 `ADAPTER_NOT_READY` 边界。

## 本次修复（2026-08-09）

1. `CiticQueryHandle.invokeQuery()`：删除 `queryMetadata()` 反射调用和 `bank_request_assembled` 日志，
   metadata 简化为 `new JSONObject()` 只放 `bankCode + apiName` 传给 httpClient.post。
2. `CiticQueryHandle`：删除整个 `queryMetadata()` 方法及未使用的 `FrontLogJsonUtils` 导入。
3. `PingAnQueryHandle.invokeQuery()`：同上——删除反射 metadata 和 `bank_request_assembled` 日志。
4. `PingAnQueryHandle`：删除整个 `queryMetadata()` 方法及未使用的 `FrontLogJsonUtils` 导入。
5. 两家 `WalletHttpClient` 的 `wallet_request_sending` 保持不动，继续输出发送前完整脱敏请求 JSON。
