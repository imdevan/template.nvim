local navigate = require("task-manager.navigate")
local config   = require("task-manager.config")

describe("navigate", function()
  before_each(function()
    config.setup()
  end)

  describe("goto_target", function()
    it("jumps to a feature by number", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task one",
      })
      
      -- Set buffer in current window before navigation
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_target(bufnr, "2")
      assert.is_true(result)
      
      -- Check cursor moved to feature 2 (line 4)
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(4, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("jumps to a task by feature.task number", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task one",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_target(bufnr, "1.2")
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("jumps to a subtask by feature.task.subtask number", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one",
        "  - [ ] 1.1.2 Subtask two",
        "- [ ] 1.2 Task two",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_target(bufnr, "1.1.2")
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(4, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when target not found", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
      })
      
      local result = navigate.goto_target(bufnr, "99")
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false for invalid target format", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
      })
      
      local result = navigate.goto_target(bufnr, "abc")
      assert.is_false(result)
      
      result = navigate.goto_target(bufnr, "1.2.3.4")
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("distinguishes between different features with same task number", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task one",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_target(bufnr, "2.1")
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(5, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("falls back to parent task when subtask not found", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Try to go to non-existent subtask 1.1.5, should fall back to task 1.1
      local result = navigate.goto_target(bufnr, "1.1.5")
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(2, cursor_line)  -- Should be on task 1.1
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("falls back to parent feature when task not found", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Try to go to non-existent task 2.5, should fall back to feature 2
      local result = navigate.goto_target(bufnr, "2.5")
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(4, cursor_line)  -- Should be on feature 2
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("falls back to feature when subtask and task both not found", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Try to go to non-existent subtask 1.5.3 (task 1.5 also doesn't exist)
      -- Should fall back to feature 1
      local result = navigate.goto_target(bufnr, "1.5.3")
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(1, cursor_line)  -- Should be on feature 1
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when feature does not exist (no fallback possible)", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Try to go to non-existent feature 99
      local result = navigate.goto_target(bufnr, "99")
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when task's parent feature does not exist", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Try to go to task 99.1 (feature 99 doesn't exist)
      local result = navigate.goto_target(bufnr, "99.1")
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("goto_next_incomplete", function()
    it("jumps to the next unchecked task", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [ ] 1.2 Task two (unchecked)",
        "- [ ] 1.3 Task three (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1, should jump to line 3 (first unchecked)
      local result = navigate.goto_next_incomplete(bufnr, 1, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("jumps to the next unchecked subtask", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [x] 1.1.1 Subtask one (checked)",
        "  - [ ] 1.1.2 Subtask two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 2, should jump to line 4 (unchecked subtask)
      local result = navigate.goto_next_incomplete(bufnr, 2, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(4, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("skips feature lines (they don't have checkboxes)", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "## Feature 2: Second",
        "- [ ] 2.1 Task one (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1, should skip feature 2 and jump to task
      local result = navigate.goto_next_incomplete(bufnr, 1, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("wraps around to the beginning when enabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [x] 1.2 Task two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 3 (last line), with wrap should go to line 2
      local result = navigate.goto_next_incomplete(bufnr, 3, true)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(2, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when no incomplete tasks exist", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [x] 1.2 Task two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_next_incomplete(bufnr, 1, true)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not wrap when wrap is disabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [x] 1.2 Task two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 3, without wrap should return false
      local result = navigate.goto_next_incomplete(bufnr, 3, false)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("goto_prev_incomplete", function()
    it("jumps to the previous unchecked task", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [ ] 1.2 Task two (unchecked)",
        "- [x] 1.3 Task three (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 4, should jump to line 3 (previous unchecked)
      local result = navigate.goto_prev_incomplete(bufnr, 4, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("jumps to the previous unchecked subtask", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one (unchecked)",
        "  - [x] 1.1.2 Subtask two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 4, should jump to line 3 (unchecked subtask)
      local result = navigate.goto_prev_incomplete(bufnr, 4, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("wraps around to the end when enabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [ ] 1.2 Task two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1 (first line), with wrap should go to line 3
      local result = navigate.goto_prev_incomplete(bufnr, 1, true)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when no incomplete tasks exist", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [x] 1.2 Task two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_prev_incomplete(bufnr, 3, true)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not wrap when wrap is disabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [ ] 1.2 Task two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1, without wrap should return false
      local result = navigate.goto_prev_incomplete(bufnr, 1, false)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("goto_next_complete", function()
    it("jumps to the next checked task", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [x] 1.2 Task two (checked)",
        "- [x] 1.3 Task three (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1, should jump to line 3 (first checked)
      local result = navigate.goto_next_complete(bufnr, 1, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("jumps to the next checked subtask", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one (unchecked)",
        "  - [x] 1.1.2 Subtask two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 2, should jump to line 4 (checked subtask)
      local result = navigate.goto_next_complete(bufnr, 2, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(4, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("skips feature lines (they don't have checkboxes)", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "## Feature 2: Second",
        "- [x] 2.1 Task one (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1, should skip feature 2 and jump to checked task
      local result = navigate.goto_next_complete(bufnr, 1, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("wraps around to the beginning when enabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [ ] 1.2 Task two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 3 (last line), with wrap should go to line 2
      local result = navigate.goto_next_complete(bufnr, 3, true)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(2, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when no complete tasks exist", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [ ] 1.2 Task two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_next_complete(bufnr, 1, true)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not wrap when wrap is disabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [ ] 1.2 Task two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 3, without wrap should return false
      local result = navigate.goto_next_complete(bufnr, 3, false)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("goto_prev_complete", function()
    it("jumps to the previous checked task", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one (checked)",
        "- [x] 1.2 Task two (checked)",
        "- [ ] 1.3 Task three (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 4, should jump to line 3 (previous checked)
      local result = navigate.goto_prev_complete(bufnr, 4, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("jumps to the previous checked subtask", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [x] 1.1.1 Subtask one (checked)",
        "  - [ ] 1.1.2 Subtask two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 4, should jump to line 3 (checked subtask)
      local result = navigate.goto_prev_complete(bufnr, 4, false)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("wraps around to the end when enabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [x] 1.2 Task two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1 (first line), with wrap should go to line 3
      local result = navigate.goto_prev_complete(bufnr, 1, true)
      assert.is_true(result)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      assert.equals(3, cursor_line)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns false when no complete tasks exist", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [ ] 1.2 Task two (unchecked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      local result = navigate.goto_prev_complete(bufnr, 3, true)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("does not wrap when wrap is disabled", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one (unchecked)",
        "- [x] 1.2 Task two (checked)",
      })
      
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Start from line 1, without wrap should return false
      local result = navigate.goto_prev_complete(bufnr, 1, false)
      assert.is_false(result)
      
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
