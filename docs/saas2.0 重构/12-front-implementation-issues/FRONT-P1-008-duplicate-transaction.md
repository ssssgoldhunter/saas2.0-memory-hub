# FRONT-P1-008 重复交易语义及三字段精确匹配不正确

- 状态：CLOSED
- 优先级：P1
- 影响：子流水为空时可能把同一主流水的其他交易误判为重复；错误响应仍表达旧幂等语义。

## 证据

- 错误码仍为 `IDEMPOTENCY_CONFLICT`，文案为请求 Hash 冲突。
- 公共 `FrontIdempotencyCheckNode` 原本不查询数据库，只重复检查 Bean Validation 已保证的字段，现已删除。
- 具体银行 Handle 的检查方法仍使用 `checkIdempotency` 旧名称。
- Handle 只在子流水非空时增加条件；空值时没有 `IS NULL/精确空值` 条件。
- 查询列名仍存在字符串字面量。

## 验收标准

1. 统一改为“重复交易检查”，不称为结果重放幂等。
2. 错误码为 `TRANSACTION_ALREADY_EXISTS(F300001, 交易已存在)`。
3. 在当前银行、当前业务表按 tenantId + bizOrderNo + bizSubOrderNo 精确查询。
4. 子流水为空时按约定的标准化空值精确匹配。
5. 命中后不调用银行、不返回旧交易结果。
6. 删除或重命名旧 Idempotency 节点、方法、日志和注释。

## 已完成收口

- 已删除无数据库查询能力的 `FrontIdempotencyCheckNode`。
- 已从 8 条交易 LiteFlow 链及 Nacos 节点说明中删除 `frontIdempotencyCheck`。
- 重复交易检查继续由具体银行 Handle 使用当前业务固定 Mapper 执行。

## 当前修复证据（2026-08-09 静态审查）

- Handle 方法已改为 `checkDuplicateTransaction`，错误码为 `TRANSACTION_ALREADY_EXISTS(F300001)`。
- 当前银行、当前业务表使用 `tenantId + bizOrderNo + bizSubOrderNo` 查询；子流水为空时使用 `IS NULL`。
- 命中后直接抛业务异常，不调用银行，也不返回或重放旧交易结果。
- 当前实例的并发窗口及后续 report 跨实例补查边界已由已关闭的 `FRONT-P1-012` 收口；report 尚未接入时
  两家 Handle 保留明确 TODO，不在本问题内预造实现。
- 用户已确认关闭；本轮未重新执行编译或测试。
