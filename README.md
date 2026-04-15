# task-manager.nvim

A Neovim plugin for managing structured plan/task markdown files.

## Installation

### lazy.nvim

```lua
{
  "imdevan/task-manager.nvim",
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
  "imdevan/task-manager.nvim",
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
    feature_line = false,
    zero_index   = false,
  },
}
```

### `feature_line`

When `true`, a `---` separator is inserted between features on add and sort. Defaults to `false`.

```
## Feature 1: Auth

---
## Feature 2: Dashboard
```

### `zero_index`

When `true`, feature, task, and subtask numbering starts at `0` instead of `1`. Defaults to `false`.

```
## Feature 0: Setup
- [ ] 0.0 Install dependencies
  - [ ] 0.0.0 Add to package.json
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
| `<leader>tee` | Eject (feature, task, or subtask under cursor) |
| `<leader>tef` | Eject feature |
| `<leader>tet` | Eject task |
| `<leader>tes` | Eject subtask |
| `<leader>tg` | Go to target (e.g. `3`, `3.2`, `3.2.1`) |
| `<leader>tn` | Next incomplete |
| `<leader>tp` | Prev incomplete |
| `<leader>tN` | Next complete |
| `<leader>tP` | Prev complete |
| `<leader>tS` | Sort document |

## Commands

| Command | Description |
|---------|-------------|
| `TaskToggleCheckbox` | Toggle task/subtask checkbox on the current line |
| `TaskAddFeature` | Prompt for a name and insert a new feature at the cursor line |
| `TaskAddTask` | Prompt for a name and insert a new task under the feature at the cursor |
| `TaskAddSubtask` | Prompt for a name and insert a new subtask under the task at the cursor |
| `TaskRemoveFeature` | Remove the feature under the cursor and all its tasks/subtasks |
| `TaskRemoveTask` | Remove the task under the cursor and all its subtasks |
| `TaskRemoveSubtask` | Remove the subtask under the cursor |
| `TaskMoveFeatureUp` | Move the feature under the cursor up |
| `TaskMoveFeatureDown` | Move the feature under the cursor down |
| `TaskMoveTaskUp` | Move the task under the cursor up within its feature |
| `TaskMoveTaskDown` | Move the task under the cursor down within its feature |
| `TaskMoveSubtaskUp` | Move the subtask under the cursor up within its task |
| `TaskMoveSubtaskDown` | Move the subtask under the cursor down within its task |
| `TaskEject` | Eject the feature, task, or subtask under the cursor (strip tokens, leaving plain text) |
| `TaskEjectFeature` | Eject the feature under the cursor (strip tokens, leaving plain text) |
| `TaskEjectTask` | Eject the task under the cursor (strip tokens, leaving plain text) |
| `TaskEjectSubtask` | Eject the subtask under the cursor (strip token, leaving plain text) |
| `TaskGoto` | Go to a specific feature, task, or subtask by number (e.g., `3`, `3.2`, `3.2.1`) |
| `TaskNextIncomplete` | Go to the next incomplete (unchecked) task or subtask |
| `TaskPrevIncomplete` | Go to the previous incomplete (unchecked) task or subtask |
| `TaskNextComplete` | Go to the next complete (checked) task or subtask |
| `TaskPrevComplete` | Go to the previous complete (checked) task or subtask |
| `TaskSort` | Sort the entire document by numbers |
| `TaskShadowAttach` | Attach shadow virtual text (completion counts) to the current buffer |

## Custom Keymaps

Set `keymaps.enabled = false` and define your own mappings using the commands directly:

```lua
{
  "imdevan/task-manager.nvim",
  opts = { keymaps = { enabled = false } },
  config = function(_, opts)
    require("task-manager").setup(opts)
    vim.keymap.set("n", "<leader>tt", "<cmd>TaskToggleCheckbox<cr>")
    vim.keymap.set("n", "<leader>taf", "<cmd>TaskAddFeature<cr>")
    -- etc.
  end,
}
```

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
