# DSH-Mode — DeepSeek Harness 工具模式

> 记录 DSH（Oh-DSH Desktop / DeepSeek Harness）在本机的工作模式与特有约定。
> 通用规则统一放 `10-Agents/Personal-Rules.md`，此处只记工具差异。
> 状态标签：`current`（2026-08-16 建立，与 `DSH.md` 同步维护）

## 这条笔记解决什么问题
DSH agent（包括本文件读者）开机第一件事要知道：DSH 是什么、规则在哪、记忆怎么双轨接入、会话怎么开始/结束。避免每次会话从零摸索。

## 工具事实
| 项 | 值 |
|----|----|
| 全称 | DeepSeek Harness（Oh-DSH Desktop 0.1.6，本机 AI 代理执行环境） |
| Web GUI | http://127.0.0.1:3080（用户所说的「本页面/本 GUI」） |
| 全局指令 | `~/.dsh/AGENTS.md`（= 工作区 `DSH.md` 副本，每次会话自动加载） |
| 会话工作区 | `/Users/limeng/workspaces/IdeaProjects_saas_dep`（SaaS 2.0 项目） |
| 项目记忆库 | `saas2.0-memory-hub/`（git 仓库，GitHub 自动同步） |
| 用户数据 | `~/.ohdsh/`（profiles/desktop 为桌面 Profile，已装 vision-toolkit、modlens 两个插件） |

## 与其它工具的关键差异（相对 Codex / Claude Code / zcode）
1. **工具纪律更严格**：文件查看用 read/glob/grep，修改用 write/edit，**不用 shell 的 cat/find/grep**。
2. **bash 无状态**：每次调用新 shell，需 `workdir` 指定目录；后台任务用 job 系列工具管理。
3. **插件化能力**：视觉能力来自插件（dsh-vision-toolkit / modlens），需配置视觉 API Credential 才可用；未配置时图片直读失败，可用 macOS Vision OCR（Swift）兜底。
4. **长期目标**：单一长目标用 goal 工具；有界委派用 subagent（默认后台）；大规模编排仅在用户明确要求时用 workflow。
5. **记忆接入**：与其它工具一致，双轨制（见下），但 DSH 全局指令已内置强制「开始读 Obsidian、结束写 Obsidian」流程。
6. **行为准则**：需求不猜只问；思考/设计/规划用 pro（deepseek-v4-pro）、执行用 flash（deepseek-v4-flash，agent 自动切换）；codegraph 优先；项目 wiki 为主、Obsidian 仅本地同步；需求/功能完成提交前更新并蒸馏 wiki。合并权威版见 `saas2.0-memory-hub/docs/开发操作手册.md`。

## 记忆双轨接入（本模式强制）
- **第二大脑（Obsidian `~/ObsidianBrain`）** = 个人/通用记忆：开始读 `90-System/MOC.md` → 定位区域；个人规则读 `10-Agents/Personal-Rules.md`；结束追加当日 `90-System/Daily-Notes/YYYY-MM-DD.md`。
- **项目记忆（`*-memory-hub`）** = 项目事实：saas2.0 强制入口 `saas2.0-memory-hub/docs/saas2.0 重构/WIKI-START.md`；lsym → `lsym-memory-hub/llms.txt`；mdl → `mdl-memory-hub/llms.txt`。
- 判断标准：个人/通用 → Obsidian；项目 → memory-hub；项目内通用结论双写。

## 会话工作流程
### 开始
1. 读 `~/ObsidianBrain/90-System/MOC.md` 与相关区域（个人记忆上下文）。
2. 加载对应项目 memory-hub 入口页。
3. 确认当前分支、任务范围、是否授权测试/编译。

### 结束
1. 追加当日 Daily Note（Obsidian）。
2. 个人/通用发现 → Obsidian；项目发现 → 项目 memory-hub。
3. memory-hub 有新提交自动 push GitHub（无需询问）；代码仓库 commit/push 必须先经用户确认。

## 本机构建命令（固定）
```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
/Users/limeng/shares/apache-maven-3.9.9/bin/mvn -Dmaven.repo.local=/tmp/mdl-m2 \
  -pl <模块列表> -am -DskipTests package
```

## 安全红线（与 Personal-Rules 一致）
- 禁止返回 `null` 或模拟成功；敏感字段（密钥/账号/卡号/手机号/证件号/姓名/验证码）禁止明文输出。
- 金额一律以分传递，禁止浮点数。
- 未获明确授权：不新增测试、不运行测试、不执行编译。
- Obsidian vault 内不存密钥明文。
- SaaS Front 专属约束以 `WIKI-START.md` §6 为准。

---
**维护**：与工作区 `DSH.md` / `~/.dsh/AGENTS.md` 同步更新（2026-08-16）
