local M = {}

---@class TaskManagerConfig
---@field tokens       TaskManagerTokens
---@field keymaps      TaskManagerKeymaps
---@field spacing      TaskManagerSpacing
---@field shadow       TaskManagerShadow
---@field feature_line boolean  insert a --- line between features on add and sort
---@field zero_index   boolean  start feature/task/subtask numbering at 0 instead of 1

---@class TaskManagerTokens
---@field feature string  template for feature header lines; use {feature} and {name}
---@field task    string  template for task lines; use {feature}, {task}, {name}
---@field subtask string  template for subtask lines; use {feature}, {task}, {subtask}, {name}

---@class TaskManagerKeymaps
---@field enabled boolean  master switch for all keymaps

---@class TaskManagerSpacing
---@field after_feature integer  blank lines inserted after a new feature header
---@field after_task    integer  blank lines inserted after a new task line
---@field after_subtask integer  blank lines inserted after a new subtask line

---@class TaskManagerShadow
---@field auto_attach boolean  attach shadow virtual text automatically on setup

M.defaults = {
  tokens = {
    feature = "## Feature {feature}: {name}",
    task    = "- [ ] {feature}.{task} {name}",
    subtask = "- [ ] {feature}.{task}.{subtask} {name}",
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
}

---@type TaskManagerConfig
M.options = vim.tbl_deep_extend("force", {}, M.defaults)

---Merge user opts over defaults and store in M.options
---@param opts? TaskManagerConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
