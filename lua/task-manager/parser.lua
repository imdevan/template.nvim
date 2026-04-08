local utils = require("task-manager.utils")

local M = {}

---Parse a single line and return its fts token, or nil if not an fts line.
---@param line string
---@return table|nil
-- Returns one of:
--   { type="feature", fn=N }
--   { type="task",    fn=N, tn=M }
--   { type="subtask", fn=N, tn=M, sn=P }
function M.parse_line(line)
  -- subtask: "- [ ] N.M.P " or "- [x] N.M.P "
  local fn, tn, sn = line:match("^%- %[.%] (%d+)%.(%d+)%.(%d+)%f[%s%z]")
  if fn then
    return { type = "subtask", fn = tonumber(fn), tn = tonumber(tn), sn = tonumber(sn) }
  end

  -- task: "- [ ] N.M " or "- [x] N.M "
  fn, tn = line:match("^%- %[.%] (%d+)%.(%d+)%f[%s%z]")
  if fn then
    return { type = "task", fn = tonumber(fn), tn = tonumber(tn) }
  end

  -- feature: "## Feature N:" or "## Feature N " (with anything after)
  fn = line:match("^## Feature (%d+)[:%s]")
  if fn then
    return { type = "feature", fn = tonumber(fn) }
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
