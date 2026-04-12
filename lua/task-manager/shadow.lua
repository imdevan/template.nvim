local parser = require("task-manager.parser")
local utils = require("task-manager.utils")

local M = {}

local ns = vim.api.nvim_create_namespace("task_manager_shadow")

---Recompute and redraw all shadow virtual text for `bufnr`.
---@param bufnr integer
function M.refresh(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	local index = parser.build_index(bufnr)

	-- Count total and complete tasks per feature number
	local totals = {}
	local complete = {}
	for _, token in ipairs(index) do
		if token.type == "task" then
			local fn = token.fn
			totals[fn] = (totals[fn] or 0) + 1
			-- Check if the raw line has [x]
			local line = utils.get_line(bufnr, token.lnum)
			if line:find("%[x%]") then
				complete[fn] = (complete[fn] or 0) + 1
			end
		end
	end

	-- Place virtual text on each feature line
	for _, token in ipairs(index) do
		if token.type == "feature" then
			local fn = token.fn
			local total = totals[fn] or 0
			local done = complete[fn] or 0
			vim.api.nvim_buf_set_extmark(bufnr, ns, token.lnum - 1, 0, {
				virt_text = { { string.format(" %d/%d tasks complete", done, total), "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end
end

---Attach shadow refresh to a buffer via autocmd.
---@param bufnr integer
function M.attach(bufnr)
	local group = vim.api.nvim_create_augroup("task_manager_shadow_" .. bufnr, { clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		group = group,
		callback = function()
			M.refresh(bufnr)
		end,
	})
	M.refresh(bufnr)
end

return M
