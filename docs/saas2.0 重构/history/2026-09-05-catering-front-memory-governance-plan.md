# Catering Front 记忆体全量治理执行计划

> **状态：待用户确认后执行。** 本计划只整理记忆体和 Obsidian，不修改业务代码；不新增或运行测试，不执行编译。

**目标：** 以 `cateringsass` 当前 `limeng_front@66d7df9d` 源码为基座，逐份核验 `saas2.0-memory-hub` 中与 Catering Front 有关的文档，使现行文档只描述最新有效口径，历史基线集中进入 `history/`，且所有事实均可追溯到当前源码、用户裁决或明确的外部协议。

**治理方式：** 文档分为“现行事实”“历史基线”“外部参考”“待确认”四类。现行事实按代码更新；纯历史材料使用 Git 移动到 `history/`；仍承担当前契约职责的 spec/字段契约保留在现行区并清理历史完成记录；代码无法证明、用户也未裁决的内容进入待确认清单，不推理补齐。

**事实优先级：** 用户本次及既有明确裁决 → 当前源码 → 当前有效的银行/外部协议 → 现行契约与约束文档 → 历史基线 → 旧项目参考。文档之间冲突时不得按文档多数表决，必须回到更高优先级证据。

**源码范围：**

- `cateringsass/catering-api/catering-api-front`
- `cateringsass/catering-modules/catering-front`
- Front 实际依赖的 `catering-common-*` 租户、Feign、MyBatis、返回体、异常与常量代码
- `cateringsass/catering-modules/catering-web-test` 中由 14 号文档声明的 Front 测试工具
- 当前代码仓库内由 Front 实际加载或引用的 LiteFlow、YAML、Mapper XML 和 SQL 资源

**文档范围：**

- `saas2.0-memory-hub/docs/saas2.0 重构/` 下全部顶层 Markdown、SQL 和 `12-front-implementation-issues/` 全部文件
- `saas2.0-memory-hub/MEMORY.md`
- `saas2.0-memory-hub/WORK_MANUAL.md`
- `saas2.0-memory-hub/docs/开发操作手册.md`
- `saas2.0-memory-hub/conversation-logs/` 中需要记录本次治理结果的当日日志
- `/Users/limeng/ObsidianBrain` 中需要持久化“历史基线旧化规则”和本次会话要点的文件

## 全局约束

1. 只写代码或用户裁决能够证明的事实；外部协议事实必须标明协议来源，不能伪装成代码事实。
2. 当前代码只作核验，不修改；本轮不新增测试、不运行测试、不编译。
3. 历史文件保留原正文语义和 Git 历史，只补必要的历史状态头、替代文档入口和失效边界。
4. 现行文档不得使用历史提交的数量、路径、签名或完成状态描述当前实现。
5. 已经无法由当前代码确认的环境验证、UAT 结论或旧编译结果，只能保留为带日期的历史证据。
6. 金额单位、敏感信息、租户分库、银行能力支持状态继续遵守现有强制约束；整理文档不得放宽代码约束。
7. 遇到代码、用户裁决、银行协议三者不能消解的冲突，停止对应条目并向用户提问，不自行选择。
8. 记忆体修改完成后按既有约定提交并自动推送；代码仓库不提交、不推送。

---

### Task 1：冻结当前源码证据矩阵

**产出：** 一份本次审计内部使用的证据矩阵，最终摘要写入 History 审计报告；不建立与 19/20/21/27/31/33 重复的现行手册。

- [ ] 记录代码分支、HEAD、远端跟踪状态和工作区状态。
  - 验证：基线固定为 `limeng_front@66d7df9d`；若执行时 HEAD 变化，停止并重新确认基线。
- [ ] 使用 CodeGraph 枚举 `FrontTransApi`、`FrontQueryApi`、`FrontAccountApi`、中信不明来款 API、中信文件处理 API 及其 Controller/Application Service 调用链。
  - 验证：每个公开方法记录精确方法名、请求类型、返回类型、Controller 和 Application Service。
- [ ] 枚举三个执行域的 Slot、Application Service、LiteFlow chain、ExecuteNode、Registry 和全部银行 Capability 实现。
  - 验证：数量与 `FrontCapability` 枚举分别统计，不用枚举项数推导 API 或实现数量。
- [ ] 枚举租户准备、银行配置加载、Feign Header 传播、MyBatis 租户注入、ShardingSphere 分库和专项 Pack 的真实调用链。
  - 验证：每条描述落到类/方法/配置资源；无法由代码确认的部署行为不写为当前事实。
- [ ] 枚举交易持久化表、Entity/Mapper/Service、状态生命周期、重复交易条件以及 DDL/SQL 资源。
  - 验证：Java 字段、Mapper SQL、文档字段字典和最终建表 SQL 逐表对应。
- [ ] 枚举中信不明来款、文件上传下载、凭证下载、RECHARGE/TI/提现补号等专项调用链。
  - 验证：能力映射、bizFunc、chnlNo、请求/响应 DTO、数据定位来源均有代码位置。
- [ ] 核对日志、错误码、敏感字段、金额单位和 unsupported/deferred 挡板。
  - 验证：区分“已实现”“明确不支持”“延期”“代码存在但无公开入口”。

### Task 2：逐份文档分类，不按文件名推定

**涉及：** `docs/saas2.0 重构/` 全部文件。

- [ ] 为每份文档记录：当前职责、状态标签、代码基线、最后核验日期、现行替代文档、是否移动。
  - 验证：每个文件只能落入“现行事实 / 历史基线 / 外部参考 / 待确认”之一。
- [ ] 对 `spec`、字段契约和设计文档判断其是否仍被 WIKI 定义为当前约束。
  - 验证：仍约束当前代码的文件保留在现行区；仅记录实施过程的部分从现行正文剥离或整体归档。
- [ ] 对 plan、交付报告、旧项目流程、已关闭 Issue、旧任务交接逐一判断是否为纯历史材料。
  - 验证：不得仅因文件名含 `plan`、`spec`、`issue` 就自动移动。
- [ ] 形成“拟保留 / 拟移动 / 待确认”清单；存在待确认项时先询问用户。

### Task 3：建立 History 体系并迁移纯历史材料

**创建：**

- `docs/saas2.0 重构/history/README.md`
- `docs/saas2.0 重构/history/2026-09-05-catering-front-memory-audit-report.md`

**修改：** 本计划确认后根据阶段 2 清单，以 Git rename 移动纯历史文件。

- [ ] 在 `history/README.md` 定义 History 用途、准入条件、目录、状态标签、现行替代入口和引用规则。
  - 验证：任何人能从索引判断一份历史文档为什么失效、何时失效、应改读哪份现行文档。
- [ ] 将纯历史 plan、交付记录、旧项目参考、已关闭任务/Issue 移入 History 的分类子目录。
  - 验证：使用 Git rename；不复制出两份可被误认为同时有效的正文。
- [ ] 给每份历史文件增加统一状态头。
  - 验证：至少包含 `historical`、原适用基线、失效原因、现行替代入口；不改写原历史裁决。
- [ ] 生成本轮审计报告，记录基线、移动清单、现行文档修改清单、已消解冲突和待确认事项。
  - 验证：报告不重复整份当前契约，只引用现行文档和源码证据。

### Task 4：按源码修订所有现行文档

**核心入口：**

- `WIKI-START.md`
- `01-front-重构总体结构设计.md`
- `02-中信银行接口能力汇总.md`
- `03-平安银行接口能力汇总.md`
- `05-front代码开发约束.md`
- `06`—`11` 号字段、DDL、查询和公共框架文档
- `13-front后续待办.md`
- `14-catering-web-test-使用说明.md`
- 经阶段 2 判定仍为当前约束的 `spec`
- `19`、`20`、`21`、`27`、`31`、`33` 号现行手册

- [ ] 统一代码基线、模块路径、类名、包名、公开 API、方法签名、返回类型和请求 DTO。
  - 验证：逐项与阶段 1 API 证据矩阵一致。
- [ ] 统一能力支持矩阵、Capability 实现数、chain 数、Account/Query/Transaction 归域和专项能力边界。
  - 验证：不再出现旧基线数字被描述为“当前”；历史数字只能链接 History。
- [ ] 统一 baseData、specialData、accountConfig、accountSpecialData 字段边界和银行固定参数来源。
  - 验证：字段名、必填性、单位、常量键、配置来源与 DTO/Capability/配置类一致。
- [ ] 统一银行接口路径、bizFunc、chnlNo、响应键大小写、成功判定和错误映射。
  - 验证：代码固定值与外部协议分别标注证据属性；两者冲突时不静默修订。
- [ ] 统一渠道表、字段字典、索引、状态更新规则和 SQL。
  - 验证：09、09A、09B、09-final、09C、09D 与当前 Entity/Mapper/实际资源一致；历史迁移 SQL 明确适用边界。
- [ ] 统一租户权威源、dataSourceId 语义、tenantId 分片、fail-closed 行为和专项 Pack 边界。
  - 验证：31、05、19、WIKI 与当前代码调用链一致。
- [ ] 统一中信不明来款、文件处理和凭证下载的最新实现。
  - 验证：27、33、02、19、WIKI 对方法、DTO、能力映射和查询来源的描述一致。
- [ ] 清理错误的 `IN_PROGRESS`、`OPEN`、已完成任务入口和旧“当前行为”描述。
  - 验证：任务状态与代码事实、用户确认和 History 记录一致；代码存在不自动等于外部/UAT 验收完成。
- [ ] 对代码未实现或明确挡板的能力保持真实表述。
  - 验证：不把枚举存在、接口声明或历史计划写成已可用能力。

### Task 5：把“历史基线旧化”固化为长期约束

**修改：**

- `docs/saas2.0 重构/WIKI-START.md`
- `docs/saas2.0 重构/05-front代码开发约束.md`
- `docs/开发操作手册.md`
- `WORK_MANUAL.md`
- `MEMORY.md`
- `/Users/limeng/ObsidianBrain/10-Agents/Personal-Rules.md`
- `/Users/limeng/ObsidianBrain/90-System/MOC.md`（仅在新增长期规则入口时）

- [ ] 写入旧化触发条件：实现被替代、任务完成、设计不再约束当前代码或代码基线明显变化。
- [ ] 写入旧化步骤：代码核验 → 分类 → Git 移动 → 状态头 → History 索引 → WIKI/链接更新 → 静态校验。
- [ ] 写入禁止事项：不得删除历史证据、不得让历史完成状态冒充当前事实、不得同时保留两份无状态区分的有效正文。
- [ ] 写入以后执行要求：功能完成或结构变化时，同一轮完成当前文档更新和历史旧化。
  - 验证：项目规则与 Obsidian 个人规则均能独立找到该流程，且不互相矛盾。

### Task 6：静态一致性和有效性终验

- [ ] 校验所有 Markdown 相对链接和移动后的路径。
  - 验证：记忆体内部指向本仓库文件的链接无缺失目标。
- [ ] 扫描历史状态词和旧基线词。
  - 验证：现行区出现 `historical/历史基线/旧实现/已废弃` 时必须指向 History 或明确说明当前替代项。
- [ ] 扫描完成状态词。
  - 验证：现行入口不存在已经结束却仍标为 `IN_PROGRESS/OPEN/FIXED_PENDING_REVIEW` 的任务；安全延期项保留真实状态。
- [ ] 交叉核对 API、Capability、chain、表、DTO、字段和固定参数矩阵。
  - 验证：同一事实在 WIKI、现行手册和字段契约中的值一致，并能追溯源码。
- [ ] 检查 History 与现行区职责隔离。
  - 验证：WIKI 的默认必读顺序不把纯历史文档列为当前实现依据；History 索引能反向找到替代文档。
- [ ] 检查 Git diff。
  - 验证：只包含记忆体和 Obsidian 文档变更，没有业务代码、生成物、测试或编译产物。

### Task 7：收尾、双轨记忆和交付

- [ ] 更新 `saas2.0-memory-hub/conversation-logs/2026-09-05.md`，记录任务、基线、主要修订和未验证项。
- [ ] 更新 `/Users/limeng/ObsidianBrain/90-System/Daily-Notes/2026-09-05.md`，记录本次治理结论并链接长期规则。
- [ ] 对项目事实更新 `MEMORY.md`；通用旧化规则双写 Obsidian。
- [ ] 输出最终报告：现行文档清单、History 清单、代码/设计偏差、已修订项、未决问题、未执行的测试/编译。
- [ ] 复核两个仓库的 Git 状态；代码仓库必须保持无改动。
- [ ] 按既有约定提交并推送 `saas2.0-memory-hub`；Obsidian 按其仓库现有状态和手册执行，不把敏感信息写入笔记。
  - 验证：远端包含记忆体提交；最终报告提供提交哈希和推送结果。

## 计划验收条件

1. 记忆体每份 Front 文档都有明确分类和状态。
2. 所有现行口径与 `limeng_front` 执行时确认的当前 HEAD 一致。
3. 纯历史材料集中在 `history/`，WIKI 和 History 索引均能导航。
4. 当前手册中不存在被历史完成记录、旧数量、旧路径、旧 DTO 或旧调用链污染的事实。
5. 所有内部链接有效；重复事实跨文档一致。
6. 不确定项以问题形式交给用户，不出现推理性补全。
7. 历史旧化流程已写入项目约束和 Obsidian，成为以后固定操作。
8. 代码仓库零改动；本轮明确未新增/运行测试，未执行编译。
