local statusline = require("task-manager.statusline")

describe("statusline", function()
	local bufnr

	before_each(function()
		bufnr = vim.api.nvim_create_buf(false, true)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("returns empty string for buffer with no fts content", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "just prose" })
		assert.are.equal("", statusline.summary(bufnr))
	end)

	it("returns total across all features", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: First",
			"- [x] 1.1 Done",
			"- [ ] 1.2 Not done",
			"",
			"## Feature 2: Second",
			"- [x] 2.1 Done",
		})
		assert.are.equal("%#TaskStatuslineIcon#󰄲%* 2/3", statusline.summary(bufnr))
	end)

	it("does not count subtasks", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: Test",
			"- [ ] 1.1 Task",
			"  - [x] 1.1.1 Subtask",
		})
		assert.are.equal("%#TaskStatuslineIcon#󰄲%* 0/1", statusline.summary(bufnr))
	end)
end)
