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
2. 你要实现的方法在 28 号目标 Capability、当前已提交代码、旧 Front 和 mdl 中分别对应什么；
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
| 中信不明来款专项协议 | `saas2.0-memory-hub/docs/中信E管家产品V2_不明来账_客户钱包应用平台_接口文档-内部集成平台.doc` | 本专项能力最终协议基线；交易码 `2033/2025/2023/2087`，不得与综合文档 `24/123` 混用 |
| mdl 参考实现 | `/Users/limeng/workspaces/IdeaProjects_mdl_dep/mdl/fund-catering-front` | 参考真实银行调用和字段映射，不复制旧框架缺陷 |
| 旧 Front 结构参考 | `/Users/limeng/workspaces/IdeaProjects_lsym_dep/slhy/fund-catering/fund-catering-front` | 只参考目录、方法语义和历史实现 |
| lsym 对象转换参考 | `IdeaProjects_lsym_dep/slhy/fund-catering/fund-catering-consume/fund-catering-consume-service/.../consume/domain/Converter.java` | 只参考“存在哪些 Req/Res ↔ Entity/Vo 转换关系”；它用的是原生 mapstruct `@Mapper` 接口，**新工程不照搬此写法、不引入其依赖**，固定改用 mapstruct-plus 的 `@AutoMapper` + `MapstructUtils.convert`（详见 05 §3.9.1） |

旧项目不是兼容基线。发生冲突时，优先级固定为：

```text
用户已确认并写入本 Wiki/28/05/字段契约的决策
→ 28-cateringfront结构简化改造方案（实施结构简化时）
→ 29-cateringfront全量扁平化迁移-plan（当前唯一实施任务）
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
→ 中信不明来款专项文档（仅实现或维护中信不明来款时）
→ 中信退款最新 lsym UAT 参考代码（仅实现中信 refund 时）
→ 当前 catering-front 代码（与上述契约不一致时按缺陷处理）
→ mdl / 旧 Front 参考代码
```

`00` 和 `04` 保留历史交接、设计过程与目标说明，不再承担当前完成状态。凡是其中出现的“已实现/未实现”与
当前代码或 Issue 清单冲突，一律以当前代码、本文、05 和 12 为准。

## 2.1 代码扫描优先使用 CodeGraph（2026-08-14 约定）

工作区已安装 CodeGraph，索引覆盖整个 `IdeaProjects_saas_dep`（含代码仓库与记忆体）。
任何涉及**定位符号、查调用链、评估改动影响面、浏览文件结构**的扫描，必须优先使用 CodeGraph CLI
（与 Cursor 中 codegraph MCP 工具输出一致），再配合 read/grep 看细节：

```bash
codegraph query <符号关键词>   # 搜索符号（同 codegraph_search）
codegraph node <符号>          # 符号源码 + 位置 + 签名（同 codegraph_node）
codegraph explore <查询>       # 相关符号源码 + 调用路径（同 codegraph_explore）
codegraph callers <符号>       # 查找调用者
codegraph callees <符号>       # 查找被调用者
codegraph impact <符号>        # 改动影响面分析
codegraph files                # 项目文件结构
codegraph status               # 索引状态
```

- 索引目录：`IdeaProjects_saas_dep/.codegraph`（SQLite，daemon 自动同步变更）；
- 命令在工作区根目录执行；AI 会话若未暴露 MCP 工具，CLI 是等价通道；
- 底层直查：`sqlite3 .codegraph/codegraph.db`（nodes/edges/files 表，跨工程定位比 grep 精准）。

## 3. 必读顺序

### 3.1 当前正式开发与对接手册

以下四份手册面向后续开发人员和 AI，内容以当前源码已实现能力为边界；进行框架扩展或上游对接时应先按任务范围阅读：

1. [19-catering-front框架与业务功能设计手册](19-catering-front框架与业务功能设计手册.md)：完整了解框架、业务能力、开发规则、约束和新增银行能力案例。
2. [20-catering-front交易接口对接手册](20-catering-front交易接口对接手册.md)：上游对接 8 个交易接口时使用，包含原始字段、银行差异、流程、返回值和调试案例。
3. [21-catering-front交易查询接口对接手册](21-catering-front交易查询接口对接手册.md)：上游对接 5 个查询接口时使用，包含请求/响应原始字段、分页明细、银行差异和调试案例。
4. [27-中信不明来款业务接入手册](27-中信不明来款业务接入手册.md)：上游接入中信不明来款专项能力时使用，包含 2033 列表、2025 退款、2023 重新匹配/实时清分、2087 状态查询的完整强类型契约。

### 3.2 设计契约、实施记录与历史资料

1. [05-front代码开发约束](05-front代码开发约束.md)：编码前必须完整阅读，属于强制约束。
2. [12-front-implementation-issues](12-front-implementation-issues/README.md)：读取当前状态，只领取一个 OPEN 问题。
3. 本次领取的 Issue 子文件及其直接引用的字段契约：先核验当前代码，再决定是否修改。
4. `cateringsass/catering-modules/catering-front/README.md` 和当前代码：确认实际实现，不依赖历史完成声明。
5. [01-front-重构总体结构设计](01-front-重构总体结构设计.md)：理解模块、请求、配置、路由和响应边界。
6. [04-front-service完整重构实施方案](04-front-service完整重构实施方案.md)：只查看目标流程和 Handle 映射；
   其中历史实施进度不作为当前状态。
7. [02-中信银行接口能力汇总](02-中信银行接口能力汇总.md)：实现中信能力时必读。
8. [03-平安银行接口能力汇总](03-平安银行接口能力汇总.md)：实现平安能力时必读。
9. [06-transfer-consume字段契约](06-transfer-consume字段契约.md)：实现 transfer/consume 时必须完整阅读。
10. [07-transferAuth-resendTransferAuthCode字段契约](07-transferAuth-resendTransferAuthCode字段契约.md)：
   实现平安 `transferAuth/resendTransferAuthCode` 时必须完整阅读。
11. [08-withdraw-refund-platform-transfer字段契约](08-withdraw-refund-platform-transfer字段契约.md)：
   实现 `withdraw/refund/platformPay/platformReceive` 时必须完整阅读。
12. [09-channel-transaction-ddl](09-channel-transaction-ddl.md)：实现任何交易落库、重复交易检查、状态查询或退款时
    必须完整阅读，渠道记录固定按“银行 + 交易业务”拆分。
13. [09A-channel-transaction-table-field-catalog](09A-channel-transaction-table-field-catalog.md)：生成、迁移或
    审查数据库 SQL 时必须阅读，其中 10 张表的全部字段、默认值、更新规则和索引均已逐表展开。
14. [09B-channel-transaction-ddl-utf8mb4.sql](09B-channel-transaction-ddl-utf8mb4.sql.md)：目标库字符集为
    `utf8mb4 / utf8mb4_general_ci` 时的**可执行最终建表 SQL**，10 张表完整 CREATE TABLE，手动建表直接用这份。
15. [09-final-rebuild-all-tables.sql](09-final-rebuild-all-tables.sql)：目标环境**全量重建脚本**，
    DROP + CREATE + 分区，10 张表一次性重建直接用这份。
16. [09C-citic-refund-legacy-columns-nullable.sql](09C-citic-refund-legacy-columns-nullable.sql)：已有库仅放宽
    中信退款 5 个兼容列非空约束的 ALTER 脚本；不删列、不删索引、不修改平安表。
17. [10-transaction-query-field-contract](10-transaction-query-field-contract.md)：实现单笔状态、平台交易明细或
    账户/登记簿交易明细查询时必须完整阅读。
18. [11-catering-common-framework-catalog](11-catering-common-framework-catalog.md)：需要新增公共返回、异常、
    请求上下文、MyBatis 或 Feign 能力前先确认公共框架是否已有实现。
19. [00-任务交接说明](00-任务交接说明.md)：仅在需要追溯历史决策时阅读，不作为当前完成状态。
20. [14-catering-web-test-使用说明](14-catering-web-test-使用说明.md)：catering-front 接口测试工具的使用与维护文档，修改测试工具前应先阅读。
21. [15-交易额外数据标准化-spec](15-交易额外数据标准化-spec.md)：specialData 组装工具类
    （`FrontSpecialDataAssembler`，api-front 实例工具类、全实例方法零 static）的标准账户结构（pay/rec）与
    (bank × capability) 组装矩阵契约；改动交易请求结构、组装工具类或 consume 侧组装 check 前必须完整阅读。
22. [16-交易额外数据标准化-plan](16-交易额外数据标准化-plan.md)：15 号 spec 的执行计划与实施记录
    （2026-08-17 工具类 + 7 个 check 骨架已落地；余 web-test 两步调用、buildRequest 补实与挂链）。
23. [17-明细查询对外契约与平安启用-spec](17-明细查询对外契约与平安启用-spec.md)：24/25 明细查询
    对外契约重构（AccountTransDetailItem/PlatformTransDetailItem 两套独立 DTO + TableDataInfo.totalPage + §1.3
    原对象迁移对照）与平安明细启用（6048/6050/6073）的契约，含用户九条裁决；实施前必须完整阅读。
24. [18-明细查询对外契约与平安启用-plan](18-明细查询对外契约与平安启用-plan.md)：17 号 spec 的
    分阶段执行计划与任务清单（T1-T11）。
25. [22-lsym-pa授权转账原始流程](22-lsym-pa授权转账原始流程.md)：lsym 平安授权转账
    （transferAuth/resendTransferAuthCode）两阶段业务流程基线（front Handle + consume 编排）。
26. [23-lsym-pa授权转账原始功能字段](23-lsym-pa授权转账原始功能字段.md)：同两接口的 lsym
    字段级输入/银行报文/返回映射基线。
27. [24-平安授权转账迁移改造方案](24-平安授权转账迁移改造方案.md)：SaaS 现状对照、差异核对项
    （receiveMobile 加密口径、验证码申请 tranType）与 consume 侧对接方案。
28. [25-平安授权转账接口改造-spec](25-平安授权转账接口改造-spec.md)：两接口对外契约
    定稿（语义键 authType/authOrderNo/authCode、payMemberCode、R<FrontTransResult> 公用）。
29. [26-平安授权转账接口改造-plan](26-平安授权转账接口改造-plan.md)：25 号 spec 的分阶段
    执行计划（T1-T18、波及文件总表、风险与回退）。
30. [27-中信不明来款业务接入手册](27-中信不明来款业务接入手册.md)：中信专项能力的最终对接说明；
    本能力不进入通用 `FrontCapability`，请求/返回均不使用 `specialData`。
31. [28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)：已批准但尚未实施的全量扁平化目标设计。
32. [29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)：
    下一位 AI 的唯一活动任务文档；覆盖 22 个通用能力、13 条链、旧结构删除、静态验收与授权门禁。

实现中信或平安能力时，应同时阅读 `02` 和 `03` 的公共字段部分，再重点阅读目标银行文档，避免把某家
银行字段错误提升为跨银行通用字段。

## 4. 当前代码已提供的框架

当前框架已经落地，后续 AI 不应重新设计：

- `catering-api-front`：API、请求响应对象、常量和枚举；
- `catering-common-core`：`R`、Front 错误码、`FrontException` 和 Front 公共配置 key；
- `catering-front`：Controller、Application Service、Router、Registry、Handle、配置装配、统一异常和日志；
- 8 个通用交易 API、5 个通用查询 API，以及中信不明来款 3 个专项 API；
- 每个 API 方法在服务内部固定自己的 `FrontCapability`，调用方不能传入或覆盖；Transaction/Query Registry
  已按 `(BankCode, FrontCapability)` 建立不可变映射，同一领域重复复合键会在启动时失败；
- 中信、平安 Transaction/Query 实现通过 `capabilityDefinitions()` 声明当前银行实际登记的能力；Registry
  将每个声明绑定为 `BankCapabilityHandle`，路由节点选中后由 Dispatch 直接执行，不再 `switch(capability)`；
- `FrontRequest → FrontFlowContext → BankRequestContext → Handle` 的上下文骨架；
- `FrontExecutionInfo` 和 `FrontExecutionStage` 的执行元数据骨架；
- `TenantBankConfigProvider`、通用账户配置对象、平安/中信账户特殊配置装配策略；
- 银行账户配置固定为两次配置接口查询：先用 `support_bank_config` 动态解析模板 key，再在当前
  `tenantId` 上下文中用该 key 查询用户银行配置；`configVersion/config_version` 已废弃且禁止恢复；
- transfer/consume 公共金额、收付款会员字段，两家银行字段常量和原始响应码常量；
- 平安 transferAuth/授权码发送重发的基础对象、对外语义键（authType/authOrderNo/authCode/
  payMemberCode/recMemberCode，2026-08-21 起）、公用 `R<FrontTransResult>` 出参与明确映射契约；
- 中信、平安 withdraw/refund 的请求对象和字段常量；中信平台收付款字段常量；
- 中信平台交易资金账户明细固定 `bizFunc=25/chnlNo=0010`，登记簿交易明细固定
  `bizFunc=24/chnlNo=0010`，两个查询的 specialData Key、交易类型、账户类型和响应字段常量；
- 中信退款固定为真退款 `/refund + bizFunc=23`，禁止迁移 mdl 的反向转账退款；
- 中信退款字段已与 lsym UAT 分支 `lsym_20260625_limeng_refundTask` 的真退款 Handle 核对；
- 中信不明来款专项能力已落地：独立 `CiticUnidentifiedRemittanceApi` 提供列表、统一处理和状态查询，
  固定使用 `2033/2025/2023/2087 + chnlNo=0010`；请求/返回全字段强类型、无 `specialData`，
  仅复用租户上下文注入、`tenant_base_config` 和 `TenantBankConfigProvider`；
- 平安 `platformPay/platformReceive` 已明确为 `UNSUPPORTED`；
- 所有交易基础对象已包含来源业务系统、业务交易逻辑类型、业务主记录 ID 和业务子记录 ID；
- 渠道流水 DDL 已按“银行 + 交易业务”拆为中信 6 张、平安 4 张，每张表均含
  `reserve1/reserve2/reserve3`，业务数据按明确字段保存，不保存业务或银行报文快照；
- 10 张渠道表的完整字段字典已逐表列出字段顺序、类型、NULL、默认值、更新规则、注释和索引，可交给其他 AI
  按目标字符集生成最终 SQL；
- 单条交易、交易状态和账户查询返回 `R<具体结果>`；分页明细查询直接返回工程统一的
  `TableDataInfo<AccountTransDetailItem>` / `TableDataInfo<PlatformTransDetailItem>`（24/25 各一套行 DTO），禁止再用 `R` 包裹；
  所有 Front 结果通过 `FrontBaseResult` 统一提供 `frontRespCode/frontRespDesc/specialData`；
- `FrontExceptionHandler` 和结构化日志工具；交易链路记录入口、能力、渠道状态、钱包和异常事件，
  查询链路在统一 Gateway 发送前记录一次脱敏摘要；任何链路均不得输出完整敏感请求/响应；
- 当前已提交基线仍使用原 LiteFlow 公共节点、Router/Registry/Handle 和三段式上下文；
  28 号目标结构尚未实施。2026-08-25 的未提交全面改造已放弃，不能据其声明当前框架已经切换；
- 下一轮按 28/29 号全量迁移：13 条链统一为 `THEN(frontValidate, tenantResolve, bankRoute)`，
  Slot 严格两层，中信/平安全部通用能力按 `channel/{bank}/{capability}` 分组；
  唯一规则文件 `resources/liteflow/front-flow.xml`，Nacos `catering-front.yml` 的
  `liteflow.rule-source` 固定为 `liteflow/front-flow.xml`；
- 渠道流水持久层已落地：10 张表的 Entity/VO/Mapper/XML/Service/ServiceImpl 已搬入 main，
  Entity 继承 `TenantEntity` 复用父类审计字段（`createBy`/`createTime`/`updateBy`/`updateTime`）；
- Handle 持久化已接入：`insertInitRecord`（INSERT INIT）→ `updateSending`（UPDATE SENDING）→
  调银行 → `updateResponse`（UPDATE 状态/响应码）；中信退款不再查询原渠道表补字段，固定使用
  `originalBizOrderNo + originalBizSubOrderNo` 组装银行原交易定位字段；五个旧 `original_*` 列仅作为可空兼容列保留；
- ShardingSphere-JDBC 分库：使用 STANDARD 模式，分片键固定为 `data_source_id`，
  `TenantDataSourceShardingAlgorithm` 直接把 `data_source_id` 的值拼成 `ds_x` 路由（不查配置中心）；
  `data_source_id` 由业务请求方在 `baseData` 传入，请求头同名字段用于跨服务透传与落库记录；
  `data_source_id` 缺失时先由链路前置节点 `tenantBaseConfigResolve` 从
  `tenant_base_config` 回填（2026-08-20 起，调用方最少只需传 tenantId + clientId）；
  回填后仍为空、或计算出的 `ds_x` 不在可用数据源列表，必须立即失败，
  禁止默认进入 `ds_0` 或第一个数据源；
- 不使用 Hint、`HintManager`、`FrontDataSourceHelper` 或 dynamic-datasource 手动切库；
- 4 个必要参数（tenantId/clientId/platformCode/dataSourceId）自动注入；每个请求由
  `tenantBaseConfigResolve` 节点用 tenantId 从 `tenant_base_config` 一次查询取出
  clientId/platformCode/dataSourceId/supportBankConfig，缺省回填前三者（显式传入优先，
  调用方最少只需传 tenantId），银行配置加载复用 supportBankConfig 免二次查询：
  `FeignRequestInterceptor`（发送端）→ `RequestContextInterceptor`（接收端，存 ThreadLocal）→
  `BaseDataRequestBodyAdvice`（反序列化后填充到 `FrontRequest<T>.baseData`），Application Service 零改动；
- 交易发送前执行重复交易校验：在当前银行业务表内按
  `tenantId + bizOrderNo + bizSubOrderNo` 查询；命中即返回“交易已存在”，不重复调用银行，
  该规则不称为请求幂等，也不返回或重放旧交易结果；按已确认部署边界不增加跨实例分布式锁。

## 4.1 Issue 与后续待办入口

当前完成状态只以 [12-front-implementation-issues/README.md](12-front-implementation-issues/README.md)
及各问题子文件为准；平安延后工作只记录在 [13-front后续待办](13-front后续待办.md)，不作为 Issue。
本页不再复制会漂移的"未完成"明细。领取任务前必须重新核对当前代码：

- `OPEN`：当前代码仍有未满足的验收项，可按清单顺序领取；
- `FIXED_PENDING_REVIEW`：已有静态修复证据，只等待用户确认，不得重复修改；
- `CLOSED`：用户已确认，不得根据历史文档重新实现；
- `DEFERRED`：安全或外部治理事项，必须另行授权。

P0/P1/P2 共 28 项功能 Issue 与独立 TODO-002 已全部 `CLOSED`（2026-08-20 用户确认
P1-015、P2-008、TODO-002 关闭；此前 25 项已于 2026-08-19 确认）。当前无 `OPEN`
功能 Issue。

平安账户状态/余额 2 个查询已按用户裁决固定保留 `ADAPTER_NOT_READY` 挡板，TODO-001 已关闭，
不得主动领取；平安退款 TODO-002 已于 2026-08-20 经用户 review 确认关闭；
report 跨实例重复交易补查已按用户裁决暂缓，
未经新的明确要求不得开发；
明文凭据轮换和 Git 历史清理由独立安全事项跟踪。
任何历史文档中的"未实现""待改""编译通过"均不是当前状态证据。

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
   ├─ capability（API 方法内部赋值；用于银行 + 能力精确路由及交易渠道流水能力记录）
   ├─ baseData
   ├─ specialData
   ├─ accountConfig（配置加载后回填）
   ├─ executionInfo
   ├─ result
   └─ failure

AbstractBankHandle.prepareContext
└─ BankRequestContext
   ├─ baseData
   ├─ specialData
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
- 不复制旧项目的 `BeanPostProcessor` 注册、字符串拼接或混入账户类型/bizFunc 的复合路由键，以及任意
  `<T> T` 返回；领域 Registry 的类型安全 `(BankCode, FrontCapability)` 是本项目规定的必要路由键，
  不属于此禁令；
- 不增加 `FrontResponse`；单条接口返回 `R<具体结果>`，分页明细查询直接返回
  `TableDataInfo<AccountTransDetailItem>` / `TableDataInfo<PlatformTransDetailItem>`（24/25 各一套行 DTO），不再使用 `R` 包裹；
- API、Controller、Application Service 使用同一方法签名并原样透传；内部 Route 和 Capability 不返回 `R`；
- 不返回 `null` 或模拟成功；
- 不允许通过反向转账模拟退款；中信退款必须调用真实 `/refund + bizFunc=23`；
- 中信退款对外固定使用 `originalBizOrderNo + originalBizSubOrderNo`，映射银行
  `ORI_BUSS_ID + ORI_BUSS_SUB_ID`；不得把 Front 的 `orgFrontSsn/transSsn` 当成中信
  `ORI_USER_SSN`，也不得为了补齐银行字段查询 Front 本地原交易表；
- 中信退款的 `ORI_USER_D_ID/ORI_USER_D_NM/ORI_USER_C_ID/ORI_USER_TRANS_DT` 是定位字段之外的
  独立必填协议字段，由上游在请求 `specialData` 中使用银行原始 key 提供；`ORI_USER_C_NM` 按银行协议选填。
  Capability 必须逐字段校验和映射，禁止整体透传；
- 中信退款 `FUND_TP` 当前取 `accountSpecialData.default_fund_type`，该配置必须存在；不得取
  `platformUserRole/default_role/self_role`，也不查询原交易进行比对；
- 不为平安虚构 `platformPay/platformReceive` 等价接口，这两项固定为 `UNSUPPORTED`；
- 渠道流水必须按银行和交易业务拆表，禁止恢复单一 `front_channel_transaction`；
- 28 号全量迁移中，API 方法内部固定 capability 并写入请求域 Slot；银行分发只允许
  `BankRouteNode → BankCapabilityRegistry → BankCapability`，Registry 按能力类
  `bank()/capability()` 自描述注册并在启动时拒绝重复键。能力类使用自己的固定渠道表 Mapper；
  禁止增加 Router/Dispatch/Handle 继承体系，禁止按 capability 动态选表，禁止调用方传表名或拼接动态 SQL；
- 每张渠道交易表必须保存业务主/子记录关联字段、业务及银行所需明确字段和
  `reserve1/reserve2/reserve3`；不保存报文快照；
- 渠道表允许按当前契约保存本系统内部使用的账户、会员、姓名、卡号等原始值，本期不要求数据库字段加密；
  该规则不放宽日志边界，日志、异常和普通接口响应不得输出密钥、完整账号/卡号、手机号、证件号、姓名或验证码；
- 本阶段信任边界是内部系统，ShardingSphere 数据源连接配置的加密和安全加固不作为本期开发、验收项；
  该豁免不影响银行协议要求的签名/加密，也不放宽日志敏感信息保护；
- `baseData` 只保存内部业务系统公共数据；银行侧账户、会员、姓名、卡号等身份类动态数据均放入
  请求 `specialData`，由具体银行 Capability 按常量白名单逐字段映射；
- 重复交易校验固定使用当前银行业务表内的
  `tenantId + bizOrderNo + bizSubOrderNo`；命中返回“交易已存在”，不重放旧结果；
- 不把银行差异字段放入公共 `baseData`；
- 中信明细查询的单个 `transactionDate`、交易类型、登记簿/账户类型必须放入 `specialData`；业务系统
  不得提交 `TRANS_DATE/PAGE/bizFunc/chnlNo`。中信 24/25 不支持跨日，业务系统按日期多次调用；
- 所有金额均以人民币分传递，禁止在 Capability 内使用浮点数或擅自转换为元；
- 不把 `specialData`、`accountSpecialData` 直接 `putAll` 到银行 `reserveMap`；
- 不允许调用方覆盖 `appId/appKey/url/mchntId/mchntMbrId/bizFunc/chnlNo` 以及
  `txnClientNo/mrchCode/stlAcctNo` 等银行账户配置；
- 所有请求、响应、配置、Context、record 组件及枚举值必须有字段级业务注释；
- 银行常量只保留当前真实能力已映射或本次需求明确确认的字段，禁止把 Word 全字段提前搬入代码；
- `bizFunc/chnlNo/API path` 在具体银行 Capability 中使用带业务注释的本地常量；字段 key 才进入
  `*ContractKeys`，不得在两处重复保存同一调用控制值；
- `transTime` 每次请求生成，`transSsn` 由具体银行 Capability 按银行规则生成并保存到渠道流水；
- 平安查询流水必须按场景分离：单笔状态查询使用原请求 `frontSsn/front_ssn → oriTransSsn`；
  6073 明细订单补全使用原应答 `queryId/bank_query_id = recordList.frontSeqNo`；
  `bank_user_ssn` 只保存明确返回的 `USER_SSN/ssn`，三者禁止互换；
- 租户数据源配置是必备前置条件；STANDARD 分片找不到配置、配置解析失败或目标 `ds_x` 不存在时
  必须立即失败，
  禁止默认路由到任意数据库；
- 钱包 `D5000000/success`、中信 `00000`、平安 `000000` 只用于 Capability 判定，
  `frontRespCode/frontRespDesc` 必须统一取 `FrontErrorCode`；
- 只有 Front 业务成功时顶层 `R.code=200`；银行业务失败时顶层也必须返回失败码，并在 data 内保留
  统一 Front 错误码、说明和状态；业务成功的 `data.frontRespCode` 同样统一为字符串 `"200"`；
- 交易链路按 05 §8 在 Capability 真实步骤附近记录开始、流水状态、钱包发送、响应和异常；
  请求/响应只记录脱敏摘要，不输出完整敏感 JSON；`Authorization`、签名头和完整银行 URL不进入日志；
- 结构简化执行全量迁移，但不得改变能力支持状态、创建虚假银行能力或提前抽象未来能力；
- 未收到用户明确要求时，不新增测试类、不运行测试、不执行编译。

## 7. 后续 AI 的实现单位

当前唯一可领取单位是 29 号全量扁平化迁移。实现步骤固定：

1. 完整阅读 28 号方案，并以当前已提交 HEAD 为实现基线；已放弃的未提交全面改造不得续写或复制；
2. 在 `04`、`06`、中信能力文档、当前已提交代码、旧 Front 和 mdl 中核对 transfer 行为；
3. 先列出 API 禁改区、字段来源、账户配置、渠道流水、错误码和日志基线；
4. 建立两层 Slot、`flow/slot|node|route`，并迁移中信/平安 22 个通用能力；
5. 每个交易 Capability 按“校验→组报文→查重/INIT→SENDING→统一 Gateway 发送→响应落库/结果”顺序展开；
6. 不增加业务 Context、Handle 继承、BankSupport、Router、Dispatch 或多层 Wallet Client；
7. 13 条链全部切换完成后删除旧 Context/Router/Dispatch/Handle 体系；
8. 按用户当次授权决定是否写测试或编译；未授权时只做静态核验并如实说明；
9. 完成后提交 22 项能力矩阵、13 条链、删除清单和行为差异给用户 review；
10. 只有用户明确确认后才分别 commit/push 代码仓库和记忆体仓库。

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
queryAccountStatus              // 平安固定保留 ADAPTER_NOT_READY 挡板
queryAccountBalance             // 平安固定保留 ADAPTER_NOT_READY 挡板
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
