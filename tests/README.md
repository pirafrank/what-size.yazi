# What-size.yazi Plugin Tests

This directory contains integration tests for the `what-size.yazi` plugin using PTY (pseudo-terminal) to test the plugin in a real Yazi TUI environment.

## Prerequisites

- Rust and Cargo (for running tests)
- Yazi installed and available in PATH
- The plugin dependencies as specified in `Cargo.toml`

## Running Tests

Run all tests:
```bash
cargo test
```

Run tests with output visible:
```bash
cargo test -- --nocapture
```

## Test Structure

### `test_yazi_loads_with_plugin`

Tests that:

1. Yazi loads successfully with the plugin configured
2. The test directory contents are displayed in the TUI
3. The plugin can be triggered using the keymap (`.` + `s`)
4. The plugin displays size information for the current directory
5. The notification shows "Current Dir: XX.XX B" format

### `test_yazi_plugin_with_selection`

Tests that:

1. Yazi loads with the plugin
2. A file can be selected using the Space key
3. The plugin can be triggered with a selection
4. The plugin displays "Selected: XX.XX B" instead of "Current Dir:"
5. The size shown is for the selected file(s)

## Test Configuration

Tests use:
- Temporary test directories (`/tmp/yazi_test_what_size_<pid>`)
- Temporary config directories (`/tmp/yazi_test_config_<pid>`)
- PTY size: 120x40 (cols x rows)
- Custom keymap from `test_config/keymap.toml`
- Plugin symlinked from the project root

## How It Works

1. **Setup**: Creates test files and directories with known content
2. **PTY Creation**: Opens a pseudo-terminal to run Yazi
3. **Yazi Launch**: Spawns Yazi with test config and environment
4. **Screen Parsing**: Uses `vt100` parser to read TUI output
5. **Interaction**: Sends key sequences to trigger plugin functionality
6. **Verification**: Checks screen contents for expected plugin output
7. **Cleanup**: Removes temporary directories and kills Yazi process

## Debugging

To see full test output including TUI contents:

```bash
cargo test -- --nocapture
```

The tests print:
- Initial Yazi output (raw ANSI sequences)
- Parsed screen contents (human-readable)
- Plugin output after triggering
- Final screen state with size information

## Additional notes

- Tests run Yazi with `YAZI_LOG=debug` for debugging
- Terminal response timeouts are expected in PTY environment
- Tests use process ID to create unique temp directories
- Cleanup happens automatically after each test

