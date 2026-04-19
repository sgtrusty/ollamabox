#!/usr/bin/env bash
# ollamabox.sh: Bootstrap Entry Point
# Total rootless, air-gapped LLM management.
# Optimized for Artix Linux - April 2026

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/lifecycle.sh"
source "$ROOT_DIR/lib/db.sh"
source "$ROOT_DIR/lib/ops.sh"

trap cleanup EXIT

setup_env
source "$ROOT_DIR/src/menu.sh"

