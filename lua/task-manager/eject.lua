local utils = require("task-manager.utils")
local parser = require("task-manager.parser")
local config = require("task-manager.config")
local renumber = require("task-manager.renumber")

local M = {}

---Eject a feature by stripping the feature token, leaving plain heading text.
---All tasks/subtasks under this feature are also ejected (their tokens stripped).
---Features below are renumbered (pushed up).
---@param bufnr integer
---@param lnum integer  line number of the feature header
---@return boolean  false if the line is not a feature
function M.eject_feature(bufnr, lnum)
	local token = parser.parse_line(utils.get_line(bufnr, lnum))
	if not token or token.type ~= "feature" then
		return false
	end
	local fn = token.fn

	-- Extract the feature name from the current line
	local line = utils.get_line(bufnr, lnum)
	local pattern, captures = utils.compile_template(config.options.tokens.feature)
	local matches = { line:match(pattern) }
	local named = {}
	for i, cap_name in ipairs(captures) do
		named[cap_name] = matches[i]
	end

	-- Replace feature line with just the name (no heading markers)
	local indent = line:match("^(%s*)") or ""
	utils.set_line(bufnr, lnum, indent .. (named.name or ""))

	-- Find all tasks and subtasks belonging to this feature and eject them
	local index = parser.build_index(bufnr)
	for _, t in ipairs(index) do
		if t.fn == fn and (t.type == "task" or t.type == "subtask") then
			local task_line = utils.get_line(bufnr, t.lnum)
			local task_pattern, task_captures
			if t.type == "task" then
				task_pattern, task_captures = utils.compile_template(config.options.tokens.task)
			else
				task_pattern, task_captures = utils.compile_template(config.options.tokens.subtask)
			end

			local task_matches = { task_line:match(task_pattern) }
			local task_named = {}
			for i, cap_name in ipairs(task_captures) do
				task_named[cap_name] = task_matches[i]
			end

			-- Replace with just the name (no list markers or checkboxes)
			local task_indent = task_line:match("^(%s*)") or ""
			utils.set_line(bufnr, t.lnum, task_indent .. (task_named.name or ""))
		end
	end

	-- Renumber features below (push up)
	renumber.push_up(bufnr, lnum, "feature")
	return true
end

---Eject the feature containing the cursor.
---Works from any line within the feature (header, task, or subtask).
function M.eject_feature_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx then
		return
	end

	-- Resolve the feature header line
	local feature_lnum
	if ctx.type == "feature" then
		feature_lnum = ctx.lnum
	else
		local fn = ctx.fn
		for _, t in ipairs(parser.build_index(bufnr)) do
			if t.type == "feature" and t.fn == fn then
				feature_lnum = t.lnum
				break
			end
		end
	end

	if not feature_lnum then
		return
	end
	M.eject_feature(bufnr, feature_lnum)
end

---Eject a task by stripping the task token, leaving plain text.
---All subtasks under this task are also ejected (their tokens stripped).
---Sibling tasks within the same feature are renumbered (pushed up).
---@param bufnr integer
---@param lnum integer  line number of the task
---@return boolean  false if the line is not a task
function M.eject_task(bufnr, lnum)
	local token = parser.parse_line(utils.get_line(bufnr, lnum))
	if not token or token.type ~= "task" then
		return false
	end
	local fn = token.fn
	local tn = token.tn

	-- Extract the task name from the current line
	local line = utils.get_line(bufnr, lnum)
	local pattern, captures = utils.compile_template(config.options.tokens.task)
	local matches = { line:match(pattern) }
	local named = {}
	for i, cap_name in ipairs(captures) do
		named[cap_name] = matches[i]
	end

	-- Replace task line with just the name
	local indent = line:match("^(%s*)") or ""
	utils.set_line(bufnr, lnum, indent .. (named.name or ""))

	-- Find all subtasks belonging to this task and eject them
	local index = parser.build_index(bufnr)
	for _, t in ipairs(index) do
		if t.fn == fn and t.tn == tn and t.type == "subtask" then
			local subtask_line = utils.get_line(bufnr, t.lnum)
			local subtask_pattern, subtask_captures = utils.compile_template(config.options.tokens.subtask)

			local subtask_matches = { subtask_line:match(subtask_pattern) }
			local subtask_named = {}
			for i, cap_name in ipairs(subtask_captures) do
				subtask_named[cap_name] = subtask_matches[i]
			end

			-- Replace with just the name
			local subtask_indent = subtask_line:match("^(%s*)") or ""
			utils.set_line(bufnr, t.lnum, subtask_indent .. (subtask_named.name or ""))
		end
	end

	-- Renumber sibling tasks below (push up)
	renumber.push_up(bufnr, lnum, "task", fn)
	return true
end

---Eject the task containing the cursor.
---Works from any line within the task (task line or its subtasks).
function M.eject_task_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx or ctx.type == "feature" then
		return
	end

	-- Resolve the task line
	local task_lnum
	local fn = ctx.fn
	local tn = ctx.tn
	for _, t in ipairs(parser.build_index(bufnr)) do
		if t.type == "task" and t.fn == fn and t.tn == tn then
			task_lnum = t.lnum
			break
		end
	end

	if not task_lnum then
		return
	end
	M.eject_task(bufnr, task_lnum)
end

---Eject a subtask by stripping the subtask token, leaving plain text.
---Sibling subtasks within the same task are renumbered (pushed up).
---@param bufnr integer
---@param lnum integer  line number of the subtask
---@return boolean  false if the line is not a subtask
function M.eject_subtask(bufnr, lnum)
	local token = parser.parse_line(utils.get_line(bufnr, lnum))
	if not token or token.type ~= "subtask" then
		return false
	end
	local fn = token.fn
	local tn = token.tn

	-- Extract the subtask name from the current line
	local line = utils.get_line(bufnr, lnum)
	local pattern, captures = utils.compile_template(config.options.tokens.subtask)
	local matches = { line:match(pattern) }
	local named = {}
	for i, cap_name in ipairs(captures) do
		named[cap_name] = matches[i]
	end

	-- Replace subtask line with just the name
	local indent = line:match("^(%s*)") or ""
	utils.set_line(bufnr, lnum, indent .. (named.name or ""))

	-- Renumber sibling subtasks below (push up)
	renumber.push_up(bufnr, lnum, "subtask", fn, tn)
	return true
end

---Eject the subtask under the cursor.
function M.eject_subtask_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx or ctx.type ~= "subtask" then
		return
	end
	M.eject_subtask(bufnr, ctx.lnum)
end

return M
