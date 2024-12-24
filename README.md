# what-size.yazi

A plugin for [yazi](https://github.com/sxyazi/yazi) to calculate the size of the current selection or the current working directory (if no selection is made).

## Compatibility

- yazi `0.4.x` since commit `2780de5aeef1ed16d1973dd6e0cd4d630c900d56` ([link](https://github.com/pirafrank/what-size.yazi/commit/2780de5aeef1ed16d1973dd6e0cd4d630c900d56)).
- yazi `0.3.x` up to commit `f08f7f2d5c94958ac4cb66c51a7c24b4319c6c93` ([link](https://github.com/pirafrank/what-size.yazi/commit/f08f7f2d5c94958ac4cb66c51a7c24b4319c6c93)).

## Requirements

- `du` on Linux. macOS and Windows support is planned.

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

If you want to copy the result to clipboard, you can add `--clipboard` or `-c` as first argument:

```toml
[manager]
prepend_keymap = [
  { on   = [ ".", "s" ], run  = "plugin what-size --args='--clipboard'", desc = "Calc size of selection or cwd" },
]
```

Change to whatever keybinding you like.

## License

MIT
