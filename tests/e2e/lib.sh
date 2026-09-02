#!/usr/bin/env bash
set -Eeuo pipefail

capture_screen() {
    tmux capture-pane -t "$SESSION" -p -J 2>/dev/null || true
}

save_screen() {
    local name="$1"
    capture_screen > "$TEST_ROOT/diagnostics/screens/$name"
}

wait_for_screen() {
    local text="$1"
    local timeout="${2:-15}"
    local deadline=$((SECONDS + timeout))

    while (( SECONDS < deadline )); do
        if capture_screen | grep -Fq -- "$text"; then
            return 0
        fi
        sleep 0.2
    done

    echo "Timed out waiting for screen text: $text" >&2
    capture_screen >&2
    return 1
}

wait_until_absent() {
    local text="$1"
    local timeout="${2:-15}"
    local deadline=$((SECONDS + timeout))

    while (( SECONDS < deadline )); do
        if ! capture_screen | grep -Fq -- "$text"; then
            return 0
        fi
        sleep 0.2
    done

    echo "Timed out waiting for screen text to disappear: $text" >&2
    capture_screen >&2
    return 1
}

set_scenario() {
    FAILED_SCENARIO="$1"
    printf '%s\n' "$FAILED_SCENARIO" > "$TEST_ROOT/diagnostics/failed-scenario"
}

assert_session_alive() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

emit() {
    ya emit-to "$CLIENT_ID" "$@"
}
