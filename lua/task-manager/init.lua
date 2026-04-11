local M = {}

---Setup the plugin with optional user configuration
---@param opts? TaskManagerConfig
function M.setup(opts)
  require("task-manager.config").setup(opts)

  vim.api.nvim_create_user_command("TaskToggleCheckbox", function()
    require("task-manager.toggle").toggle_checkbox_cursor()
  end, { desc = "Toggle task/subtask checkbox on the current line" })

  vim.api.nvim_create_user_command("TaskAddFeature", function()
    require("task-manager.add").add_feature_cursor()
  end, { desc = "Prompt for a name and insert a new feature at the cursor line" })
end

return M
