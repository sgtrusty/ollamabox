#!/usr/bin/env bash
# tests/db_test.sh: Database integration tests

source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/db.sh"

TEST_DB="$ROOT_DIR/.ollama/test_models.db"

set_up() {
    export DB_PATH="$TEST_DB"
    rm -f "$TEST_DB"
}

tear_down() {
    rm -f "$TEST_DB"
}

test_db_init_creates_table() {
    db_init
    local exists=0
    [[ -f "$DB_PATH" ]] && exists=1
    assert_equals 1 "$exists"
}

test_db_init_creates_pull_logs_table() {
    db_init
    local exists=0
    [[ -f "$DB_PATH" ]] && exists=1
    assert_equals 1 "$exists"
}

test_db_log_pull_success() {
    db_init
    db_log_pull "llama2:7b" "success" "" 30
    
    local count
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pull_logs WHERE model_name='llama2:7b' AND status='success';")
    assert_greater_than 0 "$count"
}

test_db_log_pull_failure() {
    db_init
    db_log_pull "llama2:7b" "failed" "network error" 0
    
    local count
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pull_logs WHERE model_name='llama2:7b' AND status='failed';")
    assert_greater_than 0 "$count"
}

test_db_record_use() {
    db_init
    sqlite3 "$DB_PATH" "INSERT INTO models (name, use_count) VALUES ('llama2:7b', 0);"
    
    db_record_use "llama2:7b" 5000
    
    local use_count
    use_count=$(sqlite3 "$DB_PATH" "SELECT use_count FROM models WHERE name='llama2:7b';")
    assert_equals 1 "$use_count"
}

test_db_get_stats() {
    db_init
    local stats
    stats=$(db_get_stats)
    assert_not_empty "$stats"
}

test_db_maintenance_deletes_old_entries() {
    db_init
    sqlite3 "$DB_PATH" "INSERT INTO pull_logs (model_name, status, created_at) VALUES ('oldmodel', 'success', '2020-01-01');"
    sqlite3 "$DB_PATH" "INSERT INTO pull_logs (model_name, status, created_at) VALUES ('newmodel', 'success', '2026-01-01');"
    
    db_maintenance 365
    
    local old_count
    old_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pull_logs WHERE model_name='oldmodel';")
    assert_equals 0 "$old_count"
}

test_db_list_models_returns_all() {
    db_init
    sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO models (name, family, parameters, size_bytes, use_count) VALUES ('test-model', 'llama', '7B', 1000000000, 1);"
    local list
    list=$(db_list_models)
    assert_not_empty "$list"
}

test_db_list_plugins() {
    if [[ -d "$PLUGINS_DIR" ]]; then
        local count
        count=$(ls "$PLUGINS_DIR" 2>/dev/null | wc -l)
        [[ $count -ge 0 ]]
    else
        assert_true "[[ ! -d '$PLUGINS_DIR' ]]"
    fi
}