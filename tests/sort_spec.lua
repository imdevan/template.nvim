local sort = require("task-manager.sort")
local parser = require("task-manager.parser")
local utils = require("task-manager.utils")

describe("sort", function()
	local bufnr

	before_each(function()
		bufnr = vim.api.nvim_create_buf(false, true)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("sorts features by feature number", function()
		local lines = {
			"## Feature 3: Third",
			"- [ ] 3.1 Task",
			"",
			"## Feature 1: First",
			"- [ ] 1.1 Task",
			"",
			"## Feature 2: Second",
			"- [ ] 2.1 Task",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: First",
			"- [ ] 1.1 Task",
			"## Feature 2: Second",
			"- [ ] 2.1 Task",
			"## Feature 3: Third",
			"- [ ] 3.1 Task",
		}, result)
	end)

	it("sorts tasks within features", function()
		local lines = {
			"## Feature 1: Test",
			"- [ ] 1.3 Third task",
			"- [ ] 1.1 First task",
			"- [ ] 1.2 Second task",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: Test",
			"- [ ] 1.1 First task",
			"- [ ] 1.2 Second task",
			"- [ ] 1.3 Third task",
		}, result)
	end)

	it("sorts subtasks within tasks", function()
		local lines = {
			"## Feature 1: Test",
			"- [ ] 1.1 Task",
			"  - [ ] 1.1.3 Third subtask",
			"  - [ ] 1.1.1 First subtask",
			"  - [ ] 1.1.2 Second subtask",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: Test",
			"- [ ] 1.1 Task",
			"  - [ ] 1.1.1 First subtask",
			"  - [ ] 1.1.2 Second subtask",
			"  - [ ] 1.1.3 Third subtask",
		}, result)
	end)

	it("preserves non-fts lines attached to features", function()
		local lines = {
			"## Feature 2: Second",
			"  notes: feature 2 notes",
			"- [ ] 2.1 Task",
			"",
			"## Feature 1: First",
			"  notes: feature 1 notes",
			"- [ ] 1.1 Task",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: First",
			"  notes: feature 1 notes",
			"- [ ] 1.1 Task",
			"## Feature 2: Second",
			"  notes: feature 2 notes",
			"- [ ] 2.1 Task",
		}, result)
	end)

	it("preserves non-fts lines attached to tasks", function()
		local lines = {
			"## Feature 1: Test",
			"- [ ] 1.2 Second task",
			"  notes: task 2 notes",
			"- [ ] 1.1 First task",
			"  notes: task 1 notes",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: Test",
			"- [ ] 1.1 First task",
			"  notes: task 1 notes",
			"- [ ] 1.2 Second task",
			"  notes: task 2 notes",
		}, result)
	end)

	it("preserves non-fts lines attached to subtasks", function()
		local lines = {
			"## Feature 1: Test",
			"- [ ] 1.1 Task",
			"  - [ ] 1.1.2 Second subtask",
			"    notes: subtask 2 notes",
			"  - [ ] 1.1.1 First subtask",
			"    notes: subtask 1 notes",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: Test",
			"- [ ] 1.1 Task",
			"  - [ ] 1.1.1 First subtask",
			"    notes: subtask 1 notes",
			"  - [ ] 1.1.2 Second subtask",
			"    notes: subtask 2 notes",
		}, result)
	end)

	it("sorts complex nested structure", function()
		local lines = {
			"## Feature 2: Second",
			"- [ ] 2.2 Task B",
			"  - [ ] 2.2.2 Subtask B2",
			"  - [ ] 2.2.1 Subtask B1",
			"- [ ] 2.1 Task A",
			"  - [ ] 2.1.2 Subtask A2",
			"  - [ ] 2.1.1 Subtask A1",
			"",
			"## Feature 1: First",
			"- [ ] 1.2 Task B",
			"- [ ] 1.1 Task A",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: First",
			"- [ ] 1.1 Task A",
			"- [ ] 1.2 Task B",
			"## Feature 2: Second",
			"- [ ] 2.1 Task A",
			"  - [ ] 2.1.1 Subtask A1",
			"  - [ ] 2.1.2 Subtask A2",
			"- [ ] 2.2 Task B",
			"  - [ ] 2.2.1 Subtask B1",
			"  - [ ] 2.2.2 Subtask B2",
		}, result)
	end)

	it("handles empty buffer", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
		sort.sort_document(bufnr)
		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "" }, result)
	end)

	it("preserves content before first feature", function()
		local lines = {
			"# Context",
			"",
			"This is preamble content.",
			"",
			"## Feature 2: Second",
			"- [ ] 2.1 Task",
			"",
			"## Feature 1: First",
			"- [ ] 1.1 Task",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"# Context",
			"",
			"This is preamble content.",
			"",
			"## Feature 1: First",
			"- [ ] 1.1 Task",
			"## Feature 2: Second",
			"- [ ] 2.1 Task",
		}, result)
	end)

	it("preserves content after last feature", function()
		local lines = {
			"## Feature 2: Second",
			"- [ ] 2.1 Task",
			"",
			"## Feature 1: First",
			"- [ ] 1.1 Task",
			"",
			"## Appendix",
			"Some trailing content.",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: First",
			"- [ ] 1.1 Task",
			"## Feature 2: Second",
			"- [ ] 2.1 Task",
			"",
			"## Appendix",
			"Some trailing content.",
		}, result)
	end)

	it("preserves checkbox state during sort", function()
		local lines = {
			"## Feature 1: Test",
			"- [x] 1.2 Completed task",
			"- [ ] 1.1 Incomplete task",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		sort.sort_document(bufnr)

		local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({
			"## Feature 1: Test",
			"- [ ] 1.1 Incomplete task",
			"- [x] 1.2 Completed task",
		}, result)
	end)
end)
