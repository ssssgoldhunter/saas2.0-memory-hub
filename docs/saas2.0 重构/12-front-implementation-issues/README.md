# Front 实现问题清单

> 状态：current
>
> 建立时间：2026-08-07
>
> 最近核验：2026-08-09
>
> 用途：其他 AI 每次只领取一个问题，按问题文件范围修改代码并同步引用文档。

## 状态口径

| 状态 | 含义 |
|---|---|
| `OPEN` | 当前 HEAD/工作区仍存在未满足的验收项，允许后续领取 |
| `FIXED_PENDING_REVIEW` | 代码和引用文档已有完整静态证据，等待用户确认 |
| `CLOSED` | 用户已确认完成，不得重复修改 |
| `TODO` | 能力或协议明确延后，不计入当前缺陷清零 |
| `DEFERRED` | 安全治理或外部协调事项，必须单独授权 |

问题子文件必须按以下顺序组织：状态与影响、边界或问题证据、验收标准、当前核验结果、关闭条件。
历史修复记录可以保留，但不得与当前状态、当前代码证据或关闭条件冲突。

## 使用规则

1. 开始前完整阅读上级 [WIKI-START.md](../WIKI-START.md)、
   [05-front代码开发约束](../05-front代码开发约束.md) 以及目标问题引用的字段契约。
2. 领取前先检查问题在当前 HEAD/工作区是否仍存在；已关闭问题不得重复修改。
3. 一次只处理一个问题文件，不顺带重构其他能力。
4. 修改前先向用户说明问题原因、拟修改文件、实现方式和影响范围。
5. 未收到用户明确要求时，不新增测试类、不运行测试、不执行编译。
6. 未经用户确认，不 commit、不 push。
7. 修复后先改为 `FIXED_PENDING_REVIEW` 并补齐实际证据；只有用户明确确认后才能改为 `CLOSED`。
8. 当前不把租户银行配置查询来源/字段范围和银行 HTTP URL 日志登记为功能 issue。

## 当前问题索引

| ID | 优先级 | 问题 | 状态 |
|---|---|---|---|
| [FRONT-P0-001](FRONT-P0-001-bank-code-routing.md) | P0 | 外部银行编码无法完成路由 | CLOSED |
| [FRONT-P0-002](FRONT-P0-002-request-context-injection.md) | P0 | 请求头四字段无法可靠注入 FrontRequest.baseData | CLOSED |
| [FRONT-P0-003](FRONT-P0-003-liteflow-business-exception.md) | P0 | LiteFlow 业务异常和具体返回类型未闭环 | CLOSED |
| [FRONT-P0-004](FRONT-P0-004-config-system-exception.md) | P0 | 配置加载系统异常被伪装成配置不存在 | CLOSED |
| [FRONT-P1-001](FRONT-P1-001-transfer-field-mapping.md) | P1 | transfer/consume/transferAuth 请求字段缺失 | CLOSED |
| [FRONT-P1-002](FRONT-P1-002-special-data-validation.md) | P1 | specialData 缺少按银行业务方法的必填校验 | CLOSED |
| [FRONT-P1-003](FRONT-P1-003-query-pagination.md) | P1 | 分页 code/msg/total 和游标协议不符合约束 | CLOSED |
| [FRONT-P1-004](FRONT-P1-004-citic-status-locator.md) | P1 | 中信状态查询未按交易类型选择业务流水字段 | CLOSED |
| [FRONT-P1-005](FRONT-P1-005-refund-lifecycle.md) | P1 | 中信退款定位、协议必填字段来源及职责越界 | CLOSED |
| [FRONT-P1-006](FRONT-P1-006-channel-state-on-exception.md) | P1 | 银行异常后渠道记录停留在 SENDING | FIXED_PENDING_REVIEW |
| [FRONT-P1-007](FRONT-P1-007-pingan-auth-code-resend.md) | P1 | 平安授权码重发请求对象和持久化不完整 | CLOSED |
| [FRONT-P1-008](FRONT-P1-008-duplicate-transaction.md) | P1 | 重复交易语义及三字段精确匹配不正确 | CLOSED |
| [FRONT-P1-009](FRONT-P1-009-platform-transfer-persistence.md) | P1 | 中信平台收付款落库方向错误 | CLOSED |
| [FRONT-P1-010](FRONT-P1-010-sharding-fail-closed.md) | P1 | 分库配置异常时错误回退默认数据源 | CLOSED |
| [FRONT-P1-011](FRONT-P1-011-full-chain-structured-logging.md) | P1 | 查询链路存在重复日志和无效反射采集 | FIXED_PENDING_REVIEW |
| [FRONT-P1-012](FRONT-P1-012-duplicate-transaction-atomicity.md) | P1 | 重复交易检查的实例边界 | CLOSED |
| [FRONT-P1-013](FRONT-P1-013-base-data-capability-validation.md) | P1 | baseData 缺少按银行具体能力的必填和格式校验 | FIXED_PENDING_REVIEW |
| [FRONT-P2-001](FRONT-P2-001-base-special-boundary.md) | P2 | baseData 与 specialData 字段边界未落实 | CLOSED |
| [FRONT-P2-002](FRONT-P2-002-persistence-converter.md) | P2 | Handle 反射赋值违反对象转换约束 | CLOSED |
| [FRONT-P2-003](FRONT-P2-003-resource-consistency.md) | P2 | LiteFlow 与 DDL 存在多份冲突资源 | CLOSED |
| [FRONT-P2-004](FRONT-P2-004-comments-and-docs.md) | P2 | Java 注释和历史文档存在过时口径 | CLOSED |
| [FRONT-P2-005](FRONT-P2-005-route-capability-overcoupling.md) | P2 | 统一路由节点按 capability 猜测 Router 且重复预验证 | CLOSED |
| [FRONT-P2-006](FRONT-P2-006-capability-dispatch-overcoupling.md) | P2 | 银行 + capability 未直接映射到能力 Handler | CLOSED |
| [FRONT-P2-007](FRONT-P2-007-handler-fixed-value-consistency.md) | P2 | Handle 银行固定参数和公共常量口径混用 | CLOSED |

当前合计：`21 CLOSED + 3 FIXED_PENDING_REVIEW + 0 OPEN + 2 TODO + 1 DEFERRED`。

## 当前仍需代码修复

当前没有 `OPEN` 问题；P1-006、P1-011、P1-013 已修复并处于 `FIXED_PENDING_REVIEW`，等待用户逐一确认。

## 已修复、待用户确认关闭（3 项）

1. `FRONT-P1-006`：try 覆盖完整异常窗口（DTO 组装→响应持久化），`isClearlyNotSent()` 区分 FAILED/UNKNOWN。
2. `FRONT-P1-011`：删除两个 Query Handle 的反射 metadata 和重复 `bank_request_assembled` 日志。
3. `FRONT-P1-013`：删除跨能力统一校验，按中信/平安具体接口拆分 baseData 必填/格式校验，补 resend 校验；第二
   轮补充中信 refund 日期格式校验、平安 fee 局部变量化+负数拒绝、remark 长度校验（平安 256/512）、
   bizSubOrderNo 逐接口条件写入。

以上 3 项不得重复修改；用户确认后才能从 `FIXED_PENDING_REVIEW` 改为 `CLOSED`。

## 本轮用户确认关闭（4 项）

1. `FRONT-P0-002`：确认 Front 接收 header 后注入四字段，以及 Front 调用 Feign API 时转发四字段。
2. `FRONT-P1-004`：确认中信转账/消费/退款按业务主子流水查询，提现按业务主流水查询。
3. `FRONT-P2-004`：确认当前 Java 注释、WIKI 和历史文档状态口径。
4. `FRONT-P2-007`：确认协议字段 key 与 Handle 单接口固定 value 的常量职责边界。

以上 4 项已从 `FIXED_PENDING_REVIEW` 改为 `CLOSED`，不得重复领取或修改。
`FRONT-P1-005` 的代码、字段契约和目标 DDL 已收口，用户已确认已有物理库完成
`09C-citic-refund-legacy-columns-nullable.sql`，该问题已关闭。

## 延后 TODO

以下事项明确延后，不计入当前 P0/P1/P2 缺陷清零：

| ID | 事项 | 状态 |
|---|---|---|
| [FRONT-TODO-001](FRONT-TODO-001-pingan-query-handle-integration.md) | 平安五个查询 Handle 逐接口核对和接入 | TODO |
| [FRONT-TODO-002](FRONT-TODO-002-pingan-refund-boundary-confirmation.md) | 平安退款边界与协议字段人工确认 | TODO |

## 延后安全事项

| ID | 事项 | 状态 |
|---|---|---|
| [FRONT-SEC-001](FRONT-SEC-001-plaintext-credentials.md) | Front 配置明文凭据轮换和 Git 历史清理 | DEFERRED |

## 本轮核验边界

- 状态依据 `limeng_front` 当前 HEAD 和未提交工作区静态代码，以及记忆体权威字段契约和最终 DDL；
- 代码最新提交 `0023ef9` 只包含 `TableDataInfo` 迁移，大部分 Front 修复仍未提交；
- 本轮按用户确认关闭 P0-002、P1-004、P2-004、P2-007；P1-006、P1-011、P1-013
  继续保持 `FIXED_PENDING_REVIEW`；当前没有 `OPEN` 问题；
- `FRONT-P1-012` 继续保持 `CLOSED`；两家交易 Handle 已登记 report 汇总四实例后的第二次重复查询 TODO；
- 本轮没有新增测试、没有运行测试、没有执行编译，不用历史"编译通过"替代当前验收；
- 平安五个查询和平安退款继续保持 TODO，不得由其他 issue 顺带启用；
- 明文凭据保持独立安全事项，凭据轮换、Git 历史重写和强制推送必须另行授权。

## 完成度口径

- 当前 P0/P1/P2 已无 `OPEN` 问题；21 项已关闭，剩余 3 项处于 `FIXED_PENDING_REVIEW`。
- TODO 和 DEFERRED 不阻止当前功能 issue 逐项关闭，但上线计划必须单独跟踪。
