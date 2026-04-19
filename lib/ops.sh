#!/usr/bin/env bash
# lib/ops.sh: Operational Functions
# run_sandbox, expose_network, get_local_models - functional logic

ensure_server() {
    if ! check_server; then
        echo -e "${BLUE}>>> Server not detected. Initializing engine...${NC}"
        run_sandbox "serve"
        wait_for_server
        return $?
    fi
    return 0
}

get_local_models() {
    if [[ -S "$SOCKET_PATH" ]]; then
        curl --silent --unix-socket "$SOCKET_PATH" http://localhost/api/tags |
            jq -r '.models[] | "\(.name) | \(.details.parameter_size) | \((.size / 1073741824 * 100 | round / 100)) GB"' |
            column -t -s "|"
    fi
}

expose_network() {
    ensure_server || return 1

    if ss -tuln | grep -q ":$NETWORK_PORT "; then
        echo -e "${RED}>>> Port $NETWORK_PORT is already occupied.${NC}"
        return
    fi

    echo -e "${BLUE}>>> Exposing infra to LAN (0.0.0.0:$NETWORK_PORT)...${NC}"
    socat -d -d -b 65536 TCP-LISTEN:$NETWORK_PORT,bind=0.0.0.0,fork,reuseaddr UNIX-CONNECT:"$SOCKET_PATH" &
    echo $! >>"$SERVER_PID_FILE"
    local LOCAL_IP=$(ip route get 1 | awk '{print $7;exit}')
    echo -e "${GREEN}>>> SUCCESS: Connect external apps via http://$LOCAL_IP:$NETWORK_PORT${NC}"
}

run_sandbox() {
    local mode=$1
    shift

    local gpu_flags=""
    [[ -c /dev/nvidia0 ]] && gpu_flags="--dev-bind /dev/nvidia0 /dev/nvidia0 --dev-bind /dev/nvidiactl /dev/nvidiactl --dev-bind /dev/nvidia-uvm /dev/nvidia-uvm"

    if [[ "$mode" == "serve" ]]; then
        rm -rf "$SOCK_DIR" && mkdir -p "$SOCK_DIR" && chmod 700 "$SOCK_DIR"
        setsid bwrap \
            --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib --ro-bind /lib64 /lib64 \
            --proc /proc --dev /dev $gpu_flags \
            --ro-bind "$INSTALLER_DIR" "$INSTALLER_DIR" \
            --unshare-user --unshare-pid --share-net \
            --ro-bind /etc/resolv.conf /etc/resolv.conf --ro-bind /etc/hosts /etc/hosts \
            --ro-bind /etc/ssl/certs /etc/ssl/certs --ro-bind /etc/ca-certificates /etc/ca-certificates \
            --tmpfs /home/ollama --tmpfs /tmp \
            --bind "$SOCK_DIR" "$SOCK_DIR" \
            --bind "$MODELS_DIR" /home/ollama/.ollama/models \
            --bind "$CACHE_DIR" /home/ollama/.ollama/cache \
            --setenv OLLAMA_HOST "$OLLAMA_HOST" \
            --setenv HOME /home/ollama \
            --chdir /home/ollama \
            sh -c "
                $BIN serve > '$SERVER_LOG' 2>&1 &
                while ! grep -q 'Listening on 127.0.0.1:$OLLAMA_API_PORT' '$SERVER_LOG' 2>/dev/null; do sleep 0.5; done
                exec socat -b 65536 UNIX-LISTEN:$SOCKET_PATH,fork,reuseaddr TCP:127.0.0.1:$OLLAMA_API_PORT
            " &
        echo $! >"$SERVER_PID_FILE"
        return
    fi

    local net_flag="--unshare-net"
    [[ "$mode" == "pull" ]] && net_flag="--share-net"

    bwrap \
        --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib --ro-bind /lib64 /lib64 \
        --proc /proc --dev /dev $gpu_flags $net_flag \
        --unshare-user --unshare-pid --tmpfs /home/ollama \
        --ro-bind "$INSTALLER_DIR" "$INSTALLER_DIR" \
        --ro-bind "$PLUGINS_DIR" /home/ollama/agents \
        --bind "$MODELS_DIR" /home/ollama/.ollama/models \
        --bind "$CACHE_DIR" /home/ollama/.ollama/cache \
        --bind "$SOCKET_PATH" "$SOCKET_PATH" \
        --setenv HOME /home/ollama \
        --setenv OLLAMA_HOST "$OLLAMA_HOST" \
        --chdir /home/ollama \
        sh -c "
            socat TCP-LISTEN:$OLLAMA_API_PORT,bind=127.0.0.1,fork UNIX-CONNECT:$SOCKET_PATH &
            sleep 0.2
            exec $BIN $mode \"\$@\"
        " -- "$@"
}

purge_binary() {
    ui_msg warn "⚠️ This will permanently delete the ollama binary and models!"
    read -p "Are you sure? [y/N] " yn
    [[ "$yn" =~ ^[yY] ]] || {
        ui_msg info "Aborted."
        return 1
    }
    rm -rf "$INSTALLER_DIR"
    echo -e "${RED}🗑️ Binary purged.${NC}"
}

monitor_http() {
    ensure_server || return 1
    echo -e "${BLUE}>>> Monitoring HTTP traffic on port $NETWORK_PORT...${NC}"
    echo -e "${BLUE}>>> Press Ctrl+C to stop.${NC}"
    tshark -i lo -d tcp.port==$NETWORK_PORT,http -Y "http.request || http.response" \
        -T fields -e http.request.method -e http.request.uri -e json.value.string -e json.key 2>/dev/null ||
        tshark -i lo "tcp.port == $NETWORK_PORT" -T fields -e http.request.method -e http.request.uri 2>/dev/null ||
        echo -e "${RED}>>> tshark not available. Install wireshark-cli.${NC}"
}

