# Front 重构 Wiki：AI 开发入口

> 本页是其他 AI 参与 Front 重构时的唯一入口。不要只把某个银行文档或某个 Java 文件单独交给 AI；
> 必须先让它完整阅读本页，再按本文规定的顺序读取相关文档和代码。

## 1. 给新 AI 的开场指令

可以把下面这段直接发给接手任务的 AI：

```text
先完整阅读 saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md，
再严格按其中的“必读顺序”读取文档和当前代码。不要根据旧项目直接复制实现。

阅读完成后，先向我说明：
1. 当前代码已经提供哪些框架能力；
2. 你要实现的方法在新 Handle、旧 Front 和 mdl 中分别对应什么；
3. 你准备修改哪些文件；
4. 哪些字段进入 baseData、specialData、accountConfig、accountSpecialData；
5. 本次是否收到编写测试或执行编译的明确授权。

确认上述信息后，只实现我指定的一个银行或一个能力，并同步更新记忆体文档。
```

## 2. 仓库与参考项目

| 用途 | 路径 / 分支 | 规则 |
|---|---|---|
| SaaS 代码仓库 | `/Users/limeng/workspaces/IdeaProjects_saas_dep/cateringsass`，分支 `limeng_front` | 实际开发目标，以当前代码为准 |
| 记忆体仓库 | `/Users/limeng/workspaces/IdeaProjects_saas_dep/saas2.0-memory-hub`，分支 `main` | 架构、映射和约束的知识库 |
| 中信真退款最新参考 | `/Users/limeng/workspaces/IdeaProjects_lsym_uat/slhy`，分支 `lsym_20260625_limeng_refundTask` | 参考 `ZxRefundRequest + zxRefund + bizFunc=23` 真实调用和 reserve 字段，不复制旧请求来源及敏感日志 |
| mdl 参考实现 | `/Users/limeng/workspaces/IdeaProjects_mdl_dep/mdl/fund-catering-front` | 参考真实银行调用和字段映射，不复制旧框架缺陷 |
| 旧 Front 结构参考 | `/Users/limeng/workspaces/IdeaProjects_lsym_dep/slhy/fund-catering/fund-catering-front` | 只参考目录、方法语义和历史实现 |
| lsym 对象转换参考 | `IdeaProjects_lsym_dep/slhy/fund-catering/fund-catering-consume/fund-catering-consume-service/.../consume/domain/Converter.java` | 只参考“存在哪些 Req/Res ↔ Entity/Vo 转换关系”；它用的是原生 mapstruct `@Mapper` 接口，**新工程不照搬此写法、不引入其依赖**，固定改用 mapstruct-plus 的 `@AutoMapper` + `MapstructUtils.convert`（详见 05 §3.9.1） |

旧项目不是兼容基线。发生冲突时，优先级固定为：

```text
用户已确认并写入本 Wiki/05/字段契约的决策
→ 05-front代码开发约束
→ 06-transfer-consume字段契约（实现 transfer/consume 时）
→ 07-transferAuth-resendTransferAuthCode字段契约（实现平安授权转账/验证码时）
→ 08-withdraw-refund-platform-transfer字段契约（实现提现、退款或中信平台收付款时）
→ 09-channel-transaction-ddl（实现任何交易落库、重复交易检查、状态查询或退款关联时）
→ 09A-channel-transaction-table-field-catalog（字段字典，生成或审查建表 SQL 时）
→ 09B-channel-transaction-ddl-utf8mb4.sql（目标库 utf8mb4/utf8mb4_general_ci 的可执行最终 SQL，手动建表用）
→ 09-final-rebuild-all-tables.sql（全量重建：DROP + CREATE + 分区，目标环境一次性建表用）
→ 10-transaction-query-field-contract（实现交易状态或交易明细查询时）
→ 11-catering-common-framework-catalog（需要确认公共框架已有能力时）
→ 00-任务交接说明
→ 01-front-重构总体结构设计
→ 04-front-service完整重构实施方案
→ 02/03 银行能力汇总
→ 中信退款最新 lsym UAT 参考代码（仅实现中信 refund 时）
→ 当前 catering-front 代码（与上述契约不一致时按缺陷处理）
→ mdl / 旧 Front 参考代码
```

`04` 同时包含目标结构和后续实施计划。凡是其中出现、但当前代码不存在的组件，不得描述成已实现。

## 3. 必读顺序

1. [00-任务交接说明](00-任务交接说明.md)：先确认当前完成状态、明确决策和遗留事项。
2. [05-front代码开发约束](05-front代码开发约束.md)：编码前必须完整阅读，属于强制约束。
3. [01-front-重构总体结构设计](01-front-重构总体结构设计.md)：理解模块、请求、配置、路由和响应边界。
4. [04-front-service完整重构实施方案](04-front-service完整重构实施方案.md)：查看目标流程、Handle 映射和分阶段实施内容。
5. [02-中信银行接口能力汇总](02-中信银行接口能力汇总.md)：实现中信能力时必读。
6. [03-平安银行接口能力汇总](03-平安银行接口能力汇总.md)：实现平安能力时必读。
7. [06-transfer-consume字段契约](06-transfer-consume字段契约.md)：实现 transfer/consume 时必须完整阅读。
8. [07-transferAuth-resendTransferAuthCode字段契约](07-transferAuth-resendTransferAuthCode字段契约.md)：
   实现平安 `transferAuth/resendTransferAuthCode` 时必须完整阅读。
9. [08-withdraw-refund-platform-transfer字段契约](08-withdraw-refund-platform-transfer字段契约.md)：
   实现 `withdraw/refund/platformPay/platformReceive` 时必须完整阅读。
10. [09-channel-transaction-ddl](09-channel-transaction-ddl.md)：实现任何交易落库、重复交易检查、状态查询或退款时
    必须完整阅读，渠道记录固定按“银行 + 交易业务”拆分。
11. [09A-channel-transaction-table-field-catalog](09A-channel-transaction-table-field-catalog.md)：生成、迁移或
    审查数据库 SQL 时必须阅读，其中 10 张表的全部字段、默认值、更新规则和索引均已逐表展开。
11.5. [09B-channel-transaction-ddl-utf8mb4.sql](09B-channel-transaction-ddl-utf8mb4.sql.md)：目标库字符集为
    `utf8mb4 / utf8mb4_general_ci` 时的**可执行最终建表 SQL**，10 张表完整 CREATE TABLE，手动建表直接用这份。
11.6. [09-final-rebuild-all-tables.sql](09-final-rebuild-all-tables.sql)：目标环境**全量重建脚本**，
    DROP + CREATE + 分区，10 张表一次性重建直接用这份。
12. [10-transaction-query-field-contract](10-transaction-query-field-contract.md)：实现单笔状态、平台交易明细或
    账户/登记簿交易明细查询时必须完整阅读。
13. [11-catering-common-framework-catalog](11-catering-common-framework-catalog.md)：需要新增公共返回、异常、
    请求上下文、MyBatis 或 Feign 能力前先确认公共框架是否已有实现。
14. `cateringsass/catering-modules/catering-front/README.md`：最后对照当前代码实际边界。
15. [12-front-implementation-issues](12-front-implementation-issues/README.md)：查看当前静态审查登记的
    实现问题；其他 AI 每次只领取一个问题文件，按其中范围和验收标准修改。

实现中信或平安能力时，应同时阅读 `02` 和 `03` 的公共字段部分，再重点阅读目标银行文档，避免把某家
银行字段错误提升为跨银行通用字段。

## 4. 当前代码已提供的框架

当前框架已经落地，后续 AI 不应重新设计：

- `catering-api-front`：API、请求响应对象、常量和枚举；
- `catering-common-core`：`R`、Front 错误码、`FrontException` 和 Front 公共配置 key；
- `catering-front`：Controller、Application Service、Router、Registry、Handle、配置装配、统一异常和日志；
- 8 个交易 API、5 个查询 API；
- 中信、平安各自的 Transaction/Query Handle 实现类目录；
- 构造器注入 `List<Handle>` 的唯一注册和重复银行校验；
- `FrontRequest → FrontFlowContext → BankRequestContext → Handle` 的上下文骨架；
- `FrontExecutionInfo` 和 `FrontExecutionStage` 的执行元数据骨架；
- `TenantBankConfigProvider`、通用账户配置对象、平安/中信账户特殊配置装配策略；
- transfer/consume 公共金额、收付款会员字段，两家银行字段常量和原始响应码常量；
- 平安 transferAuth/授权码发送重发的基础对象、专用结果、字段常量和明确映射契约；
- 中信、平安 withdraw/refund 的请求对象和字段常量；中信平台收付款字段常量；
- 中信平台交易资金账户明细固定 `bizFunc=25/chnlNo=0010`，登记簿交易明细固定
  `bizFunc=24/chnlNo=0010`，两个查询的 specialData Key、交易类型、账户类型和响应字段常量；
- 中信退款固定为真退款 `/refund + bizFunc=23`，禁止迁移 mdl 的反向转账退款；
- 中信退款字段已与 lsym UAT 分支 `lsym_20260625_limeng_refundTask` 的真退款 Handle 核对；
- 平安 `platformPay/platformReceive` 已明确为 `UNSUPPORTED`；
- 所有交易基础对象已包含来源业务系统、业务交易逻辑类型、业务主记录 ID 和业务子记录 ID；
- 渠道流水 DDL 已按“银行 + 交易业务”拆为中信 6 张、平安 4 张，每张表均含
  `reserve1/reserve2/reserve3`，业务数据按明确字段保存，不保存业务或银行报文快照；
- 10 张渠道表的完整字段字典已逐表列出字段顺序、类型、NULL、默认值、更新规则、注释和索引，可交给其他 AI
  按目标字符集生成最终 SQL；
- 单条交易、交易状态和账户查询返回 `R<具体结果>`；分页明细查询直接返回工程统一的
  `TableDataInfo<TransactionDetailItem>`，禁止再用 `R` 包裹；
  所有 Front 结果通过 `FrontBaseResult` 统一提供 `frontRespCode/frontRespDesc/specialData`；
- `FrontExceptionHandler` 和不输出敏感数据的全链路日志骨架；
- LiteFlow 框架已落地：7 个节点（`frontRequestValidate`/`frontRouteAndCapabilityCheck`/
  `bankHandleContextPrepare`/当前代码旧名 `frontIdempotencyCheck`/`frontTransactionDispatch`/
  `frontQueryDispatch`/`frontResponseNormalize`）+ 13 条链（8 交易 + 5 查询），
  规则文件 `resources/front-flow.xml`，nacos `catering-front.yml` 配置 `liteflow.rule-source`；
- 渠道流水持久层已落地：10 张表的 Entity/VO/Mapper/XML/Service/ServiceImpl 已搬入 main，
  Entity 继承 `TenantEntity` 复用父类审计字段（`createBy`/`createTime`/`updateBy`/`updateTime`）；
- Handle 持久化已接入：`insertInitRecord`（INSERT INIT）→ `updateSending`（UPDATE SENDING）→
  调银行 → `updateResponse`（UPDATE 状态/响应码），退款 `loadOriginalRefundFields`
  从原渠道表加载银行字段；
- ShardingSphere-JDBC 分库：使用 STANDARD 模式，SQL 分片键固定为 `tenant_id`，
  `TenantDataSourceShardingAlgorithm` 根据租户配置中的 `data_source_id` 选择 `ds_x`；
  租户数据源配置属于上线必备配置，正常情况下必须存在；若配置缺失、解析失败或目标数据源不存在，
  必须立即失败，禁止默认进入 `ds_0` 或第一个数据源；
- 不使用 Hint、`HintManager`、`FrontDataSourceHelper` 或 dynamic-datasource 手动切库；
- 4 个必要参数（tenantId/clientId/platformCode/dataSourceId）自动注入：
  `FeignRequestInterceptor`（发送端）→ `RequestContextInterceptor`（接收端，存 ThreadLocal）→
  `BaseDataRequestBodyAdvice`（反序列化后填充到 `FrontRequest<T>.baseData`），Application Service 零改动；
- 交易发送前执行重复交易校验：在当前银行业务表内按
  `tenantId + bizOrderNo + bizSubOrderNo` 查询；命中即返回“交易已存在”，不重复调用银行，
  该规则不称为请求幂等，也不返回或重放旧交易结果。

当前没有完成、应由后续具体任务实现的内容：

- ~~真实 `TenantBankConfigProvider` 远程查询~~（已实现 `RemoteTenantBankConfigProvider`）；
- ~~LiteFlow `FlowExecutor`、组件、EL 规则和链路配置~~（已实现 7 个通用节点、13 条具名链和
  FrontFlowExecutor；业务异常写 Slot 后 `setIsEnd`）；
- ~~中信、平安具体钱包请求对象、签名、加密、HTTP 调用及响应映射~~（已实现，`mvn compile` 通过）；
- ~~`transSsn` 的银行生成算法~~（已实现，落库调用待持久层）；
- 平安全部查询接口先统一为 `PENDING_INTEGRATION`，等待人工逐接口核对字段、bizFunc 和返回数组结构；
- 分页查询 API/Controller/Application Service 已统一为 `TableDataInfo<TransactionDetailItem>`；当前成功
  分支仍需改为使用 `new TableDataInfo<>(records, total)` 或显式设置
  `code=200/msg=查询成功`，并从银行
  `totalNum` 正确填充 `total`；当前 `TransactionDetailQueryData/FrontPageResult/CiticQueryHandle`
  仍保留对外无法承载的 `continuationToken`，必须删除并改为 `pageNo` 直接映射银行页码；
- 当前 `BaseDataRequestBodyAdvice` 未在 `FeignConfiguration` 显式注册，Front 应用又只扫描
  `com.chinaums.front`；即使手工注册，它的 `supports/afterBodyRead` 也只识别外层
  `BaseRequest`，无法注入 `FrontRequest<T>.baseData`。这就是 Front 拦截/注入链未生效的直接原因；
- 当前 `FeignRequestInterceptor` 在没有 Servlet 请求时直接返回，且 tenantId/clientId
  没有 `RequestContext` 兜底；必须对 4 个字段逐一执行“header 优先、RequestContext 补齐”；
- 当前 `FrontFlowExecutor` 在 Slot 业务失败时返回普通 `FrontBaseResult`，但授权码和
  分页 Application Service 立即强转为具体类，会引发 `ClassCastException`。执行器应只返回
  Slot/执行状态，由 Application Service 按声明类型构造失败返回；
- 当前两个 Dispatch Node 没有捕获 `FrontException` 并执行“写 Slot + `setIsEnd(true)`”，
  导致预期业务异常变成 LiteFlow 系统异常；分页路径还会被全局处理成
  `R<FrontBaseResult>`，违反 `TableDataInfo<T>` 协议；
- 当前租户银行配置调用的是 `getConfigMap`，不是已约定的 `getMpConfigValue`；
  必填校验也只检查 appId/appKey/url，必须补齐 mchntId/mchntMbrId 及对应银行账户配置，
  任一配置缺失都必须明确失败；
- 当前 `TenantDataSourceShardingAlgorithm` 的默认数据源兜底仍需删除，改为明确失败；
- 当前重复交易检查仍使用 `Idempotency` 名称和 `IDEMPOTENCY_CONFLICT` 旧文案，
  必须改为 `DuplicateTransaction`/`TRANSACTION_ALREADY_EXISTS`（保留统一码 `F300001`）；
  子流水为空时也必须做 `biz_sub_order_no IS NULL/空值` 的精确等值约束，严格按
  `tenantId + bizOrderNo + bizSubOrderNo` 三字段判定“交易已存在”；
- 当前仍把收付款账户、会员编号或名称放在 `baseData` 的 DTO/Handle，需要改为从 `specialData`
  读取银行协议原始 key；`baseData` 只保留内部业务系统字段。已确认的遗留包括
  `PlatformTransferBusinessData.userAccountId/userAccountName`、查询 DTO 中的银行 accountId/功能账户类型；
- 当前银行 HTTP/解析异常会在渠道记录已更新为 `SENDING` 后直接抛出，没有将记录
  收口为 `UNKNOWN/FAILED`；平安 `resendTransferAuthCode` 还没有任何渠道流水落库；
- 平安 `resendTransferAuthCode` 当前复用了转账 DTO，将协议顶层 `acctNo` 写到
  `outAcctNo`；必须使用 bizFunc=26 的专用请求对象。`receiveMobile` 是否解密仍等待人工核对；
- 两家银行 HTTP Client 的异常日志当前输出完整银行 URL，必须删除，仅记录
  bankCode/apiName/httpStatus/elapsedMs/安全异常分类；
- 当前同时存在 `resources/front-flow.xml` 与 `resources/liteflow/front-flow.xml`，Nacos 注释与
  `rule-source` 实际路径也不一致；必须仅保留一份权威规则文件；
- 数据库迁移执行组件及目标环境建表流程；
- 未经用户明确要求，禁止新增测试类、运行测试或执行编译；本次审查未编译、未运行测试。

## 5. 固定的数据流

```text
对外请求 FrontRequest
├─ baseData
│  ├─ tenantId / storeId / platformCode
│  └─ 交易、交易查询或账户查询的公共强类型字段
└─ specialData: JSONObject
   └─ 当前银行 + 当前能力的动态特殊字段

Application Service
└─ FrontFlowContext
   ├─ capability
   ├─ baseData
   ├─ specialData
   ├─ tenantBankConfig（配置加载后回填）
   ├─ executionInfo
   ├─ result
   └─ failure

AbstractBankHandle.prepareContext
└─ BankRequestContext
   ├─ baseData
   ├─ specialData
   └─ tenantBankConfig
      └─ accountConfig
         ├─ appId/appKey/url/mchntId/mchntMbrId
         └─ accountSpecialData: JSONObject
            ├─ 平安：txnClientNo/mrchCode/stlAcctNo
            └─ 中信：default/self 角色、资金类型及自有资金映射配置

具体银行 Handle
└─ FrontBaseResult 子类
   ├─ frontRespCode/frontRespDesc
   ├─ 公共业务返回字段
   └─ specialData: JSONObject
```

口头所称的“Slot”在业务代码中统一指 `FrontFlowContext`。LiteFlow 自身的内部 Slot 不作为业务对象继承；
当前执行器已经把初始化后的 `FrontFlowContext` 实例传入 13 条规则链。

## 6. 不允许变更的约束

- 不新建 `catering-front-api/common/service` 子模块；
- 不复制旧项目的 `BeanPostProcessor` 注册、复合路由键和任意 `<T> T` 返回；
- 不增加 `FrontResponse`；单条接口返回 `R<具体结果>`，分页明细查询直接返回
  `TableDataInfo<TransactionDetailItem>`，不再使用 `R` 包裹；
- API、Controller、Application Service 使用同一方法签名并原样透传；Router 和 Handle 不返回 `R`；
- 不返回 `null` 或模拟成功；
- 不允许通过反向转账模拟退款；中信退款必须调用真实 `/refund + bizFunc=23`；
- 不复制 lsym UAT 退款请求由调用方直接传 `orgPay/orgRec/orgTrans*` 的来源设计；原交易银行字段必须由
  Front 根据 `originalFrontSsn` 或原业务主/子流水组定位渠道记录后加载；
- 中信退款 `FUND_TP` 不得取 `platformUserRole/default_role/self_role`，应取原交易资金类型，或在原交易
  固定使用默认资金类型时读取 `default_fund_type` 并完成校验；
- 不为平安虚构 `platformPay/platformReceive` 等价接口，这两项固定为 `UNSUPPORTED`；
- 渠道流水必须按银行和交易业务拆表，禁止恢复单一 `front_channel_transaction`；
- 表路由只能由 Front 根据 `platformCode + capability` 显式选择固定 Repository，禁止调用方传表名或
  通过字符串拼接动态 SQL；
- 每张渠道交易表必须保存业务主/子记录关联字段、业务及银行所需明确字段和
  `reserve1/reserve2/reserve3`；不保存报文快照；
- 渠道表允许保存本系统内部使用的账户、会员、姓名、卡号等原始值，本期不要求数据库字段加密；
  但仍禁止在日志、异常消息和普通接口响应中输出这些敏感值；
- 本阶段信任边界是内部系统，ShardingSphere 数据源连接配置的加密和安全加固不作为本期开发、验收项；
  该豁免不影响银行协议要求的签名/加密，也不放宽日志安全要求；
- `baseData` 只保存内部业务系统公共数据；银行侧账户、会员、姓名、卡号等身份类动态数据均放入
  请求 `specialData`，由具体银行 Handle 按常量白名单逐字段映射；
- 重复交易校验固定使用当前银行业务表内的
  `tenantId + bizOrderNo + bizSubOrderNo`；命中返回“交易已存在”，不重放旧结果；
- 不把银行差异字段放入公共 `baseData`；
- 中信明细查询的单个 `transactionDate`、交易类型、登记簿/账户类型必须放入 `specialData`；业务系统
  不得提交 `TRANS_DATE/PAGE/bizFunc/chnlNo`。中信 24/25 不支持跨日，业务系统按日期多次调用；
- 所有金额均以人民币分传递，禁止在 Handle 内使用浮点数或擅自转换为元；
- 不把 `specialData`、`accountSpecialData` 直接 `putAll` 到银行 `reserveMap`；
- 不允许调用方覆盖 `appId/appKey/url/mchntId/mchntMbrId/bizFunc/chnlNo` 以及
  `txnClientNo/mrchCode/stlAcctNo` 等银行账户配置；
- 所有请求、响应、配置、Context、record 组件及枚举值必须有字段级业务注释；
- 银行常量只保留当前真实 Handle 已映射或本次需求明确确认的字段，禁止把 Word 全字段提前搬入代码；
- `bizFunc/chnlNo` 在具体银行 Handle 中按能力使用常量；
- `transTime` 每次请求生成，`transSsn` 由具体银行 Handle 按银行规则生成并保存到渠道流水；
- 租户数据源配置是必备前置条件；STANDARD 分片找不到配置、配置解析失败或目标 `ds_x` 不存在时
  必须立即失败，
  禁止默认路由到任意数据库；
- 钱包 `D5000000/success`、中信 `00000`、平安 `000000` 只用于 Handle 判定，
  `frontRespCode/frontRespDesc` 必须统一取 `FrontErrorCode`；
- 只有 Front 业务成功时顶层 `R.code=200`；银行业务失败时顶层也必须返回失败码，并在 data 内保留
  统一 Front 错误码、说明和状态；业务成功的 `data.frontRespCode` 同样统一为字符串 `"200"`；
- 日志不得输出密钥、完整账户配置、完整 `specialData`、卡号、手机号、证件号或验证码；
- 未收到用户明确要求时，不新增测试类、不运行测试、不执行编译。

## 7. 后续 AI 的实现单位

每次只领取“一个银行 + 一个能力”，例如“中信 transfer”或“平安 queryAccountBalance”。实现步骤固定：

1. 在 `04` 中确认新 Handle 方法与旧 Front/mdl 的映射；
2. 阅读目标银行能力文档并定位 mdl 具体实现类；
3. 列出公共字段、账户特殊配置和业务 `specialData`；
4. 只覆盖目标银行具体 Handle 的明确方法；
5. 通过现有 `BankRequestContext` 读取三段数据，不重新查询配置；
6. 显式映射银行请求和响应，不透传 JSON；
7. 补全入口、路由、配置、请求、响应、耗时和异常日志；
8. 同步更新银行能力文档、总体设计和任务交接说明；
9. 按用户当次授权决定是否写测试或编译；
10. 完成代码和文档后先报告差异；只有用户明确确认后才分别 commit/push 代码仓库和记忆体仓库。

## 8. Handle 方法入口

交易方法：

```text
transfer
transferAuth
resendTransferAuthCode
consume
refund
withdraw
platformPay
platformReceive
```

查询方法：

```text
queryAccountStatus
queryAccountBalance
queryTransactionStatus
queryPlatformTransactionDetails
queryTransactionDetails
```

具体方法与旧 Front、mdl API/Service/Handle/银行实现类的对应关系，以
[04-front-service完整重构实施方案](04-front-service完整重构实施方案.md) 的“Handle 方法映射”和
“交易/交易查询方法关联”章节为准。

## 9. 每次交付必须报告

- 实现了哪个银行、哪个能力；
- 修改了哪些代码与文档；
- 请求字段如何进入银行对象或 `reserveMap`；
- 银行响应如何进入公共结果或返回 `specialData`；
- `transSsn/bizFunc/chnlNo` 的来源；
- 哪些能力仍为 `PENDING_INTEGRATION/UNSUPPORTED`；
- 是否编写测试、运行测试或编译；
- 当前是否未提交；只有用户确认提交后才报告代码仓库和记忆体仓库提交号。
