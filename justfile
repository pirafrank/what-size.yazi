
# Run the default task, which is to list the available tasks.
default:
    just --list

# Run the real Yazi compatibility test suite with shell tracing enabled.
# Include the standard user-local bin directory where poof may be installed.
test:
    PATH="$HOME/.local/bin:$PATH" bash -x tests/e2e/run.sh

# Keep the more descriptive name available as an alias.
e2e: test

# Match the syntax check from .github/workflows/ci.yml.
check:
    lua -e "assert(loadfile('main.lua'))"

# Perform a lint check on the plugin source with luacheck.
lint:
    luacheck main.lua --globals ya cx fs ui Status --no-unused-args --no-max-line-length

# Format the plugin source with StyLua.
fmt:
    stylua main.lua

# Use StyLua to check that the plugin source is formatted correctly.
fmt-check:
    stylua --check main.lua

# Install the latest pre-built StyLua release through poof.
setup-stylua:
    poof install JohnnyMorganz/StyLua

# Run Lua checks used by the static CI workflow and than format code.
better: check lint fmt

# Run the same tests CI pipeline runs
ci: check fmt-check lint
