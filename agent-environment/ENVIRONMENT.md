# Agent 环境复现指南（第二台电脑使用）

> 用途：在**新电脑**上重建与当前机器一致的 DeepSeek Harness 开发环境。
> 阅读顺序：本文件 → `DSH.md`（工作手册）→ `开发操作手册.md`（行为准则）。
> 本目录由 `saas2.0-memory-hub` 随 git 同步到 GitHub，新电脑 clone 后即可按本文操作。

---

## 0. 环境总览（当前机器事实）

| 项 | 值 |
|----|----|
| 桌面端 | Oh-DSH Desktop 0.1.6（Electron，数据目录 `~/.ohdsh`） |
| DSH_HOME | `~/.ohdsh`（desktop profile：`profiles/desktop`） |
| Web GUI | `http://127.0.0.1:3080`（`dsh web` 独立实例，用 `~/.dsh` 全局配置；桌面端自带实例端口随机） |
| 全局指令 | `~/.dsh/AGENTS.md`（= 工作区 `DSH.md` 副本） |
| 默认模型 | `deepseek-v4-flash`（provider `deepseek-official`，effort high） |
| 会话工作区 | `/Users/limeng/workspaces/IdeaProjects_saas_dep`（SaaS 2.0） |
| 记忆库 | `saas2.0-memory-hub/`（git，GitHub 同步，**private**） |
| 第二大脑 | Obsidian `~/ObsidianBrain`（本机主 vault）；跨机同步副本 = 记忆库 `obsidian-brain/` 目录（随 git 同步，见该目录 README） |

---

## 1. DeepSeek Harness（DSH）插件

### 1.1 桌面 Profile 已装插件（`profiles/desktop/package.json` dependencies）

| 插件 | 版本/来源 | 类别 | 用途 | 使用规则 |
|------|-----------|------|------|----------|
| `@liustack/modlens` | 3.17.3（npm） | 视觉 | 图片问答 / 截图 OCR / UI 还原 | 需配置视觉 provider（见 §4）；未配置时 `modlens_read_image` 报 "No vision provider" |
| `@anionex/dsh-vision-toolkit` | 本地 link（`/tmp/vt_src`） | 视觉 | 10 个 `vision_*` 工具 + skill，图片输入变体模型 | 需配置 Credential + 托管 Python 运行时；未就绪时模型选择器只显示原始模型 |

### 1.2 安装方式

```bash
# 在 ~/.ohdsh/profiles/desktop 下
cd ~/.ohdsh/profiles/desktop
# modlens（npm 发布）
dsh plugin --profile desktop add @liustack/modlens
# vision-toolkit（本地源码 link，从仓库 clone 后 link）
dsh plugin --profile desktop add /path/to/dsh-vision-toolkit   # 或按 README 用 npm 包名
dsh plugin --profile desktop install --ignore-scripts
```

### 1.3 桌面 Profile Bundle 组成（`package.json` dsh.profile.bundles）

```yaml
bundles:
  - @deepseek-ai/dsh-base
  - @deepseek-ai/dsh-web-app
  - @oh-dsh/desktop
  - @liustack/modlens
  - @anionex/dsh-vision-toolkit
```

### 1.4 关键配置：`profiles/desktop/cordis.patch.yml`（用户层 patch）

> ⚠️ **必须保留**：禁用 `oh-vision` 的图片声明劫持，否则 vision-toolkit / modlens 的
> 图片输入变体无法注册（模型选择器只显示原始 deepseek-v4）。

```yaml
- id: oh-vision
  disabled: true
```

> 背景：桌面内置 `@oh-dsh/vision` 会给 deepseek-v4 强行声明 image 输入
> （`installDeepSeekV4ImageAdmission`），导致变体 resolve 判定"已是视觉模型"而失败。
> 禁用后 deepseek-v4 恢复 text-only，变体正常注册；图片识别改由插件提供。

---

## 2. MCP 服务器

| 工具 | MCP 服务器 | 配置位置 | 命令 |
|------|-----------|----------|------|
| Codex | `codegraph`（stdio） | `~/.codex/config.toml` `[mcp_servers.codegraph]` | `codegraph serve --mcp` |
| Codex | `node_repl`（stdio） | `~/.codex/config.toml` `[mcp_servers.node_repl]` | `/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node_repl` |
| Claude Code | `codegraph`（stdio） | `~/.claude.json` `mcpServers.codegraph` | `codegraph serve --mcp` |
| DSH | 无（`dsh-mcp-client` 在依赖树，但未注册任何 server） | — | — |

### 2.1 codegraph（三工具共用，代码理解首选）

- 二进制：npx 缓存 `~/.npm/_npx/febab48ff478372d/node_modules/.bin/codegraph`（v0.9.5）
- 已索引仓库（`~/.codegraph/` 存在）：lsym_dep、lsym_uat、mdl_dep、saas_dep、saas_uat
- 用法：`codegraph explore "<符号或问题>"` / `codegraph node <符号或文件>`；MCP 工具 `codegraph_explore` / `codegraph_node`
- 规则：仓库有 `.codegraph/` 才用，没有就跳过（不擅自建索引）

### 2.2 codegraph 安装（新电脑）

```bash
# 全局可用：npx 或 npm i -g
npx -y @colbymchenry/codegraph@0.9.5   # 或 npm i -g @colbymchenry/codegraph
codegraph --version   # 应输出 0.9.5
```

### 2.3 新电脑 MCP 配置示例

```toml
# ~/.codex/config.toml
[mcp_servers.codegraph]
type = "stdio"
command = "codegraph"
args = ["serve", "--mcp"]
```

```json
// ~/.claude.json
{ "mcpServers": { "codegraph": { "command": "codegraph", "args": ["serve", "--mcp"], "type": "stdio" } } }
```

---

## 3. Skills 与插件

### 3.1 superpowers（Codex + Claude Code）

| 工具 | 版本 | 来源 |
|------|------|------|
| Codex | 5.0.7 | `~/.codex/superpowers/`（marketplace 插件） |
| Claude Code | 5.1.0 | `~/.claude/plugins/cache/claude-plugins-official/superpowers/` |

**使用规则（用户已裁决，见 `开发操作手册.md` §15）**：
- ✅ 只用前半段：`brainstorming`（先问清意图/设计，获批）→ `writing-plans`（可执行计划）→ `subagent-driven-development`（子代理分步执行 + 审查）
- ✅ 收尾 / 验收由 agent 自己做
- ⚠️ 代码评审**由用户主动发起**，不自动触发
- ❌ 不采用：TDD 强制、自主长跑（autonomous）、自动评审、git worktrees
- 测试仍需授权：写/跑测试前先问用户

### 3.2 Codex 其他插件（`~/.codex/config.toml` [plugins.*]）

github、outlook-email、superpowers(openai-curated)、teams、superpowers(claude-plugins-official)、
documents、spreadsheets、presentations、chrome、computer-use、pdf、template-creator、sites、visualize、browser

### 3.3 Claude 其他

- 插件：`superpowers@claude-plugins-official`（lsym 项目作用域）
- 模型端点：`https://open.bigmodel.cn/api/anthropic`（GLM 系列：opus/sonnet→glm-5.2[1M]、haiku→glm-4.5-air、reasoning→glm-5.1）

---

## 4. 凭据与密钥（新电脑必须配置，值不写入本仓库）

| 凭据名 | 存放位置 | 用途 |
|--------|----------|------|
| `DEEPSEEK_API_KEY` | `~/.ohdsh/.credentials.yaml` | DeepSeek 模型调用（provider `deepseek-official`） |
| `ZHIPUAI_API_KEY` | `~/.ohdsh/.env` | 智谱 GLM（oh-vision 已禁用，暂未使用；如启用视觉直连需要） |
| `VISION_API_KEY`（可选） | `~/.ohdsh/.credentials.yaml` | vision-toolkit 默认 credential（inferera），未配置则视觉工具不可用 |

> 🔒 安全：密钥值**绝不写入记忆库/文档**；新电脑配置后仅存 `~/.ohdsh/` 本地。
> 视觉方案说明：GLM key 不是插件硬性要求；modlens 可用 Gemini key / Antigravity CLI（免 key）/ Claude 登录复用。

---

## 5. 模型选择器说明（视觉变体）

安装两个视觉插件 + 保留 `cordis.patch.yml` 后，模型选择器出现 3 组 6 个模型：

| 组 | 模型 | 说明 |
|----|------|------|
| DeepSeek | V4-Flash / V4-Pro | 原始纯文本（含图片会话不可切回） |
| DeepSeek (modlens vision) | V4-Flash / V4-Pro (modlens vision) | 图片经 modlens 视觉解析 |
| DeepSeek (Vision Toolkit) | V4-Flash / V4-Pro (Vision Toolkit) | 图片经 vision-toolkit 视觉解析 |

---

## 6. Agent 预设（ssss dsh）

- 位置：`$DSH_HOME/.agent-presets/ssss-dsh/`（`agent.cordis.yml` + `preset.yml`）
- 用途：严格高级工程师模式（行为准则内置 persona）
- 新电脑重建：复制本仓库 `agent-environment/presets/ssss-dsh/` 到 `~/.ohdsh/.agent-presets/ssss-dsh/`
- 设为默认：settings 里 `agent-presets.default = ssss-dsh`

---

## 7. 新电脑搭建步骤（速查）

```bash
# 1. 装 Oh-DSH Desktop（.dmg）
# 2. clone 记忆库（含本环境包）
git clone <saas2.0-memory-hub 仓库地址> ~/workspaces/IdeaProjects_saas_dep/saas2.0-memory-hub
# 3. 安装 DSH 插件（§1.2）
# 4. 写 cordis.patch.yml（§1.4）
# 5. 配置凭据（§4）
# 6. 装 codegraph（§2.2）+ 配置 MCP（§2.3）
# 7. 装 superpowers（§3.1）
# 8. 复制 agent 预设（§6）
# 9. 复制工作手册：DSH.md → ~/.dsh/AGENTS.md（§8）
# 10. 启动 web：见 start-web.sh
```

---

## 8. 手册部署（新电脑）

| 手册 | 源（本仓库 agent-environment/） | 目标 |
|------|-------------------------------|------|
| DSH 工作手册 | `DSH.md` | `~/.dsh/AGENTS.md`（DSH 全局，每会话加载） |
| 行为准则 | `开发操作手册.md` | 项目记忆体 `docs/开发操作手册.md`（已在库内） |
| 第二大脑（Obsidian vault） | 本仓库 `obsidian-brain/`（不在 agent-environment/ 内，在记忆库根） | Obsidian 直接打开该目录作为 vault（见 `obsidian-brain/README.md`） |

---

## 9. 网络与 GitHub 认证事实（2026-08-17 实测）

### 9.1 本机网络（github 访问受限）

- **github.com 直连不通**（443 连接超时）；`api.github.com` 直连通（HTTP 200）；
  `raw.githubusercontent.com` / `release-assets.githubusercontent.com` 直连和 HTTP 代理均被重置。
- **可用通道**：
  - 本地代理 `127.0.0.1:7890`（HTTP + SOCKS5，系统代理已开；npm 已配 proxy）；
  - **git 已配全局代理**：`git config --global http.proxy/https.proxy = http://127.0.0.1:7890`；
  - release 大文件（dmg 等）走 HTTP 代理会 SSL 重置，需用 **ghproxy 镜像**（`ghfast.top` /
    `gh-proxy.com` / `ghproxy.net`）前缀 `https://<镜像>/https://github.com/...` 下载；
    SOCKS5（`curl -x socks5h://127.0.0.1:7890`）可访问 github.com 但 release-assets 仍失败。

### 9.2 GitHub 凭据（token 认证，不落明文文件）

- 使用 GitHub PAT 替代 SSH，已通过 `git credential approve` 存入 **macOS 钥匙串**
  （`credential.helper = osxkeychain`，全局）；
- **lsym-memory-hub remote 已从 SSH 改为 https**：
  `https://github.com/ssssgoldhunter/lsym-memory-hub.git`（原 `git@github.com-lsym-memory:` 废弃，
  对应 `~/.ssh/lsym_memory_hub` 密钥未提供）；
- saas2.0-memory-hub remote 本就是 https，同走钥匙串 token；
- ⚠️ 会话中贴过的 PAT 用后应吊销轮换；token 值绝不写入记忆库。

### 9.3 Oh-DSH Desktop 安装来源

- 官方仓库：`hust-open-atom-club/oh-dsh`（GitHub），release `v0.1.6` 提供
  `Oh-DSH-Desktop-0.1.6-arm64.dmg`（Apple Silicon）/ `-x64.dmg`（Intel）；
- 2026-08-17 已装 `/Applications/Oh-DSH Desktop.app`（v0.1.6，arm64）；
  首次运行后创建 `~/.ohdsh` 与桌面 profile，再补桌面插件（modlens/vision-toolkit）与
  `cordis.patch.yml`（禁 oh-vision）。

---

**更新日期**：2026-08-16　**维护者**：ssssgoldhunter
