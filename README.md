# task-manager.nvim

A Neovim plugin for managing structured plan/task markdown files.

## Installation

### lazy.nvim

```lua
{
  "your-username/task-manager.nvim",
  opts = {},
}
```

## Running tests

Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) on your runtime path (or a clone in `vendor/plenary.nvim`).

```bash
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# or 

just test
```

### Configuration

```lua
{
  "your-username/task-manager.nvim",
  opts = {
    tokens = {
      feature = "## Feature",
      task    = "- [ ]",
      subtask = "- [ ]",
    },
    keymaps = {
      enabled = true,
    },
    spacing = {
      after_feature = 0,
      after_task    = 0,
      after_subtask = 0,
    },
    shadow = {
      auto_attach = true,
    },
  },
}
```

## Keymaps

All keymaps are prefixed with `<leader>t`. Set `keymaps.enabled = false` to disable.

| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle checkbox |
| `<leader>taf` | Add feature |
| `<leader>tat` | Add task |
| `<leader>tas` | Add subtask |
| `<leader>trf` | Remove feature |
| `<leader>trt` | Remove task |
| `<leader>trs` | Remove subtask |
| `<leader>tmK` | Move feature up |
| `<leader>tmJ` | Move feature down |
| `<leader>tmk` | Move task up |
| `<leader>tmj` | Move task down |
| `<leader>t[` | Move subtask up |
| `<leader>t]` | Move subtask down |
| `<leader>tef` | Eject feature |
| `<leader>tet` | Eject task |
| `<leader>tes` | Eject subtask |
| `<leader>tg` | Go to target (e.g. `3`, `3.2`, `3.2.1`) |
| `<leader>tn` | Next incomplete |
| `<leader>tp` | Prev incomplete |
| `<leader>tN` | Next complete |
| `<leader>tP` | Prev complete |
| `<leader>tS` | Sort document |

## Lualine

`require("task-manager.statusline").summary()` returns a formatted string like `󰄲 6/7` for the current buffer (empty string when no tasks exist).

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      { require("task-manager.statusline").summary },
    },
  },
})
```
