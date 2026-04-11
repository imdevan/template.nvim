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
end)
