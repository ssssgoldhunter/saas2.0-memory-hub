# Catering Front 三域注册收口 Implementation Plan

> 状态：implemented（2026-08-25 实施完成，独立静态验收通过；人工测试由用户承接，见文末实施记录）
>
> 当前基线：`limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2` 已完成第一阶段扁平化；30 号报告记录的是
> `frontBankExecute + 单一 BankCapabilityRegistry` 的分域改造前状态。本计划必须将全部 22 个
> Capability 迁移到所属域的强类型接口、Slot 参数和 Registry；不得跳过任何能力。迁移只调整框架归属，
> 不重写已经完成的银行业务逻辑，也不恢复已删除旧结构。

**Goal:** API、银行业务和扁平 Capability 不变，将单一执行入口收口为交易、查询、账户三个强类型执行域。

**Spec:** [28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)

## 1. 最终目标

```text
transaction：FrontTransApplicationService
            → THEN(frontTransExecute)
            → FrontTransExecuteNode
            → BankTransCapabilityRegistry
            → BankTransCapability.execute(FrontTransSlot)

query：      FrontQueryApplicationService
            → THEN(frontQueryExecute)
            → FrontQueryExecuteNode
            → BankQueryCapabilityRegistry
            → BankQueryCapability.execute(FrontQuerySlot)

account：    FrontAccountApplicationService
            → THEN(frontAccountExecute)
            → FrontAccountExecuteNode
            → BankAccountCapabilityRegistry
            → BankAccountCapability.execute(FrontAccountSlot)
```

三个域最终都直接进入同一个钱包出口：

```text
Capability → BankWalletGateway.post → BankWalletSender → HTTP
```

## 2. 强制约束

- `catering-api-front`、Controller 对外方法、Feign、请求/返回 DTO、调用方组装方式不变。
- domain、VO、Mapper、Mapper XML、数据 Service、DDL、分片规则和银行业务行为不变。
- 当前执行域精确为三个：transaction、query、account。
- 当前 Slot 精确为 `FrontBaseSlot` 及直接继承它的 `FrontTransSlot/FrontQuerySlot/FrontAccountSlot`；
  继承深度仍为两层。
- 账户状态、账户余额归 Account 域；交易状态、平台明细、登记簿明细归 Query 域。
- 三个域各自拥有强类型 Capability 接口、Registry、ExecuteNode、链组、Slot、Application Service。
- 不存在统一 `BankCapability`、统一 `BankCapabilityRegistry` 或 `FrontBankExecuteNode`。
- 不存在 `FrontValidateNode`、`TenantResolveNode`、`BankRouteNode`、Prepare、Dispatch、Normalize。
- ExecuteNode 内按顺序完成公共校验、租户配置加载、本域 Registry 路由、本域 Capability 执行和
  `FrontException` 收口；不得拆成更多 LiteFlow 节点。
- 三个 ExecuteNode 允许保留少量同构代码；禁止抽取 `AbstractExecuteNode`、Resolver、Support 或模板父类。
- Capability 内继续扁平展示校验、组报文、流水、发送和结果，不增加多层 helper。
- 钱包业务发送只调用 `BankWalletGateway.post`；Gateway 按银行路由到一个直接 HTTP 的最终 Sender。
  现有实现类名可以保留，但不得在最终 Sender 后增加 Client/Invoker/Facade 等包装层。
- 最终 Sender 在发送前记录一次 `wallet_request_sending`，响应后记录一次 `wallet_response_received`，
  失败时记录一次 `wallet_request_failed`；请求/响应 JSON 完整明文展示，Capability/Gateway 不重复记录。
- 明文规则只适用于钱包报文 body；`appKey`、私钥、签名原文、签名头、Authorization、Cookie 和其他
  非报文调用凭证不得进入日志。
- 中信不明来款保持独立 API/Channel，不注册三域 Capability；只复用既有 Loader/Gateway/common。
- 本轮不新增/运行测试、不执行编译；只做静态核验。旧 `frontBankExecute` 版本的编译记录不能证明
  三域最终版本已编译。
- 未获用户确认前不提交代码仓、不推送；记忆体文档提交不等于授权代码提交。

## 3. 13 条 LiteFlow 链归属

### 3.1 Transaction：8 条

以下 chain id 保持不变，表达式统一为 `THEN(frontTransExecute)`：

1. `chainFrontTransfer`
2. `chainFrontTransferAuth`
3. `chainFrontTransferAuthCodeResend`
4. `chainFrontConsume`
5. `chainFrontRefund`
6. `chainFrontWithdraw`
7. `chainFrontPlatformPay`
8. `chainFrontPlatformReceive`

### 3.2 Query：3 条

以下 chain id 保持不变，表达式统一为 `THEN(frontQueryExecute)`：

1. `chainFrontQueryTransStatus`
2. `chainFrontQueryPlatformTransDetails`
3. `chainFrontQueryTransDetails`

### 3.3 Account：2 条

以下 chain id 保持不变，表达式统一为 `THEN(frontAccountExecute)`：

1. `chainFrontQueryAccountStatus`
2. `chainFrontQueryAccountBalance`

## 4. 三域接口与注册

### Task 1：Slot 与 Application Service

- [x] 新增 `FrontAccountSlot extends FrontBaseSlot`，只承载账户状态/余额请求和结果。
- [x] `FrontQuerySlot` 删除账户状态/余额结果字段，只保留三类查询结果。
- [x] 建立 `FrontAccountApplicationService`，承接现有账户状态/余额 API 的内部调用；Controller 对外签名不变。
- [x] Transaction/Query/Account Application Service 分别创建并执行自己的 Slot；一次请求全程只有一个 Slot。
- [x] `FrontFlowExecutor` 保持统一 LiteFlow 执行，不增加银行判断；内部允许返回 `null`。
- [x] 三个 Application Service 调用后都先检查 Slot、再检查结果：Slot 未失败但结果为 `null` 时，
  单条接口返回带 `INTERNAL_ERROR` 的失败响应，分页接口返回非空失败页；禁止 `R.ok(null)` 或对外返回 `null`。

### Task 2：三个强类型 Capability 接口

- [x] `BankTransCapability.execute(FrontTransSlot)`。
- [x] `BankQueryCapability.execute(FrontQuerySlot)`。
- [x] `BankAccountCapability.execute(FrontAccountSlot)`。
- [x] 三个接口均只含 `bank()`、`capability()`、`execute(强类型Slot)`。
- [x] 12 个交易 Capability 只实现 `BankTransCapability`。
- [x] 6 个查询 Capability 只实现 `BankQueryCapability`。
- [x] 4 个账户 Capability 只实现 `BankAccountCapability`，其中平安两个继续是 `ADAPTER_NOT_READY` 挡板。
- [x] Capability 内不存在 `FrontBaseSlot + instanceof` 样板或跨域接口实现。

### Task 3：三个 Registry

- [x] 新建 `BankTransCapabilityRegistry`，构造器只注入 `List<BankTransCapability>`。
- [x] 新建 `BankQueryCapabilityRegistry`，构造器只注入 `List<BankQueryCapability>`。
- [x] 新建 `BankAccountCapabilityRegistry`，构造器只注入 `List<BankAccountCapability>`。
- [x] 各自建立不可变 `Map<BankCode, Map<FrontCapability, 本域Capability>>`。
- [x] 同域重复 `(BankCode, FrontCapability)` 启动失败，不静默覆盖。
- [x] Registry 内不按具体银行写 `if/switch`，不按 capability 名称猜领域。
- [x] 删除单一 `BankCapabilityRegistry` 和统一 `BankCapability`，不保留兼容转发层。

### Task 4：三个 ExecuteNode

- [x] 建立 `FrontTransExecuteNode`，组件 id 为 `frontTransExecute`。
- [x] 建立 `FrontQueryExecuteNode`，组件 id 为 `frontQueryExecute`。
- [x] 建立 `FrontAccountExecuteNode`，组件 id 为 `frontAccountExecute`。
- [x] 节点使用无参 `getFirstContextBean()`，入口明确检查所属 Slot 类型；禁止写
  `getFirstContextBean(SomeSlot.class)`。
- [x] 节点直接调用具体 `TenantBankConfigLoader` 的两个公共方法，不恢复 Provider/Assembler 链。
- [x] 节点依次完成：公共校验 → tenant base 回填/核对 → 解析 BankCode → 加载 accountConfig →
  Registry get → Capability execute。
- [x] 节点捕获 `FrontException`，写 Slot 并结束链；系统异常继续抛出。
- [x] 删除 `FrontBankExecuteNode`，不保留第四个统一执行节点。

### Task 5：链切换与结果归属

- [x] 13 个 chain id 精确保留。
- [x] 8 条交易链只引用 `frontTransExecute`。
- [x] 3 条查询链只引用 `frontQueryExecute`。
- [x] 2 条账户链只引用 `frontAccountExecute`。
- [x] 每条链只有一个组件引用，不增加公共前置/后置节点。
- [x] 账户状态、余额结果从 `FrontAccountSlot` 返回；查询分页及状态结果仍从 `FrontQuerySlot` 返回。

### Task 6：日志与异常

- [x] API/Application Service 保留入口、完成、异常收口日志。
- [x] ExecuteNode 记录配置加载和域路由结果/失败，不记录完整钱包报文。
- [x] Capability 记录业务开始、关键步骤、结果与业务异常，不重复钱包报文。
- [x] 最终 Sender 发送前记录一次 `wallet_request_sending`，包含 bank、apiName、frontSsn 和完整明文请求 JSON。
- [x] 响应后记录一次 `wallet_response_received`，包含同一组定位字段、完整明文响应 JSON、HTTP 状态和耗时。
- [x] 通信失败记录一次 `wallet_request_failed`，包含同一组定位字段、失败阶段、是否已发送、耗时和异常堆栈。
- [x] `appKey`、私钥、签名原文、签名头、Authorization、Cookie 不进入日志。

### Task 7：清理

- [x] 删除统一 `BankCapability`、`BankCapabilityRegistry`、`FrontBankExecuteNode`。
- [x] 不存在旧 Context、Handle、Router、Dispatch、Provider、AssemblerRouter、Assembler。
- [x] 不创建业务父类、BankSupport、统一跨域 Registry 或能力级 Slot。
- [x] 中信不明来款、domain/mapper/service/DDL 不因三域改造发生业务修改。

## 5. 静态验收

```bash
git diff --exit-code 0dd983a72cc7def2d60f6f35aefcc1c1160864d2 -- catering-api/catering-api-front

rg "FrontFlowContext|BankRequestContext|AbstractBankHandle|BankTransHandle|BankQueryHandle" \
  catering-modules/catering-front/src/main/java/com/chinaums/front

rg "class .*Router|class .*Dispatch|BankSupport|TenantBankConfigProvider|BankAccountConfigAssembler" \
  catering-modules/catering-front/src/main/java/com/chinaums/front

rg "interface BankCapability|class BankCapabilityRegistry|class FrontBankExecuteNode" \
  catering-modules/catering-front/src/main/java/com/chinaums/front

rg "frontTransExecute|frontQueryExecute|frontAccountExecute" \
  catering-modules/catering-front/src/main/resources/liteflow/front-flow.xml

rg "HttpRequest\.post" catering-modules/catering-front/src/main/java/com/chinaums/front/channel

git diff --check
```

验收口径：

- [x] api-front diff 为空。
- [x] Slot 继承深度为两层：Base + Trans/Query/Account 三个直接子类。
- [x] 强类型 Capability 接口、Registry、ExecuteNode 各精确为 3。
- [x] Capability 精确为 22：交易 12、查询 6、账户 4。
- [x] 13 条单节点链：交易 8、查询 3、账户 2。
- [x] 账户状态/余额只存在于 Account Slot/Registry，不注册 Query Registry。
- [x] 旧统一 Capability/Registry/ExecuteNode 和旧多层结构零残留。
- [x] `HttpRequest.post` 只存在于中信、平安最终 Sender。
- [x] 完整明文钱包请求/响应只在最终 Sender 各出现一次。
- [x] 调用凭证、密钥、签名材料和 HTTP 鉴权头不进入日志。
- [x] `FrontFlowExecutor` 返回 `null` 时，三个 Application Service 均存在显式判断；单条和分页对外结果均非空。
- [x] 未新增/运行测试、未执行编译；未把旧版本编译结果作为三域版本证据。

### 5.1 交给 AI 的静态验收提示词

```text
只做静态验收，不修改任何代码或文档，不新增/运行测试，不执行编译，不 commit、不 push。

请以 limeng_front_restruct 当前工作区和 28/29 号文档为准，逐项核验并给出文件路径、行号、数量和命令输出：
1. catering-api-front 相对 0dd983a72cc7def2d60f6f35aefcc1c1160864d2 零 diff。
2. Slot 只有 FrontBaseSlot 及直接继承它的 FrontTransSlot/FrontQuerySlot/FrontAccountSlot 两层。
3. 强类型 Capability 接口、Registry、ExecuteNode 各精确为 3；不存在统一 BankCapability、
   BankCapabilityRegistry、FrontBankExecuteNode 或兼容转发层。
4. 22 个 Capability 全部归域且无遗漏：Transaction 12、Query 6、Account 4；账户状态/余额只使用 Account 域。
5. 13 条 LiteFlow 链保持原 chain id，每条只有一个节点：Transaction 8、Query 3、Account 2。
6. 不存在业务 Context、Router、Dispatch、Handle 继承、Provider/Assembler 链、BankSupport 或能力级 Slot。
7. Capability 主方法仍按校验、组装、流水、统一发送、响应和结果顺序展开；银行业务字段和支持状态无变化。
8. 钱包业务只从 BankWalletGateway.post 发送，最终 Sender 直接 HTTP；发送前、响应后、失败日志分别为
   wallet_request_sending、wallet_response_received、wallet_request_failed，报文 body 完整明文且无重复日志。
9. FrontFlowExecutor 返回 null 时，三个 Application Service 都显式转换为非空失败响应；不存在 R.ok(null)
   或对外返回 null，分页 null 转为非空 INTERNAL_ERROR 失败页。
10. 中信不明来款、domain、mapper、service、DDL、渠道表和银行业务逻辑未因三域改造发生越界修改。

报告按 P0/P1/P2 列出问题；没有问题也必须逐项给出证据，不得只写“符合”。最后明确说明未修改文件、
未运行测试、未执行编译、未 commit、未 push。
```

## 6. 交付内容

完成后向用户提交：

1. 三域接口、Registry、ExecuteNode、Slot、Application Service 文件清单；
2. 22 项 Capability 域归属矩阵；
3. 13 条 chain id 与最终单节点表达式；
4. 删除的统一 Registry/Execute 结构；
5. 日志位置与明文报文口径；
6. API、数据层、中信不明来款禁改区静态 diff；
7. 明确声明未新增/运行测试、未执行编译、是否 commit/push。

代码 commit/push 仍需用户另行授权。


## 实施记录（2026-08-25）

- 实施方式：执行 AI 按本清单完成，独立验收两轮；
- **第一轮验收发现 2 个致命缺陷并返工**：① 三个 ExecuteNode 第④步只写注释未实现
  （bankCode 无人赋值，13 条链运行时必挂）；② AppService 用请求字段伪造 TenantBaseInfo
  且未做三项缺省回填（破坏「只传 tenantId 由配置回填」契约）。返工后三项修复
  （FIX-1/2/3）复验全部通过；
- 静态验收证据：编译 0 错误（验收方执行）；instanceof 样板 0；BankRequestContext 零残留
  （类与 context/ 目录已删）；22 Capability（12 交易 + 6 查询 + 4 账户）全部强类型参数；
  13 条链 8/3/2 映射逐一核对；api-front 对 99e696f4 零 diff；Sender 三日志事件
  （wallet_request_sending/received/failed）双银行齐备；敏感信息（appKey/私钥/签名头/
  Authorization）零日志命中；HTTP 调用仅存在于两个最终 Sender；
- 三个 ApplicationService null 语义落实：Slot 失败→R.fail(带码)；结果为 null→
  R.fail("处理结果为空")/非空失败页，无 R.ok(null)；
- **运行时验证**：按用户指示未由 AI 执行，由用户人工测试承接（第一轮缺陷正是
  编译不可见的运行时缺陷，人工测试为必要闭环）；
- 代码位于 limeng_front_restruct 工作区（未提交），基线 0dd983a7。
