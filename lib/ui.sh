#!/usr/bin/env bash
# lib/ui.sh: Pure bash TUI utilities

UI_spin() {
    local title="$1"
    local cmd="$2"
    local delay=0.2
    local chars="| / - \\"

    echo -ne "${BLUE}>>> $title...${NC} "

    eval "$cmd" &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        for ((i = 0; i < ${#chars}; i++)); do
            echo -ne "\r${BLUE}>>> $title...${chars:$i:1}${NC} "
            sleep $delay
        done
    done
    echo -ne "\r${BLUE}>>> $title... ${GREEN}done${NC}\n"

    wait $pid
    return $?
}

UI_msg() {
    local color="$1"
    shift
    case "$color" in
    success) echo -e "${GREEN}✅ $*${NC}" ;;
    error) echo -e "${RED}❌ $*${NC}" ;;
    warn) echo -e "${YELLOW}⚠️ $*${NC}" ;;
    info) echo -e "${BLUE}ℹ️ $*${NC}" ;;
    highlight) echo -e "${MAGENTA}$*${NC}" ;;
    bold) echo -e "${BOLD}$*${NC}" ;;
    *) echo "$*" ;;
    esac
}

UI_header() {
    local title="$1"
    local status="${2:-}"
    if [[ -n "$status" ]]; then
        [[ "$status" == "ONLINE" ]] && echo -e "${GREEN}--- $title [$status] ---${NC}" || echo -e "${RED}--- $title [$status] ---${NC}"
    else
        echo -e "${BLUE}--- $title ---${NC}"
    fi
}

UI_menu() {
    local depth=0
    [[ "$1" == "-d" ]] && {
        depth=$2
        shift 2
    }

    local title="$1"
    shift
    local items=("$@")
    local count=$#

    echo "" >&2
    UI_header "$title" >&2

    local i=1
    for item in "${items[@]}"; do
        local display="$item"
        local color="$NC"
        if [[ "$item" == @(\!red*|\!danger*|\!warn*) ]]; then
            color="$RED"
            display="${item#\!red*}"
            display="${display#\!danger*}"
            display="${display#\!warn*}"
        elif [[ "$item" == @(\!yellow*|\!caution*) ]]; then
            color="$YELLOW"
            display="${item#\!yellow*}"
            display="${display#\!caution*}"
        elif [[ "$item" == @(\!cyan*|\!info*) ]]; then
            color="$CYAN"
            display="${item#\!cyan*}"
            display="${display#\!info*}"
        elif [[ "$item" == @(\!magenta*|\!special*) ]]; then
            color="$MAGENTA"
            display="${item#\!magenta*}"
            display="${display#\!special*}"
        fi
        echo -e "$i) ${color}${display}${NC}" >&2
        ((i++))
    done
    echo "q) Back/Exit" >&2

    echo -n "> " >&2
    read -r result || return 1

    # Handle Navigation
    if [[ "${result,,}" =~ ^[qQbB]$ ]]; then
        [[ $depth -eq 0 ]] && return 3 # Kill signal for Main Menu
        return 1                       # Back signal for Submenus
    fi

    if [[ "$result" =~ ^[0-9]+$ ]]; then
        if [[ $result -ge 1 && $result -le $count ]]; then
            local idx=$((result - 1))
            local item="${items[$idx]}"
            item="${item#\!*}"
            echo "$item"
            return 0
        fi
    fi
    return 2 # Invalid input
}

UI_confirm() {
    local prompt="$1"
    read -p "$prompt [y/N] " yn
    [[ "$yn" =~ ^[yY] ]] && return 0
    return 1
}

UI_input() {
    local prompt="$1"
    local value="$2"
    read -p "$prompt: " value
    echo "$value"
}

UI_status() {
    local status="$1"
    [[ "$status" == "ONLINE" ]] && echo -e "${GREEN}[$status]${NC}" || echo -e "${RED}[$status]${NC}"
}

UI_table() {
    local -n data=$1
    local header="$2"
    echo ""
    [[ -n "$header" ]] && echo -e "${BLUE}$header${NC}"
    printf "%-30s %s\n" "Name" "Value"
    printf "%-30s %s\n" "----" "-----"
    for line in "${data[@]}"; do
        printf "%-30s %s\n" "$line"
    done
}

# lowercase aliases
ui_msg() { UI_msg "$@"; }
ui_spin() { UI_spin "$@"; }
ui_confirm() { UI_confirm "$@"; }
ui_input() { UI_input "$@"; }
ui_header() { UI_header "$@"; }
ui_status() { UI_status "$@"; }

