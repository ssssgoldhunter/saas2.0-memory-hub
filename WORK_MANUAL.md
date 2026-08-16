# 个人 AI 工作手册（Personal AI Work Manual）

> 李蒙（ssssgoldhunter）的个人工作手册。汇总本机 Codex 与 Claude Code 的规则、配置、记忆库约定，
> 供任何 AI 助手（Codex / Claude Code / 其他 Agent）在任何项目中遵守。
>
> - 本文件是**规则层**：告诉我「怎么工作」。
> - 业务与项目事实（用户画像、项目清单、领域知识、环境）见同目录 `MEMORY.md`（**事实层**）。
> - 项目级深度知识在各项目的 memory-hub 内，本手册只做索引与强制规则。

---

## 0. 手册来源（本机扫描到的文档）

本手册由以下本机文件归纳而成，更新时以这些原始文件为准：

| 来源 | 路径 | 内容 |
|------|------|------|
| Codex 全局规则 | `~/.codex/AGENTS.md` | CodeGraph 优先规则 |
| Claude 全局规则 | `~/.claude/CLAUDE.md` | 同上（两工具共用同一份） |
| Karpathy 编码准则 | `~/.codex/skills/karpathy-guidelines/SKILL.md` | 4 条编码行为准则（§1） |
| Codex 配置 | `~/.codex/config.toml` | 模型、插件、MCP、信任目录 |
| Codex 命令审批 | `~/.codex/rules/default.rules` | 已批准的 shell 命令前缀 |
| Claude 配置 | `~/.claude/settings.json` | GLM 模型端点、权限白名单 |
| lsym 项目规则 | `IdeaProjects_lsym_dep/lsym-memory-hub/CLAUDE.md` | 项目信息 + 工作规范 |
| mdl 项目规则 | `IdeaProjects_mdl_dep/mdl-memory-hub/CLAUDE.md` | 项目信息 + 工作规范 |
| 文档管理规则 | `IdeaProjects_lsym_dep/lsym-memory-hub/workflow/DOCUMENT_MANAGEMENT_RULES.md` | md 文档一律进记忆库（§5） |
| SaaS Front 入口 | `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md` | 多银行重构的强制入口（§6） |
| UMS 记忆 | `IdeaProjects_saas_dep/UMS.md` | UMS 新增记忆（见 MEMORY.md §6） |

---

## 1. 核心编码准则（Karpathy 4 条，强制）

> 来源：`~/.codex/skills/karpathy-guidelines/SKILL.md`、lsym/mdl 项目 CLAUDE.md。
> **权衡**：这些准则偏谨慎而非速度；琐碎任务可自行判断。

### 1.1 编码前先想清楚（不假设、不隐藏困惑、主动说明权衡）

- 实现前明确说出你的假设；不确定就先问。
- 存在多种解释时全部列出，不要静默选择一种。
- 有更简单的方案就说出来，必要时可提出反对意见。
- 有不清楚的地方就停下，说出困惑点，然后提问。

### 1.2 简单优先（最小代码解决问题，不做投机性设计）

- 不实现未被要求的功能。
- 不为单次使用的代码加抽象。
- 不增加未被要求的「灵活性 / 配置项 / 扩展点」。
- 不为不可能发生的场景写错误处理。
- 能 50 行写完就不要写 200 行。
- 自问：资深工程师会觉得这过度复杂吗？会就简化。

### 1.3 外科手术式修改（只动必须动的，只清理自己的垃圾）

- 不顺手「改进」相邻代码、注释或格式；不重构没坏的东西。
- 匹配现有代码风格，即使你个人会写得不一样。
- 发现无关死代码只说明，不删除。
- 只删除**你的修改造成**的未用 import / 变量 / 函数；不删既有死代码。
- 检验标准：每一行变更都应能追溯到用户需求。

### 1.4 目标驱动执行（定义成功标准，循环直到验证）

- 「加校验」→「先写无效输入的测试，再让它通过」。
- 「修 Bug」→「先写能复现的测试，再让它通过」。
- 「重构 X」→「重构前后测试都通过」。
- 多步骤任务先给简短计划，每步写明如何验证：
  ```
  1. [步骤] → 验证: [检查项]
  2. [步骤] → 验证: [检查项]
  ```

---

## 2. CodeGraph 优先规则

> 来源：`~/.codex/AGENTS.md` 与 `~/.claude/CLAUDE.md`（两工具共用）。

- 仓库存在 `.codegraph/` 目录（已被索引）时，**理解/定位代码优先于 grep / find / 直接读文件**：
  - MCP 工具（可用时）：`codegraph_explore` 一次回答大多数代码问题（符号源码 + 调用路径）；
    `codegraph_node` 返回单个符号的源码与调用方，或按行号读整个文件。
  - Shell（永远可用）：`codegraph explore "<符号名或问题>"`、`codegraph node <符号或文件>`。
- 仓库**没有** `.codegraph/` 目录时，完全跳过 CodeGraph（是否建索引由用户决定，不要擅自建）。

---

## 3. 本机工具与环境

### 3.1 Codex（~/.codex/config.toml）

- 模型：`gpt-5.6-sol`，`model_reasoning_effort = "high"`，`multi_agent = true`。
- 已信任目录：`~`、`IdeaProjects_lsym_dep`、`IdeaProjects_lsym_uat`、`IdeaProjects_mdl_dep`、`IdeaProjects_saas_dep`。
- 记忆目录：`~/.codex/memories/`（`MEMORY.md` / `memory_summary.md` / `raw_memories.md`，由记忆插件维护，
  **不要手工改动其内部格式**；如需固化个人记忆，写入本项目记忆库并引用）。
- 已启用插件：superpowers、github、outlook-email、teams、documents、spreadsheets、presentations、
  chrome、computer-use、pdf、template-creator、sites、visualize、browser。
- MCP：`codegraph`（stdio）、`node_repl`。

### 3.2 Claude Code（~/.claude/settings.json）

- 通过 `https://open.bigmodel.cn/api/anthropic` 使用 GLM 系列模型：
  - opus / sonnet → `glm-5.2[1M]`，haiku → `glm-4.5-air`，reasoning → `glm-5.1`。
- 权限：codegraph MCP 全部允许；`skipDangerousModePermissionPrompt = true`；`includeCoAuthoredBy = false`。
- 计划文件：`~/.claude/plans/*.md`；会话记录：`~/.claude/projects/`。

### 3.3 Java / Maven（本机固定用法）

- `JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home`
- Maven：`/Users/limeng/shares/apache-maven-3.9.9/bin/mvn`
- 本地仓库参数：`-Dmaven.repo.local=/tmp/mdl-m2`（已在 Codex 审批白名单，避免询问）
- 常见打包命令（mdl 系）：
  ```
  export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
  export PATH=$JAVA_HOME/bin:$PATH
  /Users/limeng/shares/apache-maven-3.9.9/bin/mvn -Dmaven.repo.local=/tmp/mdl-m2 \
    -pl <模块列表> -am -DskipTests package
  ```

### 3.4 Git

- 记忆库（memory-hub）**每次会话结束或必要时自动 push 到 GitHub**，无需询问（见 §5.2）。
- lsym-memory-hub 通过 `~/.ssh/lsym_memory_hub` 密钥访问 GitHub（`~/.ssh/config` 已配置）。

---

## 4. 会话工作流程

### 4.1 会话开始

1. 进入项目后**先加载对应的 memory-hub**（至少读 `llms.txt` 或对应 AI 入口页），再开始排查/实现。
   - lsym → `IdeaProjects_lsym_dep/lsym-memory-hub/llms.txt`
   - mdl → `IdeaProjects_mdl_dep/mdl-memory-hub/llms.txt`
   - saas2.0 Front → `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md`（强制入口）
2. 确认当前分支、任务范围、本次是否授权编写测试 / 运行测试 / 编译。
3. 有多个解释或不确定项，先列出来确认，不静默选择。

### 4.2 会话结束（任务结束流程）

1. 更新 `conversation-logs/YYYY-MM-DD.md`（会话摘要、关键决策、文件变更）。
2. 有重要发现时更新记忆体（技术决策、常见问题、高频规则）。
3. **自动 push 记忆库到 GitHub**（有新提交即 `git push origin main`，无需询问）。
4. **代码仓库的 commit / push 必须先经用户确认**，确认后才分别提交代码仓库和记忆库。

### 4.3 对话日志更新时机

| 场景 | 是否更新日志 |
|------|-------------|
| 完成一个功能开发 | ✅ 建议 |
| 修复一个 Bug | ✅ 建议 |
| 文档整理 / 优化 | ✅ 建议 |
| 简单代码查看 | ⭕ 可选 |
| 快速问题咨询 | ⭕ 可选 |

---

## 5. 文档与记忆体管理规则

> 来源：`DOCUMENT_MANAGEMENT_RULES.md`、lsym/mdl 项目 CLAUDE.md。

### 5.1 存储规则（默认，除非用户明确要求放别处）

| 类型 | 存放位置 |
|------|----------|
| md 文档 / 记忆体内容 | 项目 `*-memory-hub/` 仓库 |
| 项目 / 设计文档 | `memory-hub/docs/` |
| 技术 / 架构文档 | `memory-hub/architecture/` |
| 工作流程 / 偏好 | `memory-hub/workflow/` |
| 当前主题页 | `memory-hub/topics/` |
| Bug 与高频问题索引 | `memory-hub/bugs/` |
| 需求文档 | `memory-hub/requirements/` |
| 对话日志 | `memory-hub/conversation-logs/YYYY-MM-DD.md` |
| 源代码 / 配置 / 资源 | 项目代码仓库（不进记忆库） |

### 5.2 多电脑协作同步

```
工作 → 更新记忆体 → git push
   ↓
切换电脑 → git pull → 获得最新记忆体
   ↓
继续工作
```

### 5.3 文档状态标签

- `current`：当前工作基线。
- `verified-against-source`：已对照源码验证。
- `historical`：保留追溯用，未复核前不得作为当前依据。
- `needs-source-check`：可用但使用前必须核对源码。

### 5.4 源码优先原则

记忆体文档只是导航与解释；实现或做精确论断前，**先核对当前源码**（mdl 项目的 5 条工作规范同样适用：
少假设、最小改动、源码优先、可验证、历史与当前分开）。

---

## 6. 冲突时的优先级（SaaS 2.0 Front 重构固定顺序）

> 完整版本见 `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md` §2，实现该模块时以 WIKI 为准。

```text
用户已确认并写入 WIKI/05/字段契约的决策
→ 05-front代码开发约束
→ 06/07/08 字段契约（实现对应交易时）
→ 09 系列渠道流水 DDL / 字段字典
→ 10-transaction-query-field-contract
→ 11-catering-common-framework-catalog
→ 00/01/04 设计文档（其中历史完成状态一律不作当前依据）
→ 02/03 银行能力汇总
→ 中信退款最新 lsym UAT 参考代码（仅中信 refund 时）
→ 当前 catering-front 代码（与契约不一致按缺陷处理）
→ mdl / 旧 Front 参考代码（只参考实现，不复制旧框架缺陷）
```

通用原则：**用户已确认的决策 > 当前代码 > 契约/约束文档 > 设计文档 > 历史文档 > 旧项目参考**。
历史文档中的「未实现 / 待改 / 编译通过」均不是当前状态证据。

---

## 7. 安全与禁止事项

### 7.1 通用

- 禁止返回 `null` 或模拟成功。
- 日志、异常消息、接口响应中禁止输出敏感字段明文（密钥、账户配置、账号、卡号、手机号、证件号、姓名、验证码等）。
- 金额一律以「分」为单位传递，禁止浮点数。
- 未收到明确授权：不新增测试类、不运行测试、不执行编译。

### 7.2 SaaS 2.0 Front 专属（摘要，完整清单见 WIKI-START §6）

- 中信退款必须调用真实 `/refund + bizFunc=23`，禁止用反向转账模拟退款；对外固定
  `orgBizOrderNo + orgBizSubOrderNo` → 银行 `ORI_BUSS_ID + ORI_BUSS_SUB_ID`。
- 平安 `platformPay/platformReceive` 固定为 `UNSUPPORTED`，不虚构等价接口。
- 渠道流水按「银行 + 交易业务」拆表，禁止恢复单一 `front_channel_transaction`。
- 不新建 `catering-front-api/common/service` 子模块；不复制旧项目 BeanPostProcessor 注册、
  字符串拼接复合路由键、`<T> T` 返回。
- 单条接口返回 `R<具体结果>`，分页明细直接返回 `TableDataInfo<...>`，禁止再用 `R` 包裹。
- `bizFunc/chnlNo/API path` 用带注释的本地常量；字段 key 才进 `*ContractKeys`。
- 4 个必要参数（tenantId / clientId / platformCode / dataSourceId）自动注入，调用方零改动。
- ShardingSphere STANDARD 分片键固定 `data_source_id`；缺失/为空/目标 `ds_x` 不存在必须立即失败，
  禁止默认进入 `ds_0`。
- 重复交易校验用当前银行业务表 `tenantId + bizOrderNo + bizSubOrderNo`，命中返回「交易已存在」，
  不重放旧结果、不返回旧交易数据。
- `specialData` / `accountSpecialData` 禁止整体 `putAll` 到银行 `reserveMap`。
- 不允许调用方覆盖银行账户配置（appId/appKey/url/mchntId/mchntMbrId/txnClientNo/mrchCode/stlAcctNo 等）。

---

## 8. 交付与报告规范

每次交付必须报告（SaaS Front 见 WIKI-START §9，其余项目参照）：

- 做了什么（哪个银行 / 哪个能力 / 哪个 Bug / 哪个功能）；
- 修改了哪些代码与文档；
- 请求字段如何进入业务对象或 `reserveMap`；银行响应如何进入公共结果或 `specialData`；
- `transSsn/bizFunc/chnlNo` 的来源；
- 哪些能力仍为 `PENDING_INTEGRATION / UNSUPPORTED`；
- 是否编写测试、运行测试或编译（须有授权）；
- 提交状态：代码仓库与记忆库**都未提交**，等用户确认后才提交。

---

**更新日期**：2026-08-16
**维护者**：ssssgoldhunter
**配套文档**：`MEMORY.md`（个人记忆体，事实层）
