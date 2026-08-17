# Obsidian 第二大脑工作手册（李蒙 / ssssgoldhunter）

> 本文件是 Obsidian 作为**唯一个人记忆系统 / 第二大脑**的 agent 工作手册。
> - **双轨并行**：Obsidian = 个人记忆中枢（通用知识、会话记忆、个人规则、跨项目沉淀）；
>   各项目 `*-memory-hub` = 项目记忆（源码事实、项目文档），**两者同时读写、互不替代**。
> - 规则细节与来源见 `saas2.0-memory-hub/WORK_MANUAL.md`；项目事实见各 `MEMORY.md`。
> - 配套手册：DSH 用 `DSH.md`（全局 `~/.dsh/AGENTS.md`）；Codex 用 `~/.codex/AGENTS.md`；
>   Claude Code 用 `~/.claude/CLAUDE.md`。本手册是它们共同的**记忆层规范**。

## 1. 本机 Obsidian 环境（事实）

| 项 | 值 |
|----|----|
| 应用 | Obsidian（`/Applications/Obsidian.app`） |
| Vault | `~/ObsidianBrain`（唯一个人记忆 vault） |
| 打开方式 | Obsidian GUI「打开其他仓库 → ObsidianBrain」；或命令行 `open -a Obsidian ~/ObsidianBrain` |
| 同步 | 本地为主；如需跨设备用 Obsidian Sync 或 iCloud（由用户决定，不擅自启用） |
| 插件 | 默认无第三方插件依赖；核心插件按需启用（图谱/每日笔记/模板） |

## 2. 记忆分工（双轨制，强制）

| 记忆类型 | 归属 | 说明 |
|----------|------|------|
| 个人规则 / 编码准则 / agent 使用约定 | **Obsidian `10-Agents`** | 跨工具统一，各 agent 手册只留引用 |
| 通用技术知识 / 领域沉淀 / 决策记录 | **Obsidian `30-Areas` / `20-Projects`** | 第二大脑核心区 |
| 会话记忆 / 每日进展 / 待办 | **Obsidian `90-System/Daily-Notes`** | 每天一条，可回溯 |
| 项目源码事实 / 项目文档 / 字段契约 | **项目 `*-memory-hub`** | 不动，保持 git 仓库与 GitHub 同步 |
| 项目会话日志 | 项目 `*-memory-hub/conversation-logs/` | 不动 |

**写哪个的判断**：问「这是关于我的/通用的，还是关于某个项目的？」——个人/通用 → Obsidian；项目 → memory-hub。项目内的重要通用结论（如某银行对接经验）→ 双写：项目 memory-hub 记录 + Obsidian `30-Areas` 沉淀通用版。

## 3. Vault 结构（PARA 变体）

```
~/ObsidianBrain/
├── 00-Inbox/                  # 快速捕获，未整理（每周清空一次）
├── 10-Agents/                 # agent 工作模式、个人规则、提示词
│   ├── Agent-Modes/           # 各工具 agent 模式说明（DSH/Codex/Claude/zcode）
│   └── Personal-Rules.md      # 个人铁律（安全、金额、测试授权等）
├── 20-Projects/               # 项目级个人笔记（指向 memory-hub 的导航，不放源码事实）
├── 30-Areas/                  # 长期领域知识：架构、金融渠道、Java、前端、运维…
├── 40-Resources/              # 参考资源：文章、书摘、模板收藏
├── 50-Archive/                # 归档（不再活跃但保留）
└── 90-System/                 # 系统文件（本手册、模板、每日笔记、索引）
    ├── _templates/            # 笔记模板
    ├── Daily-Notes/           # 每日笔记 YYYY-MM-DD.md
    └── MOC.md                 # 内容地图（所有区域的入口索引）
```

## 4. 核心编码准则（Karpathy 4 条，强制，与各 agent 手册一致）

1. **编码前先想清楚**：不假设、不隐藏困惑、主动说明权衡；有多种解释先列出，不静默选择；不清楚就停下提问。
2. **简单优先**：最小代码解决问题；不加未要求的功能/抽象/配置。
3. **外科手术式修改**：只动必须动的；不顺手改相邻代码/格式；不重构没坏的东西。
4. **目标驱动执行**：把任务转成可验证目标并循环到验证通过；多步任务先给计划，每步写明验证方式。

## 5. 记忆读写规则

### 写入（任何 agent 会话结束时）
1. 有值得沉淀的个人/通用发现 → 写入 Obsidian 对应区域，用 `[[双向链接]]` 关联相关笔记。
2. 有项目发现 → 写项目 memory-hub（不动 Obsidian）。
3. 每次工作结束 → 在 `90-System/Daily-Notes/YYYY-MM-DD.md` 追加当天要点（若无则创建）。
4. **Obsidian vault 的 git 提交（若启用）遵循用户确认；memory-hub 自动 push GitHub（已有约定）。**

### 读取（任何 agent 会话开始时）
1. 先看 `90-System/MOC.md`（内容地图）→ 定位相关区域。
2. 个人规则类问题 → `10-Agents/Personal-Rules.md`。
3. 项目任务 → 读对应 `*-memory-hub` 入口页（Obsidian 只做导航）。
4. 每日开始时读当日 Daily Note 上下文（若有）。

### 笔记规范
- 命名：`Kebab-Case` 或中文主题词，避免空格与特殊字符（Obsidian 链接友好）。
- 每条笔记开头写 1-2 行「这条笔记解决什么问题」（可检索性第一）。
- 状态标签沿用 memory-hub：`current` / `verified-against-source` / `historical` / `needs-source-check`。
- 源码优先：Obsidian 只是记忆导航，实现与精确论断以当前源码/项目文档为准。

## 6. 会话工作流程

### 开始
1. 读 `~/ObsidianBrain/90-System/MOC.md` 与相关区域（个人记忆上下文）。
2. 确认任务类型：个人/通用 → 以 Obsidian 为记忆源；项目 → 再加载对应 memory-hub 入口页：
   - saas2.0 Front → `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md`（强制入口）
   - lsym → `IdeaProjects_lsym_dep/lsym-memory-hub/llms.txt`
   - mdl → `IdeaProjects_mdl_dep/mdl-memory-hub/llms.txt`
3. 确认当前分支、任务范围、是否授权测试/编译。

### 结束
1. 更新当日 Daily Note（Obsidian `90-System/Daily-Notes/`）。
2. 有个人/通用发现 → 写 Obsidian 对应区域；有项目发现 → 写项目 memory-hub。
3. 记忆库（memory-hub）有新提交自动 push GitHub；Obsidian vault 的同步/提交按用户约定执行。
4. 代码仓库 commit/push 必须先经用户确认。

## 7. 项目速览（导航，详见各 MEMORY.md）

| 项目 | 代码路径 | 分支 | 项目记忆库 |
|------|----------|------|-----------|
| lsym | `IdeaProjects_lsym_dep/slhy` | `lsym_prod` | `lsym-memory-hub` |
| lsym UAT | `IdeaProjects_lsym_uat/slhy` | 参考 `lsym_20260625_limeng_refundTask` | — |
| mdl | `IdeaProjects_mdl_dep/mdl` | — | `mdl-memory-hub` |
| saas2.0 | `IdeaProjects_saas_dep/cateringsass` | `limeng_front` | `saas2.0-memory-hub` |

## 8. 构建命令（本机固定，供 agent 参考）

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
/Users/limeng/shares/apache-maven-3.9.9/bin/mvn -Dmaven.repo.local=/tmp/mdl-m2 \
  -pl <模块列表> -am -DskipTests package
```

## 9. 安全与禁止事项（摘要，与各 agent 手册一致）

- 禁止返回 `null` 或模拟成功；日志/异常/响应禁止输出敏感字段明文（密钥、账号、卡号、手机号、证件号、姓名、验证码等）。
- 金额一律以分传递，禁止浮点数。
- 未收到明确授权：不新增测试、不运行测试、不执行编译。
- Obsidian vault 内不存放密钥/口令/证书私钥等敏感明文；确需记录用「链接到系统钥匙串/1Password」占位说明。
- SaaS Front 专属约束以 `WIKI-START.md` §6 为准。

---

**更新日期**：2026-08-16　**维护者**：ssssgoldhunter
