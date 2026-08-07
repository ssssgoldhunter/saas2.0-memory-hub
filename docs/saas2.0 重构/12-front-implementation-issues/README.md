# Front 实现问题清单

> 状态：current  
> 建立时间：2026-08-07  
> 用途：其他 AI 每次只领取一个问题，按文件中的范围修改代码和同步文档。

## 使用规则

1. 开始前完整阅读上级 [WIKI-START.md](../WIKI-START.md) 以及目标问题引用的字段契约。
2. 一次只处理一个问题文件，不顺带重构其他能力。
3. 修改前先向用户说明拟修改文件、字段来源和影响范围。
4. 未收到用户明确要求时，不新增测试类、不运行测试、不执行编译。
5. 未经用户确认，不 commit、不 push。
6. 修复后把问题文件的 `状态` 从 `OPEN` 改为 `FIXED_PENDING_REVIEW`，补充实际修改文件；用户确认后再改为 `CLOSED`。
7. 当前不登记以下两项：租户银行配置查询接口/字段范围调整、银行 HTTP URL 日志调整。

## 问题索引

| ID | 优先级 | 问题 | 状态 |
|---|---|---|---|
| [FRONT-P0-001](FRONT-P0-001-bank-code-routing.md) | P0 | 外部银行编码无法完成路由 | OPEN |
| [FRONT-P0-002](FRONT-P0-002-request-context-injection.md) | P0 | 请求头四字段无法可靠注入 FrontRequest.baseData | OPEN |
| [FRONT-P0-003](FRONT-P0-003-liteflow-business-exception.md) | P0 | LiteFlow 业务异常和具体返回类型未闭环 | OPEN |
| [FRONT-P1-001](FRONT-P1-001-transfer-field-mapping.md) | P1 | transfer/consume/transferAuth 请求字段缺失 | OPEN |
| [FRONT-P1-002](FRONT-P1-002-special-data-validation.md) | P1 | specialData 缺少按银行能力的必填校验 | OPEN |
| [FRONT-P1-003](FRONT-P1-003-query-pagination.md) | P1 | 分页 code/msg/total 和游标协议不符合约束 | OPEN |
| [FRONT-P1-004](FRONT-P1-004-citic-status-locator.md) | P1 | 中信交易状态查询原渠道记录定位不完整 | OPEN |
| [FRONT-P1-005](FRONT-P1-005-refund-lifecycle.md) | P1 | 退款原交易、累计金额和并发控制未闭环 | OPEN |
| [FRONT-P1-006](FRONT-P1-006-channel-state-on-exception.md) | P1 | 银行异常后渠道记录停留在 SENDING | OPEN |
| [FRONT-P1-007](FRONT-P1-007-pingan-auth-code-resend.md) | P1 | 平安授权码重发请求对象和持久化不完整 | OPEN |
| [FRONT-P1-008](FRONT-P1-008-duplicate-transaction.md) | P1 | 重复交易语义及三字段精确匹配不正确 | OPEN |
| [FRONT-P1-009](FRONT-P1-009-platform-transfer-persistence.md) | P1 | 中信平台收付款落库方向错误 | OPEN |
| [FRONT-P1-010](FRONT-P1-010-sharding-fail-closed.md) | P1 | 分库配置异常时错误回退默认数据源 | OPEN |
| [FRONT-P2-001](FRONT-P2-001-base-special-boundary.md) | P2 | baseData 与 specialData 字段边界未落实 | OPEN |
| [FRONT-P2-002](FRONT-P2-002-persistence-converter.md) | P2 | Handle 反射赋值违反对象转换约束 | OPEN |
| [FRONT-P2-003](FRONT-P2-003-resource-consistency.md) | P2 | LiteFlow 与 DDL 存在多份冲突资源 | OPEN |
| [FRONT-P2-004](FRONT-P2-004-comments-and-docs.md) | P2 | Java 注释和历史文档存在过时口径 | OPEN |

## 完成度口径

- `P0` 未清零：不能进行真实联调。
- `P1` 未清零：不能认定对应交易或查询能力完整实现。
- `P2` 未清零：可继续单能力开发，但不能认定代码结构和文档约束完全收口。
- 平安五个查询保持 `PENDING_INTEGRATION` 属于当前已确认边界，不作为缺陷登记。
