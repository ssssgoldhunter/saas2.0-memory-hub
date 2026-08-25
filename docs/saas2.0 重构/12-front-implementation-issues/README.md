# Front 实现问题清单

> 状态：current
>
> 建立时间：2026-08-07
>
> 最近核验：2026-08-25
>
> 用途：其他 AI 每次只领取一个问题，按问题文件范围修改代码并同步引用文档。

> 结构简化不是旧缺陷 Issue，当前唯一活动结构任务是
> [29-cateringfront全量扁平化迁移-plan](../29-cateringfront全量扁平化迁移-plan.md)。
> 旧 P0/P1/P2 Issue 继续保持 CLOSED，不得因结构迁移重新打开。

## 状态口径

| 状态 | 含义 |
|---|---|
| `OPEN` | 当前 HEAD/工作区仍存在未满足的验收项，允许后续领取 |
| `FIXED_PENDING_REVIEW` | 代码和引用文档已有完整静态证据，等待用户确认 |
| `CLOSED` | 用户已确认完成，不得重复修改 |
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
| [FRONT-P1-006](FRONT-P1-006-channel-state-on-exception.md) | P1 | 银行异常后渠道记录停留在 SENDING | CLOSED |
| [FRONT-P1-007](FRONT-P1-007-pingan-auth-code-resend.md) | P1 | 平安授权码重发请求对象和持久化不完整 | CLOSED |
| [FRONT-P1-008](FRONT-P1-008-duplicate-transaction.md) | P1 | 重复交易语义及三字段精确匹配不正确 | CLOSED |
| [FRONT-P1-009](FRONT-P1-009-platform-transfer-persistence.md) | P1 | 中信平台收付款落库方向错误 | CLOSED |
| [FRONT-P1-010](FRONT-P1-010-sharding-fail-closed.md) | P1 | 分库配置异常时错误回退默认数据源 | CLOSED |
| [FRONT-P1-011](FRONT-P1-011-full-chain-structured-logging.md) | P1 | 查询链路存在重复日志和无效反射采集 | CLOSED |
| [FRONT-P1-012](FRONT-P1-012-duplicate-transaction-atomicity.md) | P1 | 重复交易检查的实例边界 | CLOSED |
| [FRONT-P1-013](FRONT-P1-013-base-data-capability-validation.md) | P1 | baseData 缺少按银行具体能力的必填和格式校验 | CLOSED |
| [FRONT-P1-014](FRONT-P1-014-pingan-6073-queryid-link.md) | P1 | 平安 6073 订单回查错用 bank_user_ssn | CLOSED |
| [FRONT-P1-015](FRONT-P1-015-detail-query-total-page-failure.md) | P1 | 24/25 明细失败返回缺少 totalPage | CLOSED |
| [FRONT-P2-001](FRONT-P2-001-base-special-boundary.md) | P2 | baseData 与 specialData 字段边界未落实 | CLOSED |
| [FRONT-P2-002](FRONT-P2-002-persistence-converter.md) | P2 | Handle 反射赋值违反对象转换约束 | CLOSED |
| [FRONT-P2-003](FRONT-P2-003-resource-consistency.md) | P2 | LiteFlow 与 DDL 存在多份冲突资源 | CLOSED |
| [FRONT-P2-004](FRONT-P2-004-comments-and-docs.md) | P2 | Java 注释和历史文档存在过时口径 | CLOSED |
| [FRONT-P2-005](FRONT-P2-005-route-capability-overcoupling.md) | P2 | 统一路由节点按 capability 猜测 Router 且重复预验证 | CLOSED |
| [FRONT-P2-006](FRONT-P2-006-capability-dispatch-overcoupling.md) | P2 | 银行 + capability 未直接映射到能力 Handler | CLOSED |
| [FRONT-P2-007](FRONT-P2-007-handler-fixed-value-consistency.md) | P2 | Handle 银行固定参数和公共常量口径混用 | CLOSED |
| [FRONT-P2-008](FRONT-P2-008-detail-query-doc-contract-drift.md) | P2 | 24/25 明细查询联动文档仍有当前口径漂移 | CLOSED |
| [FRONT-P2-009](FRONT-P2-009-detail-query-legacy-dto-residual.md) | P2 | 24/25 明细旧 DTO 在 ContractKeys 注释残留 | CLOSED |

当前 P0/P1/P2 共 28 项全部 `CLOSED`（P1-015、P2-008 已于 2026-08-20 经用户确认关闭）；
独立 TODO-002 保持 `CLOSED`（2026-08-20 用户 review 确认，修复代码已在工作区完成）。

## 当前状态摘要

全部 P0/P1/P2 功能 Issue 与独立 TODO-002 均已关闭：

1. `FRONT-P1-015`（CLOSED，2026-08-20）：中信非法 `TOTAL_PAGE` 收口为失败分页、
   web-test Feign 失败分页壳补齐 `totalPage=0`，用户确认关闭。
2. `FRONT-P2-008`（CLOSED，2026-08-20）：第八轮 `pageNo/pageSize` 选填、
   `accountType` 选填（仅中信生效）口径修复，用户确认关闭。
3. `TODO-002`（CLOSED，2026-08-20）：平安退款原渠道查询、协议映射、INIT 落库、
   单实例并发查重与 DDL 口径，用户 review 确认关闭。

平安账户状态/余额已按用户裁决固定保留挡板，不再作为待解决项；report 跨实例补查
已按用户裁决暂缓（`DEFERRED`）。

### 当前仍需处理

| 类型 | 对应文档 | 说明 |
|---|---|---|
| 终验任务 | [18 号 plan T11](../18-明细查询对外契约与平安启用-plan.md) | 保持未勾选；只有用户明确授权时才执行当次编译和最终自检 |

全部功能 Issue 已关闭；上表仅为按用户授权才会执行的终验编译项，不属于缺陷。

## 历史用户确认关闭（9 项，2026-08-19）

1. `FRONT-P0-002`：确认 Front 接收 header 后注入四字段，以及 Front 调用 Feign API 时转发四字段。
2. `FRONT-P1-004`：确认中信转账/消费/退款按业务主子流水查询，提现按业务主流水查询。
3. `FRONT-P2-004`：确认当前 Java 注释、WIKI 和历史文档状态口径。
4. `FRONT-P2-007`：确认协议字段 key 与 Handle 单接口固定 value 的常量职责边界。
5. `FRONT-P1-006`：确认只将明确建连失败写 `FAILED`，无状态码的 Hutool/IO/SSL/连接中断异常写 `UNKNOWN`。
6. `FRONT-P1-011`：确认两个 Query Handle 已删除反射 metadata 和重复请求日志。
7. `FRONT-P1-013`：确认已启用接口的 baseData 校验和 06、07、08 字段契约一致。
8. `FRONT-P1-014`：确认平安 6073 已按
   `tenantId + bankQueryId(frontSeqNo)` 回查原提现记录，不再使用 `bankUserSsn`。
9. `TODO-002`：确认平安退款原渠道查询、协议映射、INIT 落库、单实例并发查重、DDL 与文档口径验收通过。

以上 9 项已改为 `CLOSED`，不得重复领取或修改。
`FRONT-P1-005` 的代码、字段契约和目标 DDL 已收口，用户已确认已有物理库完成
`09C-citic-refund-legacy-columns-nullable.sql`，该问题已关闭。

## 2026-08-20 用户确认关闭（3 项）

1. `FRONT-P1-015`：确认中信非法 `TOTAL_PAGE` 收口为失败分页、web-test Feign 失败
   分页壳补齐 `totalPage=0`。
2. `FRONT-P2-008`：确认第八轮 `pageNo/pageSize` 选填、`accountType` 选填
   （仅中信生效、平安 6073 忽略）口径修复。
3. `TODO-002`：用户 review 确认平安退款修复（原渠道两表定位、`oriTransSsn=frontSsn`、
   INIT 落库、单实例并发查重、DDL 口径）验收通过。

以上 3 项均已 `CLOSED`。

## 延后安全事项

| ID | 事项 | 状态 |
|---|---|---|
| [FRONT-SEC-001](FRONT-SEC-001-plaintext-credentials.md) | Front 配置明文凭据轮换和 Git 历史清理 | DEFERRED |

## 本轮核验边界

- 状态依据代码分支 `limeng_front@d3ec00af` 以及代码/记忆体当前工作区静态证据；
- 2026-08-20 用户确认 P1-015、P2-008、TODO-002 关闭；P0/P1/P2 28 项全部 `CLOSED`；
- 两家交易 Handle 已登记 report 汇总四实例后的第二次重复查询 TODO（跨实例补查 `DEFERRED`）；
- 本轮没有新增测试、没有运行测试、没有执行编译，不用历史"编译通过"替代当前验收；
- 平安 5 个查询中 3 个已启用、2 个按用户裁决保留挡板，TODO-001 已关闭；
  report 跨实例补查已暂缓，统一由 `13-front后续待办.md` 跟踪；
- 明文凭据保持独立安全事项，凭据轮换、Git 历史重写和强制推送必须另行授权。

## 完成度口径

- 当前 P0/P1/P2 28 项全部 `CLOSED`；独立 TODO-001/TODO-002 均已 `CLOSED`；
- 后续待办和 `DEFERRED` 安全事项不计入功能 Issue 完成度，但上线计划必须单独跟踪。
