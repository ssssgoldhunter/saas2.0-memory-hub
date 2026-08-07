# FRONT-P1-001 transfer/consume/transferAuth 请求字段缺失

- 状态：OPEN
- 优先级：P1
- 影响：银行请求与 06/07 字段契约不一致。

## 已确认缺失

1. 平安 `transfer/consume` 未调用 `fillAccountReserve`，缺少账户配置字段：
   `mrchCode/txnClientNo/stlAcctNo`。
2. 中信 `transfer/consume` 未设置钱包顶层 `remark=baseData.remark`。
3. 平安 `transfer/consume` 未设置钱包顶层 `remark=baseData.remark`。
4. 平安 `transferAuth` 只写 reserve remark，未设置钱包顶层 `remark`。

## 修改范围

- `CiticTransactionHandle`
- `PingAnTransactionHandle`
- 如实际常量或注释不一致，同步 common-core 常量及 06/07 契约。

## 验收标准

1. 字段来源严格按 06/07 契约。
2. 账户配置只能来自 `accountSpecialData`，业务请求不能覆盖。
3. `stlAcctNo` 按协议加密，禁止日志和返回明文。
4. 不把授权转账 specialData 与普通 transfer/consume 混用。
