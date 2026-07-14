#!/bin/bash
input=$(cat)

lang_mode=$(cat "$HOME/.claude/.lang-mode" 2>/dev/null || echo "off")

gh_user=$(awk -F': *' '/^    user:/{print $2; exit}' "$HOME/.config/gh/hosts.yml" 2>/dev/null)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir=$(basename "$cwd")
# Repo name = main repo basename (resolves worktrees to their parent repo); falls back to dir
git_common_dir=$(git -C "$cwd" -c gc.auto=0 rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -n "$git_common_dir" ]; then
  repo=$(basename "$(dirname "$git_common_dir")")
  in_repo=1
else
  repo="$dir"
  in_repo=0
fi
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

green='\033[1;32m'
cyan='\033[0;36m'
blue='\033[1;34m'
red='\033[0;31m'
yellow='\033[0;33m'
magenta='\033[0;35m'
dim='\033[2;90m'
reset='\033[0m'

effort=$(echo "$input" | jq -r '.effort.level // empty')
if [ -n "$effort" ]; then
  case "$effort" in
    low)    effort_color='\033[2;37m' ;;
    medium) effort_color='\033[0;36m' ;;
    high)   effort_color='\033[1;33m' ;;
    xhigh)  effort_color='\033[1;33m' ;;
    max)    effort_color='\033[1;35m' ;;
    *)      effort_color="$dim" ;;
  esac
  effort_str=" ${effort_color}effort:${effort}${reset}"
else
  effort_str=""
fi

# Git branch
git_branch=$(git -C "$cwd" -c gc.auto=0 symbolic-ref --short HEAD 2>/dev/null)
git_dirty=$(git -C "$cwd" -c gc.auto=0 status --porcelain 2>/dev/null | head -1)

if [ -n "$git_branch" ]; then
  if [ -n "$git_dirty" ]; then
    git_info=" ${blue}git:(${red}${git_branch}${blue})${reset} ${yellow}✗${reset}"
  else
    git_info=" ${blue}git:(${red}${git_branch}${blue})${reset}"
  fi
else
  git_info=""
fi

# Context progress bar
bar_width=10
filled=$((pct * bar_width / 100))
empty=$((bar_width - filled))
bar=""
[ "$filled" -gt 0 ] && printf -v fill_str "%${filled}s" && bar="${fill_str// /▓}"
[ "$empty" -gt 0 ] && printf -v empty_str "%${empty}s" && bar="${bar}${empty_str// /░}"

if [ "$pct" -ge 90 ]; then ctx_color="$red"
elif [ "$pct" -ge 70 ]; then ctx_color="$yellow"
else ctx_color="$green"; fi

# Elapsed time
mins=$((duration_ms / 60000))
secs=$(((duration_ms % 60000) / 1000))

# Rate limits
rate_str=""
if [ -n "$rate_5h" ]; then
  rate_int=$(printf '%.0f' "$rate_5h")
  rate_str="${rate_str} | 5h: ${rate_int}%"
fi
if [ -n "$rate_7d" ]; then
  rate_int=$(printf '%.0f' "$rate_7d")
  rate_str="${rate_str} | 7d: ${rate_int}%"
fi

# Lang mode indicator: yellow always
lang_color="$yellow"

account_color='\033[1;37m'
account_str=""
[ -n "$gh_user" ] && account_str="${account_color}@${gh_user}${reset} "

# Display: [project] at the main checkout; [project][worktree] inside a worktree; plain dir outside any repo
if [ "$in_repo" = "1" ]; then
  if [ "$dir" != "$repo" ]; then
    loc="[${repo}][${dir}]"
  else
    loc="[${repo}]"
  fi
else
  loc="$dir"
fi

# Line 1: account | model | loc | git | context bar
line1="${account_str}${magenta}[${model}]${reset} ${cyan}${loc}${reset}${git_info} ${ctx_color}${bar}${reset} ${pct}%"

# Line 2: time | rate limit | en:on/off | effort
line2="⏱ ${mins}m ${secs}s${rate_str} | ${lang_color}en:${lang_mode}${reset}${effort_str}"

echo -e "${line1}\n${line2}"
