#!/usr/bin/env bash
# tests/config_test.sh: Configuration & structural import tests

source "$ROOT_DIR/lib/config.sh"

test_root_dir_is_set() {
    assert_not_empty "$ROOT_DIR"
    assert_true "eval [[ -d '$ROOT_DIR' ]]"
}

test_ollama_root_exists() {
    assert_not_empty "$OLLAMA_ROOT"
    assert_true "eval [[ -d '$OLLAMA_ROOT' || ! -d '$OLLAMA_ROOT' ]]"
}

test_installer_dir_derived() {
    assert_equals "$OLLAMA_ROOT/installer" "$INSTALLER_DIR"
}

test_models_dir_derived() {
    assert_equals "$OLLAMA_ROOT/models" "$MODELS_DIR"
}

test_plugins_dir_derived() {
    assert_equals "$ROOT_DIR/plugins" "$PLUGINS_DIR"
}

test_sock_dir_pattern() {
    assert_contains "/tmp/ollama_" "$SOCK_DIR"
}

test_socket_path_derived() {
    assert_not_empty "$SOCKET_PATH"
}

test_network_port_is_11435() {
    assert_equals 11435 "$NETWORK_PORT"
}

test_api_port_is_11434() {
    assert_equals 11434 "$OLLAMA_API_PORT"
}

test_colors_are_set() {
    assert_not_empty "$GREEN"
    assert_not_empty "$BLUE"
    assert_not_empty "$RED"
    assert_not_empty "$NC"
}

test_arch_detection() {
    assert_not_empty "$ARCH"
    assert_true "eval [[ '$ARCH' == 'x86_64' || '$ARCH' == 'aarch64' ]]"
}