#!/usr/bin/env bash
set -Eeuo pipefail

: "${TEST_ROOT:?TEST_ROOT is required}"

YAZI_PATH="$(command -v yazi)" || {
    echo 'yazi is missing from PATH' >&2
    exit 1
}

YA_PATH="$(command -v ya)" || {
    echo 'ya is missing from PATH' >&2
    exit 1
}

export YAZI_PATH YA_PATH

yazi --version > "$TEST_ROOT/diagnostics/yazi-version.txt"
ya --version > "$TEST_ROOT/diagnostics/ya-version.txt"

extract_version() {
    grep -Eo '([0-9]+\.){2}[0-9]+|nightly' | head -n1 || true
}

yazi_version="$(extract_version < "$TEST_ROOT/diagnostics/yazi-version.txt")"
ya_version="$(extract_version < "$TEST_ROOT/diagnostics/ya-version.txt")"
if [[ -z "$yazi_version" || "$yazi_version" != "$ya_version" ]]; then
    echo 'yazi and ya versions differ or could not be parsed' >&2
    exit 1
fi

if [[ -z "${YAZI_VERSION:-}" ]]; then
    export YAZI_VERSION="$yazi_version"
fi

if [[ "$YAZI_VERSION" != nightly ]]; then
    requested_version="${YAZI_VERSION#v}"
    if [[ "$yazi_version" != "$requested_version" ]]; then
        echo "Installed Yazi does not match requested version $YAZI_VERSION: $yazi_version" >&2
        exit 1
    fi
fi
