#!/usr/bin/env bash
# sync_profile.sh — 从 GitHub API 拉取用户信息与仓库列表，写入 profile
# 用法：bash scripts/sync_profile.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_DIR="$SKILL_ROOT/profile"
PROFILE_FILE="$PROFILE_DIR/user-github.md"

mkdir -p "$PROFILE_DIR"

# 检查登录状态
if ! gh auth status &>/dev/null 2>&1; then
    echo "✗ 未登录 GitHub，请先运行：gh auth login"
    exit 1
fi

# 获取用户信息
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
GH_NAME=$(gh api user --jq .name 2>/dev/null || echo "")
GH_BIO=$(gh api user --jq .bio 2>/dev/null || echo "")
GH_FOLLOWERS=$(gh api user --jq .followers 2>/dev/null || echo "0")
GH_FOLLOWING=$(gh api user --jq .following 2>/dev/null || echo "0")
GH_CREATED=$(gh api user --jq '.created_at[:10]' 2>/dev/null || echo "")
GH_PUBLIC_REPOS=$(gh api user --jq .public_repos 2>/dev/null || echo "0")

# 获取仓库列表（JSON 格式，最多 200 个）
REPO_JSON=$(gh repo list --limit 200 --json name,description,visibility,primaryLanguage,isArchived,isPrivate,updatedAt,url,stargazerCount,pushedAt 2>/dev/null || echo "[]")

# 写入 profile
cat > "$PROFILE_FILE" << EOF
# 用户 GitHub Profile

> 此文件由 scripts/sync_profile.sh 自动生成，请勿手动编辑。
> 最后更新：$(date '+%Y-%m-%d %H:%M:%S')

## 账号信息

| 字段 | 值 |
|------|-----|
| 用户名 | $GH_USER |
| 姓名 | ${GH_NAME:-（未设置）} |
| 简介 | ${GH_BIO:-（无）} |
| 粉丝数 | $GH_FOLLOWERS |
| 关注数 | $GH_FOLLOWING |
| 公开仓库数 | $GH_PUBLIC_REPOS |
| 注册日期 | $GH_CREATED |

## 仓库地图

EOF

# 用 python3 格式化仓库列表为 markdown 表格
echo "$REPO_JSON" | python3 -c "
import sys, json

repos = json.load(sys.stdin)
if not repos:
    print('（暂无仓库）')
    sys.exit(0)

# 按更新时间降序排列
repos.sort(key=lambda r: r.get('pushedAt', r.get('updatedAt', '')), reverse=True)

print('| # | 仓库名 | 描述 | 语言 | 可见性 | 星标 | 最后推送 |')
print('|---|--------|------|------|--------|------|----------|')

for i, repo in enumerate(repos, 1):
    name = repo.get('name', '')
    desc = repo.get('description') or '—'
    lang = repo.get('primaryLanguage') or {}
    lang_name = lang.get('name', '—') if isinstance(lang, dict) else str(lang)
    is_private = repo.get('isPrivate', False)
    is_archived = repo.get('isArchived', False)
    visibility = '🔒 私有' if is_private else '🌐 公开'
    if is_archived:
        visibility += ' 📦 已归档'
    stars = repo.get('stargazerCount', 0)
    pushed = (repo.get('pushedAt') or repo.get('updatedAt') or '')[:10]
    if not pushed:
        pushed = '—'
    print(f'| {i} | {name} | {desc} | {lang_name} | {visibility} | ⭐{stars} | {pushed} |')

print()
print(f'**总计：{len(repos)} 个仓库**')
" >> "$PROFILE_FILE" 2>/dev/null || {
    echo "" >> "$PROFILE_FILE"
    echo "**仓库列表获取失败，请手动检查 gh repo list**" >> "$PROFILE_FILE"
}

echo "✓ Profile 已更新：$PROFILE_FILE"
