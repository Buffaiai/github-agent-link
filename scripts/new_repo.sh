#!/usr/bin/env bash
# new_repo.sh — 在当前目录新建 GitHub 仓库并推送
# 用法：
#   bash scripts/new_repo.sh <仓库名> [--description "描述"] [--public|--private] [--license MIT|Apache-2.0|none]
# 示例：
#   bash scripts/new_repo.sh my-project --description "一个有趣的项目" --public --license MIT
set -euo pipefail

# ────────────────── 参数解析 ──────────────────
REPO_NAME=""
DESC=""
VISIBILITY="public"
LICENSE="MIT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --description)
            DESC="$2"; shift 2 ;;
        --public)
            VISIBILITY="public"; shift ;;
        --private)
            VISIBILITY="private"; shift ;;
        --license)
            LICENSE="$2"; shift 2 ;;
        --help|-h)
            echo "用法: bash scripts/new_repo.sh <仓库名> [--description \"描述\"] [--public|--private] [--license MIT|Apache-2.0|none]"
            exit 0 ;;
        -*)
            echo "未知参数: $1"; exit 1 ;;
        *)
            if [ -z "$REPO_NAME" ]; then
                REPO_NAME="$1"; shift
            else
                echo "多余参数: $1"; exit 1
            fi ;;
    esac
done

if [ -z "$REPO_NAME" ]; then
    echo "用法: bash scripts/new_repo.sh <仓库名> [--description \"描述\"] [--public|--private] [--license MIT|Apache-2.0|none]"
    exit 1
fi

# ────────────────── 前置检查 ──────────────────
if ! gh auth status &>/dev/null 2>&1; then
    echo "✗ 未登录 GitHub，请先运行：gh auth login"
    exit 1
fi

GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
CWD="$(pwd)"

echo "╔══════════════════════════════════════════════════╗"
echo "║   GitHub Agent Link — 新建仓库                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  仓库名:   $REPO_NAME"
echo "  描述:     ${DESC:-（无）}"
echo "  可见性:   $VISIBILITY"
echo "  License:  $LICENSE"
echo "  本地目录: $CWD"
echo "  账号:     $GH_USER"
echo ""

# ────────────────── 确认 ──────────────────
read -p "确认创建仓库并推送？(y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消。"
    exit 0
fi

# ────────────────── 脚手架 ──────────────────
echo ""
echo "▶ [1/4] 生成项目文件"

# README.md
if [ ! -f "$CWD/README.md" ]; then
    cat > "$CWD/README.md" << EOF
# ${REPO_NAME}

${DESC:-（项目描述）}

## Usage

\`\`\`bash
# 用法说明
\`\`\`

## License

$(echo "$LICENSE" | grep -qi "^none$\|^无$" && echo "All rights reserved." || echo "[${LICENSE}](LICENSE)")
EOF
    echo "  ✓ README.md"
else
    echo "  ⚠ README.md 已存在，跳过"
fi

# LICENSE
if [ "$LICENSE" != "none" ] && [ "$LICENSE" != "无" ] && [ ! -f "$CWD/LICENSE" ]; then
    case "$LICENSE" in
        MIT)
            cat > "$CWD/LICENSE" << EOF
MIT License

Copyright (c) $(date +%Y) $GH_USER

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
            ;;
        Apache-2.0)
            # 简化版 Apache 2.0
            cat > "$CWD/LICENSE" << EOF
Apache License, Version 2.0

Copyright $(date +%Y) $GH_USER

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF
            ;;
        *)
            echo "  ⚠ 不支持的 License: $LICENSE，跳过"
            ;;
    esac
    [ -f "$CWD/LICENSE" ] && echo "  ✓ LICENSE ($LICENSE)" || true
else
    [ -f "$CWD/LICENSE" ] && echo "  ⚠ LICENSE 已存在，跳过" || echo "  ⚠ License: $LICENSE（跳过）"
fi

# .gitignore (通用)
if [ ! -f "$CWD/.gitignore" ]; then
    cat > "$CWD/.gitignore" << EOF
# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Env
.env
.env.local
*.pem

# Build
node_modules/
dist/
build/
__pycache__/
*.pyc
*.egg-info/

# Logs
*.log
EOF
    echo "  ✓ .gitignore"
else
    echo "  ⚠ .gitignore 已存在，跳过"
fi

echo ""

# ────────────────── Git 初始化与推送 ──────────────────
echo "▶ [2/4] Git 初始化"

if [ -d "$CWD/.git" ]; then
    echo "  ⚠ 已是 git 仓库，跳过 init"
else
    git init -b main
    echo "  ✓ git init (main)"
fi

git add -A
echo "  ✓ git add"

# 检查是否有变更
if git diff --cached --quiet; then
    echo "  ⚠ 无变更，跳过 commit"
else
    git commit -m "Initial commit"
    echo "  ✓ git commit"
fi

echo ""

# ────────────────── 创建 GitHub 仓库 ──────────────────
echo "▶ [3/4] 创建 GitHub 仓库"

REPO_FLAG="--$VISIBILITY"
# 检查 remote 是否已存在
if git remote get-url origin &>/dev/null 2>&1; then
    echo "  ⚠ origin remote 已存在"
    echo "    当前: $(git remote get-url origin)"
    echo "    如需更换，请先运行: git remote remove origin"
    # 尝试直接推送
    git push -u origin main 2>/dev/null && echo "  ✓ 推送成功" || echo "  ✗ 推送失败，请检查 remote 配置"
    exit 0
fi

GH_CREATE_ARGS="create $REPO_NAME $REPO_FLAG"
if [ -n "$DESC" ]; then
    GH_CREATE_ARGS="$GH_CREATE_ARGS --description \"$DESC\""
fi
GH_CREATE_ARGS="$GH_CREATE_ARGS --source=. --remote=origin --push"

# 执行创建（eval 用于处理带引号的 description）
eval "gh $GH_CREATE_ARGS" 2>&1 || {
    echo "  ✗ 仓库创建失败"
    echo "    可能原因："
    echo "    1. 仓库名已存在 → gh repo create 不支持覆盖，请先删除或改名"
    echo "    2. gh 权限不足 → 检查 gh auth status"
    echo "    3. 网络问题 → 检查网络连接"
    exit 1
}

echo "  ✓ 仓库已创建并推送"

echo ""

# ────────────────── 更新仓库地图 ──────────────────
echo "▶ [4/4] 更新仓库地图"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/sync_profile.sh" ]; then
    bash "$SCRIPT_DIR/sync_profile.sh" 2>/dev/null && echo "  ✓ 仓库地图已更新" || echo "  ⚠ 仓库地图更新失败（不影响仓库创建）"
fi

echo ""
REPO_URL="https://github.com/$GH_USER/$REPO_NAME"
echo "╔══════════════════════════════════════════════════╗"
echo "║   完成！                                          ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                    ║"
echo "║  仓库地址: $REPO_URL"
echo "║                                                    ║"
echo "╚══════════════════════════════════════════════════╝"
