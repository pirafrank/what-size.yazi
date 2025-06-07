# what-size.yazi

A plugin for [yazi](https://github.com/sxyazi/yazi) to calculate the size of the current selection or the current working directory (if no selection is made).

## Compatibility

what-size supports Yazi on Linux, macOS, and Windows.

### OS

- Linux since first commit
- macOS since commit `42c6a0e` ([link](https://github.com/pirafrank/what-size.yazi/commit/42c6a0efb7245badb16781da5380be1a1705f3f2))
- Windows since commit `4a56ead` ([link](https://github.com/pirafrank/what-size.yazi/commit/4a56ead2a84c5969791fb17416e0b451ab906c5d))

### Yazi

- yazi `25.5.28` and onwards since commit `c5c939b` ([link](https://github.com/pirafrank/what-size.yazi/commit/c5c939bb37ec1d132c942cf5724d4e847acc2977))
- yazi `25.x`-`25.4.8` since commit `fce1778` ([link](https://github.com/pirafrank/what-size.yazi/commit/fce1778d911621dc57796cdfdf11dcda3c2e28de))
- yazi `0.4.x` since commit `2780de5` ([link](https://github.com/pirafrank/what-size.yazi/commit/2780de5aeef1ed16d1973dd6e0cd4d630c900d56))
- yazi `0.3.x` up to commit `f08f7f2` ([link](https://github.com/pirafrank/what-size.yazi/commit/f08f7f2d5c94958ac4cb66c51a7c24b4319c6c93))

## Requirements

- `du` (default) on Linux/macOS, PowerShell on Windows.
- [dua](https://github.com/Byron/dua-cli) (optional): If `dua` is found in your PATH, it will be used automatically for better performance. Ensure it's installed if you want to use it.

## Installation

```sh
ya pack -a 'pirafrank/what-size'
```

## Usage

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size", desc = "Calc size of selection or cwd" },
]
```

### Arguments

You can pass arguments to the plugin to modify its behavior.

#### clipboard

If you want to copy the result to clipboard, you can use the `clipboard` argument:

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size -- clipboard", desc = "Calc size of selection or cwd" },
]
```

#### dua

If you want to force the plugin to use `dua` to skip the `dua --version` test:

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size -- dua", desc = "Calc size of selection or cwd" },
]
```

#### no-dua

To prevent the plugin from automatically using `dua` even if it's installed, pass the `no-dua` argument:

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size -- no-dua", desc = "Calc size (force non-dua)" },
]
```

Change to whatever keybinding you like.

## Feedback

If you have any feedback, suggestions, or ideas please let me know by opening an issue.

## Dev setup

Check the debug config [here](https://yazi-rs.github.io/docs/plugins/overview/#debugging).

To get debug logs while develoing use `ya.dbg()` in your code, then set the `YAZI_LOG` environment variable to `debug` before running Yazi.

```sh
YAZI_LOG=debug yazi
```

Logs will be saved to `~.local/state/yazi/yazi.log` file.

## Contributing

Contributions are welcome. Please fork the repository and submit a PR.

## License

MIT
