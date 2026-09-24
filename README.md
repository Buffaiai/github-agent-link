# GitHub Agent Link

> 用户个人 GitHub 连接器 Skill — 一次配置，全网 Agent 可用。

## 这是什么

一个 Skill，让你**手动配置一次 GitHub 身份**后，任何加载此 Skill 的 AI Agent 都能：

- 了解你的仓库地图（有哪些项目、什么语言、活跃度）
- 直接帮你新建仓库并上传本地项目
- 推送代码、补 README/LICENSE、设置 topics
- 在不同 Agent 之间无缝共享，无需重新配置

## 快速开始

### 1. 首次配置（一次性，约 2 分钟）

```bash
cd github-agent-link
bash scripts/setup.sh
```

脚本会引导你完成：
1. 环境自检（git + gh CLI）
2. GitHub 登录（`gh auth login`，浏览器授权）
3. SSH 密钥生成与上传
4. 仓库地图自动生成
5. 偏好收集

> **安全说明**：GitHub 凭证只存于本机 `gh` 钥匙串（`~/.config/gh/`），Skill 目录内不含任何密钥或 token，可安全分享。

### 2. 日常使用（让 Agent 操作你的 GitHub）

在支持的 Agent（Trae、Claude Code 等）中说：

- "新建仓库并上传这个项目"
- "我有哪些 GitHub 仓库？"
- "把这个项目推送到 GitHub"
- "开源发布这个项目"

Agent 会自动读取 `profile/user-github.md` 获取你的身份和偏好，然后执行操作。

### 3. 分享给其他 Agent

- **同机器**：Agent 自动加载 Skill，复用已有 gh 登录态，即刻可用
- **跨机器**：拷贝 Skill 文件夹过去，运行 `bash scripts/setup.sh` 重新配置（约 2 分钟）

## 目录结构

```
github-agent-link/
├── SKILL.md                        # Skill 定义：触发词 + 工作流程
├── scripts/
│   ├── setup.sh                    # 首次配置向导
│   ├── sync_profile.sh             # 仓库地图同步（从 GitHub 拉取）
│   └── new_repo.sh                 # 新建仓库并推送本地项目
├── profile/
│   ├── user-github.template.md     # Profile 模板
│   └── user-github.md              # 配置产物（gitignore，含仓库地图）
├── .gitignore
├── LICENSE
└── README.md
```

## 脚本说明

| 脚本 | 用途 |
|------|------|
| `setup.sh` | 首次配置：环境检测 → gh 登录引导 → SSH 密钥 → 仓库地图 → 偏好收集 |
| `sync_profile.sh` | 从 GitHub API 拉取用户信息和仓库列表，写入 `profile/user-github.md` |
| `new_repo.sh` | 在当前目录初始化 git、生成 README/LICENSE/.gitignore、创建 GitHub 仓库并推送 |

## 安全红线

- **凭证零落盘**：token 只存本机 gh 钥匙串，Skill 目录不含密钥
- **无猜测推送**：推送前确认 remote 正确
- **force push 需显式确认**：默认禁用
- **删除操作需二次确认**：`gh repo delete` 等不可逆操作必须确认
- **profile 只存非敏感信息**：账号名、仓库名、描述、语言标签

## 前置依赖

- [Git](https://git-scm.com/) — 版本控制
- [GitHub CLI (gh)](https://cli.github.com/) — GitHub 命令行工具
- macOS / Linux（bash 环境）

## License

[MIT](LICENSE)
