# FRONT-ACC-001 账户维护能力开发（进行中）

- 状态：IN_PROGRESS（2026-08-26 开发 AI 开发中，工作区半成品）
- 优先级：新功能（非缺陷；不在扁平化重构范围内，api-front 允许增量 diff）

## 功能范围（已见代码）

中信账户域新增 9 个 Capability + FrontAccountApplicationService 账户维护 7 方法
（开户/绑卡/解绑/关户/更新信息/白名单/提现），api-front 已扩展
`AccountBusinessData` 等 DTO 与 `ACCOUNT_OPEN/ACCOUNT_BIND_CARD/...` 枚举。

## 当前阻断（编译不过）

channel/citic/account/ 下 6 个 Capability 引用的 common-core 常量类缺失：

```text
CiticAcctOpenContractKeys        （开户）
CiticBindCardContractKeys        （绑卡/解绑）
CiticAccountInfoContractKeys     （信息更新/关户/白名单）
```

前置动作：补齐 3 个常量类 → `mvn install -pl catering-common/catering-common-core`
→ front 恢复编译。

## 交接注意事项

1. 扁平化结构已定稿并实施：分域注册（交易/查询/账户三域六件套）、Slot 路由能力
   字段已更名 `routeCapability`——**新 Capability 必须使用 `slot.getRouteCapability()`，
   禁止用旧的 `getCapability()`**；
2. `baseData.capability` 仅状态查询场景存在且语义=被查交易的原交易能力
   （10 号 §语义约定），账户维护 DTO 不涉及；
3. 银行协议字段 key 必须对照中信专项文档定义，禁止猜测；
4. 钱包日志规则：发送前后由最终 Sender 记录完整明文 JSON（用户裁决不脱敏）。
