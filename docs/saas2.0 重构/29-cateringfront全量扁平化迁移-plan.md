# Catering Front 全量扁平化迁移 Implementation Plan

> **For agentic workers:** 按任务顺序执行并逐项 review；不得从 2026-08-25 已放弃的未提交代码续写。

**Goal:** 在 API、数据表和业务行为不变的前提下，将中信、平安全部通用能力迁移到两层 Slot、三节点薄链和按能力分包的扁平结构。

**Spec:** [28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)

## 1. 全局约束

- 从 `limeng_front` 当前已提交 HEAD 的隔离 worktree 开始，不清理原脏工作区。
- `catering-api-front`、domain、mapper、VO、XML Mapper、DDL、上游组装契约不改。
- 中信 11 个、平安 11 个通用能力全部迁移；平安账户状态/余额保留挡板。
- 平安 `platformPay/platformReceive` 继续不支持，不创建虚假 Capability。
- 13 条 LiteFlow 链统一为 `THEN(frontValidate, tenantResolve, bankRoute)`。
- Slot 只有 `FrontBaseSlot ← FrontTransSlot/FrontQuerySlot` 两层。
- `flow` 只分 `slot/node/route`；禁止业务 Context、Router、Dispatch、Handle 继承、BankSupport。
- 银行按能力分包，真复用放银行 `common`；能力内允许组装代码重复。
- Capability 主方法顺序固定：校验 → 组报文 → 查重/INIT → SENDING → Gateway 发送 → 响应落库/结果。
- 纯查询能力没有渠道流水步骤，不为统一模板制造空持久化。
- 钱包业务发送只直接调用 `BankWalletGateway.post`。
- 未经用户明确授权，不新增/运行测试、不执行编译；代码 commit/push 同样另行确认。

## 2. 目标文件结构

```text
com.chinaums.front
├─ controller/
├─ service/
├─ flow/
│  ├─ slot/       FrontBaseSlot / FrontTransSlot / FrontQuerySlot
│  ├─ node/       FrontValidateNode / TenantResolveNode
│  └─ route/      BankCapability / BankCapabilityRegistry / BankRouteNode
├─ channel/
│  ├─ gateway/    BankWalletGateway 统一发送
│  ├─ citic/
│  │  ├─ common/
│  │  ├─ transfer/ consume/ withdraw/ refund/ platformpay/ platformreceive/
│  │  ├─ accountstatus/ accountbalance/ transstatus/ transdetail/ platformdetail/
│  │  └─ unidentified/
│  └─ pingan/
│     ├─ common/
│     ├─ transfer/ consume/ withdraw/ refund/ transferauth/ resendauthcode/
│     └─ accountstatus/ accountbalance/ transstatus/ transdetail/ platformdetail/
├─ config/
├─ domain/
└─ mapper/
```

能力包内不得再拆 `client/protocol/request/service/support/assembler/mapper`。

## 3. 执行任务

### Task 1：P0 基线快照

- [ ] 使用 `superpowers:using-git-worktrees` 从已提交 HEAD 建立隔离 worktree。
- [ ] 完整阅读 WIKI、28、05、02、03、06、07、08、09、10、19。
- [ ] 用 CodeGraph 加 `git show HEAD:<path>` 记录 13 个 API 的当前调用链、字段、固定值、响应和日志行为。
- [ ] 建立 22 项能力迁移矩阵；每项记录来源 Handle 方法、请求 DTO、Mapper/渠道表、Gateway 路径和结果类型。
- [ ] 确认禁改区 diff 初始为空。

### Task 2：公共框架一次建立

- [ ] 移动 Application Service 与 FlowExecutor 到 `service`，Controller 只更新 import。
- [ ] 新建严格两层 Slot；一次请求全程只传一个 Slot。
- [ ] 新建 `FrontValidateNode`、`TenantResolveNode`、`BankRouteNode`。
- [ ] 新建最小 `BankCapability`：只含 `bank()`、`capability()`、`execute(FrontBaseSlot)`。
- [ ] Registry 使用 `EnumMap<BankCode, Map<FrontCapability, BankCapability>>`，重复键启动失败。
- [ ] LiteFlow 节点用无参 `getFirstContextBean()` 取 Slot并明确校验类型。
- [ ] 13 条链全部切换为三节点薄链。

### Task 3：中信交易能力（6 项）

- [ ] `citic/transfer`：`bizFunc=27`，固定 transfer Mapper 与三阶段流水。
- [ ] `citic/consume`：`bizFunc=27`，固定 consume Mapper 与三阶段流水。
- [ ] `citic/withdraw`：`bizFunc=26`，固定 withdraw Mapper 与银行卡协议字段。
- [ ] `citic/refund`：真实 `/refund + bizFunc=23`，使用原业务主/子流水，不查本地原交易表。
- [ ] `citic/platformpay`：`bizFunc=2041`，固定 platform_pay Mapper。
- [ ] `citic/platformreceive`：`bizFunc=2042`，固定 platform_receive Mapper。
- [ ] 每个 Capability 自包含组装、持久化、发送和结果；禁止提取 CiticBankSupport。

### Task 4：中信查询能力（5 项）

- [ ] `citic/accountstatus`、`accountbalance`：账户配置与动态账户字段边界保持。
- [ ] `citic/transstatus`：按交易类型选择业务定位字段，保持查询结果映射。
- [ ] `citic/transdetail`：账户/登记簿明细原协议、分页和日期规则不变。
- [ ] `citic/platformdetail`：平台明细原协议、分页和日期规则不变。
- [ ] 查询 Capability 不创建渠道流水，不复制交易持久化模板。

### Task 5：平安交易能力（6 项）

- [ ] `pingan/transfer`、`consume`：保留功能码、reserve、加密和各自固定 Mapper。
- [ ] `pingan/withdraw`：保留提现请求、银行卡字段和三阶段流水。
- [ ] `pingan/refund`：保留原渠道两表回查、原 frontSsn/日期/账户来源和 refund Mapper。
- [ ] `pingan/transferauth`、`resendauthcode`：保留授权语义键、验证码流程和 transfer 表 capability 区分。
- [ ] 每个 Capability 自包含；禁止提取 PingAnBankSupport。

### Task 6：平安查询能力（5 项）

- [ ] `pingan/accountstatus`、`accountbalance`：迁移为明确 `ADAPTER_NOT_READY` 挡板，不伪造银行调用。
- [ ] `pingan/transstatus`：保留提现 cardNo 回查和状态归一化。
- [ ] `pingan/transdetail`：保留 6073、queryId 回查和订单补全规则。
- [ ] `pingan/platformdetail`：保留 6048/6050 分流、分页和字段映射。

### Task 7：银行 common 与统一 Gateway

- [ ] 中信/平安各自的序列号、SM2、签名、响应判断、配置属性移入银行 `common`。
- [ ] 只有至少两个已迁移能力真实复用的组件进入 `common`。
- [ ] Capability 只直接调用 `BankWalletGateway.post`，不得再包 Support/Invoker/Facade。
- [ ] Gateway 内部连接、银行 Sender 和 HTTP 细节可保留为基础设施，但业务代码看不到第二发送入口。
- [ ] 中信不明来款保持独立 API/链路，只调整 package 与 common 引用，不接入通用 Registry。

### Task 8：删除旧结构

- [ ] 删除 `flow/context`、`context/BankRequestContext`、旧 `flow/component` 转发节点。
- [ ] 删除 `route` 下旧 Router/Registry/Key。
- [ ] 删除 `handle` 下 Abstract/Trans/Query/Definition/Dispatch 体系。
- [ ] 删除两家旧大 Handle 和被新能力完全替代的旧协议多级包。
- [ ] 保留 domain/mapper/service 数据层，不做无关重构。

### Task 9：全量静态验收

```bash
git diff -- catering-api/catering-api-front
rg "FrontFlowContext|BankRequestContext|AbstractBankHandle|BankTransHandle|BankQueryHandle" \
  catering-modules/catering-front/src/main/java/com/chinaums/front
rg "class .*Router|class .*Dispatch|BankSupport" \
  catering-modules/catering-front/src/main/java/com/chinaums/front
rg "package (citic|pingan);" catering-modules/catering-front/src/main/java
rg "walletGateway\.post|bankWalletGateway\.post" \
  catering-modules/catering-front/src/main/java/com/chinaums/front/channel
```

- [ ] api-front diff 为空。
- [ ] 旧 Context/Handle/Router/Dispatch/BankSupport 零残留。
- [ ] 所有 package 位于 `com.chinaums.front`。
- [ ] 通用能力类精确为 22：中信 11 + 平安 11。
- [ ] LiteFlow 链精确为 13，均使用三节点。
- [ ] 交易能力固定 Mapper、查询能力无伪流水。
- [ ] 中信不明来款仍为独立 API/链路。

### Task 10：授权验证与交付

- [ ] 未获授权时明确记录“未新增测试、未运行测试、未执行编译”。
- [ ] 获得编译授权后才执行最终代码状态的 Maven 命令；测试需单独授权。
- [ ] 提交 22 项能力矩阵、13 条链、删除清单、行为差异和静态证据给用户 review。
- [ ] 未获用户确认前不 commit、不 push。

## 4. 完成口径

```text
API diff = 0
数据层/DDL行为变化 = 0
Slot 继承层级 = 2
Flow 公共节点 = 3
通用 Capability = 22
LiteFlow chain = 13
业务 Context / Handle 继承 / Router / Dispatch / BankSupport = 0
业务钱包发送出口 = 1
```
