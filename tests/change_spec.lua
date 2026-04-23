local change = require("task-manager.change")
local config = require("task-manager.config")

describe("change", function()
	local bufnr

	before_each(function()
		config.setup({})
		bufnr = vim.api.nvim_create_buf(false, true)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	-- -----------------------------------------------------------------------
	describe("changeTo_feature", function()
		it("converts a plain line to the first feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "My Feature" })
			change.changeTo_feature(bufnr, 1)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({ "## Feature 1: My Feature" }, lines)
		end)

		it("numbers the new feature after the preceding one", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"New Feature",
			})
			change.changeTo_feature(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"## Feature 2: New Feature",
			}, lines)
		end)

		it("renumbers features below after conversion", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"New Feature",
				"## Feature 2: Second",
			})
			change.changeTo_feature(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"## Feature 2: New Feature",
				"## Feature 3: Second",
			}, lines)
		end)

		it("is a no-op when line is already a feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: Already",
			})
			change.changeTo_feature(bufnr, 1)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({ "## Feature 1: Already" }, lines)
		end)

		it("converts a task line to a feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 My Task",
			})
			change.changeTo_feature(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"## Feature 2: My Task",
			}, lines)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("changeTo_task", function()
		it("converts a plain line to a task under the nearest feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"my task",
			})
			change.changeTo_task(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 my task",
			}, lines)
		end)

		it("numbers the new task after existing tasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Existing",
				"new task",
			})
			change.changeTo_task(bufnr, 3)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Existing",
				"- [ ] 1.2 new task",
			}, lines)
		end)

		it("renumbers tasks below after conversion", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"new task",
				"- [ ] 1.1 Existing",
			})
			change.changeTo_task(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 new task",
				"- [ ] 1.2 Existing",
			}, lines)
		end)

		it("converts a feature to a task of the preceding feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: Parent",
				"## Feature 2: ToConvert",
				"## Feature 3: After",
			})
			change.changeTo_task(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: Parent",
				"- [ ] 1.1 ToConvert",
				"## Feature 2: After",
			}, lines)
		end)

		it("re-parents child tasks as subtasks when converting a feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: Parent",
				"## Feature 2: ToConvert",
				"- [ ] 2.1 Child Task",
				"## Feature 3: After",
			})
			change.changeTo_task(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: Parent",
				"- [ ] 1.1 ToConvert",
				"- [ ] 1.1.1 Child Task",
				"## Feature 2: After",
			}, lines)
		end)

		it("does nothing when converting a feature with no preceding feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: Only",
			})
			change.changeTo_task(bufnr, 1)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({ "## Feature 1: Only" }, lines)
		end)

		it("converts a subtask to a task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.1.1 Subtask",
			})
			change.changeTo_task(bufnr, 3)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.2 Subtask",
			}, lines)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("changeTo_subtask", function()
		it("converts a plain line to a subtask under the nearest task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"my subtask",
			})
			vim.bo[bufnr].shiftwidth = 2
			change.changeTo_subtask(bufnr, 3)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.1.1 my subtask",
			}, lines)
		end)

		it("numbers the new subtask after existing subtasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.1.1 Existing",
				"new subtask",
			})
			change.changeTo_subtask(bufnr, 4)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.1.1 Existing",
				"  - [ ] 1.1.2 new subtask",
			}, lines)
		end)

		it("renumbers subtasks below after conversion", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"new subtask",
				"  - [ ] 1.1.1 Existing",
			})
			vim.bo[bufnr].shiftwidth = 2
			change.changeTo_subtask(bufnr, 3)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.1.1 new subtask",
				"  - [ ] 1.1.2 Existing",
			}, lines)
		end)

		it("does nothing when context is only a feature (no task above)", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"plain line",
			})
			change.changeTo_subtask(bufnr, 2)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"plain line",
			}, lines)
		end)

		it("converts a task to a subtask", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"- [ ] 1.2 ToConvert",
			})
			vim.bo[bufnr].shiftwidth = 2
			change.changeTo_subtask(bufnr, 3)
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task",
				"  - [ ] 1.1.1 ToConvert",
			}, lines)
		end)
	end)
end)
