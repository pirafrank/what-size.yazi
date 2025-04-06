# what-size.yazi

A plugin for [yazi](https://github.com/sxyazi/yazi) to calculate the size of the current selection or the current working directory (if no selection is made).

## Compatibility

- yazi `25.x` since commit `fce1778d911621dc57796cdfdf11dcda3c2e28de` ([link](https://github.com/pirafrank/what-size.yazi/commit/fce1778d911621dc57796cdfdf11dcda3c2e28de)).
- yazi `0.4.x` since commit `2780de5aeef1ed16d1973dd6e0cd4d630c900d56` ([link](https://github.com/pirafrank/what-size.yazi/commit/2780de5aeef1ed16d1973dd6e0cd4d630c900d56)).
- yazi `0.3.x` up to commit `f08f7f2d5c94958ac4cb66c51a7c24b4319c6c93` ([link](https://github.com/pirafrank/what-size.yazi/commit/f08f7f2d5c94958ac4cb66c51a7c24b4319c6c93)).

## Requirements

- `du` (default) on Linux. macOS
- [dua](https://github.com/Byron/dua-cli) is an alternative solution providing a fast disk usage analyzer written in Rust. If you choose this option, install per the instructions and ensure it is in your PATH. It offers better performance than `du` on large folders.

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

If you want to copy the result to the clipboard, add `clipboard` as an argument (note the space after `--`): `plugin what-size -- clipboard`

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size -- clipboard", desc = "Calc size of selection or cwd" },
]
```

#### dua

If you want to use `dua` instead of `du`, add `dua` as an argument (note the space after `--`): `plugin what-size -- dua`

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size -- dua", desc = "Calc size of selection or cwd" },
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
