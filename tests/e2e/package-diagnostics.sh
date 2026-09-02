#!/usr/bin/env bash
set -Eeuo pipefail

: "${TEST_ROOT:?TEST_ROOT is required}"
: "${YAZI_VERSION:?YAZI_VERSION is required}"

[[ -f "$TEST_ROOT/diagnostics/failed" ]] || exit 0

scenario="$(cat "$TEST_ROOT/diagnostics/failed-scenario" 2>/dev/null || echo unknown)"
printf 'failed_scenario=%s\n' "$scenario" >> "$TEST_ROOT/diagnostics/metadata.txt"

safe_version="$(printf '%s' "$YAZI_VERSION" | tr -c 'A-Za-z0-9._-' '_')"
archive="what-size-yazi-${safe_version}-diagnostics.tar.gz"

# Keep the failure payload self-contained: one archive with all evidence from
# the failed compatibility attempt.
tar -czf "$GITHUB_WORKSPACE/$archive" -C "$TEST_ROOT" diagnostics
echo "DIAGNOSTIC_ARCHIVE=$GITHUB_WORKSPACE/$archive" >> "$GITHUB_ENV"
