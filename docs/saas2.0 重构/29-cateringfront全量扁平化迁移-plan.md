# Catering Front 三域注册收口 Implementation Plan

> 状态：approved / pending-implementation
>
> 当前基线：`limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2` 已完成第一阶段扁平化；30 号报告记录的是
> `frontBankExecute + 单一 BankCapabilityRegistry` 的分域改造前状态。本计划只实施最终三域注册，
> 不重新迁移 22 个 Capability，不恢复已删除旧结构。

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
- 钱包业务发送只调用 `BankWalletGateway.post`；最终 Sender 直接 HTTP，不增加 Client/Invoker/Facade。
- Sender 唯一记录完整明文钱包请求/响应 JSON，不脱敏；Capability/Gateway 不重复记录相同报文。
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

- [ ] 新增 `FrontAccountSlot extends FrontBaseSlot`，只承载账户状态/余额请求和结果。
- [ ] `FrontQuerySlot` 删除账户状态/余额结果字段，只保留三类查询结果。
- [ ] 建立 `FrontAccountApplicationService`，承接现有账户状态/余额 API 的内部调用；Controller 对外签名不变。
- [ ] Transaction/Query/Account Application Service 分别创建并执行自己的 Slot；一次请求全程只有一个 Slot。
- [ ] `FrontFlowExecutor` 保持统一 LiteFlow 执行和响应兜底，不增加银行判断。

### Task 2：三个强类型 Capability 接口

- [ ] `BankTransCapability.execute(FrontTransSlot)`。
- [ ] `BankQueryCapability.execute(FrontQuerySlot)`。
- [ ] `BankAccountCapability.execute(FrontAccountSlot)`。
- [ ] 三个接口均只含 `bank()`、`capability()`、`execute(强类型Slot)`。
- [ ] 12 个交易 Capability 只实现 `BankTransCapability`。
- [ ] 6 个查询 Capability 只实现 `BankQueryCapability`。
- [ ] 4 个账户 Capability 只实现 `BankAccountCapability`，其中平安两个继续是 `ADAPTER_NOT_READY` 挡板。
- [ ] Capability 内不存在 `FrontBaseSlot + instanceof` 样板或跨域接口实现。

### Task 3：三个 Registry

- [ ] 新建 `BankTransCapabilityRegistry`，构造器只注入 `List<BankTransCapability>`。
- [ ] 新建 `BankQueryCapabilityRegistry`，构造器只注入 `List<BankQueryCapability>`。
- [ ] 新建 `BankAccountCapabilityRegistry`，构造器只注入 `List<BankAccountCapability>`。
- [ ] 各自建立不可变 `Map<BankCode, Map<FrontCapability, 本域Capability>>`。
- [ ] 同域重复 `(BankCode, FrontCapability)` 启动失败，不静默覆盖。
- [ ] Registry 内不按具体银行写 `if/switch`，不按 capability 名称猜领域。
- [ ] 删除单一 `BankCapabilityRegistry` 和统一 `BankCapability`，不保留兼容转发层。

### Task 4：三个 ExecuteNode

- [ ] 建立 `FrontTransExecuteNode`，组件 id 为 `frontTransExecute`。
- [ ] 建立 `FrontQueryExecuteNode`，组件 id 为 `frontQueryExecute`。
- [ ] 建立 `FrontAccountExecuteNode`，组件 id 为 `frontAccountExecute`。
- [ ] 节点使用无参 `getFirstContextBean()`，入口明确检查所属 Slot 类型；禁止写
  `getFirstContextBean(SomeSlot.class)`。
- [ ] 节点直接调用具体 `TenantBankConfigLoader` 的两个公共方法，不恢复 Provider/Assembler 链。
- [ ] 节点依次完成：公共校验 → tenant base 回填/核对 → 解析 BankCode → 加载 accountConfig →
  Registry get → Capability execute。
- [ ] 节点捕获 `FrontException`，写 Slot 并结束链；系统异常继续抛出。
- [ ] 删除 `FrontBankExecuteNode`，不保留第四个统一执行节点。

### Task 5：链切换与结果归属

- [ ] 13 个 chain id 精确保留。
- [ ] 8 条交易链只引用 `frontTransExecute`。
- [ ] 3 条查询链只引用 `frontQueryExecute`。
- [ ] 2 条账户链只引用 `frontAccountExecute`。
- [ ] 每条链只有一个组件引用，不增加公共前置/后置节点。
- [ ] 账户状态、余额结果从 `FrontAccountSlot` 返回；查询分页及状态结果仍从 `FrontQuerySlot` 返回。

### Task 6：日志与异常

- [ ] API/Application Service 保留入口、完成、异常收口日志。
- [ ] ExecuteNode 记录配置加载和域路由结果/失败，不记录完整钱包报文。
- [ ] Capability 记录业务开始、关键步骤、结果与业务异常，不重复钱包报文。
- [ ] 最终 Sender 记录一次完整明文请求 JSON，以及一次完整明文响应 JSON 或通信失败。
- [ ] Sender 异常日志保留异常堆栈、发送阶段和耗时。
- [ ] `appKey`、私钥、签名原文、签名头、Authorization、Cookie 不进入日志。

### Task 7：清理

- [ ] 删除统一 `BankCapability`、`BankCapabilityRegistry`、`FrontBankExecuteNode`。
- [ ] 不存在旧 Context、Handle、Router、Dispatch、Provider、AssemblerRouter、Assembler。
- [ ] 不创建业务父类、BankSupport、统一跨域 Registry 或能力级 Slot。
- [ ] 中信不明来款、domain/mapper/service/DDL 不因三域改造发生业务修改。

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

- [ ] api-front diff 为空。
- [ ] Slot 继承深度为两层：Base + Trans/Query/Account 三个直接子类。
- [ ] 强类型 Capability 接口、Registry、ExecuteNode 各精确为 3。
- [ ] Capability 精确为 22：交易 12、查询 6、账户 4。
- [ ] 13 条单节点链：交易 8、查询 3、账户 2。
- [ ] 账户状态/余额只存在于 Account Slot/Registry，不注册 Query Registry。
- [ ] 旧统一 Capability/Registry/ExecuteNode 和旧多层结构零残留。
- [ ] `HttpRequest.post` 只存在于中信、平安最终 Sender。
- [ ] 完整明文钱包请求/响应只在最终 Sender 各出现一次。
- [ ] 调用凭证、密钥、签名材料和 HTTP 鉴权头不进入日志。
- [ ] 未新增/运行测试、未执行编译；未把旧版本编译结果作为三域版本证据。

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
