# FRONT-P1-008 重复交易语义及三字段精确匹配不正确

- 状态：OPEN
- 优先级：P1
- 影响：子流水为空时可能把同一主流水的其他交易误判为重复；错误响应仍表达旧幂等语义。

## 证据

- 错误码仍为 `IDEMPOTENCY_CONFLICT`，文案为请求 Hash 冲突。
- `FrontIdempotencyCheckNode` 注释和 TODO 仍使用旧 `bizRequestNo/requestHash` 语义。
- Handle 只在子流水非空时增加条件；空值时没有 `IS NULL/精确空值` 条件。
- 查询列名仍存在字符串字面量。

## 验收标准

1. 统一改为“重复交易检查”，不称为结果重放幂等。
2. 错误码为 `TRANSACTION_ALREADY_EXISTS(F300001, 交易已存在)`。
3. 在当前银行、当前业务表按 tenantId + bizOrderNo + bizSubOrderNo 精确查询。
4. 子流水为空时按约定的标准化空值精确匹配。
5. 命中后不调用银行、不返回旧交易结果。
6. 删除或重命名旧 Idempotency 节点、方法、日志和注释。
