#!/usr/bin/env bash
# lib/test_runner.sh: Test Runner & Dependency Management
# Downloads/manages bashunit + checks system dependencies

if [[ -z "$ROOT_DIR" ]]; then
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export ROOT_DIR
TEST_MODULES_DIR="$ROOT_DIR/.bash_modules"
BASHUNIT_BIN="$TEST_MODULES_DIR/bashunit"
VERSION_FILE="$ROOT_DIR/VERSION"

load_version_config() {
    if [[ -f "$VERSION_FILE" ]]; then
        source "$VERSION_FILE"
    else
        echo "Missing version file -- no checksums checked"
        return
    fi
}

download_bashunit() {
    load_version_config

    mkdir -p "$TEST_MODULES_DIR"

    local url="$BASHUNIT_REPO/releases/download/$BASHUNIT_VERSION/bashunit"

    echo ">>> Downloading bashunit v$BASHUNIT_VERSION..."

    if command -v curl >/dev/null 2>&1; then
        curl -Lk -o "$BASHUNIT_BIN.tmp" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$BASHUNIT_BIN.tmp" "$url"
    else
        echo "ERROR: Neither curl nor wget available for download."
        return 1
    fi

    local actual_checksum
    if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$BASHUNIT_BIN.tmp" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual_checksum=$(shasum -a 256 "$BASHUNIT_BIN.tmp" | awk '{print $1}')
    else
        echo "WARNING: No checksum verification tool available. trusting download..."
        mv "$BASHUNIT_BIN.tmp" "$BASHUNIT_BIN"
        chmod u+x "$BASHUNIT_BIN"
        echo ">>> bashunit installed at $BASHUNIT_BIN"
        return 0
    fi

    if [[ "$actual_checksum" == "$BASHUNIT_CHECKSUM" ]]; then
        mv "$BASHUNIT_BIN.tmp" "$BASHUNIT_BIN"
        chmod u+x "$BASHUNIT_BIN"
        echo ">>> bashunit verified and installed at $BASHUNIT_BIN"
    else
        echo "ERROR: Checksum mismatch!"
        echo "  Expected: $BASHUNIT_CHECKSUM"
        echo "  Got:      $actual_checksum"
        rm -f "$BASHUNIT_BIN.tmp"
        return 1
    fi
}

ensure_bashunit() {
    if [[ ! -f "$BASHUNIT_BIN" ]]; then
        download_bashunit
    else
        load_version_config
        echo ">>> bashunit already present at $BASHUNIT_BIN"
    fi
}

install_deps() {
    echo ">>> Checking dependencies..."

    local missing=()
    local deps=("bwrap" "socat" "curl" "zstd" "fzf" "sqlite3")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "WARNING: Missing dependencies: ${missing[*]}"
        echo "Install them via your package manager (e.g., pacman -S ...)"
    else
        echo ">>> All system dependencies present."
    fi

    ensure_bashunit

    return 0
}

run_tests() {
    ensure_bashunit
    export ROOT_DIR

    local test_path="$ROOT_DIR/tests"
    if [[ ! -d "$test_path" ]]; then
        echo "ERROR: No tests directory found at $test_path"
        return 1
    fi

    echo ""
    echo ">>> Running tests from $test_path..."
    "$BASHUNIT_BIN" --env "$ROOT_DIR/tests/bootstrap.sh" "$test_path"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_deps
    run_tests
fi
