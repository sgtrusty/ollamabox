#!/usr/bin/env bash
# src/menu.sh: Interactive TUI Layer

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)}"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/lifecycle.sh"
source "$ROOT_DIR/lib/ops.sh"
source "$ROOT_DIR/lib/db.sh"
source "$ROOT_DIR/lib/test_runner.sh"
source "$ROOT_DIR/lib/ui.sh"

interactive_menu() {
    db_init
    db_seed_from_csv
    while true; do
        menu_main
        [[ $? -eq 1 ]] && continue
        break
    done
}

menu_main() {
    local status choice ret

    while true; do
        status=$(get_status)
        # Depth 0 means this is the root
        choice=$(UI_menu -d 0 "Ollama Manager [$status]" "!cyan⚡ Operations" "!yellow🛠️ Development" "!magenta⚙️ Configuration")
        ret=$?
        echo $ret >/tmp/log.txt

        case "$ret" in
        1 | 3)
            ui_msg info "Exiting..."
            exit 0
            ;; # User hit 'q' at root
        0)
            if [[ -n "$choice" ]]; then
                _menu_call "$choice"
                # We don't care what _menu_call returns; we just loop again
            fi
            ;;
        *) continue ;; # Covers invalid input (2) or back (1)
        esac
    done
}

_menu_call() {
    case "$1" in
    *Operations*) menu_operations ;;
    *Development*) menu_development ;;
    *Configuration*) menu_configuration ;;
    esac
    return 0 # Force success so the main menu loop continues
}

menu_operations() {
    local choice ret
    while true; do
        choice=$(UI_menu -d 1 "Operations [$(get_status)]" "!cyan▶️ Start Server" "!red⏹️ Stop Server" "!info📋 List Models" "!cyan⬇️ Download Models")
        ret=$?

        if [[ $ret -eq 1 ]]; then
            break # Stop THIS loop
        fi

        [[ $ret -ne 0 ]] && continue

        case "$choice" in
        *Start\ Server*) run_and_expose ;;
        *Stop\ Server*) cleanup ;;
        *List\ Models*) ensure_server && get_local_models ;;
        *Download\ Models*) menu_download ;;
        esac
    done
    return 0 # Crucial: Tell menu_main that the submenu closed normally
}

run_and_expose() {
    cleanup
    echo ""
    echo -e "${BLUE}>>> Setting up environment...${NC}"
    setup_env

    echo -e "${BLUE}>>> Launching sandbox...${NC}"
    run_sandbox "serve"

    wait_for_server || {
        ui_msg error "Server failed to start"
        return
    }
    ui_msg success "Server started!"

    read -p "Expose to LAN? [y/N] " yn
    [[ "$yn" =~ ^[yY] ]] && expose_network
}

confirm_start() {
    local status
    status=$(get_status)

    if [[ "$status" == "ONLINE" ]]; then
        read -p "Server running. Restart? [y/N] " yn
        [[ "$yn" =~ ^[yY] ]] || return 1
    fi

    read -p "Start server? [y/N] " yn
    [[ "$yn" =~ ^[yY] ]] && return 0
    return 1
}

menu_download() {
    local models
    # Allow multiple selection with fzf -m; fallback to manual entry if none chosen
    models=$(db_list_models | fzf -m --header="Select model(s)" | awk '{print $1}')
    if [[ -z "$models" ]]; then
        read -p "Model name (space-separated if multiple): " models
    fi
    [[ -n "$models" ]] && {
        setup_env
        for model in $models; do
            run_sandbox "pull" "$model"
            db_log_pull "$model" "success" "" 0
        done
    }
}

menu_run() {
    local model
    model=$(get_local_models | fzf --header="Select model" | awk '{print $1}')
    [[ -n "$model" ]] && run_sandbox "run" "$model"
}

menu_development() {
    local choice ret
    local -a dev_opts=("!cyan🧪 Run Tests" "!yellow📊 Rankings" "!magenta🤖 Agent" "!info🔌 Plugins" "!cyan📈 Monitor")

    while true; do
        choice=$(UI_menu -d 1 "Development" "${dev_opts[@]}")
        ret=$?

        [[ $ret -eq 1 ]] && break
        [[ $ret -ne 0 ]] && continue

        case "$choice" in
        *Run\ Tests*) run_tests ;;
        *Rankings*) db_get_ranked 10 ;;
        *Agent*) menu_agent ;;
        *Plugins*) ls "$PLUGINS_DIR" ;;
        *Monitor*) ensure_server && monitor_http ;;
        esac
    done
}

menu_agent() {
    ensure_server || return
    local mfile
    mfile=$(ls "$PLUGINS_DIR" | fzf --header="Select modelfile")
    [[ -z "$mfile" ]] && return
    read -p "Agent name: " aname
    [[ -n "$aname" ]] && run_sandbox "create" "$aname" "-f" "$PLUGINS_DIR/$mfile"
}

menu_configuration() {
    local choice ret
    local -a cfg_opts=("⚙️ DB Maintenance" "!danger⚠️ Cannot be reverted: Purge Binary")

    while true; do
        choice=$(UI_menu -d 1 "Configuration" "${cfg_opts[@]}")
        ret=$?

        [[ $ret -eq 1 ]] && break
        [[ $ret -ne 0 ]] && continue

        case "$choice" in
        *DB\ Maintenance*)
            read -p "Days to keep: " days
            db_maintenance "${days:-30}"
            db_get_stats
            ;;
        *Purge\ Binary*) purge_binary ;;
        esac
    done
}

main() { interactive_menu; }
main "$@"

