#!/usr/bin/env bash
set -Eeuo pipefail

: "${TEST_ROOT:?TEST_ROOT is required}"

log="$(find "$XDG_STATE_HOME" -type f -path '*/yazi/*.log' -print -quit 2>/dev/null || true)"
if [[ -n "$log" ]]; then
    cp "$log" "$TEST_ROOT/diagnostics/logs/yazi.log"
else
    : > "$TEST_ROOT/diagnostics/logs/yazi.log"
fi

# Deprecations are useful early-warning signals, but remain non-fatal while
# the exercised behavior still works.
if grep -Eiq 'deprecated|deprecation|will be removed|legacy API' "$TEST_ROOT/diagnostics/logs/yazi.log"; then
    echo "::warning::Yazi reported a possible deprecated API during what-size compatibility testing"
fi

# Keep this filter conservative: unrelated Yazi previewer/backend errors must
# not turn a successful plugin compatibility run red.
if grep -Eiq '(lua runtime error|attempt to (call|index)|nil value|failed to initialize status bar|what-size.*(error|failed|attempt)|(error|failed|attempt).*what-size)' "$TEST_ROOT/diagnostics/logs/yazi.log"; then
    echo "Yazi debug log contains a plugin/runtime error" >&2
    exit 1
fi
