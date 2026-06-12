#!/bin/bash
# Subdued truecolor status line

input=$(cat)

# --- parse JSON via node (jq is not available in this environment) ---
eval "$(echo "$input" | node "$HOME/.claude/statusline-helper.js")"

cwd="${cwd:-$(pwd)}"
if [ -z "$repo_name" ]; then
  repo_name=$(basename "$cwd")
fi

# --- git branch ---
branch=$(git --no-optional-locks -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# --- session cost ---
cost=$(awk -v c="$cost" 'BEGIN { printf "%.2f", c }')

# --- code velocity (uncommitted diff stats) ---
diffstat=$(git --no-optional-locks -C "$cwd" diff --shortstat 2>/dev/null)
added=$(echo "$diffstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
removed=$(echo "$diffstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
added=${added:-0}
removed=${removed:-0}

# --- colors (truecolor) ---
SEP="\033[38;2;90;90;90m"
GRAY="\033[38;2;200;200;200m"
BLUEGRAY="\033[38;2;120;140;160m"
AMBER="\033[38;2;180;150;100m"
GREEN="\033[38;2;120;150;120m"
RED="\033[38;2;160;110;110m"
VIOLET="\033[38;2;150;130;170m"
LABEL="\033[38;2;130;130;130m"
RESET="\033[0m"
BOLD="\033[1m"

empty_color="\033[38;2;70;70;70m"

# --- color tier for a given percentage ---
tier_color() {
  pct_int="$1"
  if [ "$pct_int" -le 0 ]; then
    echo "\033[38;2;70;70;70m"
  elif [ "$pct_int" -lt 40 ]; then
    echo "\033[38;2;120;140;120m"
  elif [ "$pct_int" -lt 70 ]; then
    echo "\033[38;2;150;150;120m"
  elif [ "$pct_int" -lt 90 ]; then
    echo "\033[38;2;170;130;110m"
  else
    echo "\033[38;2;180;110;110m"
  fi
}

# --- build a 20-cell hatched bar for a given percentage ---
build_bar() {
  pct_int="$1"
  cells=20
  filled=$(( pct_int * cells / 100 ))
  [ "$filled" -gt "$cells" ] && filled=$cells
  [ "$filled" -lt 0 ] && filled=0
  empty=$(( cells - filled ))

  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    rem=$(( filled - i ))
    if [ "$rem" -gt $(( cells * 2 / 3 )) ]; then
      bar="${bar}▓"
    elif [ "$rem" -gt $(( cells / 3 )) ]; then
      bar="${bar}▒"
    else
      bar="${bar}░"
    fi
    i=$(( i + 1 ))
  done

  empty_str=""
  i=0
  while [ "$i" -lt "$empty" ]; do
    empty_str="${empty_str}░"
    i=$(( i + 1 ))
  done

  echo "$bar|$empty_str"
}

# --- render a labeled "<label> <bar> <pct>%" segment ---
render_quota() {
  label="$1"
  pct="$2"   # empty string if unavailable

  if [ -z "$pct" ]; then
    echo "${LABEL}${label}${RESET} ${empty_color}--${RESET}"
    return
  fi

  pct_int=$(printf '%.0f' "$pct")
  color=$(tier_color "$pct_int")
  IFS='|' read -r filled_part empty_part <<< "$(build_bar "$pct_int")"

  echo "${LABEL}${label}${RESET} ${color}${filled_part}${empty_color}${empty_part}${RESET} ${color}${pct_int}%${RESET}"
}

# --- assemble output ---
out=""
out="${out}${BOLD}${GRAY}${repo_name}${RESET}"

if [ -n "$branch" ]; then
  out="${out} ${BLUEGRAY}(${branch})${RESET}"
fi

out="${out} ${SEP}|${RESET} $(render_quota "ctx" "$ctx_used")"
out="${out} ${SEP}|${RESET} $(render_quota "5h" "$five_used")"
out="${out} ${SEP}|${RESET} $(render_quota "wk" "$week_used")"

out="${out} ${SEP}|${RESET} ${AMBER}\$${cost}${RESET}"

out="${out} ${SEP}|${RESET} ${GREEN}+${added}${RESET} ${RED}-${removed}${RESET}"

out="${out} ${SEP}|${RESET} ${VIOLET}${model}${RESET}"
if [ -n "$effort" ]; then
  out="${out} ${LABEL}(${effort})${RESET}"
fi

printf "%b" "$out"
