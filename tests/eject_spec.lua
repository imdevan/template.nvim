local eject = require("task-manager.eject")
local parser = require("task-manager.parser")

describe("eject", function()
	local bufnr

	before_each(function()
		bufnr = vim.api.nvim_create_buf(false, true)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	describe("eject_feature", function()
		it("returns false when line is not a feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Plain heading",
			})

			local result = eject.eject_feature(bufnr, 1)
			assert.is_false(result)
		end)

		it("strips feature token leaving plain heading", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
			})

			local result = eject.eject_feature(bufnr, 1)
			assert.is_true(result)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
			}, lines)
		end)

		it("ejects all tasks and subtasks belonging to the feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"- [ ] 1.2 Task two",
			})

			eject.eject_feature(bufnr, 1)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
				"Task one",
				"  Subtask one",
				"Task two",
			}, lines)
		end)

		it("renumbers features below after ejection", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task one",
				"",
				"## Feature 2: Second",
				"- [ ] 2.1 Task two",
			})

			eject.eject_feature(bufnr, 1)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"First",
				"Task one",
				"",
				"## Feature 1: Second",
				"- [ ] 1.1 Task two",
			}, lines)
		end)

		it("does not affect other features' tasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task one",
				"",
				"## Feature 2: Second",
				"- [ ] 2.1 Task two",
			})

			eject.eject_feature(bufnr, 4)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task one",
				"",
				"Second",
				"Task two",
			}, lines)
		end)

		it("preserves indentation", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"  ## Feature 1: Indented Feature",
				"  - [ ] 1.1 Task one",
			})

			eject.eject_feature(bufnr, 1)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"  Indented Feature",
				"  Task one",
			}, lines)
		end)

		it("handles feature with no tasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: Empty Feature",
				"",
				"## Feature 2: Second",
			})

			eject.eject_feature(bufnr, 1)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"Empty Feature",
				"",
				"## Feature 1: Second",
			}, lines)
		end)

		it("preserves checkbox states in ejected tasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [x] 1.1 Task one",
				"- [ ] 1.2 Task two",
			})

			eject.eject_feature(bufnr, 1)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
				"Task one",
				"Task two",
			}, lines)
		end)

		it("handles multiple levels of subtasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"  - [ ] 1.1.2 Subtask two",
				"- [ ] 1.2 Task two",
				"  - [ ] 1.2.1 Subtask three",
			})

			eject.eject_feature(bufnr, 1)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
				"Task one",
				"  Subtask one",
				"  Subtask two",
				"Task two",
				"  Subtask three",
			}, lines)
		end)
	end)

	describe("eject_feature_cursor", function()
		it("ejects feature when cursor is on feature header", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			eject.eject_feature_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
				"Task one",
			}, lines)
		end)

		it("ejects feature when cursor is on a task within the feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"- [ ] 1.2 Task two",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			eject.eject_feature_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
				"Task one",
				"Task two",
			}, lines)
		end)

		it("ejects feature when cursor is on a subtask within the feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 3, 0 })

			eject.eject_feature_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"My Feature",
				"Task one",
				"  Subtask one",
			}, lines)
		end)

		it("does nothing when cursor is on a non-fts line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Plain heading",
				"Some text",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			eject.eject_feature_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Plain heading",
				"Some text",
			}, lines)
		end)
	end)

	describe("eject_task", function()
		it("returns false when line is not a task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
			})

			local result = eject.eject_task(bufnr, 1)
			assert.is_false(result)
		end)

		it("strips task token leaving plain text", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
			})

			local result = eject.eject_task(bufnr, 2)
			assert.is_true(result)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
			}, lines)
		end)

		it("ejects all subtasks belonging to the task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"  - [ ] 1.1.2 Subtask two",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"  Subtask one",
				"  Subtask two",
			}, lines)
		end)

		it("renumbers sibling tasks below after ejection", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"- [ ] 1.2 Task two",
				"- [ ] 1.3 Task three",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"- [ ] 1.1 Task two",
				"- [ ] 1.2 Task three",
			}, lines)
		end)

		it("does not affect tasks in other features", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task one",
				"",
				"## Feature 2: Second",
				"- [ ] 2.1 Task two",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"Task one",
				"",
				"## Feature 2: Second",
				"- [ ] 2.1 Task two",
			}, lines)
		end)

		it("preserves indentation", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"  - [ ] 1.1 Indented task",
				"    - [ ] 1.1.1 Indented subtask",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"  Indented task",
				"    Indented subtask",
			}, lines)
		end)

		it("preserves checkbox states in ejected task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [x] 1.1 Task one",
				"- [ ] 1.2 Task two",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"- [ ] 1.1 Task two",
			}, lines)
		end)

		it("handles task with no subtasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"- [ ] 1.2 Task two",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"- [ ] 1.1 Task two",
			}, lines)
		end)

		it("ejects last task in feature without affecting feature", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
			}, lines)
		end)

		it("renumbers subtasks of sibling tasks after ejection", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"- [ ] 1.2 Task two",
				"  - [ ] 1.2.1 Subtask one",
			})

			eject.eject_task(bufnr, 2)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"- [ ] 1.1 Task two",
				"  - [ ] 1.1.1 Subtask one",
			}, lines)
		end)
	end)

	describe("eject_task_cursor", function()
		it("ejects task when cursor is on task line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"- [ ] 1.2 Task two",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			eject.eject_task_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"- [ ] 1.1 Task two",
			}, lines)
		end)

		it("ejects task when cursor is on a subtask within the task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"- [ ] 1.2 Task two",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 3, 0 })

			eject.eject_task_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Task one",
				"  Subtask one",
				"- [ ] 1.1 Task two",
			}, lines)
		end)

		it("does nothing when cursor is on feature line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			eject.eject_task_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
			}, lines)
		end)

		it("does nothing when cursor is on a non-fts line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"Some text",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			eject.eject_task_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Some text",
			}, lines)
		end)
	end)

	describe("eject_subtask", function()
		it("returns false when line is not a subtask", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
			})

			local result = eject.eject_subtask(bufnr, 2)
			assert.is_false(result)
		end)

		it("strips subtask token leaving plain text", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			})

			local result = eject.eject_subtask(bufnr, 3)
			assert.is_true(result)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  Subtask one",
			}, lines)
		end)

		it("renumbers sibling subtasks below after ejection", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"  - [ ] 1.1.2 Subtask two",
				"  - [ ] 1.1.3 Subtask three",
			})

			eject.eject_subtask(bufnr, 3)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  Subtask one",
				"  - [ ] 1.1.1 Subtask two",
				"  - [ ] 1.1.2 Subtask three",
			}, lines)
		end)

		it("does not affect subtasks in other tasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"- [ ] 1.2 Task two",
				"  - [ ] 1.2.1 Subtask two",
			})

			eject.eject_subtask(bufnr, 3)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  Subtask one",
				"- [ ] 1.2 Task two",
				"  - [ ] 1.2.1 Subtask two",
			}, lines)
		end)

		it("preserves indentation", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"    - [ ] 1.1.1 Indented subtask",
			})

			eject.eject_subtask(bufnr, 3)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"    Indented subtask",
			}, lines)
		end)

		it("preserves checkbox states in ejected subtask", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [x] 1.1.1 Subtask one",
				"  - [ ] 1.1.2 Subtask two",
			})

			eject.eject_subtask(bufnr, 3)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  Subtask one",
				"  - [ ] 1.1.1 Subtask two",
			}, lines)
		end)

		it("ejects last subtask in task without affecting task", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			})

			eject.eject_subtask(bufnr, 3)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  Subtask one",
			}, lines)
		end)

		it("ejects middle subtask and renumbers correctly", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"  - [ ] 1.1.2 Subtask two",
				"  - [ ] 1.1.3 Subtask three",
			})

			eject.eject_subtask(bufnr, 4)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"  Subtask two",
				"  - [ ] 1.1.2 Subtask three",
			}, lines)
		end)

		it("does not affect other features or tasks", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: First",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"",
				"## Feature 2: Second",
				"- [ ] 2.1 Task two",
			})

			eject.eject_subtask(bufnr, 3)

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: First",
				"- [ ] 1.1 Task one",
				"  Subtask one",
				"",
				"## Feature 2: Second",
				"- [ ] 2.1 Task two",
			}, lines)
		end)
	end)

	describe("eject_subtask_cursor", function()
		it("ejects subtask when cursor is on subtask line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
				"  - [ ] 1.1.2 Subtask two",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 3, 0 })

			eject.eject_subtask_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  Subtask one",
				"  - [ ] 1.1.1 Subtask two",
			}, lines)
		end)

		it("does nothing when cursor is on task line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			eject.eject_subtask_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			}, lines)
		end)

		it("does nothing when cursor is on feature line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			eject.eject_subtask_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"- [ ] 1.1 Task one",
				"  - [ ] 1.1.1 Subtask one",
			}, lines)
		end)

		it("does nothing when cursor is on a non-fts line", function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
				"## Feature 1: My Feature",
				"Some text",
			})

			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })

			eject.eject_subtask_cursor()

			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			assert.are.same({
				"## Feature 1: My Feature",
				"Some text",
			}, lines)
		end)
	end)
end)
