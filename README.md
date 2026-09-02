# what-size.yazi

[![CI](https://github.com/pirafrank/what-size.yazi/actions/workflows/ci.yml/badge.svg)](https://github.com/pirafrank/what-size.yazi/actions/workflows/ci.yml)

A plugin for [yazi](https://github.com/sxyazi/yazi) to calculate the size of the current selection or the current working directory (if no selection is made).

## Compatibility

what-size supports Yazi on Linux, macOS, and Windows.

### OS

- Linux since first commit
- macOS since commit `42c6a0e` ([link](https://github.com/pirafrank/what-size.yazi/commit/42c6a0efb7245badb16781da5380be1a1705f3f2))
- Windows since commit `4a56ead` ([link](https://github.com/pirafrank/what-size.yazi/commit/4a56ead2a84c5969791fb17416e0b451ab906c5d))

### Yazi

In an effort to make things easy, I keep `compatibility/yazi-x.y.z` branches with each pointing to the most up-to-date commit compatible with yazi release `x.y.z`. Full table below.

|Yazi releases|what-size branch name|
|---|---|
|*[latest stable](https://github.com/sxyazi/yazi/releases/latest)*|`main`|
|`25.5.28`-`26.5.6`|`compatibility/yazi-25.5.28`|
|`25.x`-`25.4.8`|`compatibility/yazi-25.4.8`|
|`0.4.x`|`compatibility/yazi-0.4.x`|
|`0.3.x`|`compatibility/yazi-0.3.x`|

Please notice that `nightly` releses may work but are not explicitly supported.

## Minimum Yazi version

You can check the current minimum required Yazi version [at the beginning of the `main.lua` file](https://github.com/pirafrank/what-size.yazi/blob/main/main.lua#L1), as per [Yazi guidelines](https://yazi-rs.github.io/docs/plugins/overview/#@since).

## Additional Requirements

### On Yazi's version 25.5.28 or newer

- No requirement

### Before Yazi's version 25.5.28

- Use this commit: [Old version](https://github.com/pirafrank/what-size.yazi/commit/d8966568f2a80394bf1f9a1ace6708ddd4cc8154)
- `du` on Linux and macOS
- PowerShell on Windows

## Installation

```sh
ya pkg add pirafrank/what-size
```

or (**DEPRECATED** - use only for yazi `25.4.8` and older):

```sh
ya pack -a 'pirafrank/what-size'
```

## Usage

### Keymap

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = [ ".", "s" ]
run  = "plugin what-size"
desc = "Calc size of selection or cwd" 
```

If you want to copy the result to clipboard, you can add `--clipboard` or `-c` as 2nd positional argument:

```toml
[[mgr.prepend_keymap]]
on   = [ ".", "s" ]
run  = "plugin what-size -- '--clipboard'"
desc = "Calc size of sel/cwd + paste to clipboard"
```

```toml
[[mgr.prepend_keymap]]
on = [ ".", "s" ]
run = "plugin what-size -- '-c'"
desc = "Calc size of sel/cwd + paste to clipboard"
```

Change to whatever keybinding you like.

### User interface (optional)

If you want to place the size value exactly where you want, modify the priority value. Also changing two strings `LEFT` and `RIGHT` will add them to the left and right side of the value. Remember to add to and change these lines inside your `init.lua` file if you want to customize, or the plugin will use this configuration by default:

```lua
require("what-size"):setup({
    priority = 400,
    LEFT = "",
    RIGHT = " ",
})
```

## Feedback

If you have any feedback, suggestions, or ideas please let me know by opening an issue.

## Dev setup

Check the debug config [here](https://yazi-rs.github.io/docs/plugins/overview/#debugging).

To get debug logs while developing use `ya.dbg()` in your code, then set the `YAZI_LOG` environment variable to `debug` before running Yazi.

```sh
YAZI_LOG=debug yazi
```

Logs will be saved to `~.local/state/yazi/yazi.log` file.

### Requirements

Install these tools before running the development recipes:

- `just` for the repository commands
- Bash 5 or newer for the e2e testing
- Lua 5.4 for syntax checks
- `luacheck` for static Lua analysis; LuaRocks is useful for installing it
- `stylua` for Lua formatting; install it with `just setup-stylua`
- [poof](https://poof.fpira.com/) for Yazi and StyLua installation and version selection
- `tmux` for the real TUI compatibility test
- `git`, `curl`, `realpath`, `head`, `grep`, `find`, `date`, and `tar` for tests and diagnostics

The active `yazi` and `ya` executables must be available in `PATH` and must report the same version. Use poof to select them before running `just test`:

```sh
poof use sxyazi/yazi 26.9.1
```

### justfile

The repository includes a `justfile` with shortcuts for common development tasks:

```sh
just test           # Run the Yazi compatibility suite with shell tracing
just fmt            # Format main.lua with StyLua
just check          # Check Lua syntax
just lint           # Run Luacheck
just better         # Run Lua checks and format the source
just setup-stylua   # Install StyLua through poof
```

### Plugin definition

The repo already has a `.luarc.json` file. You only need to run the following to add the `types` plugin dependency:

```sh
ya pkg add yazi-rs/plugins:types
```

as per the [docs](https://github.com/yazi-rs/plugins/tree/main/types.yazi).

### Runtime compatibility tests

The *compatibility test setup* requires [poof](https://poof.fpira.com/) to be installed locally. You should run `poof use sxyazi/yazi <version>` before starting the tests.

The test setup checks out the plugin at the current commit.

```sh
# If you want to install any Yazi, different from the one in your PATH, you can do it with poof:
poof install sxyazi/yazi -t v25.5.31
# Note v25.5.31 is the tag on the Yazi repo. Once installed, you can switch to it with:
# Then the tests use the active yazi/ya pair by default:
tests/e2e/run.sh

# Set YAZI_VERSION when strict validation is desired:
YAZI_VERSION=26.9.1 tests/e2e/run.sh
```

With poof, you can easily install multiple versions side by side and switch the active `yazi`/`ya` pair. For example:

```sh
poof install sxyazi/yazi -t nightly
poof use sxyazi/yazi 25.5.31
tests/e2e/run.sh

poof use sxyazi/yazi nightly
tests/e2e/run.sh
```

By default, the test setup uses whichever `yazi` and `ya` versions are active in `PATH`. Set `YAZI_VERSION=26.9.1` or `YAZI_VERSION=nightly` when you want strict validation against the selected version.

Under the hood, the tests run a real Yazi TUI in a tmux pseudo-terminal. The test setup is designed to be isolated and deterministic:

- The test setup sets isolated `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME` for Yazi only
- It uses a deterministic 4096-byte fixture
- `yazi` and `ya` are resolved from PATH; their binaries remain available
- Yazi's state/config/logs are written under the temporary test directory

When running locally:

- `tests/e2e/ensure-poof.sh` keeps poof installed in the local user environment
- Set `YAZI_VERSION` when you want the test setup to reject a different installed version

When running on GitHub Actions:

- GitHub Actions installs one version per matrix job using the Setup poof Marketplace action
- On failure it writes diagnostics containing rendered terminal captures, Yazi logs, versions, configuration, and sanitized environment metadata; GitHub Actions compresses these into the retained diagnostic archive.

## Contributing

Contributions are welcome. Please fork the repository and submit a PR.

The Lua formatter MUST be run before submitting changes that touch Lua files. You can run it with: `just fmt`.

## License

MIT
