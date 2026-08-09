# FRONT-P1-007 平安授权码重发请求对象和持久化不完整

- 状态：CLOSED
- 优先级：P1
- 影响：bizFunc=26 报文语义可能错误，且授权码调用没有渠道记录。

## 证据

- 当前复用 `PingAnTransferRequest`。
- 平安协议顶层 `acctNo` 被映射到 `outAcctNo`。
- 方法直接 `doInvoke`，没有 INIT/SENDING/响应状态落库。
- `receiveMobile` 是否需要解密仍是待人工确认边界。

## 验收标准

1. 创建 bizFunc=26 专用银行请求对象，字段名与协议一致。
2. 字段来源严格按 07 号契约，不复用普通转账 specialData 语义。
3. 按平安 transfer 渠道表保存 INIT/SENDING/终态记录。
4. `smsIdx/receiveMobile` 不写日志、不保存不必要明文。
5. `receiveMobile` 解密规则在人工确认前不得臆测修改。

## 2026-08-09 代码验证

验收标准已全部满足，issue 描述滞后于当前实现：

| 验收项 | 代码证据 |
|---|---|
| 1. 专用请求对象 | ✅ `PingAnTransferAuthCodeRequest` 仅含 `outAcctNo` + `transAmt`，字段名与平安协议一致 |
| 2. 字段来源按 07 契约 | ✅ `PAY_MEMBER_ID` 来自 `PingAnTransferContractKeys`，`acctNo/intAcctNo` 来自 `PingAnTransferAuthCodeContractKeys`，不复用普通转账语义 |
| 3. INIT/SENDING/终态 | ✅ `insertInitRecord()` → `updateSending()` → `doInvoke()` 异常时 `updateResponseOnException(UNKNOWN)` → 正常时 `updateAuthCodeResponse()` |
| 4. smsIdx/receiveMobile 不写日志 | ✅ 解密后仅写入 `result.getSpecialData()`，不进入 JSON 日志（`bank_response_received` 日志用 `txResult` 占位不含此数据） |
| 5. receiveMobile 解密 | ✅ 使用标准 `sm2Crypto.decryptHex(cryptoProperties.getSm2PrivateKey(), ...)`，与已有 SM2 解密规范一致；规则沿用现有实现，未臆测修改 |
