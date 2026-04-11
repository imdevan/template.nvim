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

return M
