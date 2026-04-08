local M = {}

---Setup the plugin with optional user configuration
---@param opts? TaskManagerConfig
function M.setup(opts)
  require("task-manager.config").setup(opts)
end

return M
