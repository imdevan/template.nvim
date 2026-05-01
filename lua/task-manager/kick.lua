local utils  = require("task-manager.utils")
local parser = require("task-manager.parser")
local config = require("task-manager.config")
local remove = require("task-manager.remove")

local M = {}

---Resolve the kicked file path: add .md if no extension present.
---@return string
local function kicked_path()
  local name = config.options.kicked or "kicked"
  if not name:match("%.%w+$") then
    name = name .. ".md"
  end
  -- relative to cwd (project root)
  return name
end

---Read all lines from a file, returning {} if it doesn't exist.
---@param path string
---@return string[]
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  return lines
end

---Write lines to a file (overwrites).
---@param path  string
---@param lines string[]
local function write_file(path, lines)
  local f = assert(io.open(path, "w"))
  for _, line in ipairs(lines) do
    f:write(line .. "\n")
  end
  f:close()
end

---Collect all buffer lines belonging to a feature block (header + tasks/subtasks
---+ trailing non-fts lines), returning them and the last line number.
---@param bufnr integer
---@param lnum  integer  1-indexed feature header line
---@return string[]  lines
---@return integer   last_lnum
local function collect_feature_block(bufnr, lnum)
  local index    = parser.build_index(bufnr)
  local token    = parser.parse_line(utils.get_line(bufnr, lnum))
  local fn       = token.fn
  local last_own = lnum

  for _, t in ipairs(index) do
    if t.lnum <= lnum then goto continue end
    if t.type == "feature" then break end
    if t.fn == fn then last_own = t.lnum end
    ::continue::
  end

  -- extend to trailing non-fts lines
  local total = utils.line_count(bufnr)
  for i = last_own + 1, total do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t then break end
    last_own = i
  end

  local lines = {}
  for i = lnum, last_own do
    lines[#lines + 1] = utils.get_line(bufnr, i)
  end
  return lines, last_own
end

---Collect lines for a task block (task line + subtasks + trailing non-fts).
---@param bufnr integer
---@param lnum  integer  1-indexed task line
---@return string[]  lines
---@return integer   last_lnum
local function collect_task_block(bufnr, lnum)
  local token    = parser.parse_line(utils.get_line(bufnr, lnum))
  local fn       = token.fn
  local tn       = token.tn
  local index    = parser.build_index(bufnr)
  local last_own = lnum

  for _, t in ipairs(index) do
    if t.lnum <= lnum then goto continue end
    if t.type == "feature" or (t.type == "task" and t.fn == fn) then break end
    if t.fn == fn and t.tn == tn then last_own = t.lnum end
    ::continue::
  end

  local total = utils.line_count(bufnr)
  for i = last_own + 1, total do
    local t = parser.parse_line(utils.get_line(bufnr, i))
    if t then break end
    last_own = i
  end

  local lines = {}
  for i = lnum, last_own do
    lines[#lines + 1] = utils.get_line(bufnr, i)
  end
  return lines, last_own
end

---Return the raw feature header line for feature number `fn` in `bufnr`, or nil.
---@param bufnr integer
---@param fn    integer
---@return string|nil
local function feature_header_line(bufnr, fn)
  for _, t in ipairs(parser.build_index(bufnr)) do
    if t.type == "feature" and t.fn == fn then
      return utils.get_line(bufnr, t.lnum)
    end
  end
  return nil
end

---Find the line index (1-based) in `file_lines` where the feature header
---matching `header` appears, or nil.
---@param file_lines string[]
---@param header     string
---@return integer|nil
local function find_feature_in_file(file_lines, header)
  -- Match by feature number extracted from the header
  local token = parser.parse_line(header)
  if not token or token.type ~= "feature" then return nil end
  local fn = token.fn
  for i, line in ipairs(file_lines) do
    local t = parser.parse_line(line)
    if t and t.type == "feature" and t.fn == fn then
      return i
    end
  end
  return nil
end

---Find the last line index (1-based) of a feature block in `file_lines`
---starting at `start_idx`.
---@param file_lines string[]
---@param start_idx  integer
---@return integer
local function feature_block_end_in_file(file_lines, start_idx)
  local last = start_idx
  for i = start_idx + 1, #file_lines do
    local t = parser.parse_line(file_lines[i])
    if t and t.type == "feature" then break end
    last = i
  end
  return last
end

---Append `new_lines` into `file_lines` under the feature block starting at
---`feat_idx`, returning the modified table.
---@param file_lines string[]
---@param feat_idx   integer
---@param new_lines  string[]
---@return string[]
local function insert_under_feature(file_lines, feat_idx, new_lines)
  local end_idx = feature_block_end_in_file(file_lines, feat_idx)
  local result  = {}
  for i = 1, end_idx do result[#result + 1] = file_lines[i] end
  for _, l in ipairs(new_lines) do result[#result + 1] = l end
  for i = end_idx + 1, #file_lines do result[#result + 1] = file_lines[i] end
  return result
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Kick the FTS item at `lnum` in `bufnr`: copy it (and its children) to the
---kicked file, then remove it from the buffer.
---@param bufnr integer
---@param lnum  integer  1-indexed cursor line
function M.kick(bufnr, lnum)
  local token = parser.parse_line(utils.get_line(bufnr, lnum))
  if not token then return end

  -- Resolve to the actual item line (task/subtask: use context_at)
  local item_lnum = lnum
  if token.type == "subtask" then
    item_lnum = lnum
  elseif token.type == "task" then
    item_lnum = lnum
  end

  local path       = kicked_path()
  local file_lines = read_file(path)

  if token.type == "feature" then
    local block = collect_feature_block(bufnr, item_lnum)
    -- Append blank separator + block
    if #file_lines > 0 then file_lines[#file_lines + 1] = "" end
    for _, l in ipairs(block) do file_lines[#file_lines + 1] = l end
    write_file(path, file_lines)
    remove.remove_feature(bufnr, item_lnum)

  elseif token.type == "task" then
    local block, _ = collect_task_block(bufnr, item_lnum)
    local header   = feature_header_line(bufnr, token.fn)
    local feat_idx = header and find_feature_in_file(file_lines, header)
    if feat_idx then
      -- Feature already exists in kicked file: insert task under it
      file_lines = insert_under_feature(file_lines, feat_idx, block)
    else
      -- Append feature header + task block
      if #file_lines > 0 then file_lines[#file_lines + 1] = "" end
      if header then file_lines[#file_lines + 1] = header end
      for _, l in ipairs(block) do file_lines[#file_lines + 1] = l end
    end
    write_file(path, file_lines)
    remove.remove_task(bufnr, item_lnum)

  elseif token.type == "subtask" then
    local subtask_line = utils.get_line(bufnr, item_lnum)
    local header       = feature_header_line(bufnr, token.fn)
    local feat_idx     = header and find_feature_in_file(file_lines, header)
    if feat_idx then
      file_lines = insert_under_feature(file_lines, feat_idx, { subtask_line })
    else
      if #file_lines > 0 then file_lines[#file_lines + 1] = "" end
      if header then file_lines[#file_lines + 1] = header end
      file_lines[#file_lines + 1] = subtask_line
    end
    write_file(path, file_lines)
    remove.remove_subtask(bufnr, item_lnum)
  end
end

---Kick the FTS item under the cursor.
function M.kick_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum  = utils.cursor_line()
  local token = parser.parse_line(utils.get_line(bufnr, lnum))
  if not token then return end

  -- For task/subtask, resolve to the actual item line
  if token.type == "subtask" then
    M.kick(bufnr, lnum)
  elseif token.type == "task" then
    M.kick(bufnr, lnum)
  elseif token.type == "feature" then
    M.kick(bufnr, lnum)
  end
end

return M
