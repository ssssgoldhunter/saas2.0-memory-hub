# 个人记忆体（Personal Memory）

> 李蒙（ssssgoldhunter）的个人记忆体。汇总本机 Codex / Claude Code 记忆与各项目 memory-hub 的
> **高频事实**，是跨项目的事实层；规则层见同目录 `WORK_MANUAL.md`。
>
> - 项目级深度记忆在各项目 memory-hub 内，本文件是**总索引 + 高频事实**。
> - 使用前仍须遵守「源码优先」：记忆只是导航与解释，实现与论断以当前源码为准。

---

## 1. 用户画像

| 项 | 值 |
|----|----|
| 姓名 | 李蒙 |
| GitHub | https://github.com/ssssgoldhunter |
| 飞书 | https://jvn4jogcy6u.feishu.cn |
| 领域 | 餐饮资金体系（供应链资金：消费 / 充值 / 提现 / 转账 / 退款） |
| 工作方式 | 多项目并行（lsym、mdl、saas2.0），主导多银行渠道 Front 重构；记忆库即工作记忆，跨电脑 git 同步 |

---

## 2. 项目清单

| 项目 | 主代码路径（本机） | 活跃分支 | 记忆库（GitHub 同 ssssgoldhunter） | 说明 |
|------|---------------------|----------|-------------------------------------|------|
| **lsym** | `IdeaProjects_lsym_dep/slhy` | `lsym_prod`（生产） | `lsym-memory-hub` | 餐饮资金体系；单体 + 微服务混合（转型中） |
| **lsym UAT** | `IdeaProjects_lsym_uat/slhy` | 参考 `lsym_20260625_limeng_refundTask` | — | 中信真退款（`bizFunc=23`）的参考实现 |
| **mdl** | `IdeaProjects_mdl_dep/mdl` | — | `mdl-memory-hub` | 麦当劳餐饮资金体系；供应链部分与 lsym 相同，源自 bwcj + lsym |
| **saas2.0** | `IdeaProjects_saas_dep/cateringsass` | `limeng_front` | `saas2.0-memory-hub` | 多银行（中信 zxegj / 平安 pajzb）渠道 Front 重构 |

> 冷冻分支：lsym `lsym_20260116_limeng_restruct`（2026-05 冻结，98 文件变更 +8615/-4583）。

---

## 3. 常用技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| Java | 17（lsym/mdl）/ 21（本机构建） | 开发语言 |
| Spring Boot | 3.2.4 | 应用框架 |
| Spring Cloud | 2023.0.1 | 微服务治理 |
| Spring Alibaba | 2023.0.1.0 | 云原生特性 |
| LiteFlow | 2.12.x（lsym 2.12.4.1 / saas 2.12.1） | 流程编排引擎（核心） |
| MyBatis Plus | 3.5.5 | ORM |
| ShardingSphere | 5.5.0 | 分库分表 |
| Redis | - | 分布式锁、缓存 |
| RocketMQ | 5.1.3（mdl） | 消息队列 |
| Nacos | - | 配置中心、注册发现 |
| EasyExcel | 3.3.2 | Excel |
| MapStruct | -（新工程用 mapstruct-plus `@AutoMapper`） | 对象映射 |
| Hutool | 5.8.21 | 工具库 |
| Fastjson2 | 2.0.58（saas front） | JSON |

---

## 4. 领域核心知识（高频，勿再重复推导）

### 4.1 六大交易

消费（`chainConsume`，02 优先扣款、支持分账）、充值（`chainRecharge`，01 现金 + 02 膨胀金赠送）、
充值退款（`chainRefundRecharge`，原路退回、膨胀金收回）、提现（`chainWithDraw`，自动 + 人工审核）、
转账（`chainTransfer`，三层锁、支持批量）、消费退款（`chainConsumeRefund`，按比例 / 按单退款）。
另有：消费授权、预消费（冻结）、消费关闭（解冻）、消费算价、冻结 / 解冻、内部转账、授权转账等链。

### 4.2 子账户类型

| 代码 | 名称 | 说明 |
|------|------|------|
| 01 | 现金账户 | 可提现 |
| 02 | 膨胀金账户 | 赠送金额，优先消费，不可提现 |
| 04 | 综合账户 | 综合子账户 |

### 4.3 LiteFlow 组件与链路

| 组件 | 命名 | 职责 |
|------|------|------|
| Pack | `{业务}TransPack` | 数据打包、参数校验 |
| Check | `{校验项}Check` | 业务规则校验 |
| Trans | `{业务}Trans{类型}` | 核心交易处理、写库 |
| After | `{业务}TransAfter` | 后处理、账户变动明细 |
| Route | `{业务}Route` | 路由、分支逻辑 |

通用链路：`Pack → Check → Trans → After → Route`；写流程看 `TransSlot`，查流程看 `QuerySlot`。

### 4.4 安全机制

- **MAC + CAS**：MAC 字段作为 CAS 乐观锁，保证并发更新安全。
- **分布式锁**：Redis 锁，基于 cardCode，5 分钟超时。
- **幂等性**：基于 transNo，Redis 缓存，1 小时过期。

---

## 5. 项目要点

### 5.1 lsym / slhy（餐饮资金体系）

- 主扫描范围：`slhy/fund-catering`（base / consume / front / task / web / management / report 7 子模块，
  不含 `fund-catering-data-batch`）。
- 结构：单体 fund-catering + 微服务（auth / gateway / system / db / routing / reconcile / notify /
  file / gen / job / portal / migration）+ common-core / starter-modules(11) / api-modules / ui-modules(7)。
- 记忆库强制规则：lsym 任务默认先加载 `lsym-memory-hub`（先读 `llms.txt` 与 `workflow/PROJECT_MEMORY.md`）。
- 当前开发重点（2026-05，`lsym_prod` 主线）：入账识别异常告警（898 未配）、提现结果查询接口优化、
  授信合同功能、配置调整与优雅停机、消费退款分摊修复（同卡退款明细合并、兜底回写 `cancelXXAmt`）。
- 记忆库入口：`llms.txt` → `workflow/PROJECT_MEMORY.md` → `topics/README.md` → 必读文档。

### 5.2 mdl（麦当劳）

- 来源：bwcj + lsym（供应链部分相同）；仓库根为 `mdl/`，Java 包名保留历史前缀
  `com.chinaums.erp.slhy...`（命名空间，不代表仓库目录）。
- 代码迁移规范：从 lsym 迁移时对比差异、**如实迁移、不做主观判断**（不判断是否 Bug）；用户说迁才迁，
  不替用户决定迁移范围。
- 构建固定用 jdk-21 + `/tmp/mdl-m2` 本地仓库（见 WORK_MANUAL §3.3）。

### 5.3 saas2.0 / cateringsass（当前主战场：多银行渠道 Front 重构）

- 代码：`cateringsass/catering-modules/catering-front`（2026-09-05 复核基线
  `limeng_front@aa3dc5db`，含 tenant_id 分片切换 + 特殊能力模型收口 + dataSourceId 同源改造
  + 入账登记/单凭证下载 + 日志补齐 `94bf7481`；测试待用户执行）；
  记忆库 `saas2.0-memory-hub`。
- 当前 API：8 个交易 + 5 个查询 + 8 个账户维护（含 depositReg），共 21 个标准 Front API；
  另有中信不明来款 3 个专项 API（`CiticUnidentifiedRemittanceApi`）和中信文件上下传 8 个专项 API
  （`CiticFrontFileProcessApi`，请求/响应模型已从 `Bas*` 收口为
  `model.{request,response}.citic.file.Citic*`）。当前 `FrontCapability` 枚举 23 项，
  银行 Capability 实现类 30 个（Transaction 12 / Query 6 / Account 12），LiteFlow 链 22 条
  （8 / 3 / 11）。枚举中的 `RECHARGE`、`TI` 当前没有对应交易 Front API 或交易 Capability 实现
  （TI 凭证下载部分已落地），不能用枚举数量推导已落地 API 数。
- 中信单张凭证下载已改造为 front 自查定位（2026-09-03 UAT 验证通过，详见 `docs/saas2.0 重构/32-中信单张凭证下载改造交付.md` 与 `33-...凭证下载接口对接手册.md`）：契约=frontSsn + capability + specialData（充值传 bizOrderNo=充值表 transNo；TI 传 acctNo/transDt/bizOrderNo）；能力→凭证 TRANS_TYPE=TRANSFER/CONSUME→06、REFUND→07、WITHDRAW→04、PLATFORM_PAY→12、PLATFORM_RECEIVE→13、RECHARGE→05、TI→03（TI 已入 FrontCapability，通用能力）；**钱包应答键大小写按接口不同**：27/26/23/74 应答为大写 USER_SSN/USER_TRANS_DT，2041/2042 为驼峰 userSsn/userTransDt（BANK_WIRE_* 常量仅用于 2041/2042 应答解析）；26 提现应答无 USER_SSN 键（流水在 queryId 返回），提现凭证下载缺 bank_user_ssn 时自动经 74 状态查询补号并回填渠道行；充值/TI 上游能力未接入（充值入金走银行通知、TI 交易侧待设计），链路已就绪；web-test 首页凭证下载 tab（自动下载 PDF + 确认弹窗）；代码未提交。
- 架构：Controller → Application Service → LiteFlow（交易/查询为 `frontTenantPack + 域 ExecuteNode`
  两节点，账户单节点）→ 域 Registry
  `(BankCode, FrontCapability)` → 银行 Capability → `BankWalletGateway` → 最终 `BankWalletSender`；
  中信编码 `zxegj`、平安编码 `pajzb`。旧 Context、Router、Dispatch、Handle 和统一 Registry
  均为历史术语，不得作为当前实现模板。
- Slot 固定两层：`FrontBaseSlot`，以及直接继承它的 `FrontTransSlot` / `FrontQuerySlot` /
  `FrontAccountSlot`；内部路由字段为 `routeCapability`，不能与报文中的原交易 `capability` 混用。
- 已落地框架（不要重新设计）：api/common/front 模块边界、`R` + `FrontErrorCode`、
  `baseData + specialData`、`TenantBankConfigLoader` 两次配置查询、统一异常、三域强类型 Registry、
  渠道流水 10 张表（中信 6 + 平安 4，含 `reserve1/2/3`）、ShardingSphere STANDARD 分片
  （键 `tenant_id`，进程内租户映射缓存路由；`data_source_id` 列值 2026-09-02 起与路由同源，
  由 `TenantBankConfigLoader` 注入 `TenantDataSourceMappingCache` 取得，`tenant_base_config`
  残留值仅 WARN 观测）、4 参数自动注入，
  以及 Capability 内可顺序阅读的持久化三阶段
  （INSERT INIT → UPDATE SENDING → UPDATE RESPONSE）。
- 日志当前裁决：业务请求/响应 body 允许完整明文；最终 Sender 是钱包报文的统一输出位置。
  `appKey`、私钥、签名材料、签名/认证 Header、`Authorization`、`Cookie`、完整银行 URL 等
  非业务凭证仍禁止进入日志。当前代码仍有平安 Sender 缺少结构化 `wallet_request_failed`、
  web-test 记录 Authorization Header、
  平台收付款两个 Mapper `Base_Column_List` 重复 `data_source_id` 列、三环境 sharding
  `sql-show=true`（含 prod）等静态差异，不能写成已全部达标。
- 入口与链路日志补齐（2026-08-30 设计，代码随 `94bf7481` 提交，测试待用户执行）：`FrontTraceFilter` 把请求头 `reqId`
  （缺省生成 `ex_` 前缀）写入 MDC，`FrontLogJsonUtils` 每条结构化日志自动带 `traceId`，
  logback 模式输出 `[%X{REQ_ID}]`；`FrontInvocationLogAspect` 切点扩到含 citic 子包的全部
  Controller，请求/响应/失败三类事件带 tenantId/bizOrderNo/bizSubOrderNo 等定位字段；
  四个 Flow 节点以 `process→doProcess` 包装抛出点，校验/配置类 `FrontException` 中断时输出
  `flow_interrupted`（含 Slot 定位字段）后原样抛出。
- 完成状态只以 `docs/saas2.0 重构/12-front-implementation-issues/` 为准（OPEN / FIXED_PENDING_REVIEW /
  CLOSED / DEFERRED）；平安交易状态与两类明细、退款边界均已按历史任务关闭，账户状态/余额固定保留
  `ADAPTER_NOT_READY` 挡板；report 跨实例补查为 `DEFERRED`（见 `13-front后续待办.md`）。
- 关键结论：中信退款真退款 `/refund + bizFunc=23`（参考 lsym UAT `lsym_20260625_limeng_refundTask`）；
  平安 `platformPay/platformReceive = UNSUPPORTED`；中信明细查询固定 `bizFunc=25/chnlNo=0010`（资金账户）、
  `bizFunc=24/chnlNo=0010`（登记簿），不支持跨日。
- 中信不明来款是独立特殊能力：最终协议基线为《中信E管家产品V2_不明来账》，固定
  `2033` 列表、`2025` 退款、`2023` 重新匹配/实时清分、`2087` 状态查询及 `chnlNo=0010`；
  请求/返回全字段强类型且无 `specialData`，不进入三域 Registry/LiteFlow，只复用租户注入、配置加载
  和统一 Gateway/Sender。
- 当前活动任务：`FRONT-ACC-001` 账户维护。源码静态核验发现
  `chainFrontAccountUnwhiteName` 无方法调用、Query/Account 查询结果仍可能包装 `null`、
  平安 Sender 通信异常缺结构化失败事件；编译和联调均未获本次授权，禁止声称通过。

### 5.4 lsym UAT

- 中信真退款最新参考：`ZxRefundRequest + zxRefund + bizFunc=23`，分支
  `lsym_20260625_limeng_refundTask`；只参考真实调用与 reserve 字段，不复制旧请求来源及敏感日志。

---

## 6. UMS 记忆（catering-web-test 测试工具）

- **中信银行配置**（租户级，非账户级）：
  - 租户 `80001`（LSYM）：`selfDealType=03`、`selfFundType=015001`、`defaultRole=011002`、`defaultFundType=001002`。
  - 租户 `80002`（MDL）：`selfDealType=03`、`selfFundType=015001`、`defaultRole=015002`、`defaultFundType=015002`。
- 平台收付款 `dealType/fundTp` 从**租户级配置联动**（非账户级），`accountNo=outAcctId`。

---

## 7. 环境事实

| 项 | 值 |
|----|----|
| 本机构建 JDK | `/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home` |
| Maven | `/Users/limeng/shares/apache-maven-3.9.9/bin/mvn` |
| Maven 本地仓库 | `-Dmaven.repo.local=/tmp/mdl-m2`（已审批白名单） |
| Codex 模型 | `gpt-5.6-sol`（high reasoning，multi_agent） |
| Claude Code 模型 | 经 `open.bigmodel.cn/api/anthropic` 用 GLM：opus/sonnet→`glm-5.2[1M]`、haiku→`glm-4.5-air` |
| 记忆库 GitHub | `github.com/ssssgoldhunter/{lsym,mdl,saas2.0}-memory-hub`（自动 push 同步） |
| SSH | lsym-memory-hub 用 `~/.ssh/lsym_memory_hub` 密钥 |
| DSH-TUI | `@huiliyi37/dsh-tianshu-tui`（`~/.dsh/profiles/tui`），启动 `npx -y @deepseek-ai/dsh --profile tui` |
| OH-DSH Desktop | `/Applications/Oh-DSH Desktop.app`（v0.1.6，desktop/web/tui 三端），启动器 `ohdsh`（`~/.local/bin/ohdsh`） |
| 第二大脑同步 | 本仓库 `obsidian-brain/` 目录（private，Obsidian vault 跨机同步，见该目录 README） |

---

## 8. 高频路径速查

| 用途 | 路径 |
|------|------|
| 本手册（规则层） | `saas2.0-memory-hub/WORK_MANUAL.md` |
| 本记忆体（事实层） | `saas2.0-memory-hub/MEMORY.md` |
| SaaS Front 强制入口 | `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md` |
| lsym 记忆入口 | `IdeaProjects_lsym_dep/lsym-memory-hub/llms.txt` |
| lsym 精简记忆 | `IdeaProjects_lsym_dep/lsym-memory-hub/workflow/PROJECT_MEMORY.md` |
| mdl 记忆入口 | `IdeaProjects_mdl_dep/mdl-memory-hub/llms.txt` |
| 交易快速参考 | lsym/mdl `memory-hub/docs/TRANSACTION_QUICK_REFERENCE.md` |
| 权威设计文档 | lsym/mdl `memory-hub/docs/SUPPLY_CHAIN_DESIGN_V5.5.md` |
| 框架结构 | lsym/mdl `memory-hub/architecture/FRAMEWORK_STRUCTURE.md` |
| 第二大脑（Obsidian vault 同步） | `saas2.0-memory-hub/obsidian-brain/`（第二台电脑 clone 后直接作为 vault 打开） |
| Codex 记忆 | `~/.codex/memories/`（插件维护，勿手改格式） |
| Claude 计划 | `~/.claude/plans/` |

---

## 更新记录

- 2026-09-04：中信单张凭证下载改造收口（front 自查定位 + 钱包应答键大小写修复 + 提现 74 补号），
  UAT 验证通过；新增 32 号交付文档、33 号凭证下载对接手册；19/02 号手册与 WIKI-START 已对齐。
- 2026-08-24：补充中信不明来款专项协议、SaaS 2.0 独立能力边界及 3 个对外 API；完整对接字段见
  `docs/saas2.0 重构/27-中信不明来款业务接入手册.md`。
- 2026-08-16：初版。由本机 Codex（`~/.codex/AGENTS.md`、config.toml、rules、memories）与
  Claude（`~/.claude/CLAUDE.md`、settings.json、plans）及各项目 memory-hub 归纳生成。
