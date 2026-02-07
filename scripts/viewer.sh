#!/usr/bin/env bash
#
# Interactive tmux binding viewer.
#
# Features:
#   - Collapsible groups (expanded by default)
#   - Keyboard navigation (j/k/Up/Down, g/G, PgUp/PgDn)
#   - Search with / (incremental filtering)
#   - Mouse support (click to select, scroll wheel, click header to search)
#   - Toggle groups with Enter/Space/Tab
#   - Collapse/expand all with c/e
#   - Press q or Escape to quit
#
# Reads parsed binding data from a file argument.
# Data format: GROUP<tab>name or BIND<tab>key<tab>command

# ── Theme ──────────────────────────────────────────────────────────────────────

COLOR_RESET=$'\033[0m'
COLOR_GROUP=$'\033[1;36m'           # Bold cyan for group headers
COLOR_GROUP_COLLAPSED=$'\033[1;33m' # Bold yellow for collapsed groups
COLOR_KEY=$'\033[1;32m'             # Bold green for keys
COLOR_CMD=$'\033[0m'                # Default foreground for commands
COLOR_SELECTED=$'\033[7m'           # Reverse video for selection
COLOR_SEARCH=$'\033[1;33m'          # Yellow for search prompt
COLOR_MATCH=$'\033[1;33;4m'         # Yellow underline for search matches
COLOR_HELP=$'\033[2m'               # Dim for help text
COLOR_ARROW=$'\033[1;36m'           # Cyan for expand/collapse arrows
COLOR_COUNT=$'\033[0;2m'            # Dim for binding count

# ── Data structures ────────────────────────────────────────────────────────────

# Parallel arrays for all items (groups + bindings)
declare -a ITEM_TYPE=()       # "group" or "bind"
declare -a ITEM_GROUP=()      # group index this item belongs to
declare -a ITEM_KEY=()        # key (for binds) or group name (for groups)
declare -a ITEM_CMD=()        # command (for binds) or "" (for groups)
declare -a GROUP_NAMES=()     # group names in order
declare -a GROUP_COLLAPSED=() # 0=expanded, 1=collapsed

# Display-filtered lists
declare -a VISIBLE=() # indices into ITEM_* that are currently visible

TOTAL_BINDINGS=0 # precomputed total binding count
SELECTED=0       # index into VISIBLE
SCROLL_OFFSET=0  # first visible line in viewport
SEARCH_TERM=""
SEARCH_MODE=0 # 1 when search input is active
TERM_ROWS=0
TERM_COLS=0
KEY_COL_WIDTH=20 # width for the key column
MOUSE_ROW=0       # row from last mouse event (1-based)
MOUSE_COL=0       # col from last mouse event (1-based)

# ── Parse input ────────────────────────────────────────────────────────────────

parse_input() {
  local input_file="$1"
  local line type rest key cmd
  local group_idx=-1

  while IFS= read -r line || [[ -n "$line" ]]; do
    type="${line%%	*}"
    rest="${line#*	}"

    case "$type" in
    GROUP)
      group_idx=${#GROUP_NAMES[@]}
      GROUP_NAMES+=("$rest")
      GROUP_COLLAPSED+=(0)
      ITEM_TYPE+=("group")
      ITEM_GROUP+=("$group_idx")
      ITEM_KEY+=("$rest")
      ITEM_CMD+=("")
      ;;
    BIND)
      key="${rest%%	*}"
      cmd="${rest#*	}"
      ITEM_TYPE+=("bind")
      ITEM_GROUP+=("$group_idx")
      ITEM_KEY+=("$key")
      ITEM_CMD+=("$cmd")
      TOTAL_BINDINGS=$((TOTAL_BINDINGS + 1))
      ;;
    esac
  done <"$input_file"
}

# ── Visibility ─────────────────────────────────────────────────────────────────

rebuild_visible() {
  VISIBLE=()
  local i type gidx

  [[ -n "$SEARCH_TERM" ]] && shopt -s nocasematch

  for ((i = 0; i < ${#ITEM_TYPE[@]}; i++)); do
    type="${ITEM_TYPE[$i]}"
    gidx="${ITEM_GROUP[$i]}"

    if [[ "$type" == "group" ]]; then
      if [[ -n "$SEARCH_TERM" ]]; then
        if group_has_matches "$gidx"; then
          VISIBLE+=("$i")
        fi
      else
        VISIBLE+=("$i")
      fi
    elif [[ "$type" == "bind" ]]; then
      # Skip if group is collapsed (but not during search)
      if [[ -z "$SEARCH_TERM" ]] && ((gidx >= 0 && GROUP_COLLAPSED[gidx] == 1)); then
        continue
      fi

      if [[ -n "$SEARCH_TERM" ]]; then
        if [[ "${ITEM_KEY[$i]} ${ITEM_CMD[$i]}" != *"$SEARCH_TERM"* ]]; then
          continue
        fi
      fi

      VISIBLE+=("$i")
    fi
  done

  [[ -n "$SEARCH_TERM" ]] && shopt -u nocasematch

  # Clamp selection
  local max=$((${#VISIBLE[@]} - 1))
  if ((max < 0)); then
    SELECTED=0
  elif ((SELECTED > max)); then
    SELECTED=$max
  fi
}

group_has_matches() {
  local gidx="$1"
  local i
  for ((i = 0; i < ${#ITEM_TYPE[@]}; i++)); do
    if [[ "${ITEM_TYPE[$i]}" == "bind" ]] && ((ITEM_GROUP[i] == gidx)); then
      if [[ "${ITEM_KEY[$i]} ${ITEM_CMD[$i]}" == *"$SEARCH_TERM"* ]]; then
        return 0
      fi
    fi
  done
  return 1
}

# ── Rendering ──────────────────────────────────────────────────────────────────

get_term_size() {
  # stty size returns correct dimensions inside tmux popups; tput does not.
  local size_rows size_cols
  read -r size_rows size_cols < <(stty size 2>/dev/null) || true

  TERM_ROWS="${size_rows:-24}"

  if [[ -n "$POPUP_WIDTH" ]] && ((POPUP_WIDTH > 2)); then
    TERM_COLS=$((POPUP_WIDTH - 2))
  elif [[ -n "$size_cols" ]] && ((size_cols > 0)); then
    TERM_COLS="$size_cols"
  else
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
  fi
  ((TERM_COLS < 20)) && TERM_COLS=20
}

ensure_visible() {
  local vh=$((TERM_ROWS - 2))
  if ((SELECTED < SCROLL_OFFSET)); then
    SCROLL_OFFSET=$SELECTED
  elif ((SELECTED >= SCROLL_OFFSET + vh)); then
    SCROLL_OFFSET=$((SELECTED - vh + 1))
  fi
}

highlight_match() {
  local text="$1" search="$2"
  if [[ -z "$search" ]]; then
    printf '%s' "$text"
    return
  fi

  local tlen=${#text} slen=${#search} pos
  shopt -s nocasematch
  for ((pos = 0; pos <= tlen - slen; pos++)); do
    if [[ "${text:pos:slen}" == "$search" ]]; then
      shopt -u nocasematch
      printf '%s%s%s%s%s' \
        "${text:0:pos}" \
        "$COLOR_MATCH" \
        "${text:pos:slen}" \
        "$COLOR_RESET" \
        "${text:pos+slen}"
      return
    fi
  done
  shopt -u nocasematch
  printf '%s' "$text"
}

truncate() {
  local text="$1" max_len="$2"
  if ((${#text} > max_len)); then
    printf '%s…' "${text:0:max_len-1}"
  else
    printf '%s' "$text"
  fi
}

render() {
  get_term_size
  local vh=$((TERM_ROWS - 2))
  ensure_visible

  # Reset scroll region and move to top-left
  printf '\033[;r\033[H'

  # Search bar or help hint
  if ((SEARCH_MODE)); then
    printf '\033[K %s/%s\033[K%s\n' "$COLOR_SEARCH" "$SEARCH_TERM" "$COLOR_RESET"
  elif [[ -n "$SEARCH_TERM" ]]; then
    local match_count=0
    local vi
    for vi in "${VISIBLE[@]}"; do
      [[ "${ITEM_TYPE[$vi]}" == "bind" ]] && match_count=$((match_count + 1))
    done
    printf '\033[K %ssearch: %s (%d matches)  [n/N next/prev, Esc clear]%s\n' \
      "$COLOR_SEARCH" "$SEARCH_TERM" "$match_count" "$COLOR_RESET"
  else
    printf '\033[K %s/:search  c/e:collapse/expand all%s\n' \
      "$COLOR_HELP" "$COLOR_RESET"
  fi

  # ── Body ──
  local visible_count=${#VISIBLE[@]}
  local line_num i idx type gidx key cmd is_selected

  for ((line_num = 0; line_num < vh; line_num++)); do
    i=$((SCROLL_OFFSET + line_num))
    if ((i >= visible_count)); then
      printf '\033[K\n'
      continue
    fi

    idx="${VISIBLE[$i]}"
    type="${ITEM_TYPE[$idx]}"
    gidx="${ITEM_GROUP[$idx]}"
    key="${ITEM_KEY[$idx]}"
    cmd="${ITEM_CMD[$idx]}"
    is_selected=0
    ((i == SELECTED)) && is_selected=1

    printf '\033[K'

    if [[ "$type" == "group" ]]; then
      local arrow="▼" color="$COLOR_GROUP"
      if ((gidx >= 0 && GROUP_COLLAPSED[gidx] == 1)); then
        arrow="▶"
        color="$COLOR_GROUP_COLLAPSED"
      fi

      if ((is_selected)); then
        printf '%s\033[1m %s %s%s' "$COLOR_SELECTED" "$arrow" "$key" "$COLOR_RESET$COLOR_SELECTED"
        local label_len=$((${#key} + 5))
        local pad=$((TERM_COLS - label_len))
        ((pad > 0)) && printf '%*s' "$pad" ""
        printf '%s' "$COLOR_RESET"
      else
        printf ' %s%s%s %s%s%s' "$COLOR_ARROW" "$arrow" "$COLOR_RESET" "$color" "$key" "$COLOR_RESET"
      fi
    elif [[ "$type" == "bind" ]]; then
      local display_key="$key"
      local key_len=${#display_key}
      local pad=$((KEY_COL_WIDTH - key_len))
      ((pad < 1)) && pad=1

      # Truncate command to fit: indent(5) + key + pad + cmd <= TERM_COLS
      local line_cmd_width=$((TERM_COLS - 5 - key_len - pad))
      ((line_cmd_width < 1)) && line_cmd_width=1
      local display_cmd
      display_cmd="$(truncate "$cmd" "$line_cmd_width")"

      if ((is_selected)); then
        printf '%s     ' "$COLOR_SELECTED"
        if [[ -n "$SEARCH_TERM" ]]; then
          highlight_match "$display_key" "$SEARCH_TERM"
          printf '%*s' "$pad" ""
          printf '%s' "$COLOR_RESET$COLOR_SELECTED"
          highlight_match "$display_cmd" "$SEARCH_TERM"
        else
          printf '%s%s%s%*s%s%s' "$COLOR_KEY" "$display_key" "$COLOR_RESET$COLOR_SELECTED" "$pad" "" "$COLOR_CMD" "$display_cmd"
        fi
        # Pad rest of line for reverse video
        local content_len=$((5 + key_len + pad + ${#display_cmd}))
        local end_pad=$((TERM_COLS - content_len))
        ((end_pad > 0)) && printf '%*s' "$end_pad" ""
        printf '%s' "$COLOR_RESET"
      else
        printf '     '
        if [[ -n "$SEARCH_TERM" ]]; then
          printf '%s' "$COLOR_KEY"
          highlight_match "$display_key" "$SEARCH_TERM"
          printf '%s%*s%s' "$COLOR_RESET" "$pad" "" "$COLOR_CMD"
          highlight_match "$display_cmd" "$SEARCH_TERM"
          printf '%s' "$COLOR_RESET"
        else
          printf '%s%s%s%*s%s%s%s' "$COLOR_KEY" "$display_key" "$COLOR_RESET" "$pad" "" "$COLOR_CMD" "$display_cmd" "$COLOR_RESET"
        fi
      fi
    fi

    printf '\n'
  done

  # ── Footer ──
  printf '\033[K %s%d/%d%s' "$COLOR_HELP" "$((SELECTED + 1))" "$visible_count" "$COLOR_RESET"
}

# ── Navigation ─────────────────────────────────────────────────────────────────

toggle_group() {
  local vis_idx=$SELECTED
  if ((vis_idx >= ${#VISIBLE[@]})); then return; fi
  local idx="${VISIBLE[$vis_idx]}"
  if [[ "${ITEM_TYPE[$idx]}" != "group" ]]; then return; fi
  local gidx="${ITEM_GROUP[$idx]}"
  if ((GROUP_COLLAPSED[gidx] == 1)); then
    GROUP_COLLAPSED[$gidx]=0
  else
    GROUP_COLLAPSED[$gidx]=1
  fi
  rebuild_visible
}

collapse_all() {
  local i
  for ((i = 0; i < ${#GROUP_COLLAPSED[@]}; i++)); do
    GROUP_COLLAPSED[$i]=1
  done
  rebuild_visible
}

expand_all() {
  local i
  for ((i = 0; i < ${#GROUP_COLLAPSED[@]}; i++)); do
    GROUP_COLLAPSED[$i]=0
  done
  rebuild_visible
}

move_up() { ((SELECTED > 0)) && SELECTED=$((SELECTED - 1)) || true; }
move_down() {
  local max=$((${#VISIBLE[@]} - 1))
  ((SELECTED < max)) && SELECTED=$((SELECTED + 1)) || true
}
move_top() {
  SELECTED=0
  SCROLL_OFFSET=0
}
move_bottom() { SELECTED=$((${#VISIBLE[@]} - 1)); }

page_up() {
  local vh=$((TERM_ROWS - 2))
  SELECTED=$((SELECTED - vh))
  ((SELECTED < 0)) && SELECTED=0
  true
}

page_down() {
  local vh=$((TERM_ROWS - 2))
  local max=$((${#VISIBLE[@]} - 1))
  SELECTED=$((SELECTED + vh))
  ((SELECTED > max)) && SELECTED=$max
  true
}

search_next() {
  [[ -z "$SEARCH_TERM" ]] && return 0
  local start=$((SELECTED + 1))
  local count=${#VISIBLE[@]}

  shopt -s nocasematch
  local i idx vidx
  for ((i = 0; i < count; i++)); do
    idx=$(((start + i) % count))
    vidx="${VISIBLE[$idx]}"
    if [[ "${ITEM_TYPE[$vidx]}" == "bind" ]]; then
      if [[ "${ITEM_KEY[$vidx]} ${ITEM_CMD[$vidx]}" == *"$SEARCH_TERM"* ]]; then
        shopt -u nocasematch
        SELECTED=$idx
        return 0
      fi
    fi
  done
  shopt -u nocasematch
}

search_prev() {
  [[ -z "$SEARCH_TERM" ]] && return 0
  local count=${#VISIBLE[@]}
  local start=$((SELECTED - 1))
  ((start < 0)) && start=$((count - 1))

  shopt -s nocasematch
  local i idx vidx
  for ((i = 0; i < count; i++)); do
    idx=$(((start - i + count) % count))
    vidx="${VISIBLE[$idx]}"
    if [[ "${ITEM_TYPE[$vidx]}" == "bind" ]]; then
      if [[ "${ITEM_KEY[$vidx]} ${ITEM_CMD[$vidx]}" == *"$SEARCH_TERM"* ]]; then
        shopt -u nocasematch
        SELECTED=$idx
        return 0
      fi
    fi
  done
  shopt -u nocasematch
}

search_next_from_top() {
  [[ -z "$SEARCH_TERM" ]] && return 0
  local count=${#VISIBLE[@]}

  shopt -s nocasematch
  local i vidx
  for ((i = 0; i < count; i++)); do
    vidx="${VISIBLE[$i]}"
    if [[ "${ITEM_TYPE[$vidx]}" == "bind" ]]; then
      if [[ "${ITEM_KEY[$vidx]} ${ITEM_CMD[$vidx]}" == *"$SEARCH_TERM"* ]]; then
        shopt -u nocasematch
        SELECTED=$i
        return 0
      fi
    fi
  done
  shopt -u nocasematch
}

click_select() {
  local row="$1"
  # Body occupies rows 2 through TERM_ROWS-1
  if ((row < 2 || row > TERM_ROWS - 1)); then
    return 1
  fi
  local target=$((SCROLL_OFFSET + row - 2))
  if ((target < 0 || target >= ${#VISIBLE[@]})); then
    return 1
  fi
  SELECTED=$target
  return 0
}

# ── Input reading ──────────────────────────────────────────────────────────────

read_key() {
  local key
  IFS= read -rsn1 key 2>/dev/null || return 1

  if [[ "$key" == $'\x1b' ]]; then
    local seq=""
    IFS= read -rsn1 -t 0.05 seq 2>/dev/null || true
    if [[ -z "$seq" ]]; then
      printf 'ESCAPE'
      return
    fi
    if [[ "$seq" == "[" ]]; then
      IFS= read -rsn1 seq 2>/dev/null || true
      case "$seq" in
      A) printf 'UP' ;;
      B) printf 'DOWN' ;;
      C) printf 'RIGHT' ;;
      D) printf 'LEFT' ;;
      H) printf 'HOME' ;;
      F) printf 'END' ;;
      5)
        IFS= read -rsn1 _ 2>/dev/null
        printf 'PGUP'
        ;;
      6)
        IFS= read -rsn1 _ 2>/dev/null
        printf 'PGDN'
        ;;
      '<')
        # SGR extended mouse: ESC [ < button;col;row M/m
        local mouse_buf="" mouse_char="" mouse_count=0
        while ((mouse_count < 20)); do
          IFS= read -rsn1 -t 0.05 mouse_char 2>/dev/null || break
          if [[ "$mouse_char" == "M" || "$mouse_char" == "m" ]]; then
            break
          fi
          mouse_buf="${mouse_buf}${mouse_char}"
          mouse_count=$((mouse_count + 1))
        done
        # Safety limit hit without terminator -- drain remaining bytes
        if ((mouse_count >= 20)) && [[ "$mouse_char" != "M" && "$mouse_char" != "m" ]]; then
          while IFS= read -rsn1 -t 0.01 mouse_char 2>/dev/null; do
            [[ "$mouse_char" == "M" || "$mouse_char" == "m" ]] && break
          done
          printf 'MOUSE_OTHER'
          return
        fi
        # Ignore release events
        if [[ "$mouse_char" == "m" ]]; then
          printf 'MOUSE_RELEASE'
          return
        fi
        # Parse button;col;row
        local mouse_button mouse_col mouse_row
        IFS=';' read -r mouse_button mouse_col mouse_row <<<"$mouse_buf"
        MOUSE_ROW=$((mouse_row))
        MOUSE_COL=$((mouse_col))
        # Strip modifier bits (shift=4, meta=8, ctrl=16)
        mouse_button=$((mouse_button & ~(4 | 8 | 16)))
        case "$mouse_button" in
        0) printf 'MOUSE_LEFT' ;;
        64) printf 'MOUSE_SCROLL_UP' ;;
        65) printf 'MOUSE_SCROLL_DOWN' ;;
        *) printf 'MOUSE_OTHER' ;;
        esac
        ;;
      *) printf 'UNKNOWN' ;;
      esac
    else
      printf 'UNKNOWN'
    fi
  elif [[ "$key" == "" ]]; then
    printf 'ENTER'
  elif [[ "$key" == $'\x7f' ]] || [[ "$key" == $'\x08' ]]; then
    printf 'BACKSPACE'
  elif [[ "$key" == $'\t' ]]; then
    printf 'TAB'
  else
    printf '%s' "$key"
  fi
}

# ── Main loop ──────────────────────────────────────────────────────────────────

cleanup() {
  printf '\033[?1006l' # Disable SGR extended mouse encoding
  printf '\033[?1000l' # Disable button event tracking
  tput cnorm 2>/dev/null # Show cursor
  tput rmcup 2>/dev/null # Restore screen
  stty "$SAVED_TTY" 2>/dev/null
}

main() {
  local input_file="${1:--}"
  POPUP_WIDTH_RAW="${2:-}"
  POPUP_WIDTH=""
  if [[ "$POPUP_WIDTH_RAW" =~ ^[0-9]+$ ]]; then
    POPUP_WIDTH="$POPUP_WIDTH_RAW"
  fi

  parse_input "$input_file"

  if ((${#ITEM_TYPE[@]} == 0)); then
    echo "No bindings found."
    exit 1
  fi

  rebuild_visible

  # Save terminal state and enter raw mode
  SAVED_TTY="$(stty -g 2>/dev/null)"
  trap cleanup EXIT
  stty raw -echo opost 2>/dev/null
  tput smcup 2>/dev/null # Alternate screen
  printf '\033[2J'       # Clear alternate screen
  tput civis 2>/dev/null # Hide cursor
  printf '\033[?25l'
  printf '\033[?1000h' # Enable button event tracking
  printf '\033[?1006h' # Enable SGR extended mouse encoding

  local key
  while true; do
    render

    key="$(read_key)" || continue

    if ((SEARCH_MODE)); then
      case "$key" in
      ENTER)
        SEARCH_MODE=0
        if [[ -n "$SEARCH_TERM" ]]; then
          expand_all
        fi
        rebuild_visible
        SELECTED=0
        search_next_from_top
        ;;
      ESCAPE)
        SEARCH_MODE=0
        SEARCH_TERM=""
        rebuild_visible
        ;;
      BACKSPACE)
        if [[ -n "$SEARCH_TERM" ]]; then
          SEARCH_TERM="${SEARCH_TERM%?}"
        fi
        rebuild_visible
        ;;
      MOUSE_LEFT)
        click_select "$MOUSE_ROW" || true
        ;;
      MOUSE_SCROLL_UP) move_up; move_up; move_up ;;
      MOUSE_SCROLL_DOWN) move_down; move_down; move_down ;;
      MOUSE_RELEASE | MOUSE_OTHER) ;;
      *)
        if [[ ${#key} -eq 1 ]] && [[ "$key" =~ [[:print:]] ]]; then
          SEARCH_TERM="${SEARCH_TERM}${key}"
          rebuild_visible
        fi
        ;;
      esac
      continue
    fi

    # Normal mode
    case "$key" in
    q) break ;;
    ESCAPE)
      if [[ -n "$SEARCH_TERM" ]]; then
        SEARCH_TERM=""
        rebuild_visible
      else
        break
      fi
      ;;
    k | UP) move_up ;;
    j | DOWN) move_down ;;
    g | HOME) move_top ;;
    G | END) move_bottom ;;
    PGUP) page_up ;;
    PGDN) page_down ;;
    ENTER | " " | TAB) toggle_group ;;
    /)
      SEARCH_MODE=1
      SEARCH_TERM=""
      ;;
    n) search_next ;;
    N) search_prev ;;
    c) collapse_all ;;
    e) expand_all ;;
    MOUSE_LEFT)
      if ((MOUSE_ROW == 1)); then
        SEARCH_MODE=1
        SEARCH_TERM=""
      elif click_select "$MOUSE_ROW"; then
        local click_idx="${VISIBLE[$SELECTED]}"
        if [[ "${ITEM_TYPE[$click_idx]}" == "group" ]]; then
          toggle_group
        fi
      fi
      ;;
    MOUSE_SCROLL_UP) move_up; move_up; move_up ;;
    MOUSE_SCROLL_DOWN) move_down; move_down; move_down ;;
    MOUSE_RELEASE | MOUSE_OTHER) ;;
    esac
  done
}

main "$@"
