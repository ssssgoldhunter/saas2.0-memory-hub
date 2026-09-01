# Catering Front 框架与业务功能设计手册

> 状态：current-design / implemented
> 更新日期：2026-08-31
> 历史迁移起点：`limeng_front_restruct@0dd983a72cc7def2d60f6f35aefcc1c1160864d2`
> 当前源码基线：`limeng_front@dbd9fad5`
> 结构权威：01、05、28、29 号文档

本文供维护 `catering-front`、增加银行或实现能力时使用。它只描述现行三域扁平框架和已确认业务；
旧 Context、Router、Dispatch、Handle、统一 Registry 和 Provider/Assembler 模板不再保留在正文中。

## 1. 开发前必读

按任务类型阅读：

- 框架结构：01、05、28、29。
- 中信能力：02；平安能力：03。
- transfer/consume：06。
- 平安授权转账/验证码：07、25。
- withdraw/refund/platform transfer：08。
- 交易状态、平台明细、登记簿明细、账户状态/余额：10、17。
- 渠道流水：09、09A、09B、09-final。
- 中信不明来款：27 和专项协议文档。
- 上游接入：20、21。

字段和业务规则以专项契约为准；框架层级以 28、29 为准。不得从旧 Front/mdl 推测缺失业务。

## 2. 框架主路径

```text
Transaction API
→ FrontTransApplicationService
→ THEN(frontTenantPack, frontTransExecute)
→ FrontTenantPackNode
→ FrontTransExecuteNode
→ BankTransCapabilityRegistry
→ BankTransCapability.execute(FrontTransSlot)

Query API
→ FrontQueryApplicationService
→ THEN(frontTenantPack, frontQueryExecute)
→ FrontTenantPackNode
→ FrontQueryExecuteNode
→ BankQueryCapabilityRegistry
→ BankQueryCapability.execute(FrontQuerySlot)

Account API
→ FrontAccountApplicationService
→ THEN(frontAccountExecute)
→ FrontAccountExecuteNode
→ BankAccountCapabilityRegistry
→ BankAccountCapability.execute(FrontAccountSlot)

Capability → BankWalletGateway.post → BankWalletSender
```

API 入口和 chain id 不变。交易 8 条和交易查询 3 条链先执行统一租户准备组件，再进入本域 ExecuteNode；
账户 10 条链仍只包含 `frontAccountExecute`。业务逻辑继续在银行 Capability 内扁平展开。

## 3. Slot、接口和 Registry

```text
FrontBaseSlot
├─ FrontTransSlot
├─ FrontQuerySlot
└─ FrontAccountSlot
```

- Slot 继承只有两层，一次请求只用一个 Slot。
- Transaction 接口只接受 `FrontTransSlot`。
- Query 接口只接受 `FrontQuerySlot`。
- Account 接口只接受 `FrontAccountSlot`。
- 账户状态和余额属于 Account 域；交易状态和两类明细属于 Query 域。
- Registry 按本域 `(BankCode, FrontCapability)` 注册；重复 Key 启动失败。
- 禁止统一宽接口、`FrontBaseSlot + instanceof`、统一 Registry 或通用 ExecuteNode。

`FrontTenantPackNode` 对 Transaction/Query 执行 Header、Slot、请求 `tenantId` 一致性校验，加载
`TenantBaseInfo`，并按租户配置权威值回填或核对 `dataSourceId`。ExecuteNode 取得 Slot 后只完成本域路由和
Capability 调用；Account 域维持现有 ExecuteNode 配置加载路径。完整边界见 31 号设计。

## 4. 业务能力矩阵

### 4.1 Transaction：12 个实现

| 能力 | 中信 | 平安 | 备注 |
|---|---|---|---|
| transfer | 支持 | 支持 | 普通转账 |
| consume | 支持 | 支持 | 消费 |
| refund | 支持 | 支持 | 两家都是真退款，禁止反向转账模拟 |
| withdraw | 支持 | 支持 | 资金交易 |
| transferAuth | 不注册 | 支持 | 平安短信鉴权转账 |
| resendTransferAuthCode | 不注册 | 支持 | 平安发码/重发 |
| platformPay | 支持 | 不注册 | 中信平台付款 |
| platformReceive | 支持 | 不注册 | 中信平台收款 |

共 12 个银行 Capability：中信 6、平安 6。

### 4.2 Query：6 个实现

| 能力 | 中信 | 平安 | 结果 |
|---|---|---|---|
| transactionStatus | 支持 | 支持 | `R<TransStatusResult>` |
| platformTransactionDetails | 支持 | 支持 | `TableDataInfo<PlatformTransDetailItem>` |
| accountTransactionDetails | 支持 | 支持 | `TableDataInfo<AccountTransDetailItem>` |

共 6 个银行 Capability。Query 域不包含账户状态和账户余额。

### 4.3 Account：11 个实现

| 能力 | 中信 | 平安 | 结果 |
|---|---|---|---|
| accountStatus | 支持 | 保持 `ADAPTER_NOT_READY` 挡板 | `R<AccountStatusResult>` |
| accountBalance | 支持 | 保持 `ADAPTER_NOT_READY` 挡板 | `R<AccountBalanceResult>` |
| accountOpen | 支持 | 不注册 | `R<AccountBaseResult>` |
| accountBindCard | 支持 | 不注册 | `R<AccountBaseResult>` |
| accountUnbindCard | 支持 | 不注册 | `R<AccountBaseResult>` |
| accountUpdateInfo | 支持 | 不注册 | `R<AccountBaseResult>` |
| accountClose | 支持 | 不注册 | `R<AccountBaseResult>` |
| accountWhiteName | 支持 | 不注册 | `R<AccountBaseResult>`；`opType` 区分加白/去白 |
| accountWithdraw | 支持 | 不注册 | `R<AccountBaseResult>`；区别于 Transaction withdraw |

共 11 个银行 Capability：中信 9 个，平安 2 个挡板。账户维护新增 7 个公开 API；
当前 XML 另有 `chainFrontAccountUnwhiteName`，但没有独立 API/AppService 调用，见 §13 当前差异。

### 4.4 中信不明来款专项

提供列表、退款/重新匹配/实时清分统一处理、状态查询。它属于中信专项 Channel：

- 不注册 `FrontCapability`；
- 不进入三域 Registry/LiteFlow；
- 请求/返回使用全字段强类型 DTO，不使用 `specialData`；
- 通过 `FrontSpecialTenantPack` 统一完成专项租户准备并取得 `FrontSpecialProcessContext`，再复用 Gateway 和中信 common。

## 5. 对外请求和返回

通用能力请求继续使用：

```text
FrontRequest<T>
├─ baseData：跨银行稳定公共字段
└─ specialData：银行 + 当前能力的动态字段
```

规则：

- capability 由 API 方法内部固定。
- `baseData` 不加入银行专有账号、会员、姓名、卡号等字段。
- `specialData` 使用字段契约规定的 key，并由 Capability 按白名单逐键读取。
- `accountConfig/accountSpecialData` 来自租户配置，调用方不得传入。
- 禁止把 `specialData/accountSpecialData` 整体复制到 reserve。
- 金额统一使用 `Long` 人民币分。

返回规则：

- 单条交易、交易状态、账户状态和余额返回 `R<具体结果>`。
- 明细分页直接返回 `TableDataInfo<具体行>`，不用 `R` 再包一层。
- 顶层 `R.code=200` 只表示 Front 业务成功；业务失败必须返回失败码。
- data 内的 `frontRespCode/frontRespDesc` 使用统一 Front 错误码。
- 银行原始码只用于 Capability 判定与渠道审计，不直接对外。
- `FrontFlowExecutor` 内部允许返回 `null`；Application Service 必须先检查 Slot、再检查结果。Slot 未失败但
  结果为 `null` 时，单条返回带 `INTERNAL_ERROR` 的失败响应，分页返回非空失败页；禁止 `R.ok(null)`。

## 6. 租户与银行配置

```text
Transaction/Query：FrontTenantPackNode
→ TenantBankConfigLoader
→ RemoteConfigServiceClient

Account：FrontAccountExecuteNode
→ TenantBankConfigLoader

中信专项：FrontSpecialTenantPack
→ TenantBankConfigLoader
```

Loader 先查询 tenant base，再按 `supportBankConfig` 获取当前银行账户配置，并直接扁平组装
`TenantBankAccountConfig`。只保留 `loadTenantBaseInfo` 和 `loadBankAccountConfig` 两个公共方法。

缺失 tenant、配置模板、银行配置或分库数据源时立即失败；不得默认使用其他租户、`ds_0` 或第一数据源。
禁止恢复 Provider、AssemblerRouter、Assembler、抽象配置父类或配置 Context。

## 7. Capability 开发规范

每个类只实现一个“银行 × 能力”，并只实现一个域接口。交易能力按以下顺序编写：

```text
校验
→ 组银行请求
→ 固定表查重
→ INSERT INIT
→ UPDATE SENDING
→ BankWalletGateway.post
→ 判断银行结果
→ UPDATE 终态
→ 写 Front 结果到 Slot
```

查询/账户能力按“校验→组装→发送→判断→映射”展开，不产生交易流水。

约束：

- bizFunc、chnlNo、path、transSsn、transTime 由具体 Capability 控制。
- 银行协议 DTO 放在所属 `channel/{bank}/{transaction|query|account}` 域包。
- 能力专属组装留在能力类或一层私有方法；允许少量重复。
- 真正被同一银行多个已实现能力复用的序列、加密、响应判断等才进入 `common`。
- 禁止业务父类、Handle、Router、Dispatch、BankSupport God class、跨域 switch 和动态表名。
- 未支持能力不注册；待接入能力返回 `ADAPTER_NOT_READY`。`FrontFlowExecutor` 内部 `null` 由
  Application Service 转换为失败响应，对外不返回 null 或模拟成功。

## 8. 交易流水规则

- 每个交易能力使用自己的固定银行业务表。
- 重复检查使用 `tenantId + bizOrderNo + bizSubOrderNo`；命中表达“交易已存在”，不重放旧结果。
- 状态顺序为 `INIT → SENDING → SUCCESS/FAILED/ACCEPTED/UNKNOWN`。
- 通信超时或无法判断最终结果时标记 `UNKNOWN`，资金交易不得自动重发。
- 中信退款使用真实 `/refund + bizFunc=23`。
- 平安退款按原业务主子流水从原平安交易表取得已确认的银行定位字段。
- 本轮三域改造不修改表、Mapper、DDL 和分片逻辑。

## 9. 查询与账户规则

- 单笔交易状态使用原交易定位字段，不把 `queryId`、`frontSsn`、银行用户流水混用。
- 中信 24/25 明细一次只查单日；上游跨日时按日期多次调用。
- 分页总数和总页数按 10/17 号契约映射。
- 平安 6073 补字段使用原应答 `queryId/bank_query_id` 关联，不使用 `bank_user_ssn` 替代。
- 账户状态/余额属于 Account 域，即使 API 名包含 Query 也不得注册 Query Registry。
- 平安两个账户能力保持挡板，未经新需求不得启用不可达草稿。

## 10. Gateway、Sender 和日志

`BankWalletGateway.post` 是 Capability 唯一的钱包发送方法。Gateway 根据银行选择最终 Sender；该 Sender
直接签名并执行 HTTP。现有实现类可以保留 `WalletHttpClient` 名称，类名不是验收指标；但该类本身必须
就是最终 Sender，后面不得再套 WalletHttpClient/Invoker/Facade。

日志采用 B 方案：

1. API/Application Service：入口、完成、异常收口。
2. `FrontTenantPackNode`/ExecuteNode：租户准备、BankCode 和本域路由结果。
3. Capability：业务开始、字段校验、流水状态、银行判定和异常。
4. Sender：发送前唯一记录一次 `wallet_request_sending`；响应后唯一记录一次
   `wallet_response_received`；通信失败唯一记录一次 `wallet_request_failed`。

发送前日志包含 bank、apiName、frontSsn 和完整明文请求 JSON；响应后日志包含同一组定位字段、完整明文
响应 JSON、HTTP 状态和耗时；失败日志包含同一组定位字段、失败阶段、是否已发送、耗时和异常堆栈。
钱包请求/响应 body 不脱敏。Capability/Gateway 不得重复打印同一报文。
`appKey`、私钥、签名材料、签名/认证 Header、`Authorization`、`Cookie` 等非业务报文凭证不得进入日志、异常或普通响应。

当前源码事实：中信 Sender 已提供发送、响应和失败三类结构化事件；平安 Sender 的通信异常路径
只有普通 error 日志，尚无结构化 `wallet_request_failed`。`catering-web-test` 的
`test_feign_headers` 当前还会记录 `Authorization`，与认证凭证排除规则冲突。业务验证码属于业务
payload，按用户裁决允许明文，不再列入禁止项。以上均是待后续明确授权后修正的代码差异。

## 11. 新银行开发

复用已有 Front 能力时只需要：

1. 增加 BankCode。
2. 在 Loader 内增加一个平级配置组装分支。
3. 实现该银行最终 Sender 和 ResponseChecker。
4. 在现有三个域中实现该银行真实支持的 Capability。

Spring 注入列表会让 Capability 自描述注册到对应 Registry。不得修改 API、Application Service、chain id、Registry、ExecuteNode 或其他银行代码。

## 12. 新能力开发

增加新的 Front 能力前必须先确认：

- 是否确有新 API/业务语义，而非现有 capability 的银行字段差异；
- 属于 Transaction、Query 还是 Account；
- 请求/返回字段、来源、单位、必填和空值；
- 是否产生交易流水及固定表；
- 两家银行是否真实支持；
- 错误、超时和结果未知语义。

仅在现有三类 Slot 无法准确承载新的中间数据/状态，并经用户明确批准后，才允许增加第四执行域。

## 13. Definition of Done

- 28/29 历史迁移的既有 API/Controller/DTO 未改变；新增账户维护能力允许按新契约增加 API/DTO。
- Slot 为 Base + Trans/Query/Account 两层。
- 三个强类型接口、三个 Registry、三个 ExecuteNode。
- 当前 `FrontCapability` 枚举 21 项；其中 `RECHARGE` 暂无 Front API/银行实现。银行 Capability
  实现类 29 个，按 12/6/11 归域。
- 当前 21 条链按 8/3/10 归域：交易和交易查询是 `frontTenantPack + 域 ExecuteNode` 两节点串行链，
  账户是 `frontAccountExecute` 单节点链。
- 标准 API 20 个（8 交易 / 5 查询 / 7 账户维护），中信不明来款专项 API 3 个。
- 账户状态/余额只在 Account 域。
- Capability 主流程可在一个类中顺序读完。
- 旧 Context/Router/Dispatch/Handle、统一 Registry、Provider/Assembler 零残留。
- Sender 是唯一完整明文钱包 body 日志位置，认证凭证未入日志。
- Application Service 对执行器 `null` 结果显式转为非空失败响应。
- 中信不明来款继续独立。
- 文档、能力矩阵和实际代码一致。

租户准备与分库安全的最终实现和回归测试锚点见 31 号设计。其他历史审查项必须按当前代码重新核验，
不得继续引用旧基线的未闭环结论。


## 分片路由口径（2026-08-29 起，tenant_id 分片）

分片键为 `tenant_id`，由 MyBatis-Plus 多租户插件注入路由值，SQL 免显式分片键；
算法按 `tenant_id` 查进程内 `TenantDataSourceMappingCache` 得 `ds_x`（详见 05 §3.10.1）：
- **INSERT**：仍写 `data_source_id` 列值（entity.setDataSourceId，仅作实例标识记录，不参与路由）；
- **SELECT/UPDATE**：不再要求 `.eq(DATA_SOURCE_ID, ...)` 显式条件（2026-08-29 FR-6 已移除），
  路由由插件注入的 `tenant_id` 精确保证；
- **保障**：`tenant_id` 缺失（无租户上下文 fail-closed）、映射缺失或目标 `ds_x` 不在可用列表时
  立即失败，禁止默认路由。


## 附录：最终约束清单（持续有效）

1. package 结构扁平、流程容易顺序阅读；
2. flow 下可按能力分包；slot 集中放置，模块代码集中放置后再按不同能力分组；
3. Slot 继承层级最多两层：Base Slot + 直接继承 Base 的业务 Slot
   （FrontTransSlot/FrontQuerySlot/FrontAccountSlot 等表意命名，禁止无意义的 *Context 命名）；
4. Front 的职责保持 Registry + Route；
5. 允许每个银行、每个能力拥有独立组装代码；允许适度重复，不为消除重复增加多层继承和跳转；
6. API 是否新增或保持不变以具体业务任务为准；框架扁平化不得无故改变既有 API 契约
   （迁移既有能力类时契约零变化；新增业务能力允许新增契约）；
7. 钱包调用链保持简单：一个统一发送出口，沿用现有 WalletHttpClient 承担统一发送职责，
   不额外引入 Sender 继承体系；发送前、响应后、异常路径统一记录日志；
8. 业务日志按当前确认口径明文展示（含业务 payload 中的验证码）；`appKey`、密钥、签名私钥、
   签名/认证 Header、`Authorization`、`Cookie`、完整银行 URL 等非业务凭证仍不得输出；
9. 下游返回 null 时不得伪造成功，由外层调用方显式判断并处理。
