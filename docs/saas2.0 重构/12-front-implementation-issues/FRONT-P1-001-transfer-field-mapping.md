# FRONT-P1-001 transfer/consume/transferAuth 请求字段缺失

- 状态：CLOSED
- 优先级：P1
- 影响：银行请求与 06/07 字段契约不一致。

## 已确认缺失

1. 平安 `transfer/consume` 未调用 `fillAccountReserve`，缺少账户配置字段：
   `mrchCode/txnClientNo/stlAcctNo`。
2. 中信 `transfer/consume` 未设置钱包顶层 `remark=baseData.remark`。
3. 平安 `transfer/consume` 未设置钱包顶层 `remark=baseData.remark`。
4. 平安 `transferAuth` 只写 reserve remark，未设置钱包顶层 `remark`。

## 修改范围

- `CiticTransHandle`
- `PingAnTransHandle`
- 如实际常量或注释不一致，同步 common-core 常量及 06/07 契约。

## 验收标准

1. 字段来源严格按 06/07 契约。
2. 账户配置只能来自 `accountSpecialData`，业务请求不能覆盖。
3. `stlAcctNo` 按协议加密，禁止日志和返回明文。
4. 不把授权转账 specialData 与普通 transfer/consume 混用。

## 当前修复证据（2026-08-09 静态审查）

- 中信、平安 transfer/consume 已补齐协议请求字段和顶层 remark。
- 平安 transferAuth 使用自己的 ContractKeys，并补齐顶层 remark。
- 账户配置字段从 `accountSpecialData` 读取，未开放给业务 `specialData` 覆盖。
- 用户已确认关闭；本轮未重新执行编译或测试。
