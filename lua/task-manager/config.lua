local M = {}

---@class TaskManagerConfig
---@field tokens TaskManagerTokens
---@field keymaps TaskManagerKeymaps

---@class TaskManagerTokens
---@field feature string  pattern prefix for feature headers
---@field task string     pattern prefix for task lines
---@field subtask string  pattern prefix for subtask lines

---@class TaskManagerKeymaps
---@field enabled boolean  master switch for all keymaps

M.defaults = {
  tokens = {
    feature = "## Feature",
    task    = "- [ ]",
    subtask = "- [ ]",
  },
  keymaps = {
    enabled = true,
  },
}

---@type TaskManagerConfig
M.options = {}

---Merge user opts over defaults and store in M.options
---@param opts? TaskManagerConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
