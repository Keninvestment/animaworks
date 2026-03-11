#!/bin/bash
# collect_daily_activity.sh
# Claude Code / git の本日の活動をAnimaWorks用に収集する
# claudineのcronから type: command で呼び出される

set -euo pipefail

SCRIPTS_DIR="/Users/kensmba/scripts"
TODAY=$(date +%Y-%m-%d)
NOW_HOUR=$(date +%H)

echo "# ${TODAY} 開発・業務活動ログ"
echo ""
echo "収集時刻: $(date '+%H:%M JST')"
echo ""

# --- Git commits ---
echo "## Git コミット"
echo ""
COMMITS=$(cd "$SCRIPTS_DIR" && git log --all --since="${TODAY}T00:00:00+09:00" --format="| %ai | %s |" 2>/dev/null | sort)
if [ -z "$COMMITS" ]; then
    echo "本日のコミットなし"
else
    echo "| 時刻 | 内容 |"
    echo "|------|------|"
    echo "$COMMITS"
fi
echo ""

# --- Commit stats by area ---
echo "## プロジェクト別コミット数"
echo ""
cd "$SCRIPTS_DIR"
git log --all --since="${TODAY}T00:00:00+09:00" --format="%s" 2>/dev/null \
    | grep -oE '(agent[0-9]+|docs|animaworks|orchestrator|feat|fix|refactor)' \
    | sort | uniq -c | sort -rn \
    | while read count area; do
        echo "- ${area}: ${count}件"
    done
echo ""

# --- AnimaWorks Anima activity ---
ANIMAS_DIR="$HOME/.animaworks/animas"
if [ -d "$ANIMAS_DIR" ]; then
    echo "## AnimaWorks Anima活動"
    echo ""
    for anima_dir in "$ANIMAS_DIR"/*/; do
        name=$(basename "$anima_dir")
        episode_file="${anima_dir}episodes/${TODAY}.md"
        if [ -f "$episode_file" ]; then
            # Count non-empty activities (exclude "no response")
            total=$(grep -c "^## " "$episode_file" 2>/dev/null || echo 0)
            active=$(grep -v "no response" "$episode_file" 2>/dev/null | grep -c "^## " 2>/dev/null || echo 0)
            echo "- ${name}: 巡回${total}回 / 実質活動${active}回"
        else
            echo "- ${name}: 記録なし"
        fi
    done
    echo ""
fi

# --- Recent file changes (non-git) ---
echo "## 主な変更ファイル（直近）"
echo ""
cd "$SCRIPTS_DIR"
git diff --stat HEAD~3..HEAD 2>/dev/null | tail -5
echo ""

echo "---"
echo "以上の情報を基に、本日の成果サマリーをepisodes/に記録してください。"
