


local M = {}

---Create a normal mode keymap with description
---@param lhs string Left-hand side of the mapping
---@param cmd string Command to execute
---@param desc string Description for which-key
function M.map(mode, key, cmd, desc)
  local cfg = require("template.config").options
  local prefix = cfg.keymaps.prefix or ""
  local lhs = "<leader>" .. prefix .. key
  vim.keymap.set(mode, lhs, "<cmd>" .. cmd .. "<cr>", { desc = desc })
end

---Return the content of line n (1-indexed) in the given buffer
---@param bufnr integer
---@param n integer
---@return string
function M.get_line(bufnr, n)
  return vim.api.nvim_buf_get_lines(bufnr, n - 1, n, false)[1] or ""
end

---Set the content of line n (1-indexed) in the given buffer
---@param bufnr integer
---@param n integer
---@param text string
function M.set_line(bufnr, n, text)
  vim.api.nvim_buf_set_lines(bufnr, n - 1, n, false, { text })
end

---Return total line count for the given buffer
---@param bufnr integer
---@return integer
function M.line_count(bufnr)
  return vim.api.nvim_buf_line_count(bufnr)
end

---Return the current cursor line (1-indexed) in the current window
---@return integer
function M.cursor_line()
  return vim.api.nvim_win_get_cursor(0)[1]
end

---Move the cursor to line n (1-indexed) in the current window
---@param n integer
function M.set_cursor_line(n)
  local col = vim.api.nvim_win_get_cursor(0)[2]
  vim.api.nvim_win_set_cursor(0, { n, col })
end

return M
