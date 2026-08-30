# Front 重构 Wiki：AI 开发入口

> 本页是其他 AI 参与 Front 重构时的唯一入口。不要只把某个银行文档或某个 Java 文件单独交给 AI；
> 必须先让它完整阅读本页，再按本文规定的顺序读取相关文档和代码。

## 1. 给新 AI 的开场指令

可以把下面这段直接发给接手任务的 AI：

```text
先完整阅读 saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md，
再严格按其中的“必读顺序”读取文档和当前代码。不要根据旧项目直接复制实现。

阅读完成后，先向我说明：
1. 当前代码已经提供哪些框架能力（含 FrontAccountController/FrontAccountApi 的账户管理入口）；
2. FRONT-ACC-001 账户维护任务的当前进度与未完成项；
3. 你准备修改哪些文件；
4. 哪些字段进入 baseData、specialData、accountConfig、accountSpecialData；
5. 本次是否收到编写测试或执行编译的明确授权。

确认上述信息后，按 FRONT-ACC-001 的任务范围继续实施当前活动任务。
28、29 号三域注册方案【已完成实施】，是设计基线与历史实施记录——禁止重新执行 29 号计划
或重做已完成的三域迁移。"只做一个能力"的旧限制已取消；实施范围以最新活动任务和全量迁移要求为准。
"既有 API 零变化"只约束迁移既有能力类任务；新增业务能力任务（如账户维护）允许按契约新增 API。
```

## 2. 仓库与参考项目

| 用途 | 路径 / 分支 | 规则 |
|---|---|---|
| SaaS 代码仓库 | `/Users/limeng/workspaces/IdeaProjects_saas_dep/cateringsass`。历史基线：`limeng_front_restruct@0dd983a7`（第一阶段扁平化）；静态核验基线：`master@d164c7e7`（2026-08-30 复核，含 tenant_id 分片切换；`limeng_front@4829d1d7` 落后 master 仅 1 个文档提交） | 当前开发目标分支为 limeng_front |
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
→ 29-cateringfront全量扁平化迁移-plan（已实施完成，历史基线记录）
→ 05-front代码开发约束
→ 01-front-重构总体结构设计
→ 04-front-service完整重构实施方案
→ 19-catering-front框架与业务功能设计手册
→ 06-transfer-consume字段契约（实现 transfer/consume 时）
→ 07-transferAuth-resendTransferAuthCode字段契约（实现平安授权转账/验证码时）
→ 08-withdraw-refund-platform-transfer字段契约（实现提现、退款或中信平台收付款时）
→ 09-channel-transaction-ddl（实现任何交易落库、重复交易检查、状态查询或退款关联时）
→ 09A-channel-transaction-table-field-catalog（字段字典，生成或审查建表 SQL 时）
→ 09B-channel-transaction-ddl-utf8mb4.sql（目标库 utf8mb4/utf8mb4_general_ci 的可执行最终 SQL，手动建表用）
→ 09-final-rebuild-all-tables.sql（全量重建：DROP + CREATE + 分区，目标环境一次性建表用）
→ 10-transaction-query-field-contract（实现交易状态或交易明细查询时）
→ 11-catering-common-framework-catalog（需要确认公共框架已有能力时）
→ 02/03 银行能力汇总
→ 00-任务交接说明（仅追溯历史）
→ 中信不明来款专项文档（仅实现或维护中信不明来款时）
→ 中信退款最新 lsym UAT 参考代码（仅实现中信 refund 时）
→ 当前 catering-front 代码（与上述契约不一致时按缺陷处理）
→ mdl / 旧 Front 参考代码
```

`00` 保留历史交接，不承担当前完成状态。01、04、19 已同步为三域现行设计；实际完成状态仍必须核对
当前代码和 29 号任务清单，不得仅凭设计文档的目标描述判断已经实现。

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
3. [21-catering-front交易查询接口对接手册](21-catering-front交易查询接口对接手册.md)：上游对接
   3 个 Query 域接口和 2 个 Account 域接口时使用，包含请求/响应原始字段、分页明细、银行差异和调试案例。
4. [27-中信不明来款业务接入手册](27-中信不明来款业务接入手册.md)：上游接入中信不明来款专项能力时使用，包含 2033 列表、2025 退款、2023 重新匹配/实时清分、2087 状态查询的完整强类型契约。

### 3.2 设计契约、实施记录与历史资料

1. [05-front代码开发约束](05-front代码开发约束.md)：编码前必须完整阅读，属于强制约束。
2. [12-front-implementation-issues](12-front-implementation-issues/README.md)：读取当前状态，只领取一个 OPEN 问题。
3. 本次领取的 Issue 子文件及其直接引用的字段契约：先核验当前代码，再决定是否修改。
4. `cateringsass/catering-modules/catering-front/README.md` 和当前代码：确认实际实现，不依赖历史完成声明。
5. [01-front-重构总体结构设计](01-front-重构总体结构设计.md)：理解模块、请求、配置、路由和响应边界。
6. [04-front-service完整重构实施方案](04-front-service完整重构实施方案.md)：历史迁移期的 Service 文件职责、
   当时 22 个 Capability 实现类归域、13 条链和实施/验收顺序；当前数量以本 Wiki §4 为准。
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
31. [28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)：最终三域单节点目标设计。
    【已实施】作为设计基线保留；不得重新执行或重做三域迁移。
32. [29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)：
    【已实施】历史基线记录（含两轮验收史与分片键全覆盖修复记录）；不得重新打开为待实施。
    当前活动任务见 [FRONT-ACC-001 账户维护](12-front-implementation-issues/FRONT-ACC-001-account-maintenance-in-progress.md)。
33. [30-cateringfront扁平化迁移交付报告](30-cateringfront扁平化迁移交付报告.md)：三域裁决之前的
    `frontBankExecute + 单一 Registry` 历史交付快照；不得作为三域最终验收证据。

实现中信或平安能力时，应同时阅读 `02` 和 `03` 的公共字段部分，再重点阅读目标银行文档，避免把某家
银行字段错误提升为跨银行通用字段。

## 4. 当前代码已提供的框架

当前业务能力、扁平化第一阶段与三域注册均已落地（三域注册为已实施基线，禁止重新实施）。后续 AI 不应另起架构：

**数量口径（历史基线与当前源码分列）**：
- 28/29 号历史基线：22 个银行 Capability 实现类、13 条链（交易 8 / 查询 3 / 账户 2）；
- 当前源码（`master@d164c7e7`，2026-08-30 静态复核）：`FrontCapability` 枚举 21 项，
  **银行 Capability 实现类 29 个、LiteFlow 链 21 条**——实现类分布为交易 12 / 查询 6 / 账户 11
  （账户 11 = 中信 9 + 平安挡板 2）；
  链分布 8 交易 / 3 查询 / 10 账户（账户 10 = 既有状态/余额查询 2 + 账户维护 8）。
  枚举中的 `RECHARGE` 当前没有 Front API 或银行 Capability 实现，不能按枚举项数推导 API 数。

- `catering-api-front`：API、请求响应对象、常量和枚举；
- `catering-common-core`：`R`、Front 错误码、`FrontException` 和 Front 公共配置 key；
- `catering-front`：Controller、Application Service、LiteFlow、能力注册路由、银行 Capability、配置加载、统一异常和日志；
- 8 个交易 API、5 个查询 API、7 个账户维护 API，共 20 个标准 Front API；另有中信不明来款
  3 个专项 API；
- 每个 API 方法在服务内部固定自己的 `FrontCapability`，调用方不能传入或覆盖；最终按
  Transaction、Query、Account 三个执行域分别使用强类型 Capability 接口和 Registry，复合键重复时启动失败；
- 当前 21 条 LiteFlow 链分别只有 `frontTransExecute`、`frontQueryExecute`、
  `frontAccountExecute` 一个节点；交易 8 条、查询 3 条、账户 10 条；
- `FrontBaseSlot` 只承载公共字段，`FrontTransSlot`、`FrontQuerySlot`、`FrontAccountSlot` 直接继承 Base，
  继承深度固定为两层；
- 三个 ExecuteNode 分别完成 Slot 读取、租户配置加载、本域 Registry 路由、Capability 调用和结果/异常回填；
- 租户配置调用链固定为 `域 ExecuteNode → TenantBankConfigLoader → RemoteConfigServiceClient`；
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
  仅复用租户上下文注入、`tenant_base_config`、`TenantBankConfigLoader` 和统一 Gateway/Sender；
- 平安 `platformPay/platformReceive` 已明确为 `UNSUPPORTED`；
- 所有交易基础对象已包含来源业务系统、业务交易逻辑类型、业务主记录 ID 和业务子记录 ID；
- 渠道流水 DDL 已按“银行 + 交易业务”拆为中信 6 张、平安 4 张，每张表均含
  `reserve1/reserve2/reserve3`，业务数据按明确字段保存，不保存业务或银行报文快照；
- 10 张渠道表的完整字段字典已逐表列出字段顺序、类型、NULL、默认值、更新规则、注释和索引，可交给其他 AI
  按目标字符集生成最终 SQL；
- 单条交易、交易状态和账户查询返回 `R<具体结果>`；分页明细查询直接返回工程统一的
  `TableDataInfo<AccountTransDetailItem>` / `TableDataInfo<PlatformTransDetailItem>`（24/25 各一套行 DTO），禁止再用 `R` 包裹；
  所有 Front 结果通过 `FrontBaseResult` 统一提供 `frontRespCode/frontRespDesc/specialData`；
- `FrontExceptionHandler` 和结构化日志工具；日志目标采用 B 方案：Capability 只记录业务步骤，最终
  `BankWalletSender` 在发送前记录一次 `wallet_request_sending`、响应后记录一次
  `wallet_response_received`、失败时记录一次 `wallet_request_failed`，业务 body 使用完整明文 JSON；
  `appKey`、私钥、签名材料、签名/认证 Header、`Authorization`、`Cookie`、完整银行 URL 等
  非业务凭证禁止进入日志。当前中信 Sender 已有三类事件，平安 Sender 通信异常路径尚无结构化
  `wallet_request_failed`，不能写成两家均已达标；
- 三域注册【历史迁移已实施完成】：当时 13 条链使用单一域节点，22 个银行 Capability 实现类按
  Transaction 12、Query 6、Account 4 归域；当前账户维护增量后的数量见本节开头；银行代码按
  `channel/{bank}/{transaction|query|account}` 分组；
  后续新能力一律按此结构新增，不重建旧结构；
- 目标框架保留 LiteFlow + 注册式 Route 扩展能力：未来新银行复用现有能力时，只增加银行枚举、
  Loader 平级分支、该银行 Sender 与三个现有域中实际支持的扁平 Capability，不修改 API 入口和 chain id；
  只有出现数据和状态形态明确不同的新能力并经用户确认后，才允许新增第四执行域；
  唯一规则文件 `resources/liteflow/front-flow.xml`，Nacos `catering-front.yml` 的
  `liteflow.rule-source` 固定为 `liteflow/front-flow.xml`；
- 渠道流水持久层已落地：10 张表的 Entity/VO/Mapper/XML/Service/ServiceImpl 已搬入 main，
  Entity 继承 `TenantEntity` 复用父类审计字段（`createBy`/`createTime`/`updateBy`/`updateTime`）；
- Capability 持久化已接入：`insertInitRecord`（INSERT INIT）→ `updateSending`（UPDATE SENDING）→
  调银行 → `updateResponse`（UPDATE 状态/响应码）；中信退款不再查询原渠道表补字段，固定使用
  `originalBizOrderNo + originalBizSubOrderNo` 组装银行原交易定位字段；五个旧 `original_*` 列仅作为可空兼容列保留；
- ShardingSphere-JDBC 分库：使用 STANDARD 模式，分片键固定为 `tenant_id`，路由值由
  MyBatis-Plus 多租户插件注入；`TenantDataSourceShardingAlgorithm` 用 `tenant_id` 查进程内
  `TenantDataSourceMappingCache` 得到 `ds_x`（2026-08-29 起，提交 `c5cf5ae4`；映射权威源
  `sys_tenant.resourceConfig`，TTL 默认 15 分钟 + single-flight 懒加载 + 启动预热）；
  `data_source_id` 不参与路由，仅作为 insert 列值写入渠道表（记录数据所在库实例），
  仍由 baseData 传入、域 ExecuteNode 第④步从 `tenant_base_config` 回填；
- 查询/更新 SQL 不要求显式分片键（2026-08-29 FR-6，提交 `7ae51dd6`：Capability wrapper 的
  `data_source_id` 条件已移除）；INSERT 由 entity 列值覆盖。
  `tenant_id` 缺失（无租户上下文 fail-closed）、映射缺失/`resourceConfig` 非法、或目标
  `ds_x` 不在可用数据源列表时必须立即失败，禁止默认进入 `ds_0` 或第一个数据源；
- 不使用 Hint、`HintManager`、`FrontDataSourceHelper` 或 dynamic-datasource 手动切库；
- 4 个必要参数（tenantId/clientId/platformCode/dataSourceId）自动注入；每个请求由
  域 ExecuteNode 第③步用 tenantId 从 `tenant_base_config` 一次查询取出
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
交易 API → FrontTransApplicationService → THEN(frontTransExecute)
       → FrontTransExecuteNode → BankTransCapabilityRegistry
       → BankTransCapability.execute(FrontTransSlot)

交易查询 API → FrontQueryApplicationService → THEN(frontQueryExecute)
           → FrontQueryExecuteNode → BankQueryCapabilityRegistry
           → BankQueryCapability.execute(FrontQuerySlot)

账户状态/余额 API → FrontAccountApplicationService → THEN(frontAccountExecute)
               → FrontAccountExecuteNode → BankAccountCapabilityRegistry
               → BankAccountCapability.execute(FrontAccountSlot)

三个域 ExecuteNode → TenantBankConfigLoader → RemoteConfigServiceClient
三个域 Capability → BankWalletGateway.post → BankWalletSender
```

`FrontTransSlot`、`FrontQuerySlot`、`FrontAccountSlot` 都直接继承 `FrontBaseSlot`。每个域的
Application Service 负责构造本域 Slot 并执行原 chain id；ExecuteNode 使用 LiteFlow 无参
`getFirstContextBean()` 取 Slot、显式校验类型，不恢复通用 Context 或 Handle 继承链。

## 6. 不允许变更的约束

- 不新建 `catering-front-api/common/service` 子模块；
- 不复制旧项目的 `BeanPostProcessor` 注册、字符串拼接或混入账户类型/bizFunc 的复合路由键，以及任意
  `<T> T` 返回；领域 Registry 的类型安全 `(BankCode, FrontCapability)` 是本项目规定的必要路由键，
  不属于此禁令；
- 不增加 `FrontResponse`；单条接口返回 `R<具体结果>`，分页明细查询直接返回
  `TableDataInfo<AccountTransDetailItem>` / `TableDataInfo<PlatformTransDetailItem>`（24/25 各一套行 DTO），不再使用 `R` 包裹；
- API、Controller、Application Service 使用同一方法签名并原样透传；内部 Route 和 Capability 不返回 `R`；
- `FrontFlowExecutor` 内部允许返回 `null`，但三个 Application Service 必须立即转换为非空失败响应；
  禁止 `R.ok(null)`、空分页响应或对外返回 `null`，也不得模拟成功；
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
- 三域改造中，API 方法内部固定 capability 并写入请求域 Slot；银行分发只允许本域
  `ExecuteNode → 本域 CapabilityRegistry → 本域 Capability`。三个 Registry 分别按本域能力类的
  `bank()/capability()` 自描述注册，并在启动时拒绝重复键；不存在统一 `BankCapability`、统一 Registry
  或通用 ExecuteNode。能力类使用自己的固定渠道表 Mapper；禁止增加 Router/Dispatch/Handle 继承体系，
  禁止按 capability 动态选表，禁止调用方传表名或拼接动态 SQL；
- 每张渠道交易表必须保存业务主/子记录关联字段、业务及银行所需明确字段和
  `reserve1/reserve2/reserve3`；不保存报文快照；
- 渠道表允许按当前契约保存本系统内部使用的账户、会员、姓名、卡号等原始值，本期不要求数据库字段加密；
  最终 Sender 的钱包请求/响应 body 按用户裁决记录完整明文 JSON；私钥、签名材料、认证信息等
  不属于 body 的凭证不得进入日志，异常和普通接口响应也不得额外泄露这些凭证；
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
- 租户映射（`sys_tenant.resourceConfig`，经进程内缓存 `TenantDataSourceMappingCache`）是分片
  路由必备前置条件；`tenant_id` 为空、映射缺失/非法或目标 `ds_x` 不在可用数据源列表时
  必须立即失败，
  禁止默认路由到任意数据库；
- 钱包 `D5000000/success`、中信 `00000`、平安 `000000` 只用于 Capability 判定，
  `frontRespCode/frontRespDesc` 必须统一取 `FrontErrorCode`；
- 只有 Front 业务成功时顶层 `R.code=200`；银行业务失败时顶层也必须返回失败码，并在 data 内保留
  统一 Front 错误码、说明和状态；业务成功的 `data.frontRespCode` 同样统一为字符串 `"200"`；
- 交易链路按 05 §8 执行 B 方案：Capability 保留真实业务步骤日志，最终 Sender 唯一记录钱包
  请求/响应/失败，body 使用完整明文 JSON、不脱敏；迁移时删除重复报文日志，并继续排除非报文凭证；
- 28/29 号历史迁移必须覆盖当时全部 22 个银行 Capability 实现类；该迁移已经完成，禁止重新执行。
  当前新增能力不得重写既有银行业务逻辑、改变能力支持状态、创建虚假银行能力或提前抽象未来能力；
- 本轮用户已明确：不新增或运行测试、不执行编译，只做静态 review，禁止据此声明测试或编译通过。

## 7. 后续 AI 的实现单位

28/29 号三域注册收口【已实施完成】，禁止重新执行。**当前活动任务：FRONT-ACC-001 账户维护**
（12-front-implementation-issues/FRONT-ACC-001-account-maintenance-in-progress.md）。

通用工作方式（沿用三域实施期确认的纪律）：
1. 阅读顺序：本 WIKI → 19 → 28 → 29 → 30（历史参照）→ 当前活动 Issue → 当前源码核对未完成项；
2. 新增能力一律走三域结构：`channel/{bank}/{domain}/` 能力类 implements 对应域强类型接口，
   Registry 自动收集即完成路由；银行代码按 `channel/{bank}/{transaction|query|account}` 分组；
   当前源码实况：银行 Capability 实现类 29 个（交易 12/查询 6/账户 11，账户 11=中信 9+平安挡板 2）、
   链 21（8 交易/3 查询/10 账户）——历史基线 22/13 见 §4 数量口径；
3. 三个 ExecuteNode 各自直接读取 Slot、调用 Loader、Registry 和 Capability，不增加抽象父节点或嵌套流程；
4. 银行 Capability 保持校验、组装、持久化和结果映射可读展开；钱包发送统一经 Gateway/Sender；
5. 禁止复活 Context、Handle、BankSupport、Router、Dispatch 或多层 Wallet Client；
6. 最终发送端记录完整明文请求/响应 body；Capability 不重复打印钱包报文，认证凭证不得入日志；
7. 三个 Application Service 必须显式处理 `FrontFlowExecutor` 返回的 `null`，转为非空失败响应；
   当前只有 Transaction 路径完整收口，Query 的单条/分页结果和 Account 的查询结果仍存在
   `R.ok(null)` 或直接返回 `null` 的静态路径，属于待修代码差异，不能写成已完成；
8. 测试/编译/commit/push 均需用户当次明确授权；完成后提交改动清单与验证证据给用户 review。

### 7.1 当前源码静态差异（2026-08-29）

以下是按 `master@d164c7e7` 于 2026-08-30 复核确认仍存在的事实，不自动并入 FRONT-ACC-001
的开发范围；
后续 AI 必须先由用户确认任务边界，再修改代码：

| 差异 | 当前源码事实 | 目标口径 |
|---|---|---|
| 去白名单链 | `chainFrontAccountUnwhiteName` 仅存在于 XML 和常量，无 API/AppService 方法调用 | 删除孤儿链，或新增契约并接入；不得静默猜选 |
| null 结果 | Query 单条/分页、Account 查询仍可能包装或返回 `null` | 外层显式转为非空失败响应 |
| 平安通信失败日志 | 普通 error 日志存在，但没有结构化 `wallet_request_failed` | 最终 Sender 统一输出发送/响应/失败三类事件 |
| web-test Header 日志 | `test_feign_headers` 当前会记录 `Authorization`（`WebTestHeaderLogInterceptor`） | 业务 payload 可明文，认证凭证必须排除 |
| 请求入口日志 | Controller Aspect 与 Application Service 都会输出完整 Front 请求 | 明文允许；若要求单一入口日志，需单独确定保留层级 |
| 代码注释 | `front-flow.xml` 头注释仍写 13 条链；`TenantBankConfigLoader` 注释仍引用不存在的 `TenantResolveNode`；ExecuteNode 注释仍以 `data_source_id` 为"分片 SQL"口径；个别 Gateway/Sender 注释仍使用 Handle/旧 Registry | 注释应与 21 条链、tenant_id 分片和三域 Capability 结构一致 |
| 文件接口无实现 | `FrontFileProcessApi` 4 个方法（queryCheckFileInfo/fileDownload/fileUpload/fileDownload801）在 catering-front 无 Controller 实现，`catering-routing` 仍经 Feign 调用，`@Tag` 误写为"渠道交易查询对外接口"，未入本 Wiki §8 API 清单 | 补实现并入册，或明确为遗留接口归档；不得静默保留 |
| 平台收付款 Mapper 列重复 | `FrontCiticPlatformPay/PlatformReceiveTransactionMapper` 的 `Base_Column_List` 中 `data_source_id` 出现两次（2026-08-07 `045ab653` 引入） | 列清单去重；凡引用该 `<sql>` 的查询需回归验证 |
| ShardingSphere SQL 日志 | dev/uat/prod 三份 `shardingsphere-config-*.yaml` 均为 `props.sql-show: true` | 生产环境关闭或降级该开关，避免全量 SQL 明文（含租户/金额）进日志 |

语义约定：Slot 内部路由能力字段为 `routeCapability`（框架内部路由键）；对外报文字段
`baseData.capability` 仅在状态查询等场景存在且语义为"被查交易的原交易能力"。两者禁止互相替代。

## 8. API / Capability 方法入口

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

账户维护方法：

```text
openAccount
bindCard
unbindCard
updateAccountInfo
acctClose
whiteName                  // opType 区分加白/去白
withdraw
```

具体方法与旧 Front、mdl API/Service/Handle/银行实现类的历史对应关系，可参考
[04-front-service完整重构实施方案](04-front-service完整重构实施方案.md)；当前实现定位必须以
API → Application Service → 域 ExecuteNode → Registry → 银行 Capability 的源码调用链为准。

## 9. 每次交付必须报告

- 实现了哪个银行、哪个能力；
- 修改了哪些代码与文档；
- 请求字段如何进入银行对象或 `reserveMap`；
- 银行响应如何进入公共结果或返回 `specialData`；
- `transSsn/bizFunc/chnlNo` 的来源；
- 哪些能力仍为 `PENDING_INTEGRATION/UNSUPPORTED`；
- 是否编写测试、运行测试或编译；
- 当前是否未提交；只有用户确认提交后才报告代码仓库和记忆体仓库提交号。
