local parser = require("task-manager.parser")
local utils = require("task-manager.utils")

local M = {}

vim.api.nvim_set_hl(0, "TaskStatuslineIcon", { ctermfg = 10, fg = "LightGreen", default = true })

---Return a statusline-friendly completion summary for `bufnr` (defaults to current buffer).
---Example: "Tasks: 3/7"
---Returns "" when the buffer has no fts tasks.
---@param bufnr? integer
---@return string
function M.summary(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local done, total = 0, 0
	for _, token in ipairs(parser.build_index(bufnr)) do
		if token.type == "task" then
			total = total + 1
			if utils.get_line(bufnr, token.lnum):find("%[x%]") then
				done = done + 1
			end
		end
	end
	if total == 0 then return "" end
	return string.format("%%#TaskStatuslineIcon#󰄲%%* %d/%d", done, total)
end

return M
