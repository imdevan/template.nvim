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

  vim.api.nvim_create_user_command("TaskAddTask", function()
    require("task-manager.add").add_task_cursor()
  end, { desc = "Prompt for a name and insert a new task under the feature at the cursor" })

  vim.api.nvim_create_user_command("TaskAddSubtask", function()
    require("task-manager.add").add_subtask_cursor()
  end, { desc = "Prompt for a name and insert a new subtask under the task at the cursor" })

  vim.api.nvim_create_user_command("TaskRemoveFeature", function()
    require("task-manager.remove").remove_feature_cursor()
  end, { desc = "Remove the feature under the cursor and all its tasks/subtasks" })

  vim.api.nvim_create_user_command("TaskRemoveTask", function()
    require("task-manager.remove").remove_task_cursor()
  end, { desc = "Remove the task under the cursor and all its subtasks" })

  vim.api.nvim_create_user_command("TaskRemoveSubtask", function()
    require("task-manager.remove").remove_subtask_cursor()
  end, { desc = "Remove the subtask under the cursor" })
end

return M
