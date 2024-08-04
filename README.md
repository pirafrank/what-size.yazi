# what-size.yazi

A plugin for [yazi](https://github.com/sxyazi/yazi) to calculate the size of the current selection or the current working directory (if no selection is made).

## Requirements

- `du`

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
