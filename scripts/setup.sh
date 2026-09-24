#!/usr/bin/env bash
# setup.sh — GitHub Agent Link 首次配置脚本
# 用法：bash scripts/setup.sh
# 功能：检测环境 → 引导登录 → 检查 SSH → 生成仓库地图 → 收集偏好
set -euo pipefail

# 获取脚本所在目录（兼容 macOS）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_FILE="$SKILL_ROOT/profile/user-github.md"

echo "╔══════════════════════════════════════════════════╗"
echo "║   GitHub Agent Link — 首次配置向导                ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ────────────────── 第 1 步：环境自检 ──────────────────
echo "▶ [1/5] 环境自检"

if command -v git &>/dev/null; then
    echo "  ✓ git $(git --version)"
else
    echo "  ✗ git 未安装"
    echo "    安装命令：brew install git"
    exit 1
fi

if command -v gh &>/dev/null; then
    echo "  ✓ gh $(gh --version | head -1)"
else
    echo "  ✗ gh CLI 未安装"
    echo "    安装命令：brew install gh"
    echo "    或访问 https://cli.github.com/"
    exit 1
fi

echo ""

# ────────────────── 第 2 步：检查登录状态 ──────────────────
echo "▶ [2/5] 检查 GitHub 登录状态"

if gh auth status &>/dev/null 2>&1; then
    GH_USER=$(gh api user --jq .login 2>/dev/null || echo "")
    if [ -n "$GH_USER" ]; then
        echo "  ✓ 已登录：$GH_USER"
    else
        echo "  ⚠ gh auth 状态异常，请重新登录"
        echo "    运行：gh auth login"
        exit 1
    fi
else
    echo "  ✗ 未登录 GitHub"
    echo ""
    echo "  请手动执行以下步骤："
    echo "  1. 运行：gh auth login"
    echo "  2. 选择：GitHub.com"
    echo "  3. 协议：SSH（推荐）"
    echo "  4. 认证方式：Login with a web browser"
    echo "  5. 终端会显示一次性代码（如 XXXX-XXXX）"
    echo "  6. 浏览器打开 https://github.com/login/device 粘贴代码完成授权"
    echo ""
    echo "  完成后重新运行本脚本。"
    exit 1
fi

echo ""

# ────────────────── 第 3 步：SSH 密钥检查 ──────────────────
echo "▶ [3/5] 检查 SSH 密钥"

SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY" ]; then
    echo "  ✓ SSH 密钥已存在：$SSH_KEY"
    # 检查是否已上传到 GitHub
    if gh ssh-key list 2>/dev/null | grep -q "agent-link\|id_ed25519" 2>/dev/null; then
        echo "  ✓ 公钥已上传到 GitHub"
    else
        echo "  ⚠ 公钥可能未上传到 GitHub，尝试上传..."
        gh ssh-key add "${SSH_KEY}.pub" --title "github-agent-link $(date +%Y-%m-%d)" 2>/dev/null && echo "  ✓ 公钥已上传" || echo "  ⚠ 上传失败，请手动运行：gh ssh-key add ~/.ssh/id_ed25519.pub"
    fi
else
    echo "  ✗ 未找到 SSH 密钥"
    echo "    生成命令：ssh-keygen -t ed25519 -C \"github-agent-link\""
    echo "    上传命令：gh ssh-key add ~/.ssh/id_ed25519.pub"
    echo ""
    echo "  完成后重新运行本脚本。"
    exit 1
fi

echo ""

# ────────────────── 第 4 步：生成仓库地图 ──────────────────
echo "▶ [4/5] 生成仓库地图"

# 调用 sync_profile.sh 更新仓库地图
if [ -f "$SCRIPT_DIR/sync_profile.sh" ]; then
    bash "$SCRIPT_DIR/sync_profile.sh"
else
    echo "  ✗ sync_profile.sh 未找到，跳过"
fi

echo ""

# ────────────────── 第 5 步：验证与总结 ──────────────────
echo "▶ [5/5] 验证配置"

GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
GH_NAME=$(gh api user --jq .name 2>/dev/null || echo "")
REPO_COUNT=$(gh repo list --limit 200 --json name 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")

echo "  ✓ 账号：$GH_USER${GH_NAME:+ ($GH_NAME)}"
echo "  ✓ 仓库数量：$REPO_COUNT"
echo "  ✓ Profile 文件：$PROFILE_FILE"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   配置完成！                                      ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                    ║"
echo "║  · 凭证只存本机 gh 钥匙串，不落盘到 Skill 目录    ║"
echo "║  · profile/ 内只有仓库地图等非敏感信息             ║"
echo "║  · 可直接打包整个 skill 文件夹分享给其他 Agent     ║"
echo "║                                                    ║"
echo "╚══════════════════════════════════════════════════╝"
