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

旧项目不是兼容基线。发生冲突时，优先级固定为：

```text
当前 catering-front 代码
→ 05-front代码开发约束
→ 06-transfer-consume字段契约（实现 transfer/consume 时）
→ 07-transferAuth-resendTransferAuthCode字段契约（实现平安授权转账/验证码时）
→ 08-withdraw-refund-platform-transfer字段契约（实现提现、退款或中信平台收付款时）
→ 09-channel-transaction-ddl（实现任何交易落库、幂等、状态查询或退款关联时）
→ 09A-channel-transaction-table-field-catalog（生成或审查建表 SQL 时）
→ 10-transaction-query-field-contract（实现交易状态或交易明细查询时）
→ 00-任务交接说明
→ 01-front-重构总体结构设计
→ 04-front-service完整重构实施方案
→ 02/03 银行能力汇总
→ 中信退款最新 lsym UAT 参考代码（仅实现中信 refund 时）
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
10. [09-channel-transaction-ddl](09-channel-transaction-ddl.md)：实现任何交易落库、幂等、状态查询或退款时
    必须完整阅读，渠道记录固定按“银行 + 交易业务”拆分。
11. [09A-channel-transaction-table-field-catalog](09A-channel-transaction-table-field-catalog.md)：生成、迁移或
    审查数据库 SQL 时必须阅读，其中 10 张表的全部字段、默认值、更新规则和索引均已逐表展开。
12. [10-transaction-query-field-contract](10-transaction-query-field-contract.md)：实现单笔状态、平台交易明细或
    账户/登记簿交易明细查询时必须完整阅读。
13. `cateringsass/catering-modules/catering-front/README.md`：最后对照当前代码实际边界。

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
  `reserve1/reserve2/reserve3`，并保留业务明确列和完整业务加密快照；
- 10 张渠道表的完整字段字典已逐表列出字段顺序、类型、NULL、默认值、更新规则、注释和索引，可交给其他 AI
  按目标字符集生成最终 SQL；
- 所有接口直接返回 `R<具体结果>`，所有结果通过 `FrontBaseResult` 统一提供
  `frontRespCode/frontRespDesc/specialData`；
- `FrontExceptionHandler` 和不输出敏感数据的全链路日志骨架。

当前没有完成、应由后续具体任务实现的内容：

- 真实 `TenantBankConfigProvider` 远程查询；
- LiteFlow `FlowExecutor`、组件、EL 规则和链路配置；
- 中信、平安具体钱包请求对象、签名、加密、HTTP 调用及响应映射；
- 平安查询和其他尚未逐项确认能力的 `specialData ↔ reserveMap` 最终字段契约；
- `transSsn` 的银行生成算法和真实落库调用；
- 渠道 Entity、Mapper、Repository、显式表路由、幂等和状态机；
- 数据库迁移执行组件及目标环境建表流程；
- 未经用户明确要求的测试类和编译验证。

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
后续接入 LiteFlow 时应传入已经初始化的 `FrontFlowContext` 实例。

## 6. 不允许变更的约束

- 不新建 `catering-front-api/common/service` 子模块；
- 不复制旧项目的 `BeanPostProcessor` 注册、复合路由键和任意 `<T> T` 返回；
- 不增加 `FrontResponse`，API 必须直接返回 `R<具体结果>`；
- 不让 Application、Router 或 Handle 返回公共 `R`；
- 不返回 `null` 或模拟成功；
- 不允许通过反向转账模拟退款；中信退款必须调用真实 `/refund + bizFunc=23`；
- 不复制 lsym UAT 退款请求由调用方直接传 `orgPay/orgRec/orgTrans*` 的来源设计；原交易银行字段必须由
  Front 根据 `originalFrontSsn` 加载；
- 中信退款 `FUND_TP` 不得取 `platformUserRole/default_role/self_role`，应取原交易资金类型，或在原交易
  固定使用默认资金类型时读取 `default_fund_type` 并完成校验；
- 不为平安虚构 `platformPay/platformReceive` 等价接口，这两项固定为 `UNSUPPORTED`；
- 渠道流水必须按银行和交易业务拆表，禁止恢复单一 `front_channel_transaction`；
- 表路由只能由 Front 根据 `platformCode + capability` 显式选择固定 Repository，禁止调用方传表名或
  通过字符串拼接动态 SQL；
- 每张渠道交易表必须保存业务主/子记录关联字段、业务基础数据加密快照和
  `reserve1/reserve2/reserve3`；
- 不把银行差异字段放入公共 `baseData`；
- 中信明细查询的日期范围、交易类型、登记簿/账户类型必须放入 `specialData`；业务系统不得提交
  `TRANS_DATE/PAGE/bizFunc/chnlNo`，Handle 必须按日期范围逐日组装银行单日查询；
- 所有金额均以人民币分传递，禁止在 Handle 内使用浮点数或擅自转换为元；
- 不把 `specialData`、`accountSpecialData` 直接 `putAll` 到银行 `reserveMap`；
- 不允许调用方覆盖 `appId/appKey/url/mchntId/mchntMbrId/bizFunc/chnlNo` 以及
  `txnClientNo/mrchCode/stlAcctNo` 等银行账户配置；
- 所有请求、响应、配置、Context、record 组件及枚举值必须有字段级业务注释；
- 银行常量只保留当前真实 Handle 已映射或本次需求明确确认的字段，禁止把 Word 全字段提前搬入代码；
- `bizFunc/chnlNo` 在具体银行 Handle 中按能力使用常量；
- `transTime` 每次请求生成，`transSsn` 由具体银行 Handle 按银行规则生成并保存到渠道流水；
- 钱包 `D5000000/success`、中信 `00000`、平安 `000000` 只用于 Handle 判定，
  `frontRespCode/frontRespDesc` 必须统一取 `FrontErrorCode`；
- Handle 已正常识别的银行业务成功或失败，顶层 `R.code` 都必须是全局成功码数值 `200`；
  业务成功的 `data.frontRespCode` 同样统一为字符串 `"200"`，银行失败由 data 内统一错误码和状态表达；
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
10. 分别提交代码仓库和记忆体仓库，并报告提交号。

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
- 代码仓库和记忆体仓库提交号。
