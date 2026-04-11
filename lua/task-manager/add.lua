local utils    = require("task-manager.utils")
local config   = require("task-manager.config")
local parser   = require("task-manager.parser")
local renumber = require("task-manager.renumber")

local M = {}

---Insert a new feature header at `lnum` in `bufnr`, pushing features below down.
---The new feature number is derived from how many feature tokens already exist
---above `lnum`; features at or below `lnum` are incremented.
---@param bufnr integer
---@param lnum  integer  1-indexed line to insert at (existing line shifts down)
---@param name  string   feature name
function M.add_feature(bufnr, lnum, name)
  -- Count features strictly above the insertion line to derive the new number.
  local index  = parser.build_index(bufnr)
  local new_fn = 1
  for _, t in ipairs(index) do
    if t.type == "feature" and t.lnum < lnum then
      new_fn = t.fn + 1
    end
  end

  local line = utils.format_fts(config.options.tokens.feature, new_fn, nil, nil, name)

  -- Insert before lnum (0-indexed: lnum-1 .. lnum-1 replacement with one line)
  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum - 1, false, { line })

  -- Increment all feature/task/subtask tokens that were pushed down
  renumber.push_down(bufnr, lnum, "feature")
end

---Prompt for a feature name then insert at the current cursor line.
function M.add_feature_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum  = utils.cursor_line()
  vim.ui.input({ prompt = "Feature name: " }, function(name)
    if not name or name == "" then return end
    M.add_feature(bufnr, lnum, name)
  end)
end

---Insert a new task under the feature containing `lnum`, pushing sibling tasks down.
---The new task number is derived from how many tasks already exist in the parent
---feature above `lnum`; tasks at or below `lnum` are incremented.
---@param bufnr integer
---@param lnum  integer  1-indexed line to insert at (existing line shifts down)
---@param name  string   task name
---@return boolean  false if no parent feature could be resolved
function M.add_task(bufnr, lnum, name)
  -- Resolve parent feature by scanning upward from lnum
  local ctx = parser.context_at(bufnr, lnum)
  if not ctx then return false end
  local ref_fn = ctx.fn

  -- Count tasks in this feature strictly above lnum to derive the new task number
  local index  = parser.build_index(bufnr)
  local new_tn = 1
  for _, t in ipairs(index) do
    if t.fn == ref_fn and t.type == "task" and t.lnum < lnum then
      new_tn = t.tn + 1
    end
  end

  -- Inherit indentation from the nearest task or feature above the insertion point
  -- (skipping subtasks, which are indented deeper than a task)
  local indent = ""
  for i = lnum - 1, 1, -1 do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t and (t.type == "task" or t.type == "feature") then
      indent = utils.get_line(bufnr, i):match("^(%s*)") or ""
      break
    end
  end

  local line = indent .. utils.format_fts(config.options.tokens.task, ref_fn, new_tn, nil, name)

  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum - 1, false, { line })

  -- Increment sibling tasks (and their subtasks) at or below the insertion line
  renumber.push_down(bufnr, lnum, "task", ref_fn)
  return true
end

---Prompt for a task name then insert on the line below the cursor.
function M.add_task_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum  = utils.cursor_line()
  vim.ui.input({ prompt = "Task name: " }, function(name)
    if not name or name == "" then return end
    M.add_task(bufnr, lnum + 1, name)
  end)
end

---Insert a new subtask under the task containing `lnum`, pushing sibling subtasks down.
---The new subtask number is derived from how many subtasks already exist in the parent
---task above `lnum`; subtasks at or below `lnum` are incremented.
---@param bufnr integer
---@param lnum  integer  1-indexed line to insert at (existing line shifts down)
---@param name  string   subtask name
---@return boolean  false if no parent task could be resolved
function M.add_subtask(bufnr, lnum, name)
  -- Resolve parent task by scanning upward from the line above the insertion point;
  -- using lnum-1 so a task line at lnum is not mistaken for the parent
  local ctx = lnum > 1 and parser.context_at(bufnr, lnum - 1) or nil
  if not ctx or ctx.type == "feature" then return false end
  local ref_fn = ctx.fn
  local ref_tn = ctx.tn

  -- Count subtasks in this task strictly above lnum to derive the new subtask number
  local index  = parser.build_index(bufnr)
  local new_sn = 1
  for _, t in ipairs(index) do
    if t.fn == ref_fn and t.tn == ref_tn and t.type == "subtask" and t.lnum < lnum then
      new_sn = t.sn + 1
    end
  end

  -- Determine indentation:
  --   after a task    → task indent + one shiftwidth level
  --   after a subtask → keep that subtask's indent unchanged
  local indent = ""
  for i = lnum - 1, 1, -1 do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t and t.type == "subtask" then
      indent = utils.get_line(bufnr, i):match("^(%s*)") or ""
      break
    elseif t and t.type == "task" then
      local sw = vim.bo[bufnr].shiftwidth
      if sw == 0 then sw = vim.bo[bufnr].tabstop end
      if sw == 0 then sw = 2 end
      indent = (utils.get_line(bufnr, i):match("^(%s*)") or "") .. string.rep(" ", sw)
      break
    end
  end

  local line = indent .. utils.format_fts(config.options.tokens.subtask, ref_fn, ref_tn, new_sn, name)

  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum - 1, false, { line })

  -- Increment sibling subtasks at or below the insertion line
  renumber.push_down(bufnr, lnum, "subtask", ref_fn, ref_tn)
  return true
end

---Prompt for a subtask name then insert on the line below the cursor.
function M.add_subtask_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum  = utils.cursor_line()
  vim.ui.input({ prompt = "Subtask name: " }, function(name)
    if not name or name == "" then return end
    M.add_subtask(bufnr, lnum + 1, name)
  end)
end

return M
