# What-size.yazi Plugin Tests

This directory contains integration tests for the `what-size.yazi` plugin using PTY (pseudo-terminal) to test the plugin in a real Yazi TUI environment.

## Prerequisites

- Linux (because of clipboard testing)
- Rust and Cargo (for running tests)
- `just` optional but recommended
- Yazi installed and available in `PATH`
- The plugin dependencies as specified in `Cargo.toml`
- `sudo apt-get update && sudo apt-get install -y xclip xvfb`

## Running Tests

Run all tests:

```bash
just test
```

## Test Structure

- `test_yazi_size_cwd`: tests plugin loading and showing size of current working dir
- `test_yazi_size_selection`, tests plugin loading and showing size of one selected file
- `test_yazi_size_cwd_clipboard`, tests plugin loading, showing size of current working dir, and copying the content to clipboard
- `test_yazi_size_selection_clipboard`, tests plugin loading, showing size of one selected file, and copying the content to clipboard

## Test Configuration

Tests use:

- Temporary test directories (`/tmp/yazi_test_what_size_<pid>`)
- Temporary config directories (`/tmp/yazi_test_config_<pid>`)
- PTY size: 120x40 (cols x rows)
- Custom keymap file from `test_config/keymap.toml`
- Custom `init.lua` from `test_config/init.lua`
- Plugin directory symlinked to the project root

## Debugging

To see full test output including TUI contents:

```bash
just debug
```

Note: this may pollute your terminal because of printing of PTY content to sysout!

## Additional notes

- Tests run Yazi with `YAZI_LOG=debug` for debugging
- Terminal response timeouts are expected in PTY environment
- Tests use process ID to create unique temp directories
- Each test waits for Yazi to properly exit with a 5-second timeout
- Cleanup happens automatically after each test via Drop implementation
