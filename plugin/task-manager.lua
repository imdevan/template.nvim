-- Auto-loaded by Neovim on startup when installed as a plugin.
-- Calls setup with no args so the plugin works out of the box with defaults.
-- Users who want custom config should call require("task-manager").setup(opts)
-- in their own init.lua BEFORE this file runs, or rely on lazy.nvim's `opts` key.
if vim.g.loaded_task_manager then
  return
end
vim.g.loaded_task_manager = true

require("task-manager").setup()
