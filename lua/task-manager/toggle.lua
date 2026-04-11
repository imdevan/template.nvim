local utils  = require("task-manager.utils")
local parser = require("task-manager.parser")

local M = {}

---Toggle the checkbox on line `lnum` of `bufnr`.
---`[ ]` becomes `[x]`; `[x]` becomes `[ ]`.
---Does nothing if the line is not a task or subtask.
---@param bufnr integer
---@param lnum  integer  1-indexed
function M.toggle_checkbox(bufnr, lnum)
  local line  = utils.get_line(bufnr, lnum)
  local token = parser.parse_line(line)
  if not token or (token.type ~= "task" and token.type ~= "subtask") then
    return
  end

  local new_line, replaced = line:gsub("%[ %]", "[x]", 1)
  if replaced == 0 then
    new_line = line:gsub("%[x%]", "[ ]", 1)
  end
  utils.set_line(bufnr, lnum, new_line)
end

---Toggle the checkbox on the current cursor line in the current buffer.
function M.toggle_checkbox_cursor()
  M.toggle_checkbox(0, utils.cursor_line())
end

return M
