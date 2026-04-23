local utils    = require("task-manager.utils")
local config   = require("task-manager.config")
local parser   = require("task-manager.parser")
local renumber = require("task-manager.renumber")

local M = {}

---Extract the plain text from a line, stripping any existing fts token.
---@param bufnr integer
---@param lnum  integer
---@return string
local function extract_name(bufnr, lnum)
  local line  = utils.get_line(bufnr, lnum)
  local token = parser.parse_line(line)
  if not token then
    return line:match("^%s*(.-)%s*$") or ""
  end

  local tokens = config.options.tokens
  local tmpl
  if     token.type == "feature" then tmpl = tokens.feature
  elseif token.type == "task"    then tmpl = tokens.task
  else                                tmpl = tokens.subtask
  end

  local pat, caps = utils.compile_template(tmpl)
  local matches   = { line:match(pat) }
  local named     = {}
  for i, cap_name in ipairs(caps) do named[cap_name] = matches[i] end
  return named.name or ""
end

---Convert the line at `lnum` into a feature token.
---@param bufnr integer
---@param lnum  integer
function M.changeTo_feature(bufnr, lnum)
  local name  = extract_name(bufnr, lnum)
  local token = parser.parse_line(utils.get_line(bufnr, lnum))
  if token and token.type == "feature" then return end

  local index  = parser.build_index(bufnr)
  local new_fn = config.options.zero_index and 0 or 1
  for _, t in ipairs(index) do
    if t.lnum < lnum and t.type == "feature" then
      new_fn = t.fn + 1
    end
  end

  utils.set_line(bufnr, lnum,
    utils.format_fts(config.options.tokens.feature, new_fn, nil, nil, name))
  renumber.push_down(bufnr, lnum, "feature")
end

---Convert the line at `lnum` into a task token under the nearest feature above.
---If the line is a feature, it is converted to a task of the preceding feature
---and its child tasks/subtasks are re-parented as subtasks of the new task.
---@param bufnr integer
---@param lnum  integer
function M.changeTo_task(bufnr, lnum)
  local name  = extract_name(bufnr, lnum)
  local token = parser.parse_line(utils.get_line(bufnr, lnum))

  if token and token.type == "feature" then
    local fn    = token.fn
    local index = parser.build_index(bufnr)

    local parent_fn = nil
    for _, t in ipairs(index) do
      if t.lnum < lnum and t.type == "feature" then parent_fn = t.fn end
    end
    if not parent_fn then return end

    local new_tn = config.options.zero_index and 0 or 1
    for _, t in ipairs(index) do
      if t.lnum < lnum and t.fn == parent_fn and t.type == "task" then
        new_tn = t.tn + 1
      end
    end

    -- Collect children of this feature
    local children = {}
    for _, t in ipairs(index) do
      if t.lnum > lnum and t.fn == fn then children[#children + 1] = t end
    end

    local indent = utils.get_line(bufnr, lnum):match("^(%s*)") or ""
    utils.set_line(bufnr, lnum,
      indent .. utils.format_fts(config.options.tokens.task, parent_fn, new_tn, nil, name))

    renumber.push_down(bufnr, lnum, "task", parent_fn)
    renumber.push_up(bufnr, lnum, "feature")

    -- Re-parent children as subtasks of the new task
    local sub_seq = config.options.zero_index and 0 or 1
    for _, t in ipairs(children) do
      local child_line = utils.get_line(bufnr, t.lnum)
      local tmpl = t.type == "task" and config.options.tokens.task or config.options.tokens.subtask
      local pat, caps = utils.compile_template(tmpl)
      local matches = { child_line:match(pat) }
      local named = {}
      for i, cap_name in ipairs(caps) do named[cap_name] = matches[i] end
      local child_indent = child_line:match("^(%s*)") or ""
      local checkbox = child_line:match("%[(.)]")
      utils.set_line(bufnr, t.lnum,
        child_indent .. utils.format_fts(
          config.options.tokens.subtask, parent_fn, new_tn, sub_seq, named.name or "", checkbox))
      sub_seq = sub_seq + 1
    end

    return
  end

  -- Plain line or subtask → task
  local ctx = parser.context_at(bufnr, lnum)
  if not ctx then return end
  local ref_fn = ctx.fn

  local index  = parser.build_index(bufnr)
  local new_tn = config.options.zero_index and 0 or 1
  for _, t in ipairs(index) do
    if t.lnum < lnum and t.fn == ref_fn and t.type == "task" then
      new_tn = t.tn + 1
    end
  end

  local indent = utils.get_line(bufnr, lnum):match("^(%s*)") or ""
  utils.set_line(bufnr, lnum,
    indent .. utils.format_fts(config.options.tokens.task, ref_fn, new_tn, nil, name))
  renumber.push_down(bufnr, lnum, "task", ref_fn)
end

---Convert the line at `lnum` into a subtask token under the nearest task above.
---@param bufnr integer
---@param lnum  integer
function M.changeTo_subtask(bufnr, lnum)
  local name = extract_name(bufnr, lnum)
  local ctx  = lnum > 1 and parser.context_at(bufnr, lnum - 1) or nil
  if not ctx or ctx.type == "feature" then return end

  local ref_fn = ctx.fn
  local ref_tn = ctx.tn

  local index  = parser.build_index(bufnr)
  local new_sn = config.options.zero_index and 0 or 1
  for _, t in ipairs(index) do
    if t.lnum < lnum and t.fn == ref_fn and t.tn == ref_tn and t.type == "subtask" then
      new_sn = t.sn + 1
    end
  end

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
  utils.set_line(bufnr, lnum,
    indent .. utils.format_fts(config.options.tokens.subtask, ref_fn, ref_tn, new_sn, name))
  renumber.push_down(bufnr, lnum, "subtask", ref_fn, ref_tn)
end

function M.changeTo_feature_cursor()
  M.changeTo_feature(vim.api.nvim_get_current_buf(), utils.cursor_line())
end

function M.changeTo_task_cursor()
  M.changeTo_task(vim.api.nvim_get_current_buf(), utils.cursor_line())
end

function M.changeTo_subtask_cursor()
  M.changeTo_subtask(vim.api.nvim_get_current_buf(), utils.cursor_line())
end

return M
