#!/usr/bin/env bash
# lib/db.sh: SQLite Database Wrapper
# Ranking, model metadata, usage tracking, maintenance

DB_PATH="$OLLAMA_ROOT/models.db"

db_init() {
    mkdir -p "$(dirname "$DB_PATH")"
    sqlite3 "$DB_PATH" "
        CREATE TABLE IF NOT EXISTS models (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            family TEXT,
            parameters TEXT,
            size_bytes INTEGER,
            pulled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_used DATETIME,
            use_count INTEGER DEFAULT 0,
            total_latency_ms INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS pull_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model_name TEXT NOT NULL,
            status TEXT NOT NULL,
            error_msg TEXT,
            duration_sec REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_models_name ON models(name);
        CREATE INDEX IF NOT EXISTS idx_models_use_count ON models(use_count);
        CREATE INDEX IF NOT EXISTS idx_pull_logs_created ON pull_logs(created_at);
    "
}

db_log_pull() {
    local model=$1 status=$2 error_msg=$3 duration=$4
    sqlite3 "$DB_PATH" "
        INSERT INTO pull_logs (model_name, status, error_msg, duration_sec)
        VALUES ('$model', '$status', '$error_msg', $duration);
    "
    if [[ "$status" == "success" ]]; then
        local size
        size=$(sqlite3 "$DB_PATH" "SELECT size_bytes FROM models WHERE name='$model'")
        if [[ -z "$size" || "$size" == "NULL" ]]; then
            sqlite3 "$DB_PATH" "INSERT INTO models (name, use_count) VALUES ('$model', 0);"
        fi
    fi
}

db_record_use() {
    local model=$1 latency_ms=$2
    sqlite3 "$DB_PATH" "
        UPDATE models 
        SET use_count = use_count + 1,
            total_latency_ms = total_latency_ms + $latency_ms,
            last_used = CURRENT_TIMESTAMP
        WHERE name = '$model';
    "
}

db_get_ranked() {
    local limit=${1:-10}
    sqlite3 -header -column "$DB_PATH" "
        SELECT name, family, parameters,
               printf('%.2f', size_bytes / 1073741824.0) || ' GB' as size,
               use_count, total_latency_ms / use_count as avg_latency_ms,
               last_used
        FROM models
        ORDER BY use_count DESC
        LIMIT $limit;
    "
}

db_get_stats() {
    sqlite3 -header -column "$DB_PATH" "
        SELECT 
            (SELECT COUNT(*) FROM models) as total_models,
            (SELECT SUM(use_count) FROM models) as total_runs,
            (SELECT SUM(size_bytes) FROM models) / 1073741824 as total_gb,
            (SELECT COUNT(*) FROM pull_logs WHERE status='success') as successful_pulls,
            (SELECT COUNT(*) FROM pull_logs WHERE status='failed') as failed_pulls;
    "
}

db_maintenance() {
    local days=${1:-30}
    sqlite3 "$DB_PATH" "DELETE FROM pull_logs WHERE created_at < datetime('now', '-$days days');"
    sqlite3 "$DB_PATH" "VACUUM;"
    echo -e "${BLUE}>>> DB maintained (pruned entries older than $days days).${NC}"
}

db_list_plugins() {
    ls -1 "$PLUGINS_DIR" 2>/dev/null || echo ""
}

db_seed_from_csv() {
    if [[ ! -f "$MODELS_CSV" ]]; then
        echo -e "${RED}>>> CSV not found: $MODELS_CSV${NC}"
        return 1
    fi

    tail -n +2 "$MODELS_CSV" | while IFS=, read -r id family params ctx vram _ _; do
        [[ -z "$id" ]] && continue
        local vram_bytes=0
        if [[ -n "$vram" && "$vram" != *"+"* ]]; then
            vram_bytes=$(echo "$vram" | sed 's/GB/*1073741824/; s/MB/*1048576/' | bc 2>/dev/null || echo 0)
        fi
        sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO models (name, family, parameters, size_bytes) VALUES ('$id', '$family', '$params', $vram_bytes);"
    done

    local count
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM models;")
    echo -e "${BLUE}>>> Seeded $count models from CSV.${NC}"
}

db_list_models() {
    sqlite3 -header -column "$DB_PATH" "
        SELECT name, family, parameters,
               printf('%.2f', COALESCE(size_bytes, 0) / 1073741824.0) || ' GB' as vram,
               use_count
        FROM models
        ORDER BY name;
    "
}

db_get_model_by_name() {
    local name=$1
    sqlite3 "$DB_PATH" "SELECT name, family, parameters FROM models WHERE name='$name';"
}