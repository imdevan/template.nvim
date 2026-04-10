local utils  = require("task-manager.utils")
local config = require("task-manager.config")

local M = {}

-- Module-level pattern cache keyed by template string.
local _cache = {}

---Return the compiled (pattern, captures) for a template, using a cache.
---@param  tmpl     string
---@return string   pattern
---@return string[] captures
local function get_pattern(tmpl)
  if not _cache[tmpl] then
    local pat, caps = utils.compile_template(tmpl)
    _cache[tmpl] = { pat, caps }
  end
  return _cache[tmpl][1], _cache[tmpl][2]
end

---Try to match `line` against `tmpl`.  Returns a table of captured values
---keyed by placeholder name, or nil on no match.
---@param  line string
---@param  tmpl string
---@return table|nil
local function try_match(line, tmpl)
  local pat, caps = get_pattern(tmpl)
  local matches = { line:match(pat) }
  if matches[1] == nil then return nil end
  local result = {}
  for i, name in ipairs(caps) do
    result[name] = matches[i]
  end
  return result
end

---Parse a single line and return its fts token, or nil if not an fts line.
---@param line string
---@return table|nil
-- Returns one of:
--   { type="feature", fn=N }
--   { type="task",    fn=N, tn=M }
--   { type="subtask", fn=N, tn=M, sn=P }
function M.parse_line(line)
  local tokens = config.options.tokens

  -- subtask first (most specific — shares prefix with task)
  local m = try_match(line, tokens.subtask)
  if m then
    return {
      type = "subtask",
      fn   = tonumber(m.feature),
      tn   = tonumber(m.task),
      sn   = tonumber(m.subtask),
    }
  end

  m = try_match(line, tokens.task)
  if m then
    return {
      type = "task",
      fn   = tonumber(m.feature),
      tn   = tonumber(m.task),
    }
  end

  m = try_match(line, tokens.feature)
  if m then
    return {
      type = "feature",
      fn   = tonumber(m.feature),
    }
  end

  return nil
end

---Scan upward from line n to find the nearest fts token.
---Returns the token table (with its line number added as .lnum), or nil.
---@param bufnr integer
---@param n integer  starting line (1-indexed, inclusive)
---@return table|nil
function M.context_at(bufnr, n)
  for i = n, 1, -1 do
    local token = M.parse_line(utils.get_line(bufnr, i))
    if token then
      token.lnum = i
      return token
    end
  end
  return nil
end

---Build an ordered index of every fts token in the buffer.
---@param bufnr integer
---@return table[]  list of token tables each with a .lnum field
function M.build_index(bufnr)
  local index = {}
  for i = 1, utils.line_count(bufnr) do
    local token = M.parse_line(utils.get_line(bufnr, i))
    if token then
      token.lnum = i
      index[#index + 1] = token
    end
  end
  return index
end

return M
