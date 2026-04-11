local move = require("task-manager.move")
local parser = require("task-manager.parser")

describe("move", function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("move_feature_up", function()
    it("swaps feature with the one above", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      local result = move.move_feature_up(bufnr, 4)
      assert.is_true(result)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
      }, lines)
    end)

    it("returns false when feature is already at top", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
      })

      local result = move.move_feature_up(bufnr, 1)
      assert.is_false(result)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
      }, lines)
    end)

    it("handles features with multiple tasks and subtasks", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
        "- [ ] 2.2 Task three",
        "  - [ ] 2.2.1 Subtask two",
      })

      local result = move.move_feature_up(bufnr, 5)
      assert.is_true(result)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "- [ ] 1.2 Task three",
        "  - [ ] 1.2.1 Subtask two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
        "  - [ ] 2.1.1 Subtask one",
      }, lines)
    end)

    it("preserves checkbox states", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [x] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      move.move_feature_up(bufnr, 4)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [x] 2.1 Task one",
      }, lines)
    end)
  end)

  describe("move_feature_down", function()
    it("swaps feature with the one below", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      local result = move.move_feature_down(bufnr, 1)
      assert.is_true(result)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
      }, lines)
    end)

    it("returns false when feature is already at bottom", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      local result = move.move_feature_down(bufnr, 4)
      assert.is_false(result)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      }, lines)
    end)

    it("handles features with multiple tasks and subtasks", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
        "- [ ] 2.2 Task three",
      })

      local result = move.move_feature_down(bufnr, 1)
      assert.is_true(result)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "- [ ] 1.2 Task three",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
        "  - [ ] 2.1.1 Subtask one",
      }, lines)
    end)
  end)

  describe("move_feature_up_cursor", function()
    it("moves feature when cursor is on feature header", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 4, 0 })

      move.move_feature_up_cursor()

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
      }, lines)
    end)

    it("moves feature when cursor is on a task within the feature", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 5, 0 })

      move.move_feature_up_cursor()

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
      }, lines)
    end)
  end)

  describe("move_feature_down_cursor", function()
    it("moves feature when cursor is on feature header", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      move.move_feature_down_cursor()

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
      }, lines)
    end)

    it("moves feature when cursor is on a subtask within the feature", function()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "## Feature 1: First",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Subtask one",
        "",
        "## Feature 2: Second",
        "- [ ] 2.1 Task two",
      })

      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      move.move_feature_down_cursor()

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.same({
        "## Feature 1: Second",
        "- [ ] 1.1 Task two",
        "",
        "## Feature 2: First",
        "- [ ] 2.1 Task one",
        "  - [ ] 2.1.1 Subtask one",
      }, lines)
    end)
  end)
end)
