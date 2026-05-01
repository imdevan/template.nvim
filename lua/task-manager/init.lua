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

	vim.api.nvim_create_user_command("TaskEjectTask", function()
		require("task-manager.eject").eject_task_cursor()
	end, { desc = "Eject the task under the cursor (strip fts tokens, leaving plain text)" })

	vim.api.nvim_create_user_command("TaskEjectSubtask", function()
		require("task-manager.eject").eject_subtask_cursor()
	end, { desc = "Eject the subtask under the cursor (strip fts token, leaving plain text)" })

	vim.api.nvim_create_user_command("TaskEject", function()
		require("task-manager.eject").eject_cursor()
	end, { desc = "Eject the fts token under the cursor (feature, task, or subtask)" })

	vim.api.nvim_create_user_command("TaskGoto", function()
		require("task-manager.navigate").goto_target_prompt()
	end, { desc = "Go to a specific feature, task, or subtask by number (e.g., 3, 3.2, 3.2.1)" })

	vim.api.nvim_create_user_command("TaskNextIncomplete", function()
		require("task-manager.navigate").goto_next_incomplete_cursor()
	end, { desc = "Go to the next incomplete (unchecked) task or subtask" })

	vim.api.nvim_create_user_command("TaskPrevIncomplete", function()
		require("task-manager.navigate").goto_prev_incomplete_cursor()
	end, { desc = "Go to the previous incomplete (unchecked) task or subtask" })

	vim.api.nvim_create_user_command("TaskNextComplete", function()
		require("task-manager.navigate").goto_next_complete_cursor()
	end, { desc = "Go to the next complete (checked) task or subtask" })

	vim.api.nvim_create_user_command("TaskPrevComplete", function()
		require("task-manager.navigate").goto_prev_complete_cursor()
	end, { desc = "Go to the previous complete (checked) task or subtask" })

	vim.api.nvim_create_user_command("TaskSort", function()
		require("task-manager.sort").sort_document_cursor()
	end, { desc = "Sort the entire document by fts numbers" })

	vim.api.nvim_create_user_command("TaskChangeToFeature", function()
		require("task-manager.change").changeTo_feature_cursor()
	end, { desc = "Change the current line into a feature token" })

	vim.api.nvim_create_user_command("TaskChangeToTask", function()
		require("task-manager.change").changeTo_task_cursor()
	end, { desc = "Change the current line into a task token" })

	vim.api.nvim_create_user_command("TaskChangeToSubtask", function()
		require("task-manager.change").changeTo_subtask_cursor()
	end, { desc = "Change the current line into a subtask token" })

	vim.api.nvim_create_user_command("TaskShadowAttach", function()
		require("task-manager.shadow").attach(vim.api.nvim_get_current_buf())
	end, { desc = "Attach shadow virtual text (completion counts) to the current buffer" })

	vim.api.nvim_create_user_command("TaskShowRemaining", function()
		require("task-manager.show_remaining").toggle_show_remaining()
	end, { desc = "Toggle show remaining (incomplete) tasks" })

	vim.api.nvim_create_user_command("TaskKick", function()
		require("task-manager.kick").kick_cursor()
	end, { desc = "Kick the FTS item under the cursor to the kicked file" })

	local cfg = require("task-manager.config").options
	if cfg.keymaps.enabled then
		local map = function(lhs, cmd, desc)
			vim.keymap.set("n", lhs, "<cmd>" .. cmd .. "<cr>", { desc = desc })
		end

		map("<leader>tt", "TaskToggleCheckbox",   "Toggle checkbox")
		map("<leader>taf", "TaskAddFeature",       "Add feature")
		map("<leader>tat", "TaskAddTask",          "Add task")
		map("<leader>tas", "TaskAddSubtask",       "Add subtask")
		map("<leader>trf", "TaskRemoveFeature",    "Remove feature")
		map("<leader>trt", "TaskRemoveTask",       "Remove task")
		map("<leader>trs", "TaskRemoveSubtask",    "Remove subtask")
		map("<leader>tmK", "TaskMoveFeatureUp",    "Move feature up")
		map("<leader>tmJ", "TaskMoveFeatureDown",  "Move feature down")
		map("<leader>tmk", "TaskMoveTaskUp",       "Move task up")
		map("<leader>tmj", "TaskMoveTaskDown",     "Move task down")
		map("<leader>t[",  "TaskMoveSubtaskUp",    "Move subtask up")
		map("<leader>t]",  "TaskMoveSubtaskDown",  "Move subtask down")
		map("<leader>tef", "TaskEjectFeature",     "Eject feature")
		map("<leader>tet", "TaskEjectTask",        "Eject task")
		map("<leader>tes", "TaskEjectSubtask",     "Eject subtask")
		map("<leader>tee", "TaskEject",            "Eject (auto)")
		map("<leader>tg",  "TaskGoto",             "Go to fts target")
		map("<leader>tn",  "TaskNextIncomplete",   "Next incomplete")
		map("<leader>tp",  "TaskPrevIncomplete",   "Prev incomplete")
		map("<leader>tN",  "TaskNextComplete",     "Next complete")
		map("<leader>tP",  "TaskPrevComplete",     "Prev complete")
		map("<leader>tS",  "TaskSort",             "Sort document")
		map("<leader>tcf", "TaskChangeToFeature",  "Change to feature")
		map("<leader>tct", "TaskChangeToTask",     "Change to task")
		map("<leader>tcs", "TaskChangeToSubtask",  "Change to subtask")
		map("<leader>ts",  "TaskShowRemaining",    "Show remaining tasks")
		map("<leader>tk",  "TaskKick",             "Kick FTS item to kicked file")

		local ok, wk = pcall(require, "which-key")
		if ok then
			wk.add({ { "<leader>t", group = "task-manager" } })
		end
	end

	if cfg.shadow.auto_attach then
		vim.api.nvim_create_autocmd("BufEnter", {
			pattern = "*.md",
			callback = function(ev)
				require("task-manager.shadow").attach(ev.buf)
			end,
		})
	end
end

return M
