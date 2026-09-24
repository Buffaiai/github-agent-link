---
name: github-agent-link
description: "用户个人 GitHub 连接器。首次一次性配置后，任何 Agent 可据此了解用户的仓库地图并直接操作其 GitHub（新建仓库、上传本地项目、推送代码、开源发布）。当用户提到：GitHub、建仓、新建仓库、创建 repo、上传项目、推送到 GitHub、push 到 GitHub、开源、发布项目、我的仓库、仓库列表、仓库地图、我有哪些项目、配置 GitHub、GitHub 授权、连接 GitHub、gh 登录，或想让其他 Agent 接管/操作自己的 GitHub 时使用。Use when: GitHub setup, create repo, push local project to GitHub, publish open source, list my repos, or let another agent operate the user's GitHub."
---

# GitHub Agent Link — 用户个人 GitHub 连接器

**作者 / Author：Buffaiai**

一次性配置 GitHub 身份与偏好后，任何加载本 Skill 的 Agent 都能：
- 了解用户的仓库地图（有哪些项目、什么语言、是否活跃）
- 直接帮用户新建仓库并上传本地项目
- 推送代码、补 README/LICENSE、设置 topics
- 在不同 Agent 之间无缝共享，无需重新配置

## 触发词

**操作类**：建仓 / 新建仓库 / 创建 repo / 上传项目 / 推送到 GitHub / push 到 GitHub / 开源这个项目 / 发布到 GitHub
**查询类**：我的仓库 / 仓库列表 / 仓库地图 / 我有哪些项目
**配置类**：配置 GitHub / GitHub 授权 / 连接 GitHub / gh 登录 / 初始化 GitHub
**分享类**：分享 GitHub 给其他 Agent / 让别的 Agent 操作我的 GitHub

**不触发**：纯本地 git 操作（commit/branch 不涉及 GitHub）；日常 PR/issue/CI 审查——若宿主已有 GitHub 插件或 MCP 则优先用之，本 Skill 负责配置、建仓、上传与仓库地图。

## 工作流程

### 第 0 步：状态检测（每次调用必做，不可跳过）

1. 检查 `profile/user-github.md` 是否存在
2. 运行 `gh auth status` 检查登录态
   - 两者齐全 → 直接进入对应操作流程
   - 任一缺失 → 进入流程 A，不要替用户猜测或跳步

### 流程 A：首次配置（一次性，交互式，每步失败即停下求助）

> 运行 `bash scripts/setup.sh` 可自动执行大部分步骤，但涉及浏览器登录的环节需要用户手动操作。

1. **环境自检**：`git --version`、`gh --version`；缺失则给出安装命令（`brew install gh`）
2. **登录引导**：
   - 告诉用户运行 `gh auth login`
   - 选择顺序：`GitHub.com` → `SSH` → `Login with a web browser`
   - 终端会显示一次性代码（如 `XXXX-XXXX`），用户需将其粘贴到 https://github.com/login/device 网页完成授权
   - 等待用户确认登录完成后继续
3. **SSH 密钥**：
   - 检查 `~/.ssh/id_ed25519` 是否存在
   - 无则引导生成：`ssh-keygen -t ed25519 -C "github-agent-link"`
   - 用 `gh ssh-key add ~/.ssh/id_ed25519.pub` 上传公钥（后续推送一律走 SSH）
4. **生成仓库地图**：运行 `bash scripts/sync_profile.sh`，将 `gh api user` 与 `gh repo list --limit 100` 结果写入 `profile/user-github.md`
5. **收集偏好**并写入 profile：
   - 默认可见性（public/private）
   - 默认分支名（main）
   - LICENSE 偏好（MIT/Apache-2.0/none）
   - 命名习惯（kebab-case）
   - 哪些仓库是活跃项目
6. **验证**：`gh api user --jq .login` 确认身份，向用户展示仓库地图摘要
7. **安全说明**：向用户说明——凭证只存在本机 gh 钥匙串，Skill 文件夹内不含任何密钥，可安全分享

### 流程 B：新建仓库并上传本地项目

1. 读 `profile/user-github.md` 确认身份与偏好
2. 与用户确认：
   - 仓库名（kebab-case）
   - 描述
   - 可见性（默认用 profile 中的偏好）
   - 是否要 README/LICENSE/.gitignore
3. 脚手架：按项目语言生成
   - `README.md`（简介/用法/License 徽标）
   - `LICENSE`（按偏好选择）
   - `.gitignore`（按语言匹配）
4. 执行建仓与推送：
   ```bash
   git init -b main
   git add .
   git commit -m "Initial commit"
   gh repo create <name> --<visibility> --source=. --remote=origin --push
   ```
5. 回填：把新仓库追加进 `profile/user-github.md` 仓库地图
6. 输出仓库 URL；可选 `gh repo edit --add-topic <topics>` 补标签

### 流程 C：已有项目上传 / 继续推送

1. 检测目标目录 `.git` 状态：
   - 无 remote → 走流程 B 第 4 步建仓并挂 remote
   - 有 remote → 直接 `git push`
   - 403 时排查 gh scope 与 SSH key，而不是反复重试
2. **红线**：
   - 禁止 `force push`，除非用户明确要求
   - 删除仓库、改公开性必须二次确认

### 流程 D：仓库地图查询 / 刷新

- **查询**「我有哪些仓库」：直接读 `profile/user-github.md` 回答，不重复请求 API
- **刷新**：建仓、改描述、开源新项目后重跑 `bash scripts/sync_profile.sh`

### 流程 E：分享给其他 Agent

1. 确认 `profile/user-github.md` 为最新
2. 打包整个 Skill 文件夹（zip）或拷入对方 Agent 的 skills 目录
3. 对方 Agent 首次使用会自动走第 0 步检测：
   - 同一台机器 → 复用 gh 登录态，即刻可用
   - 跨机器 → 重跑流程 A（约 2 分钟）

## 安全红线

- **凭证零落盘**：GitHub token 只存本机 gh 钥匙串（`~/.config/gh/`），Skill 目录内不含任何密钥
- **无猜测推送**：推送前确认 remote 正确，不自动添加未验证的 remote
- **force push 需显式确认**：默认禁用，用户明确说「force push」或「强推」才执行
- **删除操作需二次确认**：`gh repo delete`、改可见性等不可逆操作必须向用户确认
- **profile 只存非敏感信息**：账号名、仓库名、描述、语言标签，不存 token/email/密码
