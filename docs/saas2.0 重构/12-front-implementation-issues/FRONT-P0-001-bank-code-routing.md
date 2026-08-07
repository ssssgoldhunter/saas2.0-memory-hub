# FRONT-P0-001 外部银行编码无法完成路由

- 状态：OPEN
- 优先级：P0
- 影响：13 个接口使用约定银行编码时均无法进入具体 Handle。

## 证据

- `BankCode` 对外值为中信 `zxegj`、平安 `pajzb`，并已提供 `BankCode.fromCode`。
- `FrontRouteAndCapabilityCheckNode.parseBankCode` 使用 `BankCode.valueOf(platformCode)`。
- `AbstractBankHandle.parseBankCode` 再次使用 `BankCode.valueOf(platformCode)`。
- `valueOf` 只接受枚举名称 `CITIC/PING_AN`，不接受对外编码。

## 修改范围

- `catering-api-front/.../BankCode.java`
- `catering-front/.../FrontRouteAndCapabilityCheckNode.java`
- `catering-front/.../AbstractBankHandle.java`
- 相关 Java 注释和 README/WIKI 实现状态。

## 验收标准

1. 两处转换统一调用 `BankCode.fromCode`，不重复实现转换规则。
2. `zxegj` 路由到中信，`pajzb` 路由到平安。
3. 空值返回 `INVALID_REQUEST`，未知编码返回 `BANK_NOT_SUPPORTED`。
4. 不开放 `CITIC/PING_AN` 作为新的外部协议值。
