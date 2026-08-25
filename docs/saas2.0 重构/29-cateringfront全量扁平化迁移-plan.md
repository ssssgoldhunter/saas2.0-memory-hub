# Catering Front 全量扁平化迁移 Implementation Plan

> **For agentic workers:** 按任务顺序执行并逐项 review；不得从 2026-08-25 已放弃的未提交代码续写。

**Goal:** 在 API、数据表和业务行为不变的前提下，将中信、平安全部通用能力迁移到两层 Slot、三节点薄链和按能力分包的扁平结构。

**Spec:** [28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)

## 1. 全局约束

- 从 `cateringsass/limeng_front@99e696f4e7ab78a1b307b5a2fd3c911698c143fb`
  建立隔离 worktree，不清理原工作区。
- `catering-api-front`、domain、mapper、VO、XML Mapper、DDL、上游组装契约不改。
- 中信 11 个、平安 11 个通用能力全部迁移；平安账户状态/余额保留挡板。
- 平安 `platformPay/platformReceive` 继续不支持，不创建虚假 Capability。
- 13 条 LiteFlow 链统一为 `THEN(frontBankExecute)`（2026-08-25 用户裁决单节点：路由+配置+执行三合一）。
- Slot 只有 `FrontBaseSlot ← FrontTransSlot/FrontQuerySlot` 两层。
- `flow` 只分 `slot/node/route`；禁止业务 Context、Router、Dispatch、Handle 继承、BankSupport。
- 银行能力扩展机制只有 Registry + Route；Validate/TenantResolve 是固定薄前置节点，不建立父类、
  Resolver、Prepare 节点或 Context 转换体系。
- 银行按能力分包，真复用放银行 `common`；能力内允许组装代码重复。
- 框架必须支持“只增加银行、复用既有能力”：新增银行 Capability/Sender 后由现有列表注册自动进入 Route，
  不修改 Controller、Application Service、LiteFlow 链、Registry 或 BankRouteNode。
- Capability 主方法顺序固定：校验 → 组报文 → 查重/INIT → SENDING → Gateway 发送 → 响应落库/结果。
- 纯查询能力没有渠道流水步骤，不为统一模板制造空持久化。
- 钱包业务发送只直接调用 `BankWalletGateway.post`。
- Gateway 只允许再分派到一个按银行实现的 `BankWalletSender`，Sender 直接完成 HTTP 调用；
  禁止 `Gateway → Sender → Client → Support/Invoker` 继续加层。
- 日志采用用户确认的 B 方案：Capability 记录业务步骤；钱包完整请求/响应只由最终 Sender 各记录一次，
  删除 Capability 中重复报文日志，其他 payload 字段范围和明文/脱敏行为保持基线。
- 用户已明确本轮不新增/运行测试、不执行编译；代码完成后提供静态证据等待用户 review，commit/push 另行确认。

## 2. 目标文件结构

```text
com.chinaums.front
├─ controller/
├─ application/  保留现有 FrontFlowExecutor / FrontTransApplicationService / FrontQueryApplicationService
├─ flow/
│  ├─ slot/       FrontBaseSlot / FrontTransSlot / FrontQuerySlot
│  └─ route/      BankCapability / BankCapabilityRegistry / FrontBankExecuteNode（单节点三合一）
├─ channel/
│  ├─ gateway/    BankWalletGateway / RoutingBankWalletGateway / BankWalletSender / OpenBodySigSigner
│  ├─ citic/
│  │  ├─ common/  含直接 HTTP 的 CiticWalletHttpClient
│  │  ├─ transaction/（4） clearsettlement/（2） query/（3） account/（2）
│  │  └─ unidentified/
│  └─ pingan/
│     ├─ common/  含直接 HTTP 的 PingAnWalletHttpClient + Crypto/Sequence
│     ├─ transaction/（6） query/（3） account/（2，挡板）
├─ config/        TenantBankConfigLoader / TenantBankAccountConfig / TenantBaseInfo
├─ domain/
└─ mapper/
```

能力包内不得再拆 `client/protocol/request/service/support/assembler/mapper`。

## 3. 执行任务

### Task 1：P0 基线快照

- [ ] 使用原生 `git worktree add --detach <path> 99e696f4e7ab78a1b307b5a2fd3c911698c143fb`
  建立隔离 worktree，再从该提交创建本次迁移分支。
- [ ] 完整阅读 WIKI、28、05、02、03、06、07、08、09、10、19。
- [ ] 用 CodeGraph 加 `git show HEAD:<path>` 记录 13 个 API 的当前调用链、字段、固定值、响应和日志行为。
- [ ] 建立 22 项能力迁移矩阵；每项记录来源 Handle 方法、请求 DTO、Mapper/渠道表、Gateway 路径和结果类型。
- [ ] 确认禁改区 diff 初始为空。

### Task 2：公共框架一次建立

- [ ] 保留现有 `application` package，不移动 Application Service 与 FlowExecutor，Controller import 不变。
- [ ] 新建严格两层 Slot；一次请求全程只传一个 Slot。
- [ ] 新建 `FrontValidateNode`、`TenantResolveNode`、`BankRouteNode`。
- [ ] 配置调用链固定为
  `TenantResolveNode → TenantBankConfigLoader → RemoteConfigServiceClient`。
- [ ] Loader 使用一个具体类直接查询和构造 `TenantBankAccountConfig`；中信/平安特殊字段各用一个平铺私有
  组装方法，不再调用第二层 helper。
- [ ] Loader 公共方法只保留 `loadTenantBaseInfo(tenantId)` 与
  `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)`；不增加配置 Bundle/Result/Context。
- [ ] 删除 Provider 接口/实现、AssemblerRouter、Assembler 接口/抽象父类及两个银行 Assembler，
  同时删除旧 `bankHandleContextPrepare` 路径。
- [ ] 新建最小 `BankCapability`：只含 `bank()`、`capability()`、
  `void execute(FrontBaseSlot)`；具体能力第一段用 `instanceof` 取得 Trans/Query Slot，结果写回 Slot 明确字段。
- [ ] Registry 使用 `EnumMap<BankCode, Map<FrontCapability, BankCapability>>`，重复键启动失败。
- [ ] Registry/Route 内不存在按具体银行编写的 `if/switch`；新银行 Capability 只靠 `bank()`、
  `capability()` 自描述并通过构造器列表注册。
- [ ] LiteFlow 节点用无参 `getFirstContextBean()` 取 Slot并明确校验类型。
- [x] 13 条链全部切换为单节点薄链（frontBankExecute 三合一，FrontException 由该节点收口写 Slot 并结束链）。
- [ ] 保留当前 13 个 chain id，只替换每条链的节点表达式，不照抄 28 号示意名称改名。
- [ ] `BankRouteNode` 捕获 `FrontException`、写 Slot 并结束链；`FrontFlowExecutor` 承接结果为空及
  `frontRespCode` 为空的旧 Normalize 兜底，不新增 Dispatch/Normalize 节点。

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

- [ ] 中信/平安各自的序列号、SM2、响应判断、配置属性移入银行 `common`；跨银行共用的
  OPEN-BODY-SIG 放 Gateway 基础设施。
- [ ] 只有至少两个已迁移能力真实复用的组件进入 `common`。
- [ ] Capability 只直接调用 `BankWalletGateway.post`，不得再包 Support/Invoker/Facade。
- [ ] 保留现有两个 `*WalletHttpClient implements BankWalletSender` 作为最终 HTTP 实现，只移动到对应银行
  `common`，不新建 `CiticBankWalletSender/PingAnBankWalletSender`。
- [ ] Gateway 内不存在按具体银行编写的 `if/switch`；新银行 Sender 只靠 `bankCode()` 自描述并通过
  构造器列表注册。
- [ ] 把 `CiticOpenBodySigSigner` 中性化为 Gateway 的 `OpenBodySigSigner`，两个最终 Sender 复用，
  平安不再引用中信 package。
- [ ] 删除依赖 `BankRequestContext` 的共享 `QueryTransStatusRequest`；两家 transstatus Capability 各自组装。
- [ ] 中信不明来款保持独立 API/package/链路，不接入通用 Registry；其 Application Service 仅把
  `TenantBankConfigProvider` 依赖替换为同一个 `TenantBankConfigLoader`，其余只允许共享组件移动导致的
  import 调整，不改专项校验、Channel 和银行业务。

### Task 8：删除旧结构

- [ ] 删除 `flow/context`、`context/BankRequestContext`、旧 `flow/component` 转发节点。
- [ ] 删除 `route` 下旧 Router/Registry/Key。
- [ ] 删除 `handle` 下 Abstract/Trans/Query/Definition/Dispatch 体系。
- [ ] 删除两家旧大 Handle 和被新能力完全替代的旧协议多级包。
- [ ] 保留 domain/mapper/service 数据层，不做无关重构。

### Task 9：全量静态验收

```bash
git diff --exit-code 99e696f4e7ab78a1b307b5a2fd3c911698c143fb -- catering-api/catering-api-front
rg "FrontFlowContext|BankRequestContext|AbstractBankHandle|BankTransHandle|BankQueryHandle" \
  catering-modules/catering-front/src/main/java/com/chinaums/front
rg "class .*Router|class .*Dispatch|BankSupport" \
  catering-modules/catering-front/src/main/java/com/chinaums/front
rg "TenantBankConfigProvider|BankAccountConfigAssembler" \
  catering-modules/catering-front/src/main/java/com/chinaums/front
rg "package (citic|pingan);" catering-modules/catering-front/src/main/java
rg "HttpRequest\.post" catering-modules/catering-front/src/main/java/com/chinaums/front/channel
rg "wallet_request_sending|wallet_response_received|发送钱包请求|银行响应" \
  catering-modules/catering-front/src/main/java/com/chinaums/front/channel
```

- [ ] api-front diff 为空。
- [ ] 旧 Context/Handle/Router/Dispatch/BankSupport 零残留。
- [ ] Provider/AssemblerRouter/Assembler 配置链零残留。
- [ ] 所有 package 位于 `com.chinaums.front`。
- [ ] 通用能力类精确为 22：中信 11 + 平安 11。
- [ ] LiteFlow 链精确为 13，均使用三节点。
- [ ] 交易能力固定 Mapper、查询能力无伪流水。
- [ ] 中信不明来款仍为独立 API/链路，且已使用 `TenantBankConfigLoader`，不存在已删除 Provider 的残留依赖。
- [ ] `HttpRequest.post` 只存在于中信、平安两个最终 Sender；业务代码只依赖 `BankWalletGateway.post`。
- [ ] Capability 无完整钱包请求/响应日志；每次银行调用只在最终 Sender 出现一次 request 和一次 response；
  其余日志 payload 字段范围和明文/脱敏行为保持基线。
- [ ] Capability 有开始、关键步骤、完成和业务异常日志；最终 Sender 有发送前、响应后和通信异常日志，
  异常日志保留堆栈。
- [ ] API、TenantBankConfigLoader、Registry/Route 分别保留入口收口、配置加载和路由结果/异常日志；
  各层记录自己的事件，但不重复打印 Sender 的钱包请求/响应报文。
- [ ] 通过静态结构确认：未来新银行复用既有能力只需扩展 BankCode、Loader 平级分支、新银行 Sender 和
  已支持 Capability，不需要改 API 入口、LiteFlow、Registry 或 Route；本次不创建示例银行代码。

### Task 10：授权验证与交付

- [ ] 明确记录“用户裁决本轮未新增测试、未运行测试、未执行编译，结果仅经过静态 review”。
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
钱包请求/响应日志位置 = 最终 Sender 唯一一处
Provider/AssemblerRouter/Assembler 链 = 0
新增银行对 API 方法/路径/DTO/返回签名及 LiteFlow/Registry/Route 的结构性修改 = 0
```
