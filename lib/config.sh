#!/usr/bin/env bash
# lib/config.sh: Configuration & Path Mapping
# All constants, paths, colors - sourced by main and other lib modules

if [[ -z "$ROOT_DIR" ]]; then
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

OLLAMA_ROOT="$ROOT_DIR/.ollama"
INSTALLER_DIR="$OLLAMA_ROOT/installer"
BIN="$INSTALLER_DIR/bin/ollama"
MODELS_DIR="$OLLAMA_ROOT/models"
CACHE_DIR="$OLLAMA_ROOT/mntcache"
PLUGINS_DIR="$ROOT_DIR/plugins"
MODELS_CSV="$ROOT_DIR/models.csv"

_user="${USER:-$(id -un 2>/dev/null || echo 'user')}"
SOCK_DIR="/tmp/ollama_${_user}_run"
SOCKET_PATH="$SOCK_DIR/ollama.sock"
SERVER_PID_FILE="$OLLAMA_ROOT/server.pid"
SERVER_LOG="$OLLAMA_ROOT/server.log"

NETWORK_PORT=11435
OLLAMA_API_PORT=11434
OLLAMA_HOST="127.0.0.1:$OLLAMA_API_PORT"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] && OLLAMA_ARCH="amd64" || OLLAMA_ARCH="arm64"
OLLAMA_DOWNLOAD_URL="https://ollama.com/download/ollama-linux-${OLLAMA_ARCH}.tar.zst"