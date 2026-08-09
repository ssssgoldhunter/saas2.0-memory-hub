# FRONT-P0-001 外部银行编码无法完成路由

- 状态：CLOSED
- 优先级：P0
- 影响：13 个接口使用约定银行编码时均无法进入具体 Handle。

## 证据

- `BankCode` 对外值为中信 `zxegj`、平安 `pajzb`，并已提供 `BankCode.fromCode`。
- 原 `FrontRouteAndCapabilityCheckNode.parseBankCode` 使用 `BankCode.valueOf(platformCode)`。
- `AbstractBankHandle.parseBankCode` 再次使用 `BankCode.valueOf(platformCode)`。
- `valueOf` 只接受枚举名称 `CITIC/PING_AN`，不接受对外编码。

## 修改范围

- `catering-api-front/.../BankCode.java`
- `catering-front/.../AbstractFrontNode.java`
- `catering-front/.../FrontTransactionRouteNode.java`
- `catering-front/.../FrontQueryRouteNode.java`
- `catering-front/.../AbstractBankHandle.java`
- 相关 Java 注释和 README/WIKI 实现状态。

## 验收标准

1. 两处转换统一调用 `BankCode.fromCode`，不重复实现转换规则。
2. `zxegj` 路由到中信，`pajzb` 路由到平安。
3. 空值返回 `INVALID_REQUEST`，未知编码返回 `BANK_NOT_SUPPORTED`。
4. 不开放 `CITIC/PING_AN` 作为新的外部协议值。

## 当前修复证据（2026-08-09 静态审查）

- 交易、查询路由节点和 `AbstractBankHandle` 均通过 `BankCode.fromCode` 解析外部编码。
- 空值映射 `INVALID_REQUEST`，未知编码映射 `BANK_NOT_SUPPORTED`。
- 后续按 `FRONT-P2-006` 改为 `(BankCode, FrontCapability)` 复合键时，外部 `platformCode → BankCode` 仍
  必须复用本问题已修复的 `BankCode.fromCode`；本问题状态不因 Registry key 扩展而回退。
- 当前工作区静态代码满足验收口径，用户已确认关闭；本轮未重新执行编译或测试。
