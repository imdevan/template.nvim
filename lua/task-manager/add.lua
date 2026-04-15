local utils    = require("task-manager.utils")
local config   = require("task-manager.config")
local parser   = require("task-manager.parser")
local renumber = require("task-manager.renumber")

local M = {}

---Insert `n` blank lines into `bufnr` immediately after `lnum` (1-indexed).
---@param bufnr integer
---@param lnum  integer
---@param n     integer
local function insert_blank_lines(bufnr, lnum, n)
  if n <= 0 then return end
  vim.api.nvim_buf_set_lines(bufnr, lnum, lnum, false, vim.fn["repeat"]({ "" }, n))
end

---Find the last content line of the feature that contains `lnum`, scanning
---forward until the next feature header (or end of buffer).  Returns the
---1-indexed line number after which the new feature should be inserted.
---@param bufnr integer
---@param lnum  integer  1-indexed reference line (cursor position)
---@return integer  insertion point (new feature goes at this line + 1)
local function find_feature_end(bufnr, lnum)
  local total = utils.line_count(bufnr)
  local last_content = lnum
  for i = lnum + 1, total do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t and t.type == "feature" then
      break
    end
    local text = utils.get_line(bufnr, i)
    if text:match("%S") then
      last_content = i
    end
  end
  return last_content
end

---Insert a new feature header after the end of the current feature block,
---always placing it one blank line after the last task/subtask/note of the
---current feature (determined by scanning forward from `lnum`).
---Features below the insertion point are pushed down and renumbered.
---@param bufnr integer
---@param lnum  integer  1-indexed cursor line (used to locate current feature)
---@param name  string   feature name
function M.add_feature(bufnr, lnum, name)
  local insert_after = find_feature_end(bufnr, lnum)
  local insert_at    = insert_after + 1

  -- Count features strictly above the insertion line to derive the new number.
  local index  = parser.build_index(bufnr)
  local new_fn = config.options.zero_index and 0 or 1
  for _, t in ipairs(index) do
    if t.type == "feature" and t.lnum < insert_at then
      new_fn = t.fn + 1
    end
  end

  local feat_line = utils.format_fts(config.options.tokens.feature, new_fn, nil, nil, name)
  local sep_lines = config.options.feature_line and { "", "---" } or { "" }

  -- Place the new feature after the last content line, always with a separator.
  local next_line = utils.get_line(bufnr, insert_after + 1)
  local prev      = utils.get_line(bufnr, insert_after)
  if not prev:match("%S") and insert_after == 1 then
    -- buffer is effectively empty (starts with blank) → insert at top
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { feat_line })
    insert_at = 1
  elseif prev:match("%S") and not next_line:match("%S") then
    -- content line followed by a blank: replace blank with separator(s) + feature
    local replacement = vim.list_extend(vim.deepcopy(sep_lines), { feat_line })
    vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after + 1, false, replacement)
    insert_at = insert_after + #replacement
  elseif prev:match("%S") then
    -- content line with no blank: insert separator(s) + feature
    local replacement = vim.list_extend(vim.deepcopy(sep_lines), { feat_line })
    vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after, false, replacement)
    insert_at = insert_after + #replacement
  else
    -- already a blank line: insert feature (and --- if feature_line) right after it
    if config.options.feature_line then
      vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after, false, { "---", feat_line })
      insert_at = insert_after + 2
    else
      vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after, false, { feat_line })
      insert_at = insert_after + 1
    end
  end

  -- Increment all feature/task/subtask tokens that were pushed down
  renumber.push_down(bufnr, insert_at, "feature")
  insert_blank_lines(bufnr, insert_at, config.options.spacing.after_feature)
  return insert_at
end

---Prompt for a feature name then insert after the current feature block.
function M.add_feature_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum  = utils.cursor_line()
  vim.ui.input({ prompt = "Feature name: " }, function(name)
    if not name or name == "" then return end
    local insert_at = M.add_feature(bufnr, lnum, name)
    vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, { "" })
    vim.api.nvim_win_set_cursor(0, { insert_at + 1, 0 })
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
  -- Resolve parent feature by scanning upward from the line above the insertion point
  -- (lnum itself is the line that will be pushed down, not the context we belong to)
  local ctx = parser.context_at(bufnr, lnum - 1)
  if not ctx then return false end
  local ref_fn = ctx.fn

  -- Count tasks in this feature strictly above lnum to derive the new task number
  local index  = parser.build_index(bufnr)
  local new_tn = config.options.zero_index and 0 or 1
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
  insert_blank_lines(bufnr, lnum, config.options.spacing.after_task)
  return lnum
end

---Scan forward from `lnum` past subtasks and non-fts notes, stopping before
---the next task, next feature, or end of buffer.
---@param bufnr integer
---@param lnum  integer  1-indexed starting line
---@return integer  line after which the new task should be inserted
local function find_task_insert_point(bufnr, lnum)
  local total = utils.line_count(bufnr)
  local insert_after = lnum
  for i = lnum + 1, total do
    local line = utils.get_line(bufnr, i)
    local t = parser.parse_line(line)
    if t and (t.type == "task" or t.type == "feature") then break end
    if not line:match("%S") then break end  -- stop at blank lines
    insert_after = i
  end
  return insert_after
end

---Prompt for a task name then insert after the last subtask/note of the current task.
---When the cursor is on a blank line, the task replaces that blank line and a new
---blank line is inserted below it.
function M.add_task_cursor()
  local bufnr     = vim.api.nvim_get_current_buf()
  local lnum      = utils.cursor_line()
  local on_blank  = not utils.get_line(bufnr, lnum):match("%S")
  vim.ui.input({ prompt = "Task name: " }, function(name)
    if not name or name == "" then return end
    local target
    if on_blank then
      -- Remove the blank line so add_task inserts at that position
      vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, {})
      target = lnum
    else
      target = find_task_insert_point(bufnr, lnum) + 1
    end
    local insert_at = M.add_task(bufnr, target, name)
    if insert_at then
      -- Ensure a blank line follows the new task (replacing any existing blank or inserting one)
      if on_blank then
        local next = utils.get_line(bufnr, insert_at + 1)
        if not next or next:match("%S") then
          vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, { "" })
        end
      end
      vim.api.nvim_win_set_cursor(0, { insert_at, 0 })
    end
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
  local new_sn = config.options.zero_index and 0 or 1
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
  insert_blank_lines(bufnr, lnum, config.options.spacing.after_subtask)
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
