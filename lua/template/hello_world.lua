local M = {}

---Insert "hello world" at the cursor location in the current buffer
function M.hello_world()
	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { "hello world" })
end

return M
