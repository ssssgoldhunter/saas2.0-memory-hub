# FRONT-P1-007 平安授权码重发请求对象和持久化不完整

- 状态：OPEN
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
