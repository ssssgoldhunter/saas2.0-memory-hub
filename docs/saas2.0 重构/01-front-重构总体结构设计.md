# SaaS 2.0 多银行渠道 Front 总体结构设计

> 状态：historical-design / superseded-by-28（结构以 28 号三域定稿为准，本文仅作历史设计记录）
> 更新日期：2026-08-26
> 代码起点：`cateringsass/limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2`
> 结构裁决：[28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)
> 实施计划：[29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)
> 银行能力落地：本文 §16（中信）、§17（平安）已并入原 02/03 接口能力汇总，飞书主文档自洽完整。

本文描述 28/29 号迁移时的目标结构和 22 个实现类 / 13 条链历史基线；当前账户维护增量后的
源码数量、状态和差异以 WIKI-START §4、§7.1 及 19 号手册为准。旧 `FrontFlowContext → BankRequestContext → Handle`、
Router/Dispatch、多节点 LiteFlow、单一 `BankCapabilityRegistry` 和
`Provider → AssemblerRouter → Assembler` 均已退出目标设计。

## 1. 建设目标

Front 面向内部业务系统提供统一的多银行交易、交易查询和账户能力：

1. API、Feign、请求/响应 DTO 和上游组装方式稳定不变。
2. LiteFlow 保留稳定 chain id，只承担执行域入口，不拆业务步骤。
3. Transaction、Query、Account 三个执行域独立注册和路由。
4. 每个“银行 × 能力”使用一个扁平 Capability，代码按真实业务顺序展开。
5. 租户配置加载保留清晰调用链，但不保留多层 Provider/Assembler 继承。
6. 钱包发送统一经 Gateway/Sender，业务报文日志只在最终 Sender 输出。
7. 新银行复用已有能力时，不修改 API、chain id、三个 Registry 或三个 ExecuteNode。

不在本次范围内：修改公共 API、改表/DDL、改变银行协议、增加虚假能力、抽象未来银行、把中信不明来款纳入通用能力框架。

## 2. 总体架构

```text
交易 API
→ FrontTransApplicationService
→ THEN(frontTransExecute)
→ FrontTransExecuteNode
→ BankTransCapabilityRegistry
→ BankTransCapability.execute(FrontTransSlot)

交易查询 API
→ FrontQueryApplicationService
→ THEN(frontQueryExecute)
→ FrontQueryExecuteNode
→ BankQueryCapabilityRegistry
→ BankQueryCapability.execute(FrontQuerySlot)

账户状态/余额 API
→ FrontAccountApplicationService
→ THEN(frontAccountExecute)
→ FrontAccountExecuteNode
→ BankAccountCapabilityRegistry
→ BankAccountCapability.execute(FrontAccountSlot)

三个域 Capability
→ BankWalletGateway.post
→ BankWalletSender
→ HTTP
```

分层职责：

| 层 | 职责 |
|---|---|
| API/Controller | 定义并透传外部契约，不包含银行判断 |
| Application Service | 固定当前 capability，创建本域 Slot，执行原 chain id，转换最终返回 |
| LiteFlow | 每条链只挂一个本域 ExecuteNode |
| ExecuteNode | 公共校验、租户配置加载、BankCode 解析、本域 Registry 路由、异常写 Slot |
| Registry | 按 `(BankCode, FrontCapability)` 返回本域强类型 Capability |
| Capability | 校验、组报文、流水处理、调用钱包、响应判断和结果映射 |
| Gateway/Sender | 统一发送入口、按银行选择 Sender、签名/HTTP/超时和最终报文日志 |
| Domain/Mapper/Service | 固定银行和能力的渠道流水持久化 |

## 3. 目标目录

```text
com.chinaums.front
├─ controller/
├─ application/
│  ├─ FrontFlowExecutor
│  ├─ FrontTransApplicationService
│  ├─ FrontQueryApplicationService
│  └─ FrontAccountApplicationService
├─ flow/
│  ├─ slot/
│  │  ├─ FrontBaseSlot
│  │  ├─ FrontTransSlot
│  │  ├─ FrontQuerySlot
│  │  └─ FrontAccountSlot
│  ├─ node/
│  │  ├─ FrontTransExecuteNode
│  │  ├─ FrontQueryExecuteNode
│  │  └─ FrontAccountExecuteNode
│  └─ route/
│     ├─ BankTransCapability / BankTransCapabilityRegistry
│     ├─ BankQueryCapability / BankQueryCapabilityRegistry
│     └─ BankAccountCapability / BankAccountCapabilityRegistry
├─ channel/
│  ├─ gateway/
│  │  ├─ BankWalletGateway
│  │  ├─ BankWalletSender
│  │  └─ OpenBodySigSigner
│  ├─ citic/
│  │  ├─ common/
│  │  ├─ transaction/
│  │  ├─ query/
│  │  ├─ account/
│  │  └─ unidentified/
│  └─ pingan/
│     ├─ common/
│     ├─ transaction/
│     ├─ query/
│     └─ account/
├─ config/
│  ├─ TenantBankConfigLoader
│  ├─ TenantBaseInfo
│  └─ TenantBankAccountConfig
├─ domain/
├─ mapper/
└─ service/
```

`flow` 只允许 `slot/node/route` 三类职责。银行目录只按
`transaction/query/account` 三域、`common` 和已确认专项分组；不得恢复多层
`client/service/support/assembler/handle` 结构。

## 4. Slot 与执行域

Slot 继承严格两层：

```text
FrontBaseSlot
├─ FrontTransSlot
├─ FrontQuerySlot
└─ FrontAccountSlot
```

- `FrontBaseSlot`：tenant base、account config、bankCode、统一失败信息等公共执行数据。
- `FrontTransSlot`：8 个交易入口的请求、capability 和 `FrontTransResult`。
- `FrontQuerySlot`：交易状态、平台明细、登记簿明细的请求和结果。
- `FrontAccountSlot`：账户状态、账户余额的请求和结果。

一次调用只创建一个域 Slot。禁止新增 `FrontFlowContext`、`BankRequestContext`、银行 Slot 或能力级 Slot。
ExecuteNode 使用 LiteFlow v2.16.X 无参 `getFirstContextBean()` 获取当前 Slot，再显式校验所属域类型。

## 5. 三域注册模型

三个接口均为强类型：

```java
interface BankTransCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontTransSlot slot);
}

interface BankQueryCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontQuerySlot slot);
}

interface BankAccountCapability {
    BankCode bank();
    FrontCapability capability();
    void execute(FrontAccountSlot slot);
}
```

每个 Registry 只注入本域接口列表，建立不可变
`Map<BankCode, Map<FrontCapability, 本域Capability>>`。同域重复复合键必须启动失败；银行不存在和能力未注册使用不同错误。

历史迁移基线的 22 个通用能力实现类归域：

| 域 | 数量 | 能力 |
|---|---:|---|
| Transaction | 12 | 两家 transfer、consume、refund、withdraw；平安 transferAuth/resend；中信 platformPay/platformReceive |
| Query | 6 | 两家交易状态、平台交易明细、登记簿交易明细 |
| Account | 4 | 两家账户状态、账户余额；平安现有两个挡板状态不变 |

不存在统一 `BankCapability`、统一 Registry、通用 ExecuteNode 或跨域支持矩阵。

### 5.1 历史 22 能力实现类 × 中信 / 平安落地映射

下表把 §5 的 22 个通用能力落到两家银行的 `bizFunc`、银行产品码与当前 Front 范围。中信
`platformCode=zxegj`（渠道号 `0010`），平安 `platformCode=pajzb`（渠道号 `0001`）。各能力的字段级
细节、报文结构与 `specialData` 边界见本文 §16（中信）、§17（平安）。

| 域 | FrontCapability | 中信（`zxegj`/`0010`） | 平安（`pajzb`/`0001`） |
|---|---|---|---|
| Transaction | `transfer` | `bizFunc=27` 支付 `21000050` 已实现 | `bizFunc=01` 会员间交易-不验证 `6034` 已实现 |
| Transaction | `consume` | `bizFunc=27` 支付 `21000050` 已实现（与 transfer 同接口，业务语义区分） | `bizFunc=01` `6034` 已实现 |
| Transaction | `refund` | `bizFunc=23` 退款 `21000051` 已实现（真退款） | `bizFunc=02` 会员间直接支付退款 已实现 |
| Transaction | `withdraw` | `bizFunc=26` 智能提现 `21000014` 已实现 | `bizFunc=01` `6033` / `36` 支持手续费 `6085` 已实现 |
| Transaction | `platformPay` | `bizFunc=2041` 平台付款 `21000047` 已实现 | **UNSUPPORTED**（无等价接口，不注册） |
| Transaction | `platformReceive` | `bizFunc=2042` 平台收款 `21000048` 已实现 | **UNSUPPORTED**（无等价接口，不注册） |
| Transaction | `transferAuth` | — 中信无此能力 | `bizFunc=45` 会员间交易-验证短信动态码 `6101` 已实现 |
| Transaction | `resendTransferAuthCode` | — 中信无此能力 | `bizFunc=26` 申请短信动态码 `6082` 已实现 |
| Query | `transactionStatus` | `bizFunc=74` 用户交易状态查询 `21000010` 已实现 | `bizFunc=02/03` 单笔状态 已实现 |
| Query | `platformTransactionDetails` | `bizFunc=25` 交易资金账户明细 `21000039` 已实现 | `bizFunc=04/05/08` 平台/会员/清分提现明细 已实现 |
| Query | `accountTransactionDetails` | `bizFunc=24` 登记簿交易明细 `21000029` 已实现 | `bizFunc=05/08/02` 子账户/清分/退票明细 已实现 |
| Account | `accountStatus` | `bizFunc=2058` 用户状态查询 `22000001` 已实现 | **ADAPTER_NOT_READY（F200003）固定挡板** |
| Account | `accountBalance` | `bizFunc=35/36/46`（交易资金/登记簿/用户余额）已实现 | **ADAPTER_NOT_READY（F200003）固定挡板** |

另：中信不明来款为独立专项，不计入 22 个通用能力，使用 `2033/2025/2023/2087` 专项接口（见 §16.7）。

## 6. LiteFlow 规则

13 个原 chain id 保持不变：

| 域 | 数量 | 节点 |
|---|---:|---|
| Transaction | 8 | `THEN(frontTransExecute)` |
| Query | 3 | `THEN(frontQueryExecute)` |
| Account | 2 | `THEN(frontAccountExecute)` |

LiteFlow v2.16.X 支持单节点 `THEN(node)`。公共校验、配置加载、路由和异常收口直接在所属域 ExecuteNode
顺序执行，不再拆成 Validate/Resolve/Route/Prepare/Dispatch/Normalize 节点。

## 7. 请求与响应边界

通用能力继续使用现有 `FrontRequest<T>`：

```text
FrontRequest
├─ baseData：跨银行公共强类型业务字段
└─ specialData：当前银行 + 当前能力的动态业务字段
```

- API 方法内部固定 capability，调用方不得传入或覆盖。
- `specialData` 按字段契约白名单逐键映射，禁止整体 `putAll`。
- `accountConfig/accountSpecialData` 只来自租户配置，不接受调用方输入。
- 单条能力返回 `R<具体结果>`；分页明细直接返回 `TableDataInfo<具体行>`。
- 银行原始响应码只用于 Capability 判定和渠道审计；对外使用统一 Front 错误码。
- 中信不明来款请求/返回为全字段强类型，不使用 `FrontRequest` 或 `specialData`。

字段细节以 06、07、08、10、25、27 号契约为准。

## 8. 租户配置

调用链固定为：

```text
域 ExecuteNode
→ TenantBankConfigLoader
→ RemoteConfigServiceClient
```

Loader 是具体类，只保留：

- `loadTenantBaseInfo(tenantId)`；
- `loadBankAccountConfig(tenantId, bankCode, tenantBaseInfo)`。

Loader 直接查询并扁平组装中信/平安配置。禁止恢复
`TenantBankConfigProvider → AssemblerRouter → Assembler`、抽象父类、Bundle/Context 或银行配置组装器继承链。

## 9. Capability 业务顺序

每个交易 Capability 的主流程必须能够从上到下读完：

1. 校验请求和当前能力字段。
2. 直接组装当前银行请求 DTO。
3. 在固定渠道表查重并写 `INIT`。
4. 更新 `SENDING`。
5. 调用 `BankWalletGateway.post`。
6. 判断银行结果并更新终态。
7. 组装 Front 结果写回 Slot。

查询和账户能力不产生交易流水，但仍需完整展示校验、组装、发送、判断、映射。允许不同能力保留少量重复；
禁止业务父类、BankSupport God class、多层 helper 或 `switch(capability)`。

## 10. 钱包发送与日志

`BankWalletGateway.post` 是业务代码唯一钱包出口；Gateway 后只允许最终 `BankWalletSender` 直接执行 HTTP。

日志采用 B 方案：

- API/Application Service：入口、完成和异常收口。
- ExecuteNode：配置加载与域路由结果，不记录钱包 body。
- Capability：业务开始、校验、流水状态、银行结果和业务异常，不重复钱包报文。
- Sender：唯一记录一次完整明文请求 JSON、一次完整明文响应 JSON 或通信失败，body 不做字段脱敏。

完整明文规则只适用于钱包报文 body。`appKey`、私钥、签名原文/材料、签名或认证 Header、
`Authorization`、`Cookie` 等非业务报文凭证禁止进入日志。

## 11. 渠道流水和分库

- 交易按“银行 + 交易能力”使用固定表，禁止统一动态表和动态表名。
- 重复检查固定使用当前表的 `tenantId + bizOrderNo + bizSubOrderNo`。
- 状态按 `INIT → SENDING → 最终状态` 更新；超时或结果不明进入 `UNKNOWN`，不得自动重发资金交易。
- 分库键是 `tenant_id`（进程内租户映射缓存路由，2026-08-29 起；`data_source_id` 仅作 insert
  列值记录实例）；`tenant_id` 缺失、映射缺失或目标数据源不存在时立即失败，不得兜底到 `ds_0`。
- 本结构增量不修改 10 张表、Entity、VO、Mapper、XML、DDL 或分片规则。

## 12. 中信不明来款专项

中信不明来款是独立特殊能力：

```text
CiticUnidentifiedRemittanceApi
→ Controller
→ CiticUnidentifiedRemittanceApplicationService
→ TenantBankConfigLoader
→ CiticUnidentifiedRemittanceChannel
→ BankWalletGateway
```

它不注册为通用 `FrontCapability`，不进入三域 Registry/LiteFlow，不使用 `specialData`；仅复用租户上下文、
Loader、Gateway 和中信 common 基础设施。协议以 27 号接入手册和专项文档为准。

## 13. 新银行接入

在不新增 Front 能力的情况下，新银行只增加：

1. `BankCode` 枚举值；
2. Loader 内一个平级配置组装分支；
3. 一个最终 BankWalletSender；
4. 该银行真实支持的三域 Capability 实现。

不修改 API、Controller、三个 Application Service、13 条 chain id、三个 Registry、三个 ExecuteNode 或其他银行代码。
只有新能力的数据和状态形态无法由现有三种 Slot 准确承载，并经用户明确批准后，才允许增加第四执行域。

## 14. 结构验收

- API/Controller/DTO 零结构变化。
- Slot 为 Base + Trans/Query/Account 两层。
- 强类型 Capability 接口、Registry、ExecuteNode 各 3 个。
- 22 个通用能力归域为 12/6/4。
- 13 条单节点链归域为 8/3/2。
- 账户状态/余额只注册 Account 域。
- 业务 Context、Router、Dispatch、Handle 父类、统一 Registry、Provider/Assembler 链为 0。
- 钱包发送出口只有 Gateway/Sender；完整明文 body 只在 Sender 出现一次。
- 中信不明来款仍为独立专项。
- 本轮按用户约束只做静态验收，不新增/运行测试、不执行编译。

## 15. 文档分工

- 05：强制代码约束。
- 19：框架与业务能力开发手册。
- 20：交易 API 对接。
- 21：交易查询和账户 API 对接。
- 27：中信不明来款专项接入。
- 28：最终结构裁决。
- 29：三域增量实施计划。
- 30：三域裁决前历史交付快照，不作为最终证据。
- 本文 §16（中信）、§17（平安）为原 02/03 银行接口能力汇总的并入版，是银行级能力落地依据；
  WIKI-START 为入口索引。三域架构以本文 §1–§14 为准，银行 `bizFunc`/字段/状态语义以 §16/§17 为准。

---

# 第二编 银行能力落地（中信 / 平安）

> 本编并入原《02-中信银行接口能力汇总》《03-平安银行接口能力汇总》，是 §5.1 落地映射的字段级依据。
> 源 Word 协议（中信 v4.7、平安 v5.5）仍为字段长度、条件必填、错误码全集、示例报文的最终基线。

## 16. 中信银行接口能力落地

> 银行编码：中信（`platformCode=zxegj`）；钱包渠道号：`0010`。
> 源文档：`中信E管家产品客户钱包应用平台_接口文档-内部集成平台v4.7.doc`
> 不明来账专项补充：`中信E管家产品V2_不明来账_客户钱包应用平台_接口文档-内部集成平台.doc`

### 16.1 当前 Front 适配结构

中信通用能力按三个执行域注册，不使用大 Handle：

| 域 | Capability | LiteFlow 入口 |
|---|---|---|
| Transaction | transfer、consume、refund、withdraw、platformPay、platformReceive | `frontTransExecute` |
| Query | transactionStatus、platformTransactionDetails、accountTransactionDetails | `frontQueryExecute` |
| Account | accountStatus、accountBalance | `frontAccountExecute` |

每个“中信 × 能力”是所属域强类型 Capability，通过本域 Registry 路由；配置由
`域 ExecuteNode → TenantBankConfigLoader → RemoteConfigServiceClient` 加载，钱包统一经
`BankWalletGateway.post → 中信 BankWalletSender` 发送。中信不明来款仍是独立专项，不进入三域 Registry/LiteFlow；请求和返回均为全字段强类型。

Sender 唯一记录完整明文钱包请求/响应 body，不做字段脱敏；其他层不得重复。`appKey`、私钥、签名材料、
认证 Header 等非业务报文凭证禁止进入日志。

### 16.2 接入协议摘要

- 通讯协议：HTTP/HTTPS RESTful；消息体 JSON，由 `msgHead` 和 `msgBody` 组成。
- 业务路径：`/cwap/account/send/{业务后缀}`；中信钱包渠道号 `0010`。
- 大多数联机交易 `transSsn` 长度 40 位，规则：`商户编号 + yyyyMMddHHmmssSSS + 8位序列`；平台商户必须保证流水号不重复，中信当日对发起方流水号做重复校验。
- 请求头：`Content-Type`、`X-Authorization`（签名类型和签名值）、`X-Version`、`X-Tx-ID`、`X-Span-ID`、`X-PSpan-ID`。
- 签名加密：普通签名 = 报文体拼接内部集成平台 Secret 后 SM3；`SIGN-TYPE` 支持 SM3、SM2WithSM3；姓名/卡号/手机号/证件号/短信验证码等用 SM2（`sm2p256v1`）。版本历史已移除 `SIGN_INFO`，新 Front 不依赖该字段。
- 金额：交易请求 `transAmt` 通常“分”；明细查询部分返回金额字段文档标注“元”，Front 必须在转换器中统一单位，不得透出原始字符串。请求时间 `yyyyMMddHHmmss`；银行返回 `yyyyMMdd`/`HHmmss` 分开。

### 16.3 公共请求与响应字段

公共请求字段：`transSsn`/`transTime`（Front 生成）、`mchntId`/`mchntMbrId`（租户银行配置）、`bizFunc`（Capability 确定）、`chnlNo`（固定 `0010`）、`acctNo`/`outAcctNo`/`inAcctNo`（业务核心，加密）、`transAmt`、`remark`、`reserve`（Capability 显式映射）。`bizFunc`/`chnlNo`/商户配置/密钥不得由业务系统经 `specialData` 覆盖。

公共响应字段：`errCode`/`errInfo`（只用于平台层成功判定并保存渠道流水，不直接透传）、`queryId`（→ `frontQueryId`）、`sysRespCode`/`sysRespDesc`（银行结果码/说明）、`status`（不可直接作终态）、`reserve`（银行扩展响应）。

中信接入成功条件：`errCode=D5000000 && errInfo=success && sysRespCode=00000`（`sysRespCode` 成功码为 **5 个 0**）。上述原始值必须转换为 `FrontErrorCode`，真实成功统一返回 `200/成功`，不得把原始银行码写入 `frontRespCode/frontRespDesc`。统一响应至少需同时判断：① 钱包平台是否受理；② `sysRespCode` 是否成功；③ 返回的是受理结果还是最终结果；④ 是否需交易状态查询确认终态。

### 16.4 接口能力总览

账户类（当前 Front 范围）：`/query-acct-info` `bizFunc=35` 交易资金账户余额 `21000036`（是）、`36` 公共登记簿余额 `21000035`（是）、`46` 用户余额 `22000006`（是）、`2058` 用户状态查询 `22000001`（是）；其余（`26` 用户注册、`21/27` 绑卡、`22` 解绑、`15/16` 信息变更、`23` 绑卡关系、`21` 注销）均为后续。

交易类：`/transfer` `27` 支付 `21000050`（消费/普通转账）、`2041` 平台付款 `21000047`、`2042` 平台收款 `21000048`、`44` 实时预付 `22000007`（暂不纳入首期）；`/withdrawal` `26` 智能提现 `21000014`（提现）；`/refund` `23` 退款 `21000051`（退款）、`2025` 不明来款退款（专项，已实现）；`/recharge` `2023` 不明来款重新匹配/实时清分（专项，已实现）；`/rechg-after-pay` `25/30/31` 平台预清分（后续）、`/rechg-after-pay-verify` `01` 预清分核销（后续）；`/recharge` `24` 综合文档不明来账（本专项不采用）。

查询类：`/query-trans-status` `74` 用户交易状态查询 `21000010`（是）、`2087` 不明来款单条状态（专项，已实现）、`73/85/123` 为后续或不采用；`/query-trans-details` `24` 登记簿交易明细 `21000029`（是）、`25` 交易资金账户明细 `21000039`（是）、`2033` 不明来款列表（专项，已实现）；`/query-check-file-info` `21/22` 内部户明细文件（后续）。

文件及辅助：`/file-upload`、`/file-download`、`/gen-auth-code` `27` 短信验证码申请 `21000062`（仅用于用户签约，不能据此认定中信支持“短信鉴权转账”）。

### 16.5 关键交易能力摘要

**消费与普通转账**（`/transfer` `bizFunc=27` 产品 支付 `21000050`）：业务核心含主/子订单号、收付方编号与名称、金额（分）、日期时间、资金类型、备注、可选分润、平台自有资金标识。中信 `reserve`：`USER_D_NM`/`USER_C_NM`/`USER_C_AMT`（分）、`USER_SHARE_*`、`P_SELF_FLAG`/`P_SELF_AMT`、`BUSS_ID`/`BUSS_SUB_ID`、`TRANS_DT`/`TRANS_TM`、`FUND_TP`/`MEMO`/`laasSsn`。`transAmt` 取 `baseData.amount`（分）；`queryId`→`frontQueryId`；`USER_TRANS_DT/TM`→公共交易日期时间。当前 `USER_SHARE_*` 未实际映射，`P_SELF_FLAG/P_SELF_AMT` 固定 `N/0`。消费与转账同接口，Front 经业务类型与渠道流水区分；`bizFunc=27` 不进 `specialData`。

**提现**（`/withdrawal` `bizFunc=26` 产品 智能提现 `21000014`）：`acctNo`（用户/平台编号）、`cardNoEnc`（SM2 加密）、`transAmt`（分）、`remark`；`reserve`：`WITH_TYPE`（`00` 用户/`01` 平台）、`BUSS_ID`、`TRANS_DT/TM`、`FEE_TYPE`（`1` 平台/`2` 用户承担）、`WITH_ACCNAME`、`laasSsn`。平台提现只能平台承担手续费；返回含 `USER_TRANS_DT/TM`、`PWDID`、`TRANS_ID`、`WITH_CHANNEL`（本行/银联代付/二代小额/大额）。提现类型与手续费承担方式须定义为核心业务枚举，而非银行原始字符串。

**退款**（`/refund` `bizFunc=23` 产品 退款 `21000051`，真退款）：新版 `ZxRefundRequest + zxRefund` 已是真退款，旧 `ZxTransferRequest + bizFunc=27` 反向转账禁止迁移。`reserve` 关键字段：`ORI_USER_D_ID/D_NM/C_ID/C_NM`、`ORI_USER_C_AMT`、`ORI_USER_SHARE_*`（未启用）、`P_SELF_FLAG`（`N`）、`P_DEAL_AMT`（`0`）、`REFUND_BUSS_ID`（`bizOrderNo`）、`REFUND_BUSS_SUB_ID`（`bizSubOrderNo`）、`ORI_BUSS_ID/SUB_ID`（`orgBizOrderNo/orgBizSubOrderNo`）、`ORI_USER_TRANS_DT`、`TRANS_DT/TM`（`businessDate/businessTime`）、`FUND_TP`（`accountSpecialData.default_fund_type`，不得取 role）、`MEMO`（`refundReason`）、`laasSsn`。定位固定 `orgBizOrderNo+orgBizSubOrderNo`，`ORI_USER_SSN` 不使用；`ORI_USER_D_ID` 等由上游经 `specialData` 银行原始 key 提供，Front 不查本地原表补齐。支持部分退款；分润/平台出资退款需单独设计。

**平台付款**（`/transfer` `bizFunc=2041` 平台付款 `21000047`）：资金方向 平台自有资金登记簿 → 用户登记簿；平台侧由商户自有资金登记簿隐式确定，不上送平台银行账号。

**平台收款**（`/transfer` `bizFunc=2042` 平台收款 `21000048`）：资金方向 用户登记簿 → 平台自有资金登记簿，方向相反。

**短信验证码**（`/gen-auth-code` `bizFunc=27` `21000062`）：仅用于用户签约（`transType=01` 注册、`sigctType=01/02` 签约发送/验证），返回 `tranId`，验证上送 `tranId+veriCd`，有效期 120 秒。中信不具备“短信鉴权转账”能力，不得包装成转账验证码接口。

### 16.6 关键查询能力摘要

**交易状态查询**（`/query-trans-status` `bizFunc=74` `21000010`）：固定使用调用方提供的业务流水，不扫描本地渠道表补条件：`originalCapability`→原交易能力、`originalTransactionDate`→`oriTransDate`、`bizOrderNo`→`BUSS_ID`、`bizSubOrderNo`→`BUSS_SUB_ID`、`acctNo`→`acctNo`（加密）、`laasSsn`（Capability 生成）。原交易能力与银行字段固定映射：`TRANSFER/CONSUME/REFUND`→`BUSS_ID+BUSS_SUB_ID+TRANS_TYPE=01`；`WITHDRAW`→只上送 `BUSS_ID`。状态语义：`00` 已受理（ACCEPTED/PROCESSING）、`01` 成功（SUCCESS）、`02` 失败（FAILED）、`03` 处理中（PROCESSING）、`04` 已退款、`05` 已退汇（RETURNED）。不得只按 HTTP/钱包平台成功设 `frontStatus=SUCCESS`。

**登记簿交易明细**（`/query-trans-details` `bizFunc=24` 登记簿 `21000029`）：`acctNo`（加密映射顶层）、`transactionDate`（单日，`TRANS_DATE`）、`transactionType`（`reserve.TRANS_TYPE`）、`accountType`（可选 `registerAttr`）、`PAGE`（续查游标，每页默认 50）。`TRANS_TYPE`：`01` 入金分账/`02` 交易划转/`03` 提现/`04` 提现手续费/`05` 提现退汇/`06` 渠道来账/`98` 所有明细/`99` 所有汇总；业务系统须明确选择，禁用含义不清的“实收/所有”。`accountType`：`01` 公共调账/`12` 平台自有资金/`13` 担保/`17` 待结算手续费；旧 UAT 曾传 `00` 但 v4.7 定义为 `01/12/13/17`，联调前不得开放任意账户类型。

**平台交易资金账户明细**（`/query-trans-details` `bizFunc=25` `21000039`）：`transactionDate`→`reserve.TRANS_DATE`、`transactionType`→`reserve.TRANS_TYPE`、`PAGE`（从 1 开始，每页默认 20）。`transactionType`：`01` 转账入金/`02` 退汇/`03` 支付渠道入金/`04` 提现/`05` 退款（预留）/`99` 所有。金额字段文档标注“元”，必须统一转换为分。

### 16.7 不明来款专项、specialData 边界与流水

**中信不明来款专项**（独立 Channel，不进通用 `FrontCapability`）：对外固定强类型 `CiticUnidentifiedRemittanceApi`，请求/返回均不使用 `specialData`：

| 对外方法 | 中信接口 | 固定值 | 说明 |
|---|---|---|---|
| `queryPages` | `/query-trans-details` | `2033/0010` | 翻页聚合返回 |
| `process`（退款） | `/refund` | `2025/0010`，`operateType=0` | 退款补充域提升到报文顶层 |
| `process`（重新匹配） | `/recharge` | `2023/0010`，`operateType=1` | `transDate/transJrno` 定位，`userId` 可空 |
| `process`（实时清分） | `/recharge` | `2023/0010`，`operateType=2` | 额外必填 `registerType/userId` |
| `queryStatus` | `/query-trans-status` | `2087/0010` | `oriTransSsn/oriTransDate` 取列表 `transJrno/transDate` |

租户数据复用公共能力：直接请求 DTO 继承 `BaseRequest`，四公共字段由 Header/Feign 注入，缺失用 `tenant_base_config` 回填；银行账户配置由 `TenantBankConfigLoader` 加载；调用方不能传 `appId/appKey/url/mchntId/mchntMbrId/bizFunc/chnlNo`。`2087.oriTransSsn/oriTransDate` 取列表 `transJrno/transDate`，不得改用处理接口返回的 `frontSsn`。客户账（`accountType=0`）时 `bankNo/acctSeq/acctTransNo/finTransFlag` 均必填；内部账（`1`）不要求这四项。

**`specialData` 边界**（仅通用交易/查询 API；不明来款专项用全字段强类型 DTO）：可放中信特有可选字段、明细查询业务日期与当前银行交易类型、登记簿明细 `accountType`、分润扩展、特殊登记簿属性、文档允许的银行扩展备注。不得放：`bizFunc`/`chnlNo`/`mchntId`/`mchntMbrId`、银行地址/密钥/签名加密算法、`frontSsn`、银行 `TRANS_DATE/PAGE`、已具跨银行公共语义的提现类型与手续费承担方式。

**渠道流水要求**（交易类至少保存）：`tenantId`/`platformCode`、Front 业务类型、`frontSsn`、主/子订单、原 `frontSsn`、实际 `bizFunc=27/26/23/2041/2042`、银行流水/查询流水/交易日期时间、明确业务字段与银行定位字段（不保存完整请求/响应报文快照）、`ACCEPTED/PROCESSING/SUCCESS/FAILED/UNKNOWN/RETURNED` 状态。

### 16.8 风险与待确认项

1. 中信短信验证码接口是用户签约能力，不是已确认的转账鉴权能力。
2. 消费和普通转账都映射 `bizFunc=27`，Front 需通过业务类型和渠道流水区分。
3. 退款是否首期支持部分退款、分润退款、平台出资退款需产品确认。
4. `24` 查询不定义含义不清的“实收”；业务系统明确选择 `01 入金分账` 或 `06 渠道来账`。
5. `24` 的 `98/99` 分别作为“所有明细/所有汇总”独立枚举，不能合并。
6. 明细响应金额存在“元”，交易请求金额使用“分”，必须统一转换。
7. `74` 状态查询的已受理/处理中/成功/退款/退汇必须映射为不同 Front 状态。
8. 版本历史已移除 `SIGN_INFO`，旧实现若仍发送该字段需重构时删除。
9. 旧代码中的 `null`、模拟成功和硬编码仅能作为结构参考，不能作为银行能力证明。
10. 文件/预清分/实时预付暂不进首期；中信不明来款已作为专项独立实现，不得重新并入通用框架。

## 17. 平安银行接口能力落地

> 银行编码：平安（`platformCode=pajzb`）；钱包渠道号：`0001`。
> 源文档：`客户钱包应用平台_接口文档-平安项目(总)v5.5.doc`
> 当前启用约束（2026-08-19）：平安交易状态、平台交易明细、交易明细已启用；账户状态、账户余额按裁决固定
> 保留 `PENDING_INTEGRATION/ADAPTER_NOT_READY` 挡板，不再作为待接入项。

### 17.1 当前 Front 适配结构

平安通用能力按三个执行域注册，不使用大 Handle：

| 域 | Capability | LiteFlow 入口 |
|---|---|---|
| Transaction | transfer、consume、refund、withdraw、transferAuth、resendTransferAuthCode | `frontTransExecute` |
| Query | transactionStatus、platformTransactionDetails、accountTransactionDetails | `frontQueryExecute` |
| Account | accountStatus、accountBalance（保持既有挡板） | `frontAccountExecute` |

每个“平安 × 能力”实现所属域强类型接口，通过本域 Registry 路由；配置由
`域 ExecuteNode → TenantBankConfigLoader → RemoteConfigServiceClient` 加载，钱包统一经
`BankWalletGateway.post → 平安 BankWalletSender` 发送。Sender 唯一记录完整明文钱包 body；`appKey`、私钥、
签名材料、认证 Header 等非业务报文凭证禁止进入日志。

### 17.2 接入协议摘要

- 接口地址：`域名前缀 + /cwap/account/send/{业务后缀}`；测试 `https://test-api-open.chinaums.com/v1`，生产 `https://api-mop.chinaums.com/v1`。
- 公共约束：平安见证宝渠道号固定 `0001`；请求/响应 JSON；`reserve` 为 JSON 补充域；金额通常“分”；日期 `yyyyMMdd`，时间 `HHmmss` 或完整 `yyyyMMddHHmmss`。
- 认证与敏感信息：每笔请求 HTTP 头携带 `Authorization`；姓名/卡号/手机号/证件号/短信验证码用 SM2（`sm2p256v1`）；资金汇总账户、见证子账户、银行卡号/户名按接口要求加密；Front 必须集中完成加密，业务系统不能传已拼装的完整银行请求。
- 平安交易流水 `transSsn`：接入方编号（6 位）+ `MMDD`（4 位）+ 12 位序列，总长 22 位，要求永久唯一；Front 独立生成并与 `frontSsn` 建立映射。`frontSsn` 承接本次发给银行的 `transSsn`（落 `front_ssn`），与银行应答 `queryId`、可能存在的 `USER_SSN/ssn` 是三个不同字段，不能把 `queryId` 解释成请求 `transSsn`。

### 17.3 公共请求与响应字段

公共请求字段：`transSsn`/`transTime`（Front 生成）、`mchntId`（租户配置）、`mchntMbrId`（配置或业务核心）、`bizFunc`（Capability 确定）、`chnlNo`（固定 `0001`）、`acctNo`/`outAcctNo`/`inAcctNo`（加密）、`transAmt`（分，含手续费）、`fee`（分）、`ccy`、`remark`、`reserve`（Capability 显式映射）。

公共响应字段：`errCode`/`errInfo`（只用于平台层成功判定并保存渠道流水，不直接透传）、`queryId`（→ `frontQueryId`）、`sysRespCode`/`sysRespDesc`（银行结果码/说明）、`status`（不直接作终态）、`reserve`（具体响应解析器使用）。

平安接入成功条件：`errCode=D5000000 && errInfo=success && sysRespCode=000000`（`sysRespCode` 成功码为 **6 个 0**，不同于中信的 5 个 0）。上述原始值必须转换为 `FrontErrorCode`，真实成功统一返回 `200/成功`。

**重要**：平安部分交易同步只返回“受理成功”，特别是提现。Front 必须区分 `受理成功 != 银行最终成功`；终态需查交易状态，成功后仍可能发生退票。

### 17.4 关键交易能力摘要

**消费与普通转账**（`/transfer` `bizFunc=01` 会员间交易-不验证 `6034`）：`functionFlag`：`6` 直接支付 T+1、`7` 免密支付、`9` 直接支付 T+0。公共字段：转出/转入见证子账户、会员编号及户名、金额 `baseData.amount`（分，映射 `transAmt` 且含手续费）、手续费 `baseData.fee`（分，映射 `fee`，无则 0）、币种、订单号、交易类型、备注。`reserve`：`mrchCode`/`txnClientNo`/`functionFlag`/`stlAcctNo`（来自 `accountSpecialData`，SM2 加密）/`outAcctId`/`outAcctName`/`inAcctId`/`inAcctName`（加密）/`transType`/`orderId`/`orderInfo`。适配结论：消费与转账复用同一底层接口，业务类型/订单类型/渠道流水仍区分；lsym 生产 transfer 固定 `functionFlag=9`，consume 默认或 `bankChannelNo=0109` 固定 `9`、`0107` 固定 `7`；`functionFlag` 改变结算与退款语义，必须由平安 Capability 按已确认 Front 场景选择，不向业务系统透传原始值；新 Front 当前只实现 `9`，旧 `0107` 场景待重新核对；成功响应 `specialData` 默认空，后续只能白名单逐项写入，禁止整体透传 `reserve`。

**短信鉴权转账**（`/transfer` `bizFunc=45` 会员间交易-验证短信动态码 `6101`；验证码 `/gen-auth-code` `bizFunc=26` `6082`）：文档证明的是“短信鉴权转账”而非“授信额度转账”；`transferAuth` 固定 `bizFunc=45/chnlNo=0001/functionFlag=9/tranType=01`；`resendTransferAuthCode` 固定 `bizFunc=26/chnlNo=0001/tranType=2`，文档无独立“重发”接口，重发语义=生成新银行流水再次调用申请接口，不上送旧 `smsIdx`；`bizFunc=26` 返回的 `smsIdx/receiveMobile` 为 SM2 密文，Capability 解密后按白名单写回 `specialData` 且不记录；`messageOrderNo/messageCheckCode` 放请求 `specialData`，由 Capability 加密；重复申请限流/有效期/旧码失效仍需联调确认。

**提现**（`/withdrawal`，两种用途）：`bizFunc=01` 会员提现-不验证 `6033`（直接申请提现）、`bizFunc=36` 会员提现-支持手续费 `6085`（平台手续费+短信验证）。`bizFunc=01` 关键数据：见证子账户、收款银行卡、提现金额、会员/证件/户名、资金汇总账户、平台号/客户号。`bizFunc=36` 增加：收款账号户名、市场手续费、短信指令号/验证码、可选网银签名。状态语义：同步响应=受理；最终成功需查 `query-trans-status` `bizFunc=03`；成功后仍可能退票，退票经 `query-trans-details` `bizFunc=02` 查询。

**退款**（`/refund`）：`bizFunc=02` 服务 `6006/6034/6101` 直接支付（`functionFlag=6/9`），`bizFunc=06` 服务 `6163/6165/6166` 会员资金支付。`5.5` 新增免密支付 `functionFlag=7` 的退款处理未明确，支持免密消费退款前必须向银行确认。lsym 长短款调用 `transConsumeCancel`，平安 Capability 构造真 `/refund` 并固定 `bizFunc=02`，请求无 `functionFlag`；当前退款只服务内部长短款修复：业务系统提供原主子流水，Front 按 `tenantId+originalBizOrderNo+originalBizSubOrderNo` 精确查平安原转账/消费渠道表，加载原 `frontSsn`、原交易日期、原收付款账户/会员字段，完成加密、报文组装与落库；`oriTransSsn` 必须取原记录 `front_ssn`，不得取 `bank_user_ssn`；查表只补渠道协议数据，不判断累计退款金额或资格；不纳入 `bizFunc=06`、普通业务退款、分润退款或平台出资退款。

**平台付款与平台收款**：平安文档存在 `bizFunc=02` 补贴、`01` 会员间交易、`46` 会员资金支付、子账户登记挂账等，但**没有与中信 `2041/2042` 在账户方向和账簿语义上完全等价的成对接口**。结论：不能直接将平安“补贴”等同于平台付款；`PaTransTransferHandle` 未覆盖 `platformPay/platformReceive`（继承父类 `null` 返回）；新 Front 已确认两项为中信专有能力，平安必须标记 **UNSUPPORTED**，不再保留“待接入”状态；不能直接将普通会员间转账等同于平台收款；未来重新评估必须单独确认平安侧平台自有/营销/资方/挂账账户资金模型，不得在现有两个 API 中复用普通转账。

### 17.5 账户查询与挡板裁决

**账户信息查询**（`/query-acct-info`）：`bizFunc=01` 按会员代码查会员子账户、`63` 查资金汇总账户余额 `6011`、`64` 查会员子账户；主要返回见证子账户、账户类型、可用/可提现/冻结金额、资金汇总账户余额、会员及账户基础信息。

**账户信息列表查询**（`/query-acct-info-list`）：`bizFunc=01` 普通会员子账户余额、`02` 功能子账户余额、`03` 会员子账户余额 `6093`；旧代码用 `03`，文档同段同时出现 `01/02/03` 但部分说明只标 `01/02`，新实现前需确认三种用途边界与正式投产值。

**账户状态挡板裁决**（关键）：平安账户查询响应存在 `acctState` 等字段，但文档多处标注忽略，未发现与中信 `2058 用户状态查询` 完全等价的独立能力。因此 `queryAccountStatus`：中信可返回明确用户状态；平安不能仅以“账户查询成功”模拟用户状态正常；当前产品裁决为**保留 `ADAPTER_NOT_READY` 挡板（F200003），不核对候选接口**，未来重新打开需银行提供正式状态字段与枚举。账户余额（`queryAccountBalance`）同理固定挡板。§4.4 全部账户查询 `bizFunc`（01/63/64/01/02/03）均不在当前接入范围，原因与重新打开条件见本小节；中信侧对应能力（2058/35/36/46）已实现。

### 17.6 关键交易查询摘要

**交易状态查询**（`/query-trans-status`）：当前映射——普通转账/消费/短信鉴权转账→`bizFunc=02`、提现→`03`、充值→`04`、特定批量/冻结/补贴/分账终态→`06`。主要请求：`oriTransSsn`（原交易流水）、`oriTransDate`、部分用途要求资金汇总账户、`mrchCode`/`txnClientNo`。银行原状态：`0` 成功（SUCCESS）、`1` 失败（FAILED）、`2` 待确认（UNKNOWN/PROCESSING）、`5` 待处理（PROCESSING）、`6` 处理中（PROCESSING）；返回值非 0/1 时视为状态未明，约 5 分钟后再次查询。`bizFunc` 由原渠道流水交易类型决定；单笔状态查询由调用方传原交易 `frontSsn`→`oriTransSsn`（即原请求发给银行的 `transSsn`，存 `front_ssn`），不使用原应答 `queryId/bank_query_id` 或 `bank_user_ssn`；Front 需定义查询重试/超时/最终人工处理边界。

**平台普通转账充值明细**（`/query-trans-details` `bizFunc=04` `6050`）：查会员主动转账进入资金汇总账户明细；`functionFlag=1` 当日/`2` 历史、`stlAcctNo`、`page`、`mrchCode`/`txnClientNo`。只覆盖平安平台入金一部分，不能直接等价为中信 `bizFunc=25` 所有平台交易类型。

**子账户时间段交易明细**（`/query-trans-details` `bizFunc=05` `6072`）：`functionFlag`（`1` 当日/`2` 历史）、`stlAcctNo`、`subAcctNo`、`queryFlag`（`1` 全部/`2` 转出/`3` 转入）、`pageNum`（每页最多 20）、`mrchCode`/`txnClientNo`；记账类型含支付/冻结/解冻/登记挂账/预支付/确认付款/退款/见证+收单。

**清分、提现和退款明细**（`/query-trans-details` `bizFunc=08` `6073`）：`queryFlag` `2` 提现及相关退款/`3` 清分充值/`4` 收款编码退款。平安原文档 v5.5 对提现用途 36 应答字段名为 `queryId`、业务含义 `FrontSeqNo（见证系统流水号）`；6073 行内对应 `frontSeqNo`，可直接关联，但不改变保存边界：`FrontSeqNo` 是平安对应答 `queryId` 的描述，非请求 `transSsn/front_ssn`。两种查询分开：单笔状态查询 `baseData.frontSsn→oriTransSsn→原请求 transSsn/front_ssn`；6073 订单补全 `recordList.frontSeqNo→原应答 queryId/bank_query_id`。不得因中信用 `USER_SSN` 就把平安 `queryId` 全局解释成 `ssn`。

**提现退票**（`/query-trans-details` `bizFunc=02` `6048`）：关键响应原提现交易流水、见证/市场流水、退票原因/日期、退票入账流水与金额、付款账号户名银行、收款方见证子账户、业务流水号；应作为提现终态处理的一部分，而非普通明细可选字段。

**平台交易查询与中信差异**：中信平台资金账户明细 `25` 可直接筛选 渠道实收/转账/退汇/提现/所有；平安分散在 `04`（入金）/`05`（会员交易）/`08`（提现清分部分退款）/`02`（提现退票）/`39`（银行费用）。平安 `queryPlatformTransactions` 须明确选择：只支持某些通用类型、或按通用类型调不同 `bizFunc`、或对“所有”发起多银行查询并聚合；未确定分页/排序/去重/超时规则前，不建议首期实现跨多 `bizFunc` 的“所有交易”聚合。

### 17.7 specialData 边界与渠道流水作用

**`specialData` 边界**（可放）：银行特有可选订单内容、经契约定义的平安扩展备注、暂未进公共核心的条件字段、特定查询接口的可选筛选扩展。（不应放）：`bizFunc`/`chnlNo`、`mchntId`/`appIdBank`/`appKeyBank`、`txnClientNo`/`mrchCode`/`stlAcctNo` 等平安账户静态配置、URL/签名/加密算法/密钥、`functionFlag` 对应业务模式原始码、`queryFlag`/查询场景等已定义公共语义字段、Front/银行流水号生成规则。

**渠道流水作用**（除审计外须保存）：原交易平安 `bizFunc`、`functionFlag`、提现模式 `01/36`、银行 `transSsn`/`queryId`、原 `frontSsn`、业务主/子订单、同步受理状态与最终状态、退款使用的原交易类型。这样状态查询、退款和提现退票查询才能由 Front 自动选择正确银行能力。

### 17.8 风险与待确认项

1. 源文件名 5.5、封面 5.4，需确认正式投产版本。
2. 旧 `0107→functionFlag=7` 消费场景是否继续支持待重新核对；当前长短款退款只按已确认 `bizFunc=02` 真退款链路，不扩展其他退款产品。
3. “授信转账”应改“短信鉴权转账”，除非银行另有授信额度类产品。
4. 验证码重发已约束为再次调用申请接口，但限流、旧码失效及有效期仍需联调确认。
5. 提现首期支持 `01`、`36` 还是两者待确认。
6. 提现同步成功只是受理成功，必须查状态并处理退票。
7. 平台付款、平台收款没有与中信 `2041/2042` 完全等价接口，新 Front 明确不支持。
8. 账户列表查询 `01/02/03` 文档描述交叉，需确认正式 `bizFunc`。
9. 交易明细目录列 `bizFunc=43`，公共请求说明列到 `40`，需确认 `43` 是否投产。
10. 平安平台交易查询需跨 `04/05/08/02/39`，不能简单套用中信类型。
11. 平安缺少已确认的中信 `2058` 等价账户状态查询。
12. 平安不同查询用途返回数组结构不同，必须按用途用独立响应解析器。

### 17.9 当前核对结论

- 交易状态查询已启用；平台明细和账户明细已按 17 号 spec 启用，不再列为后续待接入项。
- 平安退款当前只启用 `/refund + bizFunc=02`，由 Front 查原渠道记录补齐协议字段；`bizFunc=06` 不在本期范围。
- 账户状态和账户余额按裁决保留 `ADAPTER_NOT_READY` 挡板，不再继续核对或接入。
- 平台付款、平台收款明确不支持。
- 其他银行产品的投产范围必须另立契约确认，不得从本能力汇总直接推导为已支持能力。
