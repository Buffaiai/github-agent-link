# GitHub Agent Link 使用文档

> 完整配置步骤、脚本参数说明、示例命令与故障排查指南。

---

## 目录

- [1. 概述](#1-概述)
- [2. 前置依赖](#2-前置依赖)
- [3. 安装](#3-安装)
- [4. 首次配置（详细步骤）](#4-首次配置详细步骤)
- [5. 日常使用：让 Agent 操作你的 GitHub](#5-日常使用让-agent-操作你的-github)
- [6. 脚本参数手册](#6-脚本参数手册)
  - [6.1 setup.sh](#61-setupsh)
  - [6.2 sync_profile.sh](#62-sync_profileh)
  - [6.3 new_repo.sh](#63-new_reposh)
- [7. Profile 文件格式](#7-profile-文件格式)
- [8. 分享给其他 Agent](#8-分享给其他-agent)
- [9. 故障排查](#9-故障排查)
- [10. 安全模型](#10-安全模型)
- [11. FAQ](#11-faq)

---

## 1. 概述

GitHub Agent Link 是一个 Skill，解决的核心问题是：**AI Agent 每次操作用户 GitHub 都要重新了解身份和上下文**。

一次配置后，任何加载此 Skill 的 Agent 都能：

| 能力 | 说明 |
|------|------|
| 仓库感知 | 自动读取用户的仓库地图（名称、语言、可见性、活跃度） |
| 新建仓库 | 一键建仓 + 生成 README/LICENSE/.gitignore + 推送 |
| 推送代码 | 已有项目自动挂 remote 并 push，新项目自动建仓 |
| 仓库地图刷新 | 从 GitHub API 拉取最新仓库列表写入 profile |
| 跨 Agent 共享 | Skill 文件夹可直接拷贝/打包给其他 Agent |

**设计原则**：凭证零落盘——GitHub token 只存本机 `gh` 钥匙串，Skill 目录不含任何密钥。

---

## 2. 前置依赖

| 工具 | 最低版本 | 安装命令 | 用途 |
|------|----------|----------|------|
| [Git](https://git-scm.com/) | 2.30+ | `brew install git` | 版本控制 |
| [GitHub CLI (gh)](https://cli.github.com/) | 2.30+ | `brew install gh` | GitHub API 操作 |
| Python 3 | 3.8+ | macOS 自带 / `brew install python3` | 仓库地图 JSON 解析 |
| Bash | 4.0+ | macOS 自带 | 脚本运行环境 |

验证安装：

```bash
git --version    # 应显示 git version 2.30+
gh --version     # 应显示 gh version 2.30+
python3 --version # 应显示 Python 3.8+
```

---

## 3. 安装

### 方式一：从 GitHub 克隆

```bash
git clone git@github.com:Buffaiai/github-agent-link.git
cd github-agent-link
```

### 方式二：直接拷贝文件夹

将整个 `github-agent-link/` 文件夹拷贝到目标位置即可。Skill 无编译步骤，无外部依赖安装。

### 放置位置

根据你使用的 Agent，放到对应的 skills 目录：

| Agent | skills 目录 |
|-------|------------|
| Trae | `~/.trae-cn/skills/` 或项目内 skills 目录 |
| Claude Code | 项目内 `.claude/skills/` |
| 其他 | 参考各 Agent 的 Skill 加载文档 |

---

## 4. 首次配置（详细步骤）

### 第 1 步：运行配置向导

```bash
cd github-agent-link
bash scripts/setup.sh
```

脚本会依次执行 5 个阶段的检测。如果所有依赖就绪且已登录，你会看到：

```
╔══════════════════════════════════════════════════╗
║   GitHub Agent Link — 首次配置向导                ║
╚══════════════════════════════════════════════════╝

▶ [1/5] 环境自检
  ✓ git git version 2.50.1
  ✓ gh gh version 2.100.0

▶ [2/5] 检查 GitHub 登录状态
  ✓ 已登录：your-username

▶ [3/5] 检查 SSH 密钥
  ✓ SSH 密钥已存在：/home/user/.ssh/id_ed25519

▶ [4/5] 生成仓库地图
✓ Profile 已更新

▶ [5/5] 验证配置
  ✓ 账号：your-username
  ✓ 仓库数量：7
  ✓ Profile 文件：profile/user-github.md

╔══════════════════════════════════════════════════╗
║   配置完成！                                      ║
╚══════════════════════════════════════════════════╝
```

### 第 2 步（如未登录）：GitHub 授权

如果 setup.sh 在第 2 步报 `✗ 未登录 GitHub`，按以下步骤操作：

```bash
gh auth login
```

按交互提示选择：

```
? What account do you want to log into? → GitHub.com
? What is your preferred protocol for Git operations? → SSH
? How would you like to authenticate GitHub CLI? → Login with a web browser
```

终端会显示一次性代码：

```
! First copy your one-time code: XXXX-XXXX
Press Enter to open github.com in your browser...
```

1. 按 Enter 打开浏览器
2. 将代码 `XXXX-XXXX` 粘贴到 https://github.com/login/device
3. 点击 Authorize
4. 回到终端，等待 `✓ Authentication complete`

完成后重新运行 `bash scripts/setup.sh`。

### 第 3 步（如无 SSH 密钥）：生成密钥

如果 setup.sh 在第 3 步报 `✗ 未找到 SSH 密钥`：

```bash
# 生成密钥（一路回车即可，或设置密码短语）
ssh-keygen -t ed25519 -C "github-agent-link"

# 上传公钥到 GitHub
gh ssh-key add ~/.ssh/id_ed25519.pub --title "github-agent-link"

# 测试 SSH 连接
ssh -T git@github.com
# 应显示: Hi your-username! You've successfully authenticated...
```

完成后重新运行 `bash scripts/setup.sh`。

### 第 4 步：确认仓库地图

配置完成后，查看生成的 profile：

```bash
cat profile/user-github.md
```

你会看到类似这样的内容：

```markdown
# 用户 GitHub Profile

> 此文件由 scripts/sync_profile.sh 自动生成，请勿手动编辑。
> 最后更新：2026-09-24 09:44:49

## 账号信息

| 字段 | 值 |
|------|-----|
| 用户名 | your-username |
| 姓名 | Your Name |
| 公开仓库数 | 7 |
| 注册日期 | 2026-08-22 |

## 仓库地图

| # | 仓库名 | 描述 | 语言 | 可见性 | 星标 | 最后推送 |
|---|--------|------|------|--------|------|----------|
| 1 | project-a | 一个有趣的项目 | Python | 🌐 公开 | ⭐3 | 2026-09-22 |
| 2 | project-b | 另一个项目 | TypeScript | 🔒 私有 | ⭐0 | 2026-09-19 |
...
```

### 第 5 步（可选）：手动补充偏好

编辑 `profile/user-github.md`，在文件末尾添加你的个人偏好：

```markdown
## 个人偏好

| 偏好 | 值 |
|------|-----|
| 默认可见性 | public |
| 默认分支 | main |
| License 偏好 | MIT |
| 命名习惯 | kebab-case |

## 活跃项目

- project-a（当前正在维护的主项目）
- project-c（实验性项目）
```

---

## 5. 日常使用：让 Agent 操作你的 GitHub

配置完成后，在任何加载了此 Skill 的 Agent 中直接用自然语言指令即可。

### 示例对话

#### 新建仓库并上传项目

```
你：帮我把当前目录的项目上传到 GitHub，仓库名叫 my-awesome-tool，
    描述是"一个超棒的工具集"，开源，MIT 协议。

Agent：读取 profile 确认身份...
       确认信息：
         仓库名: my-awesome-tool
         描述: 一个超棒的工具集
         可见性: public
         License: MIT
       生成 README.md、LICENSE、.gitignore...
       执行 git init + commit + gh repo create + push...
       完成！仓库地址: https://github.com/your-username/my-awesome-tool
```

#### 查询仓库列表

```
你：我有哪些 GitHub 仓库？

Agent：读取 profile/user-github.md...
       你共有 7 个仓库：
       1. project-a (Python, 公开, 最后推送 2026-09-22)
       2. project-b (TypeScript, 私有, 最后推送 2026-09-19)
       ...
       如需刷新仓库地图，请说"刷新仓库列表"。
```

#### 推送已有项目

```
你：这个项目已经有本地 git 了，帮我推到 GitHub。

Agent：检测到已有 .git 但无 remote...
       走建仓流程：
         仓库名: current-dir-name
         可见性: public (来自 profile 偏好)
       挂载 remote 并推送...
       完成！仓库地址: https://github.com/your-username/current-dir-name
```

#### 刷新仓库地图

```
你：刷新一下我的仓库列表

Agent：运行 sync_profile.sh...
       ✓ 已更新 7 个仓库的地图
```

### 触发词速查

| 意图 | 示例说法 |
|------|----------|
| 建仓上传 | "新建仓库"/"创建 repo"/"上传项目"/"推送到 GitHub"/"开源这个项目" |
| 查询仓库 | "我的仓库"/"仓库列表"/"仓库地图"/"我有哪些项目" |
| 配置 | "配置 GitHub"/"连接 GitHub"/"gh 登录" |
| 分享 | "分享 GitHub 给其他 Agent"/"让别的 Agent 操作我的 GitHub" |

---

## 6. 脚本参数手册

### 6.1 setup.sh

**用途**：首次配置向导，自动检测环境并引导完成全部配置。

```bash
bash scripts/setup.sh
```

**参数**：无

**执行流程**：

| 步骤 | 检测内容 | 失败时的处理 |
|------|----------|-------------|
| 1/5 环境自检 | `git --version`、`gh --version` | 给出 `brew install` 命令并退出 |
| 2/5 登录状态 | `gh auth status` | 输出 `gh auth login` 操作指南并退出 |
| 3/5 SSH 密钥 | `~/.ssh/id_ed25519` 是否存在 | 给出 `ssh-keygen` + `gh ssh-key add` 命令并退出 |
| 4/5 仓库地图 | 调用 `sync_profile.sh` | 如脚本缺失则跳过，不中断 |
| 5/5 验证 | `gh api user` 确认身份 | 输出配置摘要 |

**示例输出**：见[第 4 节](#4-首次配置详细步骤)。

---

### 6.2 sync_profile.sh

**用途**：从 GitHub API 拉取用户信息和仓库列表，格式化写入 `profile/user-github.md`。

```bash
bash scripts/sync_profile.sh
```

**参数**：无

**前置条件**：已运行 `gh auth login`

**输出文件**：`profile/user-github.md`（自动覆盖旧文件）

**拉取的数据**：

| 字段 | API 来源 | 说明 |
|------|---------|------|
| 用户名 | `gh api user --jq .login` | GitHub 账号名 |
| 姓名 | `gh api user --jq .name` | 显示名 |
| 简介 | `gh api user --jq .bio` | 个人简介 |
| 粉丝/关注数 | `gh api user --jq .followers/.following` | 统计数据 |
| 公开仓库数 | `gh api user --jq .public_repos` | 公开仓库计数 |
| 注册日期 | `gh api user --jq .created_at` | 账号创建时间 |
| 仓库列表 | `gh repo list --limit 200` | 最多 200 个仓库 |

**仓库列表字段**：

```
仓库名 | 描述 | 主语言 | 可见性 | 星标数 | 最后推送时间
```

**使用场景**：
- 首次配置后生成仓库地图
- 新建仓库后更新地图
- 定期刷新保持地图最新

**示例**：

```bash
# 刷新仓库地图
bash scripts/sync_profile.sh
# 输出: ✓ Profile 已更新：profile/user-github.md

# 查看更新结果
cat profile/user-github.md | head -30
```

---

### 6.3 new_repo.sh

**用途**：在当前目录初始化 git 仓库、生成项目文件、创建 GitHub 仓库并推送。

```bash
bash scripts/new_repo.sh <仓库名> [选项]
```

**参数**：

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `<仓库名>` | 是 | — | 仓库名称（建议 kebab-case） |
| `--description "描述"` | 否 | （无） | 仓库描述 |
| `--public` | 否 | 默认 | 公开仓库 |
| `--private` | 否 | — | 私有仓库 |
| `--license <类型>` | 否 | MIT | License 类型：MIT / Apache-2.0 / none |
| `--help` | 否 | — | 显示帮助 |

**执行流程**：

```
[1/4] 生成项目文件
  ├─ README.md（如不存在则生成，含仓库名/描述/License 徽标）
  ├─ LICENSE（按 --license 参数生成 MIT 或 Apache-2.0）
  └─ .gitignore（通用模板：OS/IDE/Env/Build/Logs）

[2/4] Git 初始化
  ├─ git init -b main（如已有 .git 则跳过）
  ├─ git add -A
  └─ git commit -m "Initial commit"（如无变更则跳过）

[3/4] 创建 GitHub 仓库
  ├─ 检查 remote 是否已存在
  ├─ gh repo create <name> --<visibility> --source=. --remote=origin --push
  └─ 失败时给出 3 种可能原因

[4/4] 更新仓库地图
  └─ 自动调用 sync_profile.sh
```

**示例命令**：

```bash
# 最简单：公开仓库 + MIT License
bash scripts/new_repo.sh my-project

# 带描述
bash scripts/new_repo.sh my-project --description "一个超棒的工具集"

# 私有仓库 + Apache 2.0
bash scripts/new_repo.sh my-project --description "内部工具" --private --license Apache-2.0

# 不生成 LICENSE 文件
bash scripts/new_repo.sh my-project --license none
```

**交互确认**：脚本执行前会显示配置摘要并要求确认：

```
  仓库名:   my-project
  描述:     一个超棒的工具集
  可见性:   public
  License:  MIT
  本地目录: /Users/you/projects/my-project
  账号:     your-username

确认创建仓库并推送？(y/N)
```

**完成输出**：

```
╔══════════════════════════════════════════════════╗
║   完成！                                          ║
╠══════════════════════════════════════════════════╣
║  仓库地址: https://github.com/your-username/my-project
╚══════════════════════════════════════════════════╝
```

---

## 7. Profile 文件格式

`profile/user-github.md` 是配置产物，Agent 读取此文件了解用户身份和仓库。

### 文件结构

```markdown
# 用户 GitHub Profile

> 此文件由 scripts/sync_profile.sh 自动生成，请勿手动编辑。
> 最后更新：YYYY-MM-DD HH:MM:SS

## 账号信息

| 字段 | 值 |
|------|-----|
| 用户名 | your-username |
| 姓名 | Your Name |
| 简介 | ... |
| 粉丝数 | 0 |
| 关注数 | 0 |
| 公开仓库数 | 7 |
| 注册日期 | 2026-01-01 |

## 仓库地图

| # | 仓库名 | 描述 | 语言 | 可见性 | 星标 | 最后推送 |
|---|--------|------|------|--------|------|----------|
| 1 | repo-a | ... | Python | 🌐 公开 | ⭐3 | 2026-09-22 |
| 2 | repo-b | ... | TypeScript | 🔒 私有 | ⭐0 | 2026-09-19 |
...

**总计：7 个仓库**
```

### 手动扩展区域

sync_profile.sh 生成的文件末尾可手动追加：

```markdown
## 个人偏好

| 偏好 | 值 |
|------|-----|
| 默认可见性 | public |
| 默认分支 | main |
| License 偏好 | MIT |
| 命名习惯 | kebab-case |

## 活跃项目

- repo-a（当前主项目，每周更新）
- repo-c（实验性项目）
```

> **注意**：sync_profile.sh 会覆盖账号信息和仓库地图区域，但不会删除手动添加的"个人偏好"和"活跃项目"部分（它们位于文件末尾，不在覆盖范围内）。
>
> **实际上 sync_profile.sh 会覆盖整个文件**。如需保留偏好，请在 sync_profile.sh 执行后手动追加，或修改脚本保留偏好部分。

### 模板文件

`profile/user-github.template.md` 是空白模板，可作为手动配置的起点。

---

## 8. 分享给其他 Agent

### 场景一：同机器不同 Agent

Skill 已在同一台机器上，Agent 只需将其加入自己的 skills 目录：

```bash
# 假设新 Agent 的 skills 目录为 ~/.new-agent/skills/
cp -r github-agent-link ~/.new-agent/skills/
```

新 Agent 首次使用时会自动走第 0 步检测，发现 `gh auth status` 已通过 → 直接可用，无需重新配置。

### 场景二：跨机器分享

```bash
# 打包
cd /path/to/skills
zip -r github-agent-link.zip github-agent-link/

# 传输（示例：scp）
scp github-agent-link.zip user@remote:/tmp/

# 在目标机器上解压并配置
unzip /tmp/github-agent-link.zip -d ~/.skills/
cd ~/.skills/github-agent-link
bash scripts/setup.sh   # 约 2 分钟完成配置
```

### 场景三：通过 Git 仓库分享

```bash
# 克隆
git clone https://github.com/your-username/github-agent-link.git
cd github-agent-link

# 配置
bash scripts/setup.sh
```

> **安全提示**：`profile/user-github.md` 已被 `.gitignore` 排除，不会泄露仓库地图。GitHub 凭证只存在本机，不随 Skill 文件传输。

---

## 9. 故障排查

### 问题 1：`✗ gh CLI 未安装`

```
原因：未安装 GitHub CLI
解决：
  brew install gh          # macOS
  sudo apt install gh      # Ubuntu/Debian
  # 或访问 https://cli.github.com/ 下载
```

### 问题 2：`✗ 未登录 GitHub`

```
原因：gh 未完成认证
解决：
  gh auth login
  # 选择：GitHub.com → SSH → Login with a web browser
  # 按提示完成浏览器授权
```

### 问题 3：`✗ 未找到 SSH 密钥`

```
原因：本机没有 SSH 密钥或路径不对
解决：
  ssh-keygen -t ed25519 -C "github-agent-link"
  # 一路回车（或设密码短语）
  gh ssh-key add ~/.ssh/id_ed25519.pub --title "github-agent-link"
  ssh -T git@github.com  # 验证
```

### 问题 4：`仓库创建失败 (403 Resource not accessible)`

```
原因：gh token 权限不足，缺少 repo scope
解决：
  gh auth refresh -s repo
  # 或重新登录：
  gh auth login
```

### 问题 5：`推送失败 (Permission denied)`

```
原因：SSH 密钥未上传到 GitHub 或密钥格式不对
排查：
  ssh -T git@github.com
  # 如显示 "Hi username! You've successfully authenticated" 则 SSH 正常
  # 如报错，检查：
  gh ssh-key list  # 查看已上传的密钥
  gh ssh-key add ~/.ssh/id_ed25519.pub  # 重新上传
```

### 问题 6：`sync_profile.sh 仓库列表为空`

```
原因1：账号确实没有仓库
原因2：gh token 权限不足，无法读取私有仓库
排查：
  gh repo list --limit 10  # 手动检查
  gh auth status           # 检查 token scope
  gh auth refresh -s repo  # 补充权限
```

### 问题 7：`new_repo.sh 提示仓库名已存在`

```
原因：GitHub 上已有同名仓库
解决：
  # 方案1：改名
  bash scripts/new_repo.sh different-name --description "..."

  # 方案2：先删除旧仓库（需确认）
  gh repo delete old-name --yes  # 谨慎！不可恢复

  # 方案3：手动在 GitHub 网页改名/删除
```

### 问题 8：Python3 相关错误

```
原因：sync_profile.sh 用 python3 解析 JSON，系统可能缺少或版本过低
解决：
  brew install python3      # macOS
  python3 --version         # 确认 3.8+
```

---

## 10. 安全模型

### 凭证存储

| 数据 | 存储位置 | 是否随 Skill 分享 |
|------|----------|------------------|
| GitHub Token | `~/.config/gh/` (gh 钥匙串) | 否 |
| SSH 私钥 | `~/.ssh/id_ed25519` | 否 |
| SSH 公钥 | `~/.ssh/id_ed25519.pub` | 否（已上传 GitHub） |
| 用户名/仓库名 | `profile/user-github.md` | 是（非敏感） |
| 仓库描述/语言 | `profile/user-github.md` | 是（非敏感） |

### .gitignore 排除规则

```gitignore
# 用户个人 GitHub profile（含仓库地图等用户数据）
profile/user-github.md
```

这意味着即使将 Skill 推送到公开 GitHub 仓库，也不会泄露用户的仓库地图。

### 操作红线

| 操作 | 策略 |
|------|------|
| `git push --force` | 默认禁用，需用户明确说"force push"或"强推" |
| `gh repo delete` | 必须向用户二次确认 |
| 修改仓库可见性 | 必须向用户二次确认 |
| 添加 remote | 推送前确认 remote URL 正确，不自动添加未验证的 remote |
| 403 错误 | 排查 gh scope 与 SSH key，不反复重试 |

---

## 11. FAQ

**Q: 为什么不用 Personal Access Token (PAT) 而用 gh auth login？**

A: gh auth login 使用 OAuth device flow，比手动管理 PAT 更安全——token 自动刷新，scope 可控，不会在命令历史中留下明文。如需使用 PAT，可运行 `gh auth login --with-token < token.txt`。

**Q: 可以配置多个 GitHub 账号吗？**

A: 可以。gh 支持多账号：

```bash
gh auth login          # 登录主账号
gh auth switch         # 切换账号
```

但 Skill 的 profile 只记录当前激活账号。如需多账号，可复制多个 Skill 实例，每个实例配置不同账号。

**Q: 私有仓库会出现在仓库地图中吗？**

A: 会。`gh repo list` 默认列出所有你有权限的仓库（包括私有）。但 profile 文件被 `.gitignore` 排除，不会上传到 Git。

**Q: 能限制只拉取公开仓库吗？**

A: 可以修改 `sync_profile.sh`，将 `gh repo list` 改为：

```bash
gh repo list --visibility public --limit 200
```

**Q: Windows 支持吗？**

A: 脚本使用 bash 语法，可在 WSL (Windows Subsystem for Linux) 或 Git Bash 中运行。原生 PowerShell 不支持。建议使用 WSL。

**Q: 如何更新 Skill 本身？**

A:

```bash
cd github-agent-link
git pull origin main
```

> 注意：`git pull` 不会覆盖你的 `profile/user-github.md`（被 .gitignore 排除）。

**Q: 如何卸载？**

A:

```bash
# 删除 Skill 文件夹
rm -rf github-agent-link

# （可选）撤销 gh 授权
gh auth logout

# （可选）删除 SSH 密钥
rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

---

## 附录：完整目录结构

```
github-agent-link/
├── SKILL.md                        # Skill 定义：触发词 + 工作流程
├── scripts/
│   ├── setup.sh                    # 首次配置向导
│   ├── sync_profile.sh             # 仓库地图同步（从 GitHub 拉取）
│   └── new_repo.sh                 # 新建仓库并推送本地项目
├── profile/
│   ├── .gitkeep                    # 占位文件
│   ├── user-github.template.md     # Profile 模板（手动配置参考）
│   └── user-github.md              # 配置产物（gitignore，含仓库地图）
├── .gitignore                      # 排除 profile/user-github.md
├── LICENSE                         # MIT
├── README.md                       # 快速开始指南
└── USAGE.md                        # 本文档
```

---

*最后更新：2026-09-24 | 作者：Buffaiai | License: MIT*
