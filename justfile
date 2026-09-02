
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

# Match the luacheck invocation from .github/workflows/ci.yml.
lint:
    luacheck main.lua --globals ya cx fs ui Status --no-unused-args --no-max-line-length

# Format the plugin source with StyLua.
fmt:
    stylua main.lua

# Install the latest pre-built StyLua release through poof.
setup-stylua:
    poof install JohnnyMorganz/StyLua

# Run the two Lua checks used by the static CI workflow.
better: check fmt lint
