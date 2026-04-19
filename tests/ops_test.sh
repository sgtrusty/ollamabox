#!/usr/bin/env bash
# tests/ops_test.sh: Operational functionality tests

source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/ops.sh"

test_run_sandbox_function_exists() {
    assert_true "eval [[ \$(type -t run_sandbox) == 'function' ]]"
}

test_ensure_server_function_exists() {
    assert_true "eval [[ \$(type -t ensure_server) == 'function' ]]"
}

test_expose_network_function_exists() {
    assert_true "eval [[ \$(type -t expose_network) == 'function' ]]"
}

test_get_local_models_function_exists() {
    assert_true "eval [[ \$(type -t get_local_models) == 'function' ]]"
}

test_socket_path_defined() {
    assert_not_empty "$SOCKET_PATH"
    assert_contains "ollama.sock" "$SOCKET_PATH"
}

test_network_port_defined() {
    assert_not_empty "$NETWORK_PORT"
    assert_equals "11435" "$NETWORK_PORT"
}

test_server_pid_file_defined() {
    assert_not_empty "$SERVER_PID_FILE"
    assert_contains "server.pid" "$SERVER_PID_FILE"
}

test_server_log_defined() {
    assert_not_empty "$SERVER_LOG"
    assert_contains "server.log" "$SERVER_LOG"
}

test_expose_network_checks_port_format() {
    assert_true "eval [[ '$NETWORK_PORT' =~ ^[0-9]+$ ]]"
    assert_true "eval [[ \$NETWORK_PORT -gt 0 ]]"
    assert_true "eval [[ \$NETWORK_PORT -lt 65536 ]]"
}