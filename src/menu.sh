#!/usr/bin/env bash
# src/menu.sh: Interactive TUI Layer
# Menu handling and user interaction - delegates to ops

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/lifecycle.sh"
source "$ROOT_DIR/lib/ops.sh"
source "$ROOT_DIR/lib/db.sh"

interactive_menu() {
    db_init
    db_seed_from_csv

    while true; do
        local status
        status=$(get_status)
        local status_color=$RED
        [[ "$status" == "ONLINE" ]] && status_color=$GREEN

        echo -e "\n${BLUE}--- Ollama Sandboxed Manager [ ${status_color}${status}${NC} ] ---${NC}"
        echo "1) Start Server"
        echo "2) Stop Server"
        echo "3) Download Model"
        echo "4) Run Model"
        echo "5) List Local Models"
        echo "6) Purge Binary"
        echo "7) Expose to LAN"
        echo "8) Create Custom Agent"
        echo "9) Model Rankings"
        echo "a) DB Maintenance"
        echo "b) Plugin Directory"
        echo "c) Monitor HTTP"
        echo "q) Exit"
        read -p "Selection: " opt

        case $opt in
        1)
            cleanup
            setup_env
            run_sandbox "serve"
            ;;
        2)
            cleanup
            echo "Server stopped."
            ;;
        3)
            ensure_server || continue
            local model
            local selected
            selected=$(db_list_models | fzf --reverse --height 50% --header "FAMILY PARAMS VRAM USE")
            model=$(echo "$selected" | awk '{print $1}')
            [[ -z "$model" ]] && { read -p "Enter custom name: " model; }
            [[ -n "$model" ]] && {
                setup_env
                run_sandbox "pull" "$model"
                db_log_pull "$model" "success" "" 0
            }
            ;;
        4)
            ensure_server || continue
            echo -e "${BLUE}>>> Select local model:${NC}"
            local model
            model=$(get_local_models | fzf --reverse --height 40% --header "Local Inventory")
            [[ -n "$model" ]] && {
                setup_env
                run_sandbox "run" "$model"
            }
            ;;
        5)
            ensure_server || continue
            get_local_models
            ;;
        6)
            purge_binary
            ;;
        7) expose_network ;;
        8)
            ensure_server || continue
            echo -e "${BLUE}>>> Select Modelfile from ./plugins:${NC}"
            local mfile
            mfile=$(ls "$PLUGINS_DIR" | fzf --reverse --header "Choose a recipe")
            [[ -z "$mfile" ]] && continue
            read -p "Enter name for new agent: " aname
            [[ -n "$aname" ]] && run_sandbox "create" "$aname" "-f" "/home/ollama/agents/$mfile"
            ;;
        9)
            echo -e "${BLUE}>>> Model Rankings:${NC}"
            db_get_ranked 10
            ;;
        a)
            read -p "Prune entries older than (days): " days
            days=${days:-30}
            db_maintenance "$days"
            db_get_stats
            ;;
        b)
            echo -e "${BLUE}>>> Plugins directory: ${PLUGINS_DIR}${NC}"
            ls -la "$PLUGINS_DIR"
            ;;
        c) monitor_http ;;
        q) exit 0 ;;
        esac
    done
}

main() { interactive_menu; }
main "$@"