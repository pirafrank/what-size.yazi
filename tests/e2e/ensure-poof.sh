#!/usr/bin/env bash
set -Eeuo pipefail

if command -v poof >/dev/null 2>&1; then
    return 0 2>/dev/null || exit 0
fi

if [[ "${CI:-false}" == true || "${GITHUB_ACTIONS:-false}" == true ]]; then
    echo 'poof is missing from PATH; Setup poof must run before the compatibility harness' >&2
    exit 1
fi

echo 'poof was not found; bootstrapping it from poof.fpira.com' >&2

# Use the official installer only for local development. CI must use the
# already-approved Setup poof action instead of downloading executable code.
curl -fsSL https://poof.fpira.com/install.sh | sh

# The installer may place poof in a user-local directory that is not in the
# current shell's PATH yet. Add the documented user locations before probing.
export PATH="${HOME}/.local/bin:${PATH}"
hash -r

if command -v poof >/dev/null 2>&1; then
    # Persist poof's own bin directory according to its supported shell setup.
    poof enable >/dev/null 2>&1 || true
    hash -r
fi

if ! command -v poof >/dev/null 2>&1; then
    echo 'poof is not available on PATH; run `poof enable` and retry' >&2
    exit 1
fi
