# FRONT-ACC-001 账户维护能力开发（进行中）

- 状态：IN_PROGRESS（2026-08-29 核验：代码已在 `limeng_front@cead0222`，代码工作区干净；
  静态缺口、编译和联调尚未闭环）
- 优先级：新功能（非缺陷；不在扁平化重构范围内，api-front 允许增量 diff）

## 功能范围（已见代码）

中信 Account 域当前共有 **9 个 Capability**：既有查询能力 **2** 个
（CiticAccountStatusCapability / CiticAccountBalanceCapability，含平安侧挡板对位），
账户维护新增能力 **7** 个。FrontAccountApplicationService 承接账户维护 7 方法，
与新增 7 个 Capability 一一对应：

| # | AppService 方法 | Capability | FrontCapability |
|---|---|---|---|
| 1 | openAccount | CiticAccountOpenCapability | ACCOUNT_OPEN |
| 2 | bindCard | CiticAccountBindCardCapability | ACCOUNT_BIND_CARD |
| 3 | unbindCard | CiticAccountUnbindCardCapability | ACCOUNT_UNBIND_CARD |
| 4 | updateAccountInfo | CiticAccountUpdateInfoCapability | ACCOUNT_UPDATE_INFO |
| 5 | acctClose | CiticAccountCloseCapability | ACCOUNT_CLOSE |
| 6 | whiteName（含 unwhiteName 链） | CiticAccountWhiteNameCapability | ACCOUNT_WHITE_NAME（opType 区分去白） |
| 7 | withdraw | CiticAccountWithdrawCapability | ACCOUNT_WITHDRAW |

api-front 已扩展 `AccountBusinessData` 等 DTO 与对应枚举；
Slot 已扩展（FrontAccountSlot 持有 AccountBusinessData 请求域与 AccountBaseResult 结果承载）。

## 状态分级

- ✅ 文件已存在：9 个 Capability、AppService、Controller、链定义（XML）、
  3 个常量类（静态检查确认存在，2026-08-27）；
- ⚠️ 静态检查发现一项待确认：`chainFrontAccountUnwhiteName` 链只在 XML 与 AppService
  常量中存在，**无任何方法调用**——`FrontAccountApi` 仅有 `/white-name` 端点，
  去白通过 `specialData.opType` 区分。该链属孤儿链，待用户确认删除还是接入
  （如接入需补 `unwhiteName` API 端点与 AppService 方法）；
- 数量与分布（当前源码实测）：`FrontCapability` 枚举 21 项；银行 Capability 实现类 29 个 =
  交易 12 / 查询 6 / 账户 11
  （账户 11 = 中信 9 + 平安挡板 2）；链 21 = 8 交易 / 3 查询 / 10 账户
  （账户 10 = 既有状态/余额查询 2 + 账户维护 8）；
- ⏳ 待编译验证：整体编译状态待验证——原缺常量类阻塞已解除（3 个常量类已在源码中，
  静态检查确认），但解除后未执行编译，禁止声称"编译已通过"；
- ⏳ 待联调验证：由用户安排同事进行运行测试。

## 交接注意事项

1. 扁平化结构已定稿并实施：分域注册（交易/查询/账户三域六件套）、Slot 路由能力
   字段已更名 `routeCapability`——**新 Capability 必须使用 `slot.getRouteCapability()`，
   禁止用旧的 `getCapability()`**；
2. `baseData.capability` 仅状态查询场景存在且语义=被查交易的原交易能力
   （10 号 §语义约定），账户维护 DTO 不涉及；
3. 银行协议字段 key 必须对照中信专项文档定义，禁止猜测；
4. 钱包日志规则：发送前后由最终 Sender 记录完整明文业务 JSON（用户裁决不脱敏）；
   `appKey`、私钥、签名/认证 Header、`Authorization`、`Cookie` 等非业务凭证仍禁止输出。
5. `chainFrontAccountUnwhiteName` 的处理是本任务当前唯一明确静态分歧：删除或新增 API 接入会改变
   交付形态，必须先由用户裁决，不能由接手 AI 静默选择。
