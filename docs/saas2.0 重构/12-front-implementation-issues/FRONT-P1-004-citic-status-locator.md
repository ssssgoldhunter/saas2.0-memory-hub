# FRONT-P1-004 中信交易状态查询原渠道记录定位不完整

- 状态：OPEN
- 优先级：P1
- 影响：使用业务主子流水查询时可能不带银行要求的 acctNo/原银行流水，或查询到错误记录。

## 证据

- `resolveAccountNoForStatusQuery` 只在存在 `frontSsn` 时查询。
- 只查中信 transfer/consume/withdraw 表，未覆盖 refund/platformPay/platformReceive。
- 查询未带 tenantId 条件。
- 同时提供 frontSsn 和业务主子流水时没有交叉校验。
- 数据库异常被 catch 后返回 null，系统异常被隐藏。
- 没有按原记录补充 `ORI_USER_SSN`。

## 验收标准

1. 支持 `frontSsn` 或 `bizOrderNo + bizSubOrderNo` 定位。
2. 同时提供多组定位条件时必须指向同一记录。
3. 查询固定包含 tenantId，并按中信当前能力的有限表集合查找。
4. 未找到原交易明确业务失败，数据库异常继续抛出。
5. 从原记录加载 acctNo、银行流水等协议字段，调用方不能伪造。
