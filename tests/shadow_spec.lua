local shadow = require("task-manager.shadow")

describe("shadow", function()
	local bufnr

	before_each(function()
		bufnr = vim.api.nvim_create_buf(false, true)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	local function get_virt_text(lnum)
		local ns = vim.api.nvim_get_namespaces()["task_manager_shadow"]
		if not ns then return nil end
		local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true })
		if #marks == 0 then return nil end
		local vt = marks[1][4].virt_text
		if not vt or #vt == 0 then return nil end
		return vt[1][1]
	end

	it("shows 0/0 for a feature with no tasks", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: Empty",
		})
		shadow.refresh(bufnr)
		assert.are.equal(" 0/0 tasks complete", get_virt_text(1))
	end)

	it("shows correct count for unchecked tasks", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: Test",
			"- [ ] 1.1 Task one",
			"- [ ] 1.2 Task two",
		})
		shadow.refresh(bufnr)
		assert.are.equal(" 0/2 tasks complete", get_virt_text(1))
	end)

	it("counts checked tasks correctly", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: Test",
			"- [x] 1.1 Done",
			"- [ ] 1.2 Not done",
			"- [x] 1.3 Also done",
		})
		shadow.refresh(bufnr)
		assert.are.equal(" 2/3 tasks complete", get_virt_text(1))
	end)

	it("tracks counts independently per feature", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: First",
			"- [x] 1.1 Done",
			"- [ ] 1.2 Not done",
			"",
			"## Feature 2: Second",
			"- [ ] 2.1 Not done",
		})
		shadow.refresh(bufnr)
		assert.are.equal(" 1/2 tasks complete", get_virt_text(1))
		assert.are.equal(" 0/1 tasks complete", get_virt_text(5))
	end)

	it("does not count subtasks", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"## Feature 1: Test",
			"- [ ] 1.1 Task",
			"  - [x] 1.1.1 Subtask done",
		})
		shadow.refresh(bufnr)
		assert.are.equal(" 0/1 tasks complete", get_virt_text(1))
	end)
end)
