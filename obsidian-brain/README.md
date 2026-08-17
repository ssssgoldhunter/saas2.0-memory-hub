# obsidian-brain — 第二大脑（Obsidian 唯一个人记忆）

> 本目录是 Obsidian 第二大脑 vault 的**跨电脑同步副本**，随 `saas2.0-memory-hub`
> git 仓库同步（仓库已设为 **private**，仅本人账号可见）。
> 主 vault 路径：`~/ObsidianBrain`（本机）。第二台电脑用本目录作为 vault 打开。

## 是什么

Obsidian = 唯一个人记忆系统 / 第二大脑（个人规则、通用知识、跨项目沉淀、会话记忆）。
与各项目 `*-memory-hub`（项目事实）构成**双轨制**，互不替代。规范见
`90-System/OBSIDIAN-BRAIN-MANUAL.md`。

## 第二台电脑使用（Mac）

```bash
# 1. 前提：GitHub 账号已登录（gh 或 SSH key）；仓库是私有的，需本人账号访问
# 2. clone 记忆库
git clone https://github.com/ssssgoldhunter/saas2.0-memory-hub.git ~/workspaces/IdeaProjects_saas_dep/saas2.0-memory-hub

# 3. 用 Obsidian 打开本目录作为 vault：
#    Obsidian → 打开其他仓库 → 选择 ~/workspaces/IdeaProjects_saas_dep/saas2.0-memory-hub/obsidian-brain
#    或命令行：open -a Obsidian ~/workspaces/IdeaProjects_saas_dep/saas2.0-memory-hub/obsidian-brain
```

## 日常同步（写笔记后）

```bash
cd ~/workspaces/IdeaProjects_saas_dep/saas2.0-memory-hub
git add obsidian-brain/
git commit -m "obsidian: <今日要点>"
git push
```

换电脑开始工作前：`git pull`。

## 注意

- **仓库是 private**：只有 ssssgoldhunter 账号可见，第二台电脑必须用本人 GitHub 登录。
- `.obsidian/workspace.json`（界面布局）已被 `.gitignore` 排除，各机器各自维护。
- vault 内不存放密钥/口令/证书私钥等敏感明文（见 `OBSIDIAN-BRAIN-MANUAL.md`）。
- 本目录由 git 同步；如后续需要 git 之外的双向实时同步（iCloud 等），可另行配置。

---
**更新日期**：2026-08-16　**维护者**：ssssgoldhunter
