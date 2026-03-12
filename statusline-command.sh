#!/bin/bash
# Claude Code Status Line Script v2.0
# Format:
#   📂 ~/git/github.com/org/repo
#   🐙 repo-name(クリッカブル) │ 🌿 main +2 ~3
#   🧠 ████████░░░░░░░ 53%  (claude-sonnet-4-6)
#   🔢 ↑1234 ↓567 📦3456 cached │ 💰 $0.05 │ ✏️  +10 -3
#   🟢 5h: █████│░░░░ 50.0% ✓ │ ♻️ 14:30
#   🟢 7d: ███│░░░░░░ 30.0% ✓ │ ♻️ 3/14 00:00
#   🤖 agent-name │ 🌲 worktree-name (branch)
#   ⚠️  200Kトークン超過！（条件付き表示）
#
# Features:
#   - OAuth Usage API からレート制限を取得（5h/7d）+ ペーシングターゲット（│マーカー）
#   - ペーシング判定: ターゲット以下=✓、超過=⚡
#   - OSC 8 エスケープシーケンスでリポジトリ名をクリッカブルリンク化
#   - 200Kトークン超過時に点滅警告
#   - エージェント名 + ワークツリー情報の表示
#   - APIレスポンスは /tmp/claude/statusline-usage-cache.json にキャッシュ（60秒間）

input=$(cat)

# =========================================================
# OAuth Token 取得
# =========================================================
get_oauth_token() {
    local token=""
    # 1. 環境変数
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi
    # 2. macOS Keychain
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi
    # 3. Linux credentials file
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi
    echo ""
}

# =========================================================
# キャッシュ付き Usage API 呼び出し
# =========================================================
cache_file="/tmp/claude/statusline-usage-cache.json"
cache_max_age=60
mkdir -p /tmp/claude

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
    now=$(date +%s)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$cache_max_age" ]; then
        needs_refresh=false
    fi
    usage_data=$(cat "$cache_file" 2>/dev/null)
fi

if $needs_refresh; then
    touch "$cache_file" 2>/dev/null
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -s --max-time 10 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.34" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            usage_data="$response"
            echo "$response" > "$cache_file"
        fi
    fi
fi

# =========================================================
# ヘルパー関数: ISO日時文字列をエポック秒に変換（macOS対応）
# =========================================================
iso_to_epoch() {
    local iso_str="$1"
    local epoch
    # GNU date (Linux)
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then echo "$epoch"; return 0; fi
    # BSD date (macOS)
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi
    [ -n "$epoch" ] && echo "$epoch"
}

format_reset_time() {
    local iso_str="$1"
    local style="$2"
    { [ -z "$iso_str" ] || [ "$iso_str" = "null" ]; } && return
    local epoch
    epoch=$(iso_to_epoch "$iso_str")
    [ -z "$epoch" ] && return
    local formatted=""
    case "$style" in
        time)
            formatted=$(date -d "@$epoch" +"%H:%M" 2>/dev/null || date -j -r "$epoch" +"%H:%M" 2>/dev/null)
            ;;
        datetime)
            formatted=$(date -d "@$epoch" +"%-m/%d %H:%M" 2>/dev/null || date -j -r "$epoch" +"%-m/%d %H:%M" 2>/dev/null)
            ;;
    esac
    [ -n "$formatted" ] && echo "$formatted"
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

    # OSC 8 クリッカブルリンク: GitHubリポジトリURLを取得
    remote_url=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")
    github_url=""
    if [ -n "$remote_url" ]; then
        # SSH形式 (git@github.com:user/repo.git) → HTTPS形式に変換
        if [[ "$remote_url" == git@* ]]; then
            github_url=$(echo "$remote_url" | sed 's|git@\(.*\):\(.*\)\.git|https://\1/\2|' | sed 's|\.git$||')
        elif [[ "$remote_url" == https://* ]]; then
            github_url=$(echo "$remote_url" | sed 's|\.git$||')
        fi
    fi

    # OSC 8 でリポジトリ名をクリッカブルに
    if [ -n "$github_url" ] && [ -n "$repo_name" ]; then
        repo_display="\033]8;;${github_url}\033\\${repo_name}\033]8;;\033\\"
    else
        repo_display="$repo_name"
    fi

    if [ -n "$repo_name" ] && [ -n "$branch" ]; then
        line2="🐙 $repo_display │ 🌿 $branch$diff_info"
    elif [ -n "$repo_name" ]; then
        line2="🐙 $repo_display"
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
# Line 4: Token counts + Cost + Code changes + Duration
# =========================================================
line4=""
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

# 数値にカンマ区切りを追加
format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# 時間フォーマット（ミリ秒→時:分:秒）
format_duration_ms() {
    local ms=$(printf "%.0f" "$1" 2>/dev/null || echo 0)
    local total_sec=$(( ms / 1000 ))
    local hours=$(( total_sec / 3600 ))
    local mins=$(( (total_sec % 3600) / 60 ))
    local secs=$(( total_sec % 60 ))
    if [ "$hours" -gt 0 ]; then
        printf "%dh%02dm" $hours $mins
    elif [ "$mins" -gt 0 ]; then
        printf "%dm%02ds" $mins $secs
    else
        printf "%ds" $secs
    fi
}

token_info=""
[ -n "$total_input" ] && [ "$total_input" != "null" ] && token_info="${token_info}↑$(format_number "$total_input")"
[ -n "$total_output" ] && [ "$total_output" != "null" ] && token_info="${token_info} ↓$(format_number "$total_output")"
[ -n "$cache_read" ] && [ "$cache_read" != "null" ] && [ "$cache_read" != "0" ] && token_info="${token_info} 📦$(format_number "$cache_read") cached"

if [ -n "$token_info" ]; then
    line4="🔢 $token_info"
fi

# コスト（total_cost_usd はセッション総コストを直接反映）
if [ -n "$total_cost" ] && [ "$total_cost" != "null" ]; then
    display_cost=$(echo "$total_cost" | awk '{
        val = $1 + 0
        if (val == 0) printf "0"
        else if (val < 0.01) printf "%.4f", val
        else if (val < 0.1) printf "%.3f", val
        else printf "%.2f", val
    }')
    if [ "$display_cost" != "0" ]; then
        cost_str="💰 \$${display_cost}"
        if [ -n "$line4" ]; then
            line4="$line4 │ $cost_str"
        else
            line4="$cost_str"
        fi
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

# 経過時間（total_duration_ms / total_api_duration_ms）
total_dur_int=$(printf "%.0f" "$total_duration_ms" 2>/dev/null || echo 0)
if [ "$total_dur_int" -gt 0 ]; then
    duration_str="⏱️  $(format_duration_ms $total_dur_int)"
    api_dur_int=$(printf "%.0f" "$api_duration_ms" 2>/dev/null || echo 0)
    if [ "$api_dur_int" -gt 0 ]; then
        duration_str="$duration_str(API:$(format_duration_ms $api_dur_int))"
    fi
    if [ -n "$line4" ]; then
        line4="$line4 │ $duration_str"
    else
        line4="$duration_str"
    fi
fi

# =========================================================
# Line 5 & 6: OAuth Usage API から実際の利用率を表示
# =========================================================

# 使用率に応じた絵文字
usage_emoji() {
    local used=$1
    if [ "$used" -le 20 ]; then echo "🟢"
    elif [ "$used" -le 40 ]; then echo "🟡"
    elif [ "$used" -le 60 ]; then echo "🟠"
    else echo "🔴"
    fi
}

# 使用量バー（█=使用済み、░=残り、│=ペーシングターゲット）
make_usage_bar() {
    local pct=$1
    local target=${2:-}
    local total=10
    local filled=$(( pct * total / 100 ))
    [ $filled -gt $total ] && filled=$total

    local target_pos=-1
    if [ -n "$target" ] && [ "$target" -ge 0 ] 2>/dev/null && [ "$target" -lt 100 ]; then
        target_pos=$(( target * total / 100 ))
        [ "$target_pos" -ge "$total" ] && target_pos=$(( total - 1 ))
    fi

    local bar_str=""
    for ((i=0; i<total; i++)); do
        if [ "$i" -eq "$target_pos" ]; then
            bar_str="${bar_str}│"
        elif [ "$i" -lt "$filled" ]; then
            bar_str="${bar_str}█"
        else
            bar_str="${bar_str}░"
        fi
    done
    echo "$bar_str"
}

# =========================================================
# ペーシングターゲット計算
# =========================================================
calc_pacing_target() {
    local reset_iso="$1"
    local window_secs="$2"
    { [ -z "$reset_iso" ] || [ "$reset_iso" = "null" ]; } && return
    local reset_epoch
    reset_epoch=$(iso_to_epoch "$reset_iso")
    [ -z "$reset_epoch" ] && return
    local now_epoch
    now_epoch=$(date +%s)
    local start_epoch=$(( reset_epoch - window_secs ))
    local elapsed=$(( now_epoch - start_epoch ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    [ "$elapsed" -gt "$window_secs" ] && elapsed=$window_secs
    echo $(( elapsed * 100 / window_secs ))
}

line5=""
line6=""
if [ -n "$usage_data" ] && echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1; then
    # 5時間セッション
    five_hour_utilization=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.1f", $1}')
    five_hour_int=$(printf "%.0f" "$five_hour_utilization")
    five_hour_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
    five_hour_reset=$(format_reset_time "$five_hour_reset_iso" "time")
    five_hour_emoji=$(usage_emoji "$five_hour_int")

    # ペーシングターゲット計算（5時間 = 18000秒）
    five_hour_target=$(calc_pacing_target "$five_hour_reset_iso" 18000)

    five_hour_bar=$(make_usage_bar "$five_hour_int" "$five_hour_target")
    # ペーシング判定: 使用率がターゲットを超えている場合は⚡、下回っていれば✓
    pace_indicator_5h=""
    if [ -n "$five_hour_target" ] && [ "$five_hour_int" -gt 0 ]; then
        if [ "$five_hour_int" -gt "$five_hour_target" ]; then
            pace_indicator_5h=" \033[33m⚡\033[0m"
        else
            pace_indicator_5h=" \033[32m✓\033[0m"
        fi
    fi
    line5="${five_hour_emoji} 5h: $five_hour_bar ${five_hour_utilization}%${pace_indicator_5h}"
    [ -n "$five_hour_reset" ] && line5="$line5 │ ♻️ $five_hour_reset"

    # 7日間
    seven_day_utilization=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.1f", $1}')
    seven_day_int=$(printf "%.0f" "$seven_day_utilization")
    seven_day_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
    seven_day_reset=$(format_reset_time "$seven_day_reset_iso" "datetime")
    seven_day_emoji=$(usage_emoji "$seven_day_int")

    # ペーシングターゲット計算（7日 = 604800秒）
    seven_day_target=$(calc_pacing_target "$seven_day_reset_iso" 604800)

    seven_day_bar=$(make_usage_bar "$seven_day_int" "$seven_day_target")
    pace_indicator_7d=""
    if [ -n "$seven_day_target" ] && [ "$seven_day_int" -gt 0 ]; then
        if [ "$seven_day_int" -gt "$seven_day_target" ]; then
            pace_indicator_7d=" \033[33m⚡\033[0m"
        else
            pace_indicator_7d=" \033[32m✓\033[0m"
        fi
    fi
    line6="${seven_day_emoji} 7d: $seven_day_bar ${seven_day_utilization}%${pace_indicator_7d}"
    [ -n "$seven_day_reset" ] && line6="$line6 │ ♻️ $seven_day_reset"
else
    line5="⏱️  5h: -- (データ取得中...)"
    line6="📅 7d: -- (データ取得中...)"
fi

# =========================================================
# Line 7: エージェント名 + ワークツリー情報
# =========================================================
line7=""
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
worktree_branch=$(echo "$input" | jq -r '.worktree.branch // empty')

line7_parts=""
if [ -n "$agent_name" ] && [ "$agent_name" != "null" ]; then
    line7_parts="🤖 \033[95m${agent_name}\033[0m"
fi
if [ -n "$worktree_name" ] && [ "$worktree_name" != "null" ]; then
    wt_info="🌲 \033[36m${worktree_name}\033[0m"
    if [ -n "$worktree_branch" ] && [ "$worktree_branch" != "null" ]; then
        wt_info="$wt_info (\033[36m${worktree_branch}\033[0m)"
    fi
    if [ -n "$line7_parts" ]; then
        line7_parts="$line7_parts │ $wt_info"
    else
        line7_parts="$wt_info"
    fi
fi
[ -n "$line7_parts" ] && line7="$line7_parts"

# =========================================================
# 200Kトークン超過警告
# =========================================================
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
warning_line=""
if [ "$exceeds_200k" = "true" ]; then
    warning_line="\033[5m\033[91m⚠️  200Kトークン超過！コンテキスト品質が低下しています。新セッションを推奨します。\033[0m"
fi

# =========================================================
# Line 8: Session ID + Transcript Path
# =========================================================
line8=""
if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
    short_session="${session_id:0:8}"
    line8="🆔 \033[2m${short_session}...\033[0m"
fi
if [ -n "$transcript_path" ] && [ "$transcript_path" != "null" ]; then
    transcript_name=$(basename "$transcript_path")
    transcript_link="\033]8;;file://${transcript_path}\033\\📄 ${transcript_name}\033]8;;\033\\"
    if [ -n "$line8" ]; then
        line8="$line8 │ $transcript_link"
    else
        line8="$transcript_link"
    fi
fi

# =========================================================
# Output
# =========================================================
output="$line1"
[ -n "$line2" ] && output="$output\n$line2"
[ -n "$line3" ] && output="$output\n$line3"
[ -n "$line4" ] && output="$output\n$line4"
[ -n "$line5" ] && output="$output\n$line5"
[ -n "$line6" ] && output="$output\n$line6"
[ -n "$line7" ] && output="$output\n$line7"
[ -n "$line8" ] && output="$output\n$line8"
[ -n "$warning_line" ] && output="$output\n$warning_line"

printf '%b\n' "$output"
