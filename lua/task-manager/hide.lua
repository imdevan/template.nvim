local utils  = require("task-manager.utils")
local parser = require("task-manager.parser")

local M = {}

-- Track scratch buffers: source_bufnr -> scratch_bufnr
local _scratch = {}

---Collect lines to show: incomplete tasks/subtasks and their parent features.
---Returns lines and a map from scratch line number (1-indexed) to source line number.
---@param bufnr integer
---@return string[], table
local function visible_lines(bufnr)
  local index = parser.build_index(bufnr)

  -- Determine which feature numbers have at least one incomplete task/subtask.
  local feature_needed = {}
  local task_needed    = {}  -- [fn..","..tn] = true

  for _, tok in ipairs(index) do
    if tok.type == "task" then
      local line = utils.get_line(bufnr, tok.lnum)
      if line:match("%[ %]") then
        feature_needed[tok.fn] = true
      end
    elseif tok.type == "subtask" then
      local line = utils.get_line(bufnr, tok.lnum)
      if line:match("%[ %]") then
        feature_needed[tok.fn] = true
        task_needed[tok.fn .. "," .. tok.tn] = true
      end
    end
  end

  local lines    = {}
  local line_map = {}  -- scratch lnum -> source lnum

  for _, tok in ipairs(index) do
    local line = utils.get_line(bufnr, tok.lnum)
    local include = false
    if tok.type == "feature" then
      include = feature_needed[tok.fn]
    elseif tok.type == "task" then
      include = line:match("%[ %]") ~= nil
              or task_needed[tok.fn .. "," .. tok.tn]
    elseif tok.type == "subtask" then
      include = line:match("%[ %]") ~= nil
    end
    if include then
      lines[#lines + 1]    = line
      line_map[#lines]     = tok.lnum
    end
  end

  return lines, line_map
end

---Open a scratch buffer showing only incomplete tasks.
---@param bufnr integer
function M.hide_completed(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local lines, line_map = visible_lines(bufnr)
  local scratch = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
  vim.bo[scratch].filetype   = "markdown"
  vim.bo[scratch].modifiable = false
  vim.bo[scratch].bufhidden  = "wipe"

  _scratch[bufnr] = scratch

  vim.api.nvim_set_current_buf(scratch)

  local function jump()
    local scratch_lnum = vim.api.nvim_win_get_cursor(0)[1]
    local src_lnum     = line_map[scratch_lnum]
    M.show_all(bufnr)
    if src_lnum then
      vim.api.nvim_win_set_cursor(0, { src_lnum, 0 })
    end
  end

  local opts = { buffer = scratch, nowait = true }
  vim.keymap.set("n", "q",     function() M.show_all(bufnr) end, opts)
  vim.keymap.set("n", "<cr>",  jump, opts)
  vim.keymap.set("n", "i",     jump, opts)
  vim.keymap.set("n", "e",     jump, opts)

  vim.notify(string.format("Showing %d incomplete item(s) — <cr>/i/e to jump, q to return", #lines), vim.log.levels.INFO)
end

---Return to the original buffer.
---@param bufnr integer
function M.show_all(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local scratch = _scratch[bufnr]
  _scratch[bufnr] = nil
  vim.api.nvim_set_current_buf(bufnr)
  if scratch and vim.api.nvim_buf_is_valid(scratch) then
    vim.api.nvim_buf_delete(scratch, { force = true })
  end
end

---Toggle the incomplete-only view.
function M.toggle_hide_completed()
  local bufnr = vim.api.nvim_get_current_buf()
  -- If we're currently in a scratch buffer, find the source.
  for src, scr in pairs(_scratch) do
    if scr == bufnr then
      M.show_all(src)
      return
    end
  end
  if _scratch[bufnr] then
    M.show_all(bufnr)
  else
    M.hide_completed(bufnr)
  end
end

-- Exposed for testing.
M._hidden_ranges = function(bufnr)
  local index  = parser.build_index(bufnr)
  local vlines, _ = visible_lines(bufnr)
  local shown  = {}
  for _, l in ipairs(vlines) do shown[l] = true end
  local ranges = {}
  for _, tok in ipairs(index) do
    local line = utils.get_line(bufnr, tok.lnum)
    if not shown[line] then
      ranges[#ranges + 1] = { tok.lnum, tok.lnum }
    end
  end
  return ranges
end

return M
