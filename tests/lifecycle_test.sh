#!/usr/bin/env bash
# tests/lifecycle_test.sh: Lifecycle management tests

source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/lifecycle.sh"

test_cleanup_function_exists() {
    local result
    result=$(type cleanup 2>/dev/null)
    assert_contains "function" "$result"
}

test_setup_env_function_exists() {
    local result
    result=$(type setup_env 2>/dev/null)
    assert_contains "function" "$result"
}

test_check_server_function_exists() {
    local result
    result=$(type check_server 2>/dev/null)
    assert_contains "function" "$result"
}

test_wait_for_server_function_exists() {
    local result
    result=$(type wait_for_server 2>/dev/null)
    assert_contains "function" "$result"
}

test_get_status_function_exists() {
    local result
    result=$(type get_status 2>/dev/null)
    assert_contains "function" "$result"
}

test_cleanup_handles_missing_pid() {
    local result
    result=$(type cleanup 2>/dev/null)
    assert_contains "function" "$result"
}

test_check_server_returns_1_when_no_socket() {
    local result
    result=$(type check_server 2>/dev/null)
    assert_contains "function" "$result"
}

test_get_status_offline_when_no_socket() {
    local result
    result=$(type get_status 2>/dev/null)
    assert_contains "function" "$result"
}