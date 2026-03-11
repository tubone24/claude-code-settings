#!/bin/bash
# Claude Code Status Line Script
# Format:
#   📂 ~/git/github.com/org/repo
#   🐙 repo-name │ 🌿 main +2 ~3
#   🧠 ████████░░░░░░░ 53% │ 💪 claude-sonnet-4-6
#   🔢 ↑1234 ↓567 📦3456 cached
#   ⏱️  セッション: 12m/5h (4%) │ リセット: 14:30
#   📅 週リミット: 2h30m/25h (10%) │ リセット: 2026-03-14 00:00
#
# NOTE: セッション時間・週リミットはstatusLine JSONに含まれないため、
#       ~/.claude/session-tracking/ 配下のファイルで状態を管理します。
#       セッション制限時間・週制限時間はClaude Proの仕様値を定数として使用しています。
#       実際のリセット時刻はAnthropicのサーバー側で管理されており、
#       ここでの表示は「セッション開始からの経過時間」を基にした推定値です。

# =========================================================
# 定数設定（Claude Proの制限値 - 変更する場合はここを編集）
# =========================================================
SESSION_LIMIT_HOURS=5          # セッションあたりの上限時間（時間）
WEEKLY_LIMIT_HOURS=25          # 週あたりの上限時間（時間）
TRACKING_DIR="$HOME/.claude/session-tracking"
SESSION_DB="$TRACKING_DIR/sessions.json"
WEEK_STATE_FILE="$TRACKING_DIR/week-state.json"

# =========================================================
# セッション追跡の初期化
# =========================================================
mkdir -p "$TRACKING_DIR"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // ""')
now_epoch=$(date +%s)

# sessions.json がなければ初期化
if [ ! -f "$SESSION_DB" ]; then
    echo '{}' > "$SESSION_DB"
fi

# week-state.json がなければ初期化
# 週の開始: 月曜00:00 (JST) を計算
if [ ! -f "$WEEK_STATE_FILE" ]; then
    # 今週月曜日のepochを計算（macOS/BSD date対応）
    day_of_week=$(date +%u)  # 1=月曜, 7=日曜
    days_since_monday=$(( day_of_week - 1 ))
    monday_epoch=$(( now_epoch - days_since_monday * 86400 ))
    # 当日00:00にリセット
    monday_date=$(date -r "$monday_epoch" "+%Y-%m-%d")
    monday_midnight=$(date -j -f "%Y-%m-%d %H:%M:%S" "$monday_date 00:00:00" "+%s" 2>/dev/null || echo "$monday_epoch")
    next_monday_midnight=$(( monday_midnight + 7 * 86400 ))
    echo "{\"week_start\": $monday_midnight, \"week_end\": $next_monday_midnight, \"total_seconds\": 0}" > "$WEEK_STATE_FILE"
fi

# =========================================================
# セッション開始時刻の記録・取得
# =========================================================
session_start_epoch=""
if [ -n "$session_id" ]; then
    # このsession_idの開始時刻がDBにあるか確認
    session_start_epoch=$(jq -r --arg sid "$session_id" '.[$sid].start // ""' "$SESSION_DB" 2>/dev/null)

    if [ -z "$session_start_epoch" ] || [ "$session_start_epoch" = "null" ]; then
        # 新規セッション: 現在時刻を記録
        session_start_epoch=$now_epoch
        tmp=$(mktemp)
        jq --arg sid "$session_id" --argjson start "$now_epoch" \
            '.[$sid] = {"start": $start, "last_seen": $start}' \
            "$SESSION_DB" > "$tmp" 2>/dev/null && mv "$tmp" "$SESSION_DB"
    else
        # 既存セッション: last_seenを更新
        tmp=$(mktemp)
        jq --arg sid "$session_id" --argjson now "$now_epoch" \
            '.[$sid].last_seen = $now' \
            "$SESSION_DB" > "$tmp" 2>/dev/null && mv "$tmp" "$SESSION_DB"
    fi
fi

# =========================================================
# 週状態のリセットチェック
# =========================================================
week_end=$(jq -r '.week_end // 0' "$WEEK_STATE_FILE" 2>/dev/null || echo 0)
if [ "$now_epoch" -ge "$week_end" ] 2>/dev/null; then
    # 新しい週が始まった: リセット
    day_of_week=$(date +%u)
    days_since_monday=$(( day_of_week - 1 ))
    monday_epoch=$(( now_epoch - days_since_monday * 86400 ))
    monday_date=$(date -r "$monday_epoch" "+%Y-%m-%d")
    monday_midnight=$(date -j -f "%Y-%m-%d %H:%M:%S" "$monday_date 00:00:00" "+%s" 2>/dev/null || echo "$monday_epoch")
    next_monday_midnight=$(( monday_midnight + 7 * 86400 ))
    echo "{\"week_start\": $monday_midnight, \"week_end\": $next_monday_midnight, \"total_seconds\": 0}" > "$WEEK_STATE_FILE"
    week_end=$next_monday_midnight
fi

# =========================================================
# 週の累計時間を計算（全セッションのsessionごとのユニーク秒数を合計）
# =========================================================
week_start=$(jq -r '.week_start // 0' "$WEEK_STATE_FILE" 2>/dev/null || echo 0)
# 今週開始以降のセッション合計秒数を計算
# セッションごとに (last_seen - start) を合計（ただし週開始より前の部分はカット）
weekly_total_seconds=$(jq --argjson ws "$week_start" --argjson now "$now_epoch" '
    [to_entries[] |
        .value |
        if .start == null then 0
        else
            (if .start < $ws then $ws else .start end) as $eff_start |
            (if (.last_seen // $now) > $now then $now else (.last_seen // $now) end) as $eff_end |
            (if $eff_end > $eff_start then $eff_end - $eff_start else 0 end)
        end
    ] | add // 0
' "$SESSION_DB" 2>/dev/null || echo 0)

# =========================================================
# ヘルパー関数: 秒を "Xh Ym" / "Xm" 形式に変換
# =========================================================
format_duration() {
    local secs=$1
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    if [ "$h" -gt 0 ]; then
        echo "${h}h${m}m"
    else
        echo "${m}m"
    fi
}

# =========================================================
# ヘルパー関数: プログレスバー生成（長さ10）
# =========================================================
make_bar() {
    local pct=$1
    local total=10
    local filled=$(( pct * total / 100 ))
    [ $filled -gt $total ] && filled=$total
    local empty=$(( total - filled ))
    local bar_str=""
    for i in $(seq 1 $filled); do bar_str="${bar_str}█"; done
    for i in $(seq 1 $empty);  do bar_str="${bar_str}░"; done
    echo "$bar_str"
}

# =========================================================
# Line 1: Current Directory
# =========================================================
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
home="$HOME"
display_dir="${cwd/#$home/\~}"
line1="📂 $display_dir"

# =========================================================
# Line 2: Git repo name & branch
# =========================================================
line2=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    repo_name=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || echo "")
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo "")

    git_status=$(git -C "$cwd" status --porcelain 2>/dev/null)
    staged=$(echo "$git_status" | grep -c "^[MADRC]" 2>/dev/null || echo 0)
    unstaged=$(echo "$git_status" | grep -c "^.[MD]" 2>/dev/null || echo 0)
    untracked=$(echo "$git_status" | grep -c "^??" 2>/dev/null || echo 0)

    diff_info=""
    [ "$staged" -gt 0 ] 2>/dev/null && diff_info="$diff_info +$staged"
    [ "$unstaged" -gt 0 ] 2>/dev/null && diff_info="$diff_info ~$unstaged"
    [ "$untracked" -gt 0 ] 2>/dev/null && diff_info="$diff_info ?$untracked"

    if [ -n "$repo_name" ] && [ -n "$branch" ]; then
        line2="🐙 $repo_name │ 🌿 $branch$diff_info"
    elif [ -n "$repo_name" ]; then
        line2="🐙 $repo_name"
    fi
fi

# =========================================================
# Line 3: Context window progress bar & model
# =========================================================
model_id=$(echo "$input" | jq -r '.model.id // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

bar=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    used_int=$(printf "%.0f" "$used_pct" 2>/dev/null || echo 0)
    bar_total=15
    filled=$(( used_int * bar_total / 100 ))
    [ $filled -gt $bar_total ] && filled=$bar_total
    empty=$(( bar_total - filled ))
    # カラーコーディング: 0-69%=緑, 70-89%=黄, 90%+=赤
    if [ "$used_int" -ge 90 ]; then
        color="\033[31m"  # 赤
    elif [ "$used_int" -ge 70 ]; then
        color="\033[33m"  # 黄
    else
        color="\033[32m"  # 緑
    fi
    reset_color="\033[0m"
    bar_str=""
    for i in $(seq 1 $filled); do bar_str="${bar_str}█"; done
    for i in $(seq 1 $empty);  do bar_str="${bar_str}░"; done
    bar="🧠 ${color}${bar_str} ${used_int}%${reset_color}"
fi

line3=""
if [ -n "$bar" ] && [ -n "$model_id" ]; then
    line3="$bar  ($model_id)"
elif [ -n "$bar" ]; then
    line3="$bar"
elif [ -n "$model_id" ]; then
    line3="🧠 ($model_id)"
fi

# =========================================================
# Line 4: Token counts + Cost + Code changes
# =========================================================
line4=""
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

token_info=""
[ -n "$total_input" ] && [ "$total_input" != "null" ] && token_info="${token_info}↑${total_input}"
[ -n "$total_output" ] && [ "$total_output" != "null" ] && token_info="${token_info} ↓${total_output}"
[ -n "$cache_read" ] && [ "$cache_read" != "null" ] && [ "$cache_read" != "0" ] && token_info="${token_info} 📦${cache_read} cached"

if [ -n "$token_info" ]; then
    line4="🔢 $token_info"
fi

# セッションコスト
if [ -n "$total_cost" ] && [ "$total_cost" != "null" ] && [ "$total_cost" != "0" ]; then
    cost_str="💰 \$${total_cost}"
    if [ -n "$line4" ]; then
        line4="$line4 │ $cost_str"
    else
        line4="$cost_str"
    fi
fi

# コード変更量
code_changes=""
if [ -n "$lines_added" ] && [ "$lines_added" != "null" ] && [ "$lines_added" != "0" ]; then
    code_changes="\033[32m+${lines_added}\033[0m"
fi
if [ -n "$lines_removed" ] && [ "$lines_removed" != "null" ] && [ "$lines_removed" != "0" ]; then
    if [ -n "$code_changes" ]; then
        code_changes="${code_changes} \033[31m-${lines_removed}\033[0m"
    else
        code_changes="\033[31m-${lines_removed}\033[0m"
    fi
fi
if [ -n "$code_changes" ]; then
    if [ -n "$line4" ]; then
        line4="$line4 │ ✏️  ${code_changes}"
    else
        line4="✏️  ${code_changes}"
    fi
fi

# =========================================================
# Line 5: セッション使用時間 (推定値 - JSONに含まれないため外部ファイルで管理)
# =========================================================
line5=""
if [ -n "$session_start_epoch" ] && [ "$session_start_epoch" != "null" ]; then
    session_elapsed=$(( now_epoch - session_start_epoch ))
    session_limit_secs=$(( SESSION_LIMIT_HOURS * 3600 ))
    session_pct=$(( session_elapsed * 100 / session_limit_secs ))
    [ $session_pct -gt 100 ] && session_pct=100

    elapsed_fmt=$(format_duration "$session_elapsed")
    limit_fmt="${SESSION_LIMIT_HOURS}h"
    session_bar=$(make_bar "$session_pct")

    # セッションリセット時刻 = セッション開始 + 5時間
    reset_epoch=$(( session_start_epoch + session_limit_secs ))
    reset_time=$(date -r "$reset_epoch" "+%H:%M" 2>/dev/null || date -d "@$reset_epoch" "+%H:%M" 2>/dev/null || echo "?")

    line5="⏱️  $session_bar $elapsed_fmt/${limit_fmt} (${session_pct}%) │ ♻️ $reset_time"
fi

# =========================================================
# Line 6: 週リミット (推定値 - JSONに含まれないため外部ファイルで管理)
# =========================================================
line6=""
weekly_limit_secs=$(( WEEKLY_LIMIT_HOURS * 3600 ))
weekly_pct=$(( weekly_total_seconds * 100 / weekly_limit_secs ))
[ $weekly_pct -gt 100 ] && weekly_pct=100

weekly_used_fmt=$(format_duration "$weekly_total_seconds")
weekly_limit_fmt="${WEEKLY_LIMIT_HOURS}h"
weekly_bar=$(make_bar "$weekly_pct")

# 週リセット日時 = 次の月曜00:00
week_reset_str=$(date -r "$week_end" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$week_end" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "?")

line6="📅 $weekly_bar $weekly_used_fmt/${weekly_limit_fmt} (${weekly_pct}%) │ ♻️ $week_reset_str"

# =========================================================
# Output
# =========================================================
output="$line1"
[ -n "$line2" ] && output="$output\n$line2"
[ -n "$line3" ] && output="$output\n$line3"
[ -n "$line4" ] && output="$output\n$line4"
[ -n "$line5" ] && output="$output\n$line5"
[ -n "$line6" ] && output="$output\n$line6"

printf '%b\n' "$output"
