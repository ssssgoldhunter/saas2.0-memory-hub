# DSH 工作手册（DeepSeek Harness Agent 工作手册）

> 李蒙（ssssgoldhunter）为 DeepSeek Harness（DSH）代理编写的工作手册。
> 本文件同时以 `~/.dsh/AGENTS.md` 安装为 DSH 全局指令（每次会话自动加载）；本副本放在工作区根目录便于查阅。
> - 规则细节与来源见 `saas2.0-memory-hub/WORK_MANUAL.md`；项目事实见 `saas2.0-memory-hub/MEMORY.md`。
> - 配套手册：Codex 用 `~/.codex/AGENTS.md`；Claude Code 用 `~/.claude/CLAUDE.md`；
>   Obsidian（唯一个人记忆/第二大脑）用 `~/ObsidianBrain/90-System/OBSIDIAN-BRAIN-MANUAL.md`（工作区副本 `OBSIDIAN.md`）。

## 1. 关于 DSH 环境（事实）

| 项 | 值 |
|----|----|
| 全称 | DeepSeek Harness（本机 AI 代理执行环境） |
| Web GUI | http://127.0.0.1:3080（用户所说的「本页面/本 GUI」） |
| 全局指令文件 | `~/.dsh/AGENTS.md`（$DSH_HOME 默认 `~/.dsh`；每次会话自动加载） |
| 项目指令文件 | 项目根到 cwd 各目录的 `AGENTS.md` / `CLAUDE.md`（同名同内容只渲染一次） |
| 会话工作区 | `/Users/limeng/workspaces/IdeaProjects_saas_dep`（当前：SaaS 2.0 项目） |
| 记忆库 | `saas2.0-memory-hub/`（git 仓库，GitHub 自动同步） |

## 2. 本环境工具使用约定（DSH 特有，必须遵守）

- **文件查看**：用 `read` 工具读文本（带行号）；用 `glob` 找文件、`grep` 搜内容，**不用** shell 的 cat/find/grep/rg。
- **文件修改**：用 `write`（整文件）或 `edit`（精确替换）；改前先 read。
- **bash**：每次调用都是新 shell，无状态残留；用 `workdir` 指定目录；**每次检查 `[exit code: N]`**，失败先查原因再继续。
- **长任务**：后台任务用 `run_in_background` 启动，用 `job_output`/`job_kill`/`job_list` 管理；不要 busy-poll，先做其他独立工作。
- **多步工作**：用 `todo_write` 维护任务清单（每步标记 in_progress/completed）。
- **长期目标**：单一长目标用 goal 工具（create/get/update_goal）；有界委派用 `subagent`（默认后台）。
- **大规模多代理编排**：仅当用户明确要求 workflow 时使用 `workflow` 脚本。
- **沙箱/审批**：遵循当前 DSH 文件策略与审批策略；被拒绝的操作立即停下说明，不绕道。
- **环境变量**：`$DSH_*` 暴露运行时事实，需要时先查看再使用。

## 3. 核心编码准则（Karpathy 4 条，强制）

1. **编码前先想清楚**：不假设、不隐藏困惑、主动说明权衡；有多种解释先列出，不静默选择；不清楚就停下提问。
2. **简单优先**：最小代码解决问题；不加未要求的功能/抽象/配置；能 50 行不写 200 行。
3. **外科手术式修改**：只动必须动的；不顺手改相邻代码/格式；不重构没坏的东西；只清理自己改动造成的孤儿 import/变量。
4. **目标驱动执行**：把任务转成可验证目标并循环到验证通过；多步任务先给计划，每步写明验证方式。

## 3. 高级工程师行为准则（强制，合并权威版见 saas2.0-memory-hub/docs/开发操作手册.md）

1. **需求不猜只问**：以用户原话/需求文档为准；歧义、缺失、多解 → 当场提问，不静默选择。
2. **pro 想 / flash 做（自动切换）**：思考/设计/规划用 deepseek-v4-pro；执行子任务/编码用 deepseek-v4-flash。切换由 agent 自动判断，判断不了才问用户。
3. **codegraph 优先**：有 `.codegraph/` 时理解/定位代码首选 codegraph，先于 grep/读文件。
4. **记忆双轨 + wiki 蒸馏**：项目 `*-memory-hub` 是主要事实源（完整总结项目+wiki）；Obsidian 仅本地同步。需求/功能完成、提交前必须更新项目记忆体并蒸馏（判断不了先问是否对结构/业务蒸馏）。
5. **pro 规划必须进 plan 模式**：先出完整计划（步骤+验证方式），确认后再执行。
6. **执行严格照需求文档**：不做文档外的事；执行中发现问题当场提问，不自顾自完成。
7. **遵守各项目开发约束**：不理解就提问确认（SaaS Front 以 WIKI-START.md §6 为准）。
8. **外科手术式修改 / 目标驱动验证 / 提交先确认 / 诚实沟通 / 金额用分 / 长任务用 todo**：见权威版 §8–§14。

## 4. CodeGraph 优先规则

- 仓库存在 `.codegraph/` 目录时，理解/定位代码优先用 CodeGraph：MCP `codegraph_explore`/`codegraph_node`，
  或 shell `codegraph explore "<符号或问题>"` / `codegraph node <符号或文件>`。
- 没有 `.codegraph/` 目录就完全跳过（是否建索引由用户决定，不擅自建）。

## 5. 会话工作流程

### 开始
0. **先取回第二大脑上下文（Obsidian 唯一个人记忆，强制）**：
   - 读 `~/ObsidianBrain/90-System/MOC.md`（内容地图）定位相关区域；
   - 个人规则类问题读 `~/ObsidianBrain/10-Agents/Personal-Rules.md`；
   - 每日开始时读当日 `~/ObsidianBrain/90-System/Daily-Notes/YYYY-MM-DD.md`（若有）。
1. 再加载对应项目的 memory-hub（至少读入口页），再排查/实现：
   - lsym → `IdeaProjects_lsym_dep/lsym-memory-hub/llms.txt`
   - mdl → `IdeaProjects_mdl_dep/mdl-memory-hub/llms.txt`
   - saas2.0 Front → `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md`（强制入口）
2. 确认当前分支、任务范围、是否授权测试/编译。

### 结束
1. **写回第二大脑（Obsidian，强制）**：
   - 追加当日 `~/ObsidianBrain/90-System/Daily-Notes/YYYY-MM-DD.md` 要点（无则按模板创建）；
   - 有个人/通用发现 → 写 Obsidian 对应区域（30-Areas / 20-Projects / 40-Resources），用 `[[双向链接]]` 关联；
   - 判断标准：关于我的/通用的 → Obsidian；关于项目的 → memory-hub；项目通用结论双写。
2. 更新 `conversation-logs/YYYY-MM-DD.md`（功能开发/Bug 修复/文档整理后建议更新）。
3. 有重要发现更新项目记忆体。
4. **自动 push 记忆库到 GitHub**（有新提交即 push，无需询问）。
5. **代码仓库 commit/push 必须先经用户确认**。

## 6. 记忆双轨制（第二大脑 + 项目记忆，强制）

- **Obsidian `~/ObsidianBrain` = 唯一个人记忆系统/第二大脑**：个人规则、通用知识、跨项目沉淀、会话记忆。
  规范见 `~/ObsidianBrain/90-System/OBSIDIAN-BRAIN-MANUAL.md`（工作区副本 `OBSIDIAN.md`）。
- **项目 `*-memory-hub` = 项目记忆**：源码事实、项目文档、字段契约。两者**同时读写、互不替代**。
- 判断标准：问「这是关于我的/通用的，还是关于某个项目的？」——个人/通用 → Obsidian；项目 → memory-hub。
- 状态标签：`current` / `verified-against-source` / `historical` / `needs-source-check`（两套记忆通用）。
- 源码优先：记忆体只是导航，实现与精确论断以当前源码为准。
- Obsidian vault 内不存放密钥/口令/证书私钥等敏感明文。

## 7. 文档与记忆体管理

- 所有 md 文档与记忆体内容放项目 `*-memory-hub/` 或 Obsidian vault（按双轨制判断）；源代码/配置/资源留在项目仓库。
- 状态标签：`current` / `verified-against-source` / `historical` / `needs-source-check`。
- 源码优先：记忆体只是导航，实现与精确论断以当前源码为准。

## 8. 项目速览（详见 MEMORY.md）

| 项目 | 代码路径 | 分支 | 记忆库 |
|------|----------|------|--------|
| lsym | `IdeaProjects_lsym_dep/slhy` | `lsym_prod` | `lsym-memory-hub` |
| lsym UAT | `IdeaProjects_lsym_uat/slhy` | 参考 `lsym_20260625_limeng_refundTask`（中信真退款） | — |
| mdl | `IdeaProjects_mdl_dep/mdl` | — | `mdl-memory-hub` |
| saas2.0 | `IdeaProjects_saas_dep/cateringsass` | `limeng_front` | `saas2.0-memory-hub` |

## 9. 构建命令（本机固定）

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
/Users/limeng/shares/apache-maven-3.9.9/bin/mvn -Dmaven.repo.local=/tmp/mdl-m2 \
  -pl <模块列表> -am -DskipTests package
```

## 10. 安全与禁止事项（摘要）

- 禁止返回 `null` 或模拟成功；日志/异常/响应禁止输出敏感字段明文（密钥、账号、卡号、手机号、证件号、姓名、验证码等）。
- 金额一律以分传递，禁止浮点数。
- 未收到明确授权：不新增测试、不运行测试、不执行编译。
- SaaS Front 专属约束（中信真退款 `bizFunc=23`、平安 `platformPay/platformReceive=UNSUPPORTED`、按银行拆渠道表、`data_source_id` 分片缺失即失败等）以 `WIKI-START.md` §6 为准。

---

**更新日期**：2026-08-16　**维护者**：ssssgoldhunter
