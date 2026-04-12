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
  },
}
```
