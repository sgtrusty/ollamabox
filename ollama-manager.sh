#!/usr/bin/env bash
# ollama-box-manager: Total rootless, air-gapped LLM management.
# Optimized for Artix Linux - April 2026

set -e

# --- Configuration & Path Mapping ---
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_ROOT="$ROOT_DIR/.ollama"
INSTALLER_DIR="$OLLAMA_ROOT/installer"
BIN="$INSTALLER_DIR/bin/ollama"
MODELS_DIR="$OLLAMA_ROOT/models"
CACHE_DIR="$OLLAMA_ROOT/mntcache"
CUSTOM_AGENTS_DIR="$ROOT_DIR/agents"

mkdir -p "$CUSTOM_AGENTS_DIR"

SOCK_DIR="/tmp/ollama_$(whoami)_run"
SOCKET_PATH="$SOCK_DIR/ollama.sock"
SERVER_PID_FILE="$OLLAMA_ROOT/server.pid"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

cleanup() {
    if [[ -f "$SERVER_PID_FILE" ]]; then
        local pids=$(cat "$SERVER_PID_FILE")
        echo -e "\n${BLUE}>>> Terminating background processes...${NC}"
        for pid in $pids; do
            kill -TERM -"$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
        done
        pkill -f "socat TCP-LISTEN:11435" 2>/dev/null || true
        sleep 1
        rm -f "$SERVER_PID_FILE"
        rm -rf "$SOCK_DIR"
    fi
}
trap cleanup EXIT

setup_env() {
    if [[ ! -f "$BIN" ]]; then
        echo -e "${BLUE}>>> Provisioning isolated environment...${NC}"
        mkdir -p "$INSTALLER_DIR" "$MODELS_DIR" "$CACHE_DIR"
        ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && OLLAMA_ARCH="amd64" || OLLAMA_ARCH="arm64"
        curl -L "https://ollama.com/download/ollama-linux-${OLLAMA_ARCH}.tar.zst" | zstd -d | tar -xf - -C "$INSTALLER_DIR"
    fi
}

ensure_server() {
    if [[ ! -S "$SOCKET_PATH" ]]; then
        echo -e "${BLUE}>>> Server not detected. Initializing engine...${NC}"
        run_sandbox "serve"
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
    fi
}

get_local_models() {
    if [[ -S "$SOCKET_PATH" ]]; then
        # Query API, format size to GB, and align with column
        curl --silent --unix-socket "$SOCKET_PATH" http://localhost/api/tags |
            jq -r '.models[] | "\(.name) | \(.details.parameter_size) | \((.size / 1073741824 * 100 | round / 100)) GB"' |
            column -t -s "|"
    fi
}

expose_network() {
    ensure_server || return 1

    # Check if port is already in use
    if ss -tuln | grep -q ":11435 "; then
        echo -e "${RED}>>> Port 11435 is already occupied.${NC}"
        return
    fi

    echo -e "${BLUE}>>> Exposing infra to LAN (0.0.0.0:11435)...${NC}"
    # Start the bridge and append PID to tracker
    socat -d -d -b 65536 TCP-LISTEN:11435,bind=0.0.0.0,fork,reuseaddr UNIX-CONNECT:"$SOCKET_PATH" &
    echo $! >>"$SERVER_PID_FILE"
    local LOCAL_IP=$(ip route get 1 | awk '{print $7;exit}')
    echo -e "${GREEN}>>> SUCCESS: Connect external apps via http://$LOCAL_IP:11435${NC}"
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
            --setenv OLLAMA_HOST "127.0.0.1:11434" \
            --setenv HOME /home/ollama \
            --chdir /home/ollama \
            sh -c "
                $BIN serve > '$OLLAMA_ROOT/server.log' 2>&1 &
                while ! grep -q 'Listening on 127.0.0.1:11434' '$OLLAMA_ROOT/server.log' 2>/dev/null; do sleep 0.5; done
                exec socat -b 65536 UNIX-LISTEN:$SOCKET_PATH,fork,reuseaddr TCP:127.0.0.1:11434
            " &
        echo $! >"$SERVER_PID_FILE"
        return
    fi

    local net_flag="--unshare-net"
    [[ "$mode" == "pull" ]] && net_flag="--share-net"

    # Use a jailed socat to map the bound socket back to a local port inside the bwrap container
    # This tricks the Ollama CLI into thinking it's talking to a real local server.
    bwrap \
        --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib --ro-bind /lib64 /lib64 \
        --proc /proc --dev /dev $gpu_flags $net_flag \
        --unshare-user --unshare-pid --tmpfs /home/ollama \
        --ro-bind "$INSTALLER_DIR" "$INSTALLER_DIR" \
        --ro-bind "$CUSTOM_AGENTS_DIR" /home/ollama/agents \
        --bind "$MODELS_DIR" /home/ollama/.ollama/models \
        --bind "$CACHE_DIR" /home/ollama/.ollama/cache \
        --bind "$SOCKET_PATH" "$SOCKET_PATH" \
        --setenv HOME /home/ollama \
        --setenv OLLAMA_HOST "127.0.0.1:11434" \
        --chdir /home/ollama \
        sh -c "
            socat TCP-LISTEN:11434,bind=127.0.0.1,fork UNIX-CONNECT:$SOCKET_PATH &
            sleep 0.2
            exec $BIN $mode \"\$@\"
        " -- "$@"
}

interactive_menu() {
    while true; do
        local status="${RED}OFFLINE${NC}"
        [[ -S "$SOCKET_PATH" ]] && status="${GREEN}ONLINE${NC}"
        echo -e "\n${BLUE}--- Ollama Sandboxed Manager [ $status ] ---${NC}"
        echo "1) Start Server"
        echo "2) Stop Server"
        echo "3) Download Model"
        echo "4) Run Model"
        echo "5) List Local Models"
        echo "6) Purge Binary"
        echo "7) Expose to LAN"
        echo "8) Create Custom Agent from Modelfile"
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
            if [[ -f "$ROOT_DIR/models.csv" ]]; then
                selected=$( (tail -n +2 "$ROOT_DIR/models.csv" && echo "MANUAL [Enter custom name]") |
                    column -s, -t | fzf --header "ID FAMILY PARAMS CTX VRAM" --reverse --height 50% --border)
                model=$(echo "$selected" | awk '{print $1}')
            fi
            [[ -z "$model" || "$model" == "MANUAL" ]] && { read -p "Enter custom name: " model; }
            [[ -n "$model" ]] && {
                setup_env
                run_sandbox "pull" "$model"
            }
            ;;
        4)
            ensure_server || continue
            echo -e "${BLUE}>>> Select local model:${NC}"
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
            rm -rf "$INSTALLER_DIR"
            echo "Purged."
            ;;
        7) expose_network ;;
        8)
            ensure_server || continue
            echo -e "${BLUE}>>> Select Modelfile from ./agents:${NC}"
            mfile=$(ls "$CUSTOM_AGENTS_DIR" | fzf --reverse --header "Choose a recipe")
            [[ -z "$mfile" ]] && continue
            read -p "Enter name for new agent: " aname
            [[ -n "$aname" ]] && run_sandbox "create" "$aname" "-f" "/home/ollama/agents/$mfile"
            ;;
        9)
            tshark -i lo -d tcp.port==11435,http -Y "http.request || http.response" -T fields -e http.request.method -e http.request.uri -e json.value.string -e json.key
            ;;
        q) exit 0 ;;
        esac
    done
}

setup_env
interactive_menu
