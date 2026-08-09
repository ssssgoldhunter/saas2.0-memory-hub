# FRONT-P2-004 Java 注释和历史文档存在过时口径

- 状态：CLOSED
- 优先级：P2
- 影响：其他 AI 可能根据注释重新实现已废弃的快照、幂等或错误路由逻辑。

## 已确认示例

- `FrontBaseRequestData` 注释称 `zxegj/pajzb` 使用 `BankCode.valueOf` 转换。
- `BaseTransactionBusinessData` 注释称保存完整 baseData 加密快照，并称 bizRequestNo 是幂等键。
- `BaseRequest.dataSourceId` 注释称用于分库路由；当前约束为只记录，实际分片键是 tenant_id。
- 公共 `FrontIdempotencyCheckNode` 已删除；`FrontExecutionInfo.requestHash` 仍描述“幂等框架接入后回填”，
  但当前没有调用方，且渠道表约束明确禁止 `request_hash` 字段。
- 00/02/03 中保留 platformCode 待确认、旧 functionFlag 或旧 baseData 边界等历史描述。
- WIKI 中历史“编译通过”不能代表当前未提交工作树状态。

## 验收标准

1. Java 对象和 Slot 字段注释说明真实用途、来源和禁止边界。
2. 删除快照、旧幂等、错误 valueOf、dataSourceId 路由等过时描述。
3. 旧能力文档保留历史内容时显式标注 superseded，并指向当前契约。
4. WIKI 的"已实现/未实现"与当前代码审查结果一致，不把历史编译记录当成当前验收结果。

## 当前核验结果（2026-08-09）

部分 Java 注释已清理：

| 文件 | 原问题 | 当前状态 |
|---|---|---|
| `FrontBaseRequestData.java` | 称 `BankCode.valueOf` 转换 | ✅ 已写 `BankCode.fromCode(platformCode)` |
| `BaseTransactionBusinessData.java` | 称保存加密快照、bizRequestNo 是幂等键 | ✅ 原注释已不包含此内容，仅"幂等控制"改为"重复交易检查" |
| `BaseRequest.dataSourceId` | 称用于分库路由 | ✅ 已写"不参与分库路由（分片键是 tenant_id）" |
| `FrontExecutionInfo.requestHash` | 称"幂等框架接入后回填" | ✅ 已写"预留字段，当前未使用" |
| `FrontIdempotencyCheckNode` | 已删除，提及该节点的注释不存 | ✅ 文件已不存在，无残留引用 |

本轮已收口：

1. WIKI 已改为当前 `(BankCode, FrontCapability) → BankCapabilityHandle` 路由结构，Dispatch 只执行路由结果，
   不再描述“大 Handle + capability switch”为当前事实。
2. WIKI 已删除复制的历史“当前没有完成”长清单；当前状态只引用 Issue README 和子文件，历史编译声明
   不作为验收证据。
3. `00`、`04` 已标记为历史交接/参考方案，内部旧阶段勾选和未完成描述不得覆盖当前代码与 Issue 状态。
4. `BasePageQuery`、`RequestContext` 已明确请求 `dataSourceId` 只用于上下文传递和记录；SQL 分片键是
   `tenant_id`，实际 `ds_x` 来自租户配置 `data_source_id`。
5. 中信、平安提现 ContractKeys 的账户、卡号、姓名注释已统一为 `specialData` 原始 key 来源。
6. `BankTransactionHandle.refund` 已删除“由 Front 渠道流水补全原交易字段”的公共错误描述，明确中信与平安边界分开。
7. 10 个渠道交易 ServiceImpl 已删除不存在的“4 个加密快照 text 字段/专用快照组件”注释。
8. `FrontExecutionInfo.capability` 注释已改为 Registry 复合路由键和交易渠道流水记录，不再描述公共 Dispatch 选方法。

## 修改记录（2026-08-09）

1. `RefundBusinessData.java` 类注释重写：删除"三组选一"、Front 加载原交易、originalCapability 回填等
   过时描述，改为"中信退款固定使用组 2（originalBizOrderNo + originalBizSubOrderNo）定位，原银行字段
   从 specialData 读取，Front 不查询本地原交易补齐"；字段级注释同步修正。
2. `CiticWithdrawContractKeys.java` 字段注释 `ACCOUNT_NO/CARD_NO` 修正为"取 specialData"，
   删除 `baseData.withdrawAccountId/baseData.bankCardNo` 等错误来源描述。
3. WIKI 曾按错误的“全部已完成”状态收缩处理顺序；当时重新核验确认 P1-004/006/011/013 为 OPEN。
   当前 P1-004 已由用户确认关闭，P1-006/011/013 保持 `FIXED_PENDING_REVIEW`；具体状态只引用 Issue README，
   避免再次产生双份状态。
4. 修正 `BasePageQuery`、`RequestContext`、`FrontExecutionInfo`、两家提现 ContractKeys 和
   `BankTransactionHandle` 的过时注释；清理 10 个 ServiceImpl 的快照遗留描述。
5. 为 `00` 和 `04` 增加历史文档标识，旧阶段状态不再作为当前开发入口。

## 用户确认（2026-08-09）

- 本轮只修改文档和 Java 注释，没有改变字段、接口、银行报文或运行逻辑；
- 静态检索已不再发现本问题列出的错误 `dataSourceId` 路由、提现字段来源或快照注释；
- 用户已确认上述注释与文档收口结果，本问题转为 `CLOSED`。

## 关闭条件

- Java DTO、Slot、公共上下文和 ContractKeys 注释与当前字段来源完全一致；
- WIKI 的已实现/未实现列表以当前代码和 issue 状态为准；
- 退款旧边界、旧 Router/Dispatch 结构和历史编译结论不得继续作为当前事实；
- 历史材料确需保留时明确标注 superseded 并链接当前契约；
- 当前验收项均已完成并经用户确认；后续发现新的过时口径时单独登记，不回退本问题状态。
