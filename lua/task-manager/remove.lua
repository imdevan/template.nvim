local utils    = require("task-manager.utils")
local parser   = require("task-manager.parser")
local renumber = require("task-manager.renumber")

local M = {}

---Remove the feature at `lnum` along with all its tasks and subtasks, then
---push-up the features below.
---@param bufnr integer
---@param lnum  integer  1-indexed line of the feature header
---@return boolean  false if the line is not a feature
function M.remove_feature(bufnr, lnum)
  local token = parser.parse_line(utils.get_line(bufnr, lnum))
  if not token or token.type ~= "feature" then return false end
  local fn = token.fn

  -- Collect all lines belonging to this feature (header + its tasks/subtasks).
  -- A line belongs to the feature if it has no fts token OR its fts token has
  -- the same fn.  We stop when we hit a different feature.
  local index    = parser.build_index(bufnr)
  local last_own = lnum  -- last line owned by this feature

  for _, t in ipairs(index) do
    if t.lnum <= lnum then goto continue end
    if t.type == "feature" then break end
    if t.fn == fn then last_own = t.lnum end
    ::continue::
  end

  -- Also extend last_own to cover any non-fts lines trailing the last token
  -- (notes lines, blank lines) up to but not including the next feature header.
  local total = utils.line_count(bufnr)
  for i = last_own + 1, total do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t then
      if t.type == "feature" then break end
      -- another fts token belonging to a different feature — stop
      break
    end
    last_own = i
  end

  -- Delete the range [lnum, last_own] (0-indexed end is exclusive)
  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, last_own, false, {})

  -- Push-up: decrement feature numbers for everything that was below
  renumber.push_up(bufnr, lnum - 1, "feature")
  return true
end

---Remove the task at `lnum` along with all its subtasks, then push-up sibling
---tasks within the same feature.
---@param bufnr integer
---@param lnum  integer  1-indexed line of the task
---@return boolean  false if the line is not a task
function M.remove_task(bufnr, lnum)
  local token = parser.parse_line(utils.get_line(bufnr, lnum))
  if not token or token.type ~= "task" then return false end
  local fn = token.fn
  local tn = token.tn

  -- Find the last line owned by this task (its subtasks + trailing non-fts lines)
  local index    = parser.build_index(bufnr)
  local last_own = lnum

  for _, t in ipairs(index) do
    if t.lnum <= lnum then goto continue end
    -- Stop at the next task in the same feature or at any other feature
    if t.type == "feature" or (t.type == "task" and t.fn == fn) then break end
    if t.fn == fn and t.tn == tn then last_own = t.lnum end
    ::continue::
  end

  -- Extend to cover trailing non-fts lines (notes) before the next fts token
  local total = utils.line_count(bufnr)
  for i = last_own + 1, total do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t then break end
    last_own = i
  end

  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, last_own, false, {})

  renumber.push_up(bufnr, lnum - 1, "task", fn)
  return true
end

---Remove the task containing the cursor.
---Works from any line within the task (task line or its subtasks).
function M.remove_task_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx   = parser.context_at(bufnr, utils.cursor_line())
  if not ctx or ctx.type == "feature" then return end

  -- Resolve the task line (cursor may be on a subtask)
  local task_lnum
  local fn = ctx.fn
  local tn = ctx.tn
  for _, t in ipairs(parser.build_index(bufnr)) do
    if t.type == "task" and t.fn == fn and t.tn == tn then
      task_lnum = t.lnum
      break
    end
  end

  if not task_lnum then return end
  M.remove_task(bufnr, task_lnum)
end

---Remove the subtask at `lnum`, then push-up sibling subtasks within the same task.
---@param bufnr integer
---@param lnum  integer  1-indexed line of the subtask
---@return boolean  false if the line is not a subtask
function M.remove_subtask(bufnr, lnum)
  local token = parser.parse_line(utils.get_line(bufnr, lnum))
  if not token or token.type ~= "subtask" then return false end
  local fn = token.fn
  local tn = token.tn

  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, {})

  renumber.push_up(bufnr, lnum - 1, "subtask", fn, tn)
  return true
end

---Remove the subtask under the cursor.
function M.remove_subtask_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx   = parser.context_at(bufnr, utils.cursor_line())
  if not ctx or ctx.type ~= "subtask" then return end
  M.remove_subtask(bufnr, ctx.lnum)
end

---Remove the feature containing the cursor.
---Works from any line within the feature (header, task, or subtask).
function M.remove_feature_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx   = parser.context_at(bufnr, utils.cursor_line())
  if not ctx then return end

  -- If cursor is on a task or subtask, resolve the parent feature header line
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

  if not feature_lnum then return end
  M.remove_feature(bufnr, feature_lnum)
end

return M
