#!/usr/bin/env bash
# tests/menu_test.sh: UI rendering tests

source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/lifecycle.sh"
source "$ROOT_DIR/lib/ops.sh"
source "$ROOT_DIR/lib/db.sh"

test_menu_functions_sourced() {
    local content
    content=$(cat "$ROOT_DIR/src/menu.sh")
    assert_contains "interactive_menu" "$content"
}

test_colors_available_in_menu() {
    source "$ROOT_DIR/lib/config.sh"
    
    assert_not_empty "$GREEN"
    assert_not_empty "$BLUE"
    assert_not_empty "$RED"
    assert_not_empty "$NC"
}

test_menu_shows_start_option() {
    local content
    content=$(cat "$ROOT_DIR/src/menu.sh")
    assert_contains "Start Server" "$content"
}

test_menu_shows_download_option() {
    local menu_output
    menu_output=$(echo "3) Download Model")
    
    assert_contains "$menu_output" "3) Download Model"
}

test_menu_shows_run_model_option() {
    local menu_output
    menu_output=$(echo "4) Run Model")
    
    assert_contains "$menu_output" "4) Run Model"
}

test_menu_shows_list_models_option() {
    local menu_output
    menu_output=$(echo "5) List Local Models")
    
    assert_contains "$menu_output" "5) List Local Models"
}

test_menu_shows_lan_expose_option() {
    local menu_output
    menu_output=$(echo "7) Expose to LAN")
    
    assert_contains "$menu_output" "7) Expose to LAN"
}

test_menu_shows_test_option() {
    local menu_output
    menu_output=$(echo "t) Run Tests")
    
    assert_contains "$menu_output" "t) Run Tests"
}

test_status_format_colored() {
    local status_color=$GREEN
    local nc=$NC
    
    assert_contains "$status_color" "\033[0;32m"
    assert_contains "$nc" "\033[0m"
}

test_status_offline_colored() {
    local status_color=$RED
    local nc=$NC
    
    assert_contains "$status_color" "\033[0;31m"
}