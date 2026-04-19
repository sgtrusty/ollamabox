#!/usr/bin/env bash
# lib/lifecycle.sh: Lifecycle Management
# cleanup, setup_env, ensure_server - fundamental sandboxes lifecycle

cleanup() {
    if [[ -f "$SERVER_PID_FILE" ]]; then
        local pids=$(cat "$SERVER_PID_FILE")
        echo -e "\n${BLUE}>>> Terminating background processes...${NC}"
        for pid in $pids; do
            kill -TERM -"$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
        done
        pkill -f "socat TCP-LISTEN:$NETWORK_PORT" 2>/dev/null || true
        sleep 1
        rm -f "$SERVER_PID_FILE"
        rm -rf "$SOCK_DIR"
    fi
}

setup_env() {
    if [[ ! -f "$BIN" ]]; then
        echo -e "${BLUE}>>> Provisioning isolated environment...${NC}"
        mkdir -p "$INSTALLER_DIR" "$MODELS_DIR" "$CACHE_DIR" "$PLUGINS_DIR"
        curl -L "$OLLAMA_DOWNLOAD_URL" | zstd -d | tar -xf - -C "$INSTALLER_DIR"
    fi
}

check_server() {
    if [[ -S "$SOCKET_PATH" ]]; then
        return 0
    fi
    return 1
}

wait_for_server() {
    echo -ne "${BLUE}>>> Waiting for API health check...${NC}"
    for i in {1..60}; do
        if curl -s -o /dev/null --unix-socket "$SOCKET_PATH" http://localhost/api/tags; then
            echo -e " ${GREEN}READY${NC}"
            return 0
        fi
        echo -ne "."
        sleep 0.5
    done
    echo -e "\n${RED}FAILED: API did not respond.${NC}"
    return 1
}

get_status() {
    if [[ -S "$SOCKET_PATH" ]]; then
        echo "ONLINE"
    else
        echo "OFFLINE"
    fi
}