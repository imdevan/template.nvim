# template.nvim

Minimal Neovim plugin template. Ships one feature — printing "hello world" at the cursor — as a working example.

## Installation

### lazy.nvim

```lua
{
  "imdevan/template.nvim",
  opts = {},
}
```

## Configuration

```lua
{
  "imdevan/template.nvim",
  opts = {
    keymaps = {
      enabled = true,
    },
  },
}
```

## Keymaps

| Key | Action |
|-----|--------|
| `<leader>hw` | Insert "hello world" at the cursor |

Set `keymaps.enabled = false` to disable and define your own mapping:

```lua
{
  "imdevan/template.nvim",
  opts = { keymaps = { enabled = false } },
  config = function(_, opts)
    require("template").setup(opts)
    vim.keymap.set("n", "<leader>hw", "<cmd>HelloWorld<cr>")
  end,
}
```

## Commands

| Command | Description |
|---------|-------------|
| `HelloWorld` | Insert "hello world" at the cursor |

## Running tests

Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) on your runtime path (or a clone in `vendor/plenary.nvim`).

```bash
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# or

just test
```
