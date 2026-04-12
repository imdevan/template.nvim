local utils = require("task-manager.utils")
local parser = require("task-manager.parser")
local renumber = require("task-manager.renumber")

local M = {}

---Find the line range [start, end] of a feature block.
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

	-- Extend to cover trailing non-fts lines, but NOT blank line separators
	local total = utils.line_count(bufnr)
	for i = last_own + 1, total do
		local line = utils.get_line(bufnr, i)
		local t = parser.parse_line(line)
		if t then
			break
		end
		-- Stop at blank lines (they separate features)
		if line:match("^%s*$") then
			break
		end
		last_own = i
	end

	return feature_lnum, last_own
end

---Find the line range [start, end] of a task block.
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

	-- Extend to trailing non-fts lines, but NOT blank lines
	local total = utils.line_count(bufnr)
	for i = last_own + 1, total do
		local line = utils.get_line(bufnr, i)
		local t = parser.parse_line(line)
		if t then
			break
		end
		-- Stop at blank lines
		if line:match("^%s*$") then
			break
		end
		last_own = i
	end

	return task_lnum, last_own
end

---Find the line range [start, end] of a subtask.
---@param bufnr integer
---@param subtask_lnum integer  line number of the subtask
---@return integer, integer  start_line, end_line
local function get_subtask_range(bufnr, subtask_lnum)
	local token = parser.parse_line(utils.get_line(bufnr, subtask_lnum))
	if not token or token.type ~= "subtask" then
		return subtask_lnum, subtask_lnum
	end

	local last_own = subtask_lnum

	-- Extend to trailing non-fts lines, but NOT blank lines
	local total = utils.line_count(bufnr)
	for i = last_own + 1, total do
		local line = utils.get_line(bufnr, i)
		local t = parser.parse_line(line)
		if t then
			break
		end
		-- Stop at blank lines
		if line:match("^%s*$") then
			break
		end
		last_own = i
	end

	return subtask_lnum, last_own
end

---Sort the entire document by fts numbers.
---Features are sorted by feature number, tasks within each feature by task
---number, and subtasks within each task by subtask number.
---@param bufnr integer
function M.sort_document(bufnr)
	local index = parser.build_index(bufnr)
	if #index == 0 then
		return
	end

	-- Build a hierarchical structure with content
	local features = {}
	local feature_map = {}

	-- First pass: create structure and extract all content upfront
	for _, token in ipairs(index) do
		if token.type == "feature" then
			local feat_start, feat_end = get_feature_range(bufnr, token.lnum)
			local feat = {
				token = token,
				tasks = {},
				start_lnum = feat_start,
				end_lnum = feat_end,
				all_lines = vim.api.nvim_buf_get_lines(bufnr, feat_start - 1, feat_end, false),
			}
			features[#features + 1] = feat
			feature_map[token.fn] = feat
		elseif token.type == "task" then
			local feat = feature_map[token.fn]
			if feat then
				local task_start, task_end = get_task_range(bufnr, token.lnum)
				local task = {
					token = token,
					subtasks = {},
					start_lnum = task_start,
					end_lnum = task_end,
					all_lines = vim.api.nvim_buf_get_lines(bufnr, task_start - 1, task_end, false),
				}
				feat.tasks[#feat.tasks + 1] = task
			end
		elseif token.type == "subtask" then
			local feat = feature_map[token.fn]
			if feat then
				for _, task in ipairs(feat.tasks) do
					if task.token.tn == token.tn then
						local sub_start, sub_end = get_subtask_range(bufnr, token.lnum)
						local subtask = {
							token = token,
							start_lnum = sub_start,
							end_lnum = sub_end,
							all_lines = vim.api.nvim_buf_get_lines(bufnr, sub_start - 1, sub_end, false),
						}
						task.subtasks[#task.subtasks + 1] = subtask
						break
					end
				end
			end
		end
	end

	-- Sort features by feature number
	table.sort(features, function(a, b)
		return a.token.fn < b.token.fn
	end)

	-- Sort tasks within each feature and subtasks within each task
	for _, feat in ipairs(features) do
		table.sort(feat.tasks, function(a, b)
			return a.token.tn < b.token.tn
		end)

		for _, task in ipairs(feat.tasks) do
			table.sort(task.subtasks, function(a, b)
				return a.token.sn < b.token.sn
			end)
		end
	end

	-- Reconstruct the buffer with sorted content
	local new_lines = {}

	-- Preserve content before first feature (find minimum start_lnum)
	if #features > 0 then
		local first_feature_lnum = features[1].start_lnum
		for _, feat in ipairs(features) do
			if feat.start_lnum < first_feature_lnum then
				first_feature_lnum = feat.start_lnum
			end
		end
		if first_feature_lnum > 1 then
			local preamble = vim.api.nvim_buf_get_lines(bufnr, 0, first_feature_lnum - 1, false)
			for _, line in ipairs(preamble) do
				table.insert(new_lines, line)
			end
		end
	end

	for feat_idx, feat in ipairs(features) do
		-- Add feature header (first line of feature)
		table.insert(new_lines, feat.all_lines[1])

		if #feat.tasks > 0 then
			-- Collect all task line numbers that belong to this feature (in original buffer)
			local task_lnums = {}
			for _, task in ipairs(feat.tasks) do
				task_lnums[task.start_lnum] = true
			end

			-- Add non-task lines between feature header and first task
			for i = 2, #feat.all_lines do
				local abs_lnum = feat.start_lnum + i - 1
				if task_lnums[abs_lnum] then
					-- This is where a task starts, stop adding feature lines
					break
				end
				table.insert(new_lines, feat.all_lines[i])
			end

			-- Add sorted tasks
			for _, task in ipairs(feat.tasks) do
				-- Add task line (first line of task)
				table.insert(new_lines, task.all_lines[1])

				if #task.subtasks > 0 then
					-- Collect all subtask line numbers that belong to this task
					local subtask_lnums = {}
					for _, subtask in ipairs(task.subtasks) do
						subtask_lnums[subtask.start_lnum] = true
					end

					-- Add non-subtask lines between task and first subtask
					for i = 2, #task.all_lines do
						local abs_lnum = task.start_lnum + i - 1
						if subtask_lnums[abs_lnum] then
							-- This is where a subtask starts, stop adding task lines
							break
						end
						table.insert(new_lines, task.all_lines[i])
					end

					-- Add sorted subtasks
					for _, subtask in ipairs(task.subtasks) do
						for _, line in ipairs(subtask.all_lines) do
							table.insert(new_lines, line)
						end
					end
				else
					-- No subtasks, add all remaining task lines
					for i = 2, #task.all_lines do
						table.insert(new_lines, task.all_lines[i])
					end
				end
			end
		else
			-- No tasks, add all remaining feature lines
			for i = 2, #feat.all_lines do
				table.insert(new_lines, feat.all_lines[i])
			end
		end

		-- Add blank line separator between features (except after last)
		if feat_idx < #features then
			table.insert(new_lines, "")
		end
	end

	-- Preserve content after last feature
	if #features > 0 then
		local last_feature_end = features[1].end_lnum
		for _, feat in ipairs(features) do
			if feat.end_lnum > last_feature_end then
				last_feature_end = feat.end_lnum
			end
		end
		local total = utils.line_count(bufnr)
		if last_feature_end < total then
			local postamble = vim.api.nvim_buf_get_lines(bufnr, last_feature_end, total, false)
			for _, line in ipairs(postamble) do
				table.insert(new_lines, line)
			end
		end
	end

	-- Replace entire buffer content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)

	-- Run full renumber pass to ensure consistency
	renumber.renumber(bufnr)
end

---Sort the document from the cursor position.
function M.sort_document_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	M.sort_document(bufnr)
end

return M
