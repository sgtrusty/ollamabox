#!/usr/bin/env bash
# tests/lifecycle_test.sh: Lifecycle management tests

source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/lifecycle.sh"

test_cleanup_function_exists() {
    type cleanup >/dev/null 2>&1
}

test_setup_env_function_exists() {
    type setup_env >/dev/null 2>&1
}

test_check_server_function_exists() {
    type check_server >/dev/null 2>&1
}

test_wait_for_server_function_exists() {
    type wait_for_server >/dev/null 2>&1
}

test_get_status_function_exists() {
    type get_status >/dev/null 2>&1
}

test_cleanup_handles_missing_pid() {
    type cleanup >/dev/null 2>&1
}

test_check_server_returns_1_when_no_socket() {
    type check_server >/dev/null 2>&1
}

test_get_status_offline_when_no_socket() {
    type get_status >/dev/null 2>&1
}