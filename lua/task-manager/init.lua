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

  vim.api.nvim_create_user_command("TaskMoveFeatureUp", function()
    require("task-manager.move").move_feature_up_cursor()
  end, { desc = "Move the feature under the cursor up" })

  vim.api.nvim_create_user_command("TaskMoveFeatureDown", function()
    require("task-manager.move").move_feature_down_cursor()
  end, { desc = "Move the feature under the cursor down" })

  vim.api.nvim_create_user_command("TaskMoveTaskUp", function()
    require("task-manager.move").move_task_up_cursor()
  end, { desc = "Move the task under the cursor up within its feature" })

  vim.api.nvim_create_user_command("TaskMoveTaskDown", function()
    require("task-manager.move").move_task_down_cursor()
  end, { desc = "Move the task under the cursor down within its feature" })

  vim.api.nvim_create_user_command("TaskMoveSubtaskUp", function()
    require("task-manager.move").move_subtask_up_cursor()
  end, { desc = "Move the subtask under the cursor up within its task" })

  vim.api.nvim_create_user_command("TaskMoveSubtaskDown", function()
    require("task-manager.move").move_subtask_down_cursor()
  end, { desc = "Move the subtask under the cursor down within its task" })

  vim.api.nvim_create_user_command("TaskEjectFeature", function()
    require("task-manager.eject").eject_feature_cursor()
  end, { desc = "Eject the feature under the cursor (strip fts tokens, leaving plain text)" })
end

return M
