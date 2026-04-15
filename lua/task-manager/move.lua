local utils = require("task-manager.utils")
local parser = require("task-manager.parser")
local renumber = require("task-manager.renumber")

local M = {}

---Find the line range [start, end] (1-indexed, inclusive) of a feature block.
---Returns the feature header line and the last line owned by the feature
---(including all tasks, subtasks, and trailing non-fts lines, but NOT the
---blank line separator before the next feature).
---@param bufnr integer
---@param feature_lnum integer  line number of the feature header
---@return integer, integer  start_line, end_line
local function get_feature_range(bufnr, feature_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, feature_lnum))
	if not token or token.type ~= "feature" then
		return feature_lnum, feature_lnum
	end
	local fn = token.fn

	local index = parser.build_index(bufnr)
	local last_own = feature_lnum

	-- Find all lines belonging to this feature
	for _, t in ipairs(index) do
		if t.lnum <= feature_lnum then
			goto continue
		end
		if t.type == "feature" then
			break
		end
		if t.fn == fn then
			last_own = t.lnum
		end
		::continue::
	end

	-- Extend to cover trailing non-fts lines, but stop before blank lines
	-- that separate features
	local total = utils.line_count(bufnr)
	for i = last_own + 1, total do
		local line = utils.get_line(bufnr, i)
		local t = parser.parse_line(line)
		if t then
			-- Hit another fts token, stop
			break
		end
		-- If it's a blank line, check if the next line is a feature
		if line:match("^%s*$") then
			if i < total then
				local next_t = parser.parse_line(utils.get_line(bufnr, i + 1))
				if next_t and next_t.type == "feature" then
					-- This blank line separates features, don't include it
					break
				end
			end
		end
		last_own = i
	end

	return feature_lnum, last_own
end

---Move a feature block up by swapping it with the feature above.
---@param bufnr integer
---@param feature_lnum integer  line number of the feature header to move
---@return boolean  false if the feature is already at the top
function M.move_feature_up(bufnr, feature_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, feature_lnum))
	if not token or token.type ~= "feature" then
		return false
	end

	-- Find the feature above
	local index = parser.build_index(bufnr)
	local prev_feature_lnum = nil
	for _, t in ipairs(index) do
		if t.type == "feature" and t.lnum < feature_lnum then
			prev_feature_lnum = t.lnum
		end
	end

	if not prev_feature_lnum then
		return false
	end -- already at top

	-- Get ranges for both features
	local prev_start, prev_end = get_feature_range(bufnr, prev_feature_lnum)
	local curr_start, curr_end = get_feature_range(bufnr, feature_lnum)

	-- Extract the text blocks
	local prev_lines = vim.api.nvim_buf_get_lines(bufnr, prev_start - 1, prev_end, false)
	local curr_lines = vim.api.nvim_buf_get_lines(bufnr, curr_start - 1, curr_end, false)

	-- Replace the entire range with swapped blocks, adding blank line separator
	local combined = {}
	for _, line in ipairs(curr_lines) do
		table.insert(combined, line)
	end
	table.insert(combined, "") -- blank line separator
	for _, line in ipairs(prev_lines) do
		table.insert(combined, line)
	end

	vim.api.nvim_buf_set_lines(bufnr, prev_start - 1, curr_end, false, combined)

	-- Renumber the entire buffer to fix all numbering
	renumber.renumber(bufnr)

	-- Move cursor to the new position of the moved feature (if in a valid window)
	local new_lnum = prev_start
	if vim.api.nvim_get_current_buf() == bufnr then
		pcall(utils.set_cursor_line, new_lnum)
	end

	return true
end

---Move a feature block down by swapping it with the feature below.
---@param bufnr integer
---@param feature_lnum integer  line number of the feature header to move
---@return boolean  false if the feature is already at the bottom
function M.move_feature_down(bufnr, feature_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, feature_lnum))
	if not token or token.type ~= "feature" then
		return false
	end

	-- Find the feature below
	local index = parser.build_index(bufnr)
	local next_feature_lnum = nil
	for _, t in ipairs(index) do
		if t.type == "feature" and t.lnum > feature_lnum then
			next_feature_lnum = t.lnum
			break
		end
	end

	if not next_feature_lnum then
		return false
	end -- already at bottom

	-- Get ranges for both features
	local curr_start, curr_end = get_feature_range(bufnr, feature_lnum)
	local next_start, next_end = get_feature_range(bufnr, next_feature_lnum)

	-- Extract the text blocks
	local curr_lines = vim.api.nvim_buf_get_lines(bufnr, curr_start - 1, curr_end, false)
	local next_lines = vim.api.nvim_buf_get_lines(bufnr, next_start - 1, next_end, false)

	-- Replace the entire range with swapped blocks, adding blank line separator
	local combined = {}
	for _, line in ipairs(next_lines) do
		table.insert(combined, line)
	end
	table.insert(combined, "") -- blank line separator
	for _, line in ipairs(curr_lines) do
		table.insert(combined, line)
	end

	vim.api.nvim_buf_set_lines(bufnr, curr_start - 1, next_end, false, combined)

	-- Renumber the entire buffer to fix all numbering
	renumber.renumber(bufnr)

	-- Move cursor to the new position of the moved feature (if in a valid window)
	local new_lnum = curr_start + #next_lines + 1
	if vim.api.nvim_get_current_buf() == bufnr then
		pcall(utils.set_cursor_line, new_lnum)
	end

	return true
end

---Find the line range [start, end] of a task block (task + its subtasks +
---trailing non-fts lines, stopping before the next task or feature).
---@param bufnr integer
---@param task_lnum integer  line number of the task
---@return integer, integer  start_line, end_line
local function get_task_range(bufnr, task_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, task_lnum))
	if not token or token.type ~= "task" then
		return task_lnum, task_lnum
	end
	local fn = token.fn
	local tn = token.tn

	local index = parser.build_index(bufnr)
	local last_own = task_lnum

	for _, t in ipairs(index) do
		if t.lnum <= task_lnum then
			goto continue
		end
		if t.type == "feature" or (t.type == "task" and t.fn == fn) then
			break
		end
		if t.fn == fn and t.tn == tn then
			last_own = t.lnum
		end
		::continue::
	end

	-- Extend to trailing non-fts lines before the next fts token,
	-- but stop before blank lines or --- separators that form a feature boundary
	local total = utils.line_count(bufnr)
	for i = last_own + 1, total do
		local line = utils.get_line(bufnr, i)
		local t = parser.parse_line(line)
		if t then break end
		if not line:match("%S") then break end
		if line:match("^%s*---%s*$") then break end
		last_own = i
	end

	return task_lnum, last_own
end
---@param bufnr integer
---@param task_lnum integer  line number of the task to move
---@return boolean  false if already at the top of the feature
function M.move_task_up(bufnr, task_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, task_lnum))
	if not token or token.type ~= "task" then
		return false
	end
	local fn = token.fn

	-- Find the task above in the same feature
	local index = parser.build_index(bufnr)
	local prev_task_lnum = nil
	for _, t in ipairs(index) do
		if t.type == "task" and t.fn == fn and t.lnum < task_lnum then
			prev_task_lnum = t.lnum
		end
	end

	if not prev_task_lnum then
		return false
	end

	local prev_start, prev_end = get_task_range(bufnr, prev_task_lnum)
	local curr_start, curr_end = get_task_range(bufnr, task_lnum)

	local prev_lines = vim.api.nvim_buf_get_lines(bufnr, prev_start - 1, prev_end, false)
	local curr_lines = vim.api.nvim_buf_get_lines(bufnr, curr_start - 1, curr_end, false)

	local combined = {}
	for _, line in ipairs(curr_lines) do
		table.insert(combined, line)
	end
	for _, line in ipairs(prev_lines) do
		table.insert(combined, line)
	end

	vim.api.nvim_buf_set_lines(bufnr, prev_start - 1, curr_end, false, combined)
	renumber.renumber(bufnr)

	if vim.api.nvim_get_current_buf() == bufnr then
		pcall(utils.set_cursor_line, prev_start)
	end
	return true
end

---Move a task block down by swapping it with the task below in the same feature.
---@param bufnr integer
---@param task_lnum integer  line number of the task to move
---@return boolean  false if already at the bottom of the feature
function M.move_task_down(bufnr, task_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, task_lnum))
	if not token or token.type ~= "task" then
		return false
	end
	local fn = token.fn

	-- Find the task below in the same feature
	local index = parser.build_index(bufnr)
	local next_task_lnum = nil
	for _, t in ipairs(index) do
		if t.type == "task" and t.fn == fn and t.lnum > task_lnum then
			next_task_lnum = t.lnum
			break
		end
	end

	if not next_task_lnum then
		return false
	end

	local curr_start, curr_end = get_task_range(bufnr, task_lnum)
	local next_start, next_end = get_task_range(bufnr, next_task_lnum)

	local curr_lines = vim.api.nvim_buf_get_lines(bufnr, curr_start - 1, curr_end, false)
	local next_lines = vim.api.nvim_buf_get_lines(bufnr, next_start - 1, next_end, false)

	local combined = {}
	for _, line in ipairs(next_lines) do
		table.insert(combined, line)
	end
	for _, line in ipairs(curr_lines) do
		table.insert(combined, line)
	end

	vim.api.nvim_buf_set_lines(bufnr, curr_start - 1, next_end, false, combined)
	renumber.renumber(bufnr)

	if vim.api.nvim_get_current_buf() == bufnr then
		pcall(utils.set_cursor_line, curr_start + #next_lines)
	end
	return true
end

---Move the task containing the cursor up.
---Works from any line within the task (task or subtask line).
function M.move_task_up_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx or ctx.type == "feature" then
		return
	end
	local fn, tn = ctx.fn, ctx.tn
	for _, t in ipairs(parser.build_index(bufnr)) do
		if t.type == "task" and t.fn == fn and t.tn == tn then
			M.move_task_up(bufnr, t.lnum)
			return
		end
	end
end

---Move the task containing the cursor down.
---Works from any line within the task (task or subtask line).
function M.move_task_down_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx or ctx.type == "feature" then
		return
	end
	local fn, tn = ctx.fn, ctx.tn
	for _, t in ipairs(parser.build_index(bufnr)) do
		if t.type == "task" and t.fn == fn and t.tn == tn then
			M.move_task_down(bufnr, t.lnum)
			return
		end
	end
end

---Find the line range [start, end] of a subtask (subtask line + trailing
---non-fts lines, stopping before the next subtask or task).
---@param bufnr integer
---@param subtask_lnum integer  line number of the subtask
---@return integer, integer  start_line, end_line
local function get_subtask_range(bufnr, subtask_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, subtask_lnum))
	if not token or token.type ~= "subtask" then
		return subtask_lnum, subtask_lnum
	end
	local fn = token.fn
	local tn = token.tn

	local last_own = subtask_lnum

	-- Extend to trailing non-fts lines before the next fts token
	local total = utils.line_count(bufnr)
	for i = last_own + 1, total do
		local t = parser.parse_line(utils.get_line(bufnr, i))
		if t then
			break
		end
		last_own = i
	end

	return subtask_lnum, last_own
end

---Move a subtask up by swapping it with the subtask above in the same task.
---@param bufnr integer
---@param subtask_lnum integer  line number of the subtask to move
---@return boolean  false if already at the top of the task
function M.move_subtask_up(bufnr, subtask_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, subtask_lnum))
	if not token or token.type ~= "subtask" then
		return false
	end
	local fn = token.fn
	local tn = token.tn

	-- Find the subtask above in the same task
	local index = parser.build_index(bufnr)
	local prev_subtask_lnum = nil
	for _, t in ipairs(index) do
		if t.type == "subtask" and t.fn == fn and t.tn == tn and t.lnum < subtask_lnum then
			prev_subtask_lnum = t.lnum
		end
	end

	if not prev_subtask_lnum then
		return false
	end

	-- Get ranges for both subtasks (including trailing notes)
	local prev_start, prev_end = get_subtask_range(bufnr, prev_subtask_lnum)
	local curr_start, curr_end = get_subtask_range(bufnr, subtask_lnum)

	-- Extract the text blocks
	local prev_lines = vim.api.nvim_buf_get_lines(bufnr, prev_start - 1, prev_end, false)
	local curr_lines = vim.api.nvim_buf_get_lines(bufnr, curr_start - 1, curr_end, false)

	-- Swap the blocks
	local combined = {}
	for _, line in ipairs(curr_lines) do
		table.insert(combined, line)
	end
	for _, line in ipairs(prev_lines) do
		table.insert(combined, line)
	end

	vim.api.nvim_buf_set_lines(bufnr, prev_start - 1, curr_end, false, combined)

	-- Renumber to fix subtask numbers
	renumber.renumber(bufnr)

	if vim.api.nvim_get_current_buf() == bufnr then
		pcall(utils.set_cursor_line, prev_start)
	end
	return true
end

---Move a subtask down by swapping it with the subtask below in the same task.
---@param bufnr integer
---@param subtask_lnum integer  line number of the subtask to move
---@return boolean  false if already at the bottom of the task
function M.move_subtask_down(bufnr, subtask_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, subtask_lnum))
	if not token or token.type ~= "subtask" then
		return false
	end
	local fn = token.fn
	local tn = token.tn

	-- Find the subtask below in the same task
	local index = parser.build_index(bufnr)
	local next_subtask_lnum = nil
	for _, t in ipairs(index) do
		if t.type == "subtask" and t.fn == fn and t.tn == tn and t.lnum > subtask_lnum then
			next_subtask_lnum = t.lnum
			break
		end
	end

	if not next_subtask_lnum then
		return false
	end

	-- Get ranges for both subtasks (including trailing notes)
	local curr_start, curr_end = get_subtask_range(bufnr, subtask_lnum)
	local next_start, next_end = get_subtask_range(bufnr, next_subtask_lnum)

	-- Extract the text blocks
	local curr_lines = vim.api.nvim_buf_get_lines(bufnr, curr_start - 1, curr_end, false)
	local next_lines = vim.api.nvim_buf_get_lines(bufnr, next_start - 1, next_end, false)

	-- Swap the blocks
	local combined = {}
	for _, line in ipairs(next_lines) do
		table.insert(combined, line)
	end
	for _, line in ipairs(curr_lines) do
		table.insert(combined, line)
	end

	vim.api.nvim_buf_set_lines(bufnr, curr_start - 1, next_end, false, combined)

	-- Renumber to fix subtask numbers
	renumber.renumber(bufnr)

	if vim.api.nvim_get_current_buf() == bufnr then
		pcall(utils.set_cursor_line, curr_start + #next_lines)
	end
	return true
end

---Move the subtask under the cursor up.
function M.move_subtask_up_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx or ctx.type ~= "subtask" then
		return
	end
	M.move_subtask_up(bufnr, ctx.lnum)
end

---Move the subtask under the cursor down.
function M.move_subtask_down_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local ctx = parser.context_at(bufnr, utils.cursor_line())
	if not ctx or ctx.type ~= "subtask" then
		return
	end
	M.move_subtask_down(bufnr, ctx.lnum)
end

---Move the feature containing the cursor up.
function M.move_feature_up_cursor()
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
	M.move_feature_up(bufnr, feature_lnum)
end

---Move the feature containing the cursor down.
function M.move_feature_down_cursor()
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
	M.move_feature_down(bufnr, feature_lnum)
end

return M
