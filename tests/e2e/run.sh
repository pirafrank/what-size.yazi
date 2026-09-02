#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve the script directory without invoking a user-customized `pwd`
# function or alias. A newline in this value would corrupt every sourced path.
SCRIPT_DIR="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")"
YAZI_VERSION="${YAZI_VERSION:-}"

# Ensure poof is installed to allow for easy Yazi install and version changes.
source "$SCRIPT_DIR/ensure-poof.sh"

TEST_ROOT="${TEST_ROOT:-${RUNNER_TEMP:-/tmp}/what-size-e2e-${YAZI_VERSION:-path}-$$}"
export TEST_ROOT YAZI_VERSION
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
export TERM="${TERM:-xterm-256color}" YAZI_LOG=debug

# Github Actions sets GITHUB_WORKSPACE to the repository root, but local runs may not have it.
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$(git -C "$SCRIPT_DIR/../.." rev-parse --show-toplevel)}"
export GITHUB_WORKSPACE

SESSION="what-size-e2e-${GITHUB_RUN_ID:-local}-$$"

# Yazi's --client-id is parsed as an unsigned numeric DDS identifier. Keep
# the tmux session name descriptive, but use a timestamp/PID value for Yazi.
CLIENT_ID="$(date +%s)$$"

FAILED_SCENARIO=unknown

mkdir -p "$XDG_CONFIG_HOME/yazi/plugins/what-size.yazi" \
    "$TEST_ROOT/fixture" "$TEST_ROOT/diagnostics/screens" "$TEST_ROOT/diagnostics/logs"

cleanup() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    if [[ -f "$TEST_ROOT/diagnostics/failed" ]]; then
        printf '%s\n' "${FAILED_SCENARIO:-unknown}" > "$TEST_ROOT/diagnostics/failed-scenario"
    fi
}

capture_failure_evidence() {
    # A dead tmux pane still contains the process's final terminal output when
    # remain-on-exit is enabled. Capture it before cleanup removes the session.
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        tmux capture-pane -t "$SESSION" -p -J \
            > "$TEST_ROOT/diagnostics/screens/99-failure.txt" 2>/dev/null || true
        tmux list-panes -t "$SESSION" -F \
            'pane_dead=#{pane_dead} exit_status=#{pane_dead_status} command=#{pane_current_command}' \
            > "$TEST_ROOT/diagnostics/pane-status.txt" 2>/dev/null || true
    fi

    # Startup failures happen before the normal post-shutdown log inspection.
    # Copy the log here as well so those failures remain actionable.
    local log
    log="$(find "$XDG_STATE_HOME" -type f -path '*/yazi/*.log' -print -quit 2>/dev/null || true)"
    if [[ -n "$log" ]]; then
        cp "$log" "$TEST_ROOT/diagnostics/logs/yazi.log"
    fi
}

on_error() {
    local status=$?

    printf '%s\n' "$status" > "$TEST_ROOT/diagnostics/failed"
    capture_failure_evidence
    cleanup
    exit "$status"
}

trap on_error ERR
trap cleanup EXIT

# Install the exact checkout under test. This prevents CI from accidentally
# loading a published plugin package instead of the source in this commit.
cp "$GITHUB_WORKSPACE/main.lua" "$XDG_CONFIG_HOME/yazi/plugins/what-size.yazi/main.lua"

# Use a unique marker so assertions prove the complete setup/status callback
# path executed, rather than matching an unrelated size elsewhere in the UI.
printf '%s\n' \
    'require("what-size"):setup({' \
    '    priority = 400,' \
    '    LEFT = "[WHAT-SIZE:",' \
    '    RIGHT = "]",' \
    '})' > "$XDG_CONFIG_HOME/yazi/init.lua"
cp "$XDG_CONFIG_HOME/yazi/init.lua" "$TEST_ROOT/diagnostics/init.lua"
head -c 4096 /dev/zero > "$TEST_ROOT/fixture/size-4096.dat"

# This validates the PATH-selected binaries and records their exact versions.
source "$SCRIPT_DIR/install-yazi.sh"
source "$SCRIPT_DIR/lib.sh"

# Record the resolved channel only as diagnostic metadata. The user-facing
# input is YAZI_VERSION; the literal value "nightly" is the only canary tag.
printf '%s\n' \
    "yazi_channel=$([[ "$YAZI_VERSION" == nightly ]] && echo nightly || echo stable)" \
    "yazi_requested_version=${YAZI_VERSION:-path}" \
    "what_size_commit=${GITHUB_SHA:-local}" \
    "github_run_id=${GITHUB_RUN_ID:-local}" \
    "github_run_attempt=${GITHUB_RUN_ATTEMPT:-1}" \
    "github_ref=${GITHUB_REF:-local}" \
    "github_run_url=${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-local}/actions/runs/${GITHUB_RUN_ID:-local}" \
    > "$TEST_ROOT/diagnostics/metadata.txt"
# Keep environment diagnostics intentionally small so secrets are not copied
# into the failure artifact.
uname -a > "$TEST_ROOT/diagnostics/environment.txt"
printf 'TERM=%s\nshell=%s\n' "$TERM" "$BASH_VERSION" >> "$TEST_ROOT/diagnostics/environment.txt"
tmux -V >> "$TEST_ROOT/diagnostics/environment.txt"
poof --version >> "$TEST_ROOT/diagnostics/environment.txt" 2>&1 || true

# Yazi is a full-screen TUI, so tmux provides the real PTY and rendered-screen
# state that stdout alone cannot represent.
tmux new-session \
    -d \
    -s "$SESSION" \
    -x 120 \
    -y 40 \
    "exec yazi --client-id '$CLIENT_ID' '$TEST_ROOT/fixture'"

tmux set-option -t "$SESSION" remain-on-exit on

set_scenario start-yazi
wait_for_screen size-4096.dat
save_screen 00-start.txt

set_scenario cwd-calculation
emit plugin what-size
wait_for_screen 'Current Dir: 4.00 KB'
save_screen 01-cwd-notification.txt

set_scenario cwd-status
wait_for_screen '[WHAT-SIZE:4.00 KB]'
save_screen 02-cwd-status.txt

set_scenario selection
emit toggle
wait_for_screen size-4096.dat

set_scenario selected-calculation
emit plugin what-size
wait_for_screen 'Selected: 4.00 KB'
save_screen 03-selected-notification.txt

set_scenario selected-status
wait_for_screen '[WHAT-SIZE:4.00 KB]'
save_screen 04-selected-status.txt

# Clipboard behavior depends on a desktop clipboard provider, which is not
# deterministic on the headless CI runner. Keep it out of compatibility tests.
set_scenario selection
emit toggle

set_scenario selected-status
wait_until_absent '[WHAT-SIZE:4.00 KB]'
save_screen 05-after-deselect.txt

set_scenario shutdown
emit quit
deadline=$((SECONDS + 15))

# `remain-on-exit` keeps the tmux session available for post-mortem capture,
# so session existence alone does not indicate that Yazi is still running.
while tmux has-session -t "$SESSION" 2>/dev/null && \
    [[ "$(tmux list-panes -t "$SESSION" -F '#{pane_dead}' 2>/dev/null)" != 1 ]] && \
    (( SECONDS < deadline )); do
    sleep 0.2
done

if tmux has-session -t "$SESSION" 2>/dev/null && \
    [[ "$(tmux list-panes -t "$SESSION" -F '#{pane_dead}' 2>/dev/null)" != 1 ]]; then
    echo 'Yazi did not shut down cleanly' >&2

    # This branch is outside a simple command context, so record the failure
    # explicitly before exiting instead of relying on the ERR trap.
    printf '1\n' > "$TEST_ROOT/diagnostics/failed"
    capture_failure_evidence
    exit 1
fi

pane_exit_status="$(tmux list-panes -t "$SESSION" -F '#{pane_dead_status}' 2>/dev/null || true)"
if [[ -n "$pane_exit_status" && "$pane_exit_status" != 0 ]]; then
    echo "Yazi exited with status $pane_exit_status" >&2
    printf '1\n' > "$TEST_ROOT/diagnostics/failed"
    capture_failure_evidence
    exit 1
fi

source "$SCRIPT_DIR/inspect-log.sh"
rm -f "$TEST_ROOT/diagnostics/failed-scenario"
