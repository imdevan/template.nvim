local remove = require("task-manager.remove")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- Open a floating window on bufnr, set cursor to lnum, call fn(), then close.
local function with_cursor(bufnr, lnum, fn)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor", row = 0, col = 0, width = 80, height = 24, focusable = true,
  })
  vim.api.nvim_win_set_cursor(win, { lnum, 0 })
  fn()
  vim.api.nvim_win_close(win, true)
end

describe("remove", function()

  describe("remove_feature", function()

    it("returns false when line is not a feature", function()
      local buf = make_buf({ "- [ ] 1.1 Task one" })
      assert.is_false(remove.remove_feature(buf, 1))
    end)

    it("removes a lone feature from the buffer (leaves one empty line)", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
      })
      remove.remove_feature(buf, 1)
      local lines = get_lines(buf)
      assert.equals(1, #lines)
      assert.equals("", lines[1])
    end)

    it("removes a feature and all its tasks and subtasks (leaves one empty line)", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "- [ ] 1.2 Task two",
      })
      remove.remove_feature(buf, 1)
      local lines = get_lines(buf)
      assert.equals(1, #lines)
      assert.equals("", lines[1])
    end)

    it("renumbers the feature below after removal", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
        "## Feature 3: Gamma",
      })
      remove.remove_feature(buf, 1)
      local lines = get_lines(buf)
      assert.equals(2, #lines)
      assert.equals("## Feature 1: Beta",  lines[1])
      assert.equals("## Feature 2: Gamma", lines[2])
    end)

    it("renumbers tasks and subtasks of features below", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
        "- [ ] 2.1 Task one",
        "  - [ ] 2.1.1 Sub one",
        "## Feature 3: Gamma",
        "- [ ] 3.1 Task two",
      })
      remove.remove_feature(buf, 1)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Beta",    lines[1])
      assert.equals("- [ ] 1.1 Task one",    lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one", lines[3])
      assert.equals("## Feature 2: Gamma",   lines[4])
      assert.equals("- [ ] 2.1 Task two",    lines[5])
    end)

    it("removes a middle feature and renumbers correctly", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task A",
        "## Feature 2: Beta",
        "- [ ] 2.1 Task B",
        "## Feature 3: Gamma",
        "- [ ] 3.1 Task C",
      })
      remove.remove_feature(buf, 3)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task A",     lines[2])
      assert.equals("## Feature 2: Gamma",  lines[3])
      assert.equals("- [ ] 2.1 Task C",     lines[4])
    end)

    it("also removes trailing non-fts lines (notes) that belong to the feature", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  notes: something",
        "## Feature 2: Beta",
      })
      remove.remove_feature(buf, 1)
      local lines = get_lines(buf)
      assert.equals(1, #lines)
      assert.equals("## Feature 1: Beta", lines[1])
    end)

  end)

  describe("remove_feature_cursor", function()

    it("removes feature when cursor is on the feature header", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
      })
      with_cursor(buf, 1, function() remove.remove_feature_cursor() end)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Beta", lines[1])
    end)

    it("removes feature when cursor is on a task line within it", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
      })
      with_cursor(buf, 2, function() remove.remove_feature_cursor() end)
      local lines = get_lines(buf)
      assert.equals(1, #lines)
      assert.equals("## Feature 1: Beta", lines[1])
    end)

    it("removes feature when cursor is on a subtask line within it", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "## Feature 2: Beta",
      })
      with_cursor(buf, 3, function() remove.remove_feature_cursor() end)
      local lines = get_lines(buf)
      assert.equals(1, #lines)
      assert.equals("## Feature 1: Beta", lines[1])
    end)

  end)

  describe("remove_task", function()

    it("returns false when line is not a task", function()
      local buf = make_buf({ "## Feature 1: Alpha" })
      assert.is_false(remove.remove_task(buf, 1))
    end)

    it("removes a task with no subtasks", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
      })
      remove.remove_task(buf, 2)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task two",   lines[2])
    end)

    it("removes a task and all its subtasks", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "  - [ ] 1.1.2 Sub two",
        "- [ ] 1.2 Task two",
      })
      remove.remove_task(buf, 2)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task two",   lines[2])
    end)

    it("renumbers sibling tasks after removal", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
        "- [ ] 1.3 Task three",
      })
      remove.remove_task(buf, 2)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",   lines[1])
      assert.equals("- [ ] 1.1 Task two",    lines[2])
      assert.equals("- [ ] 1.2 Task three",  lines[3])
    end)

    it("renumbers subtasks of sibling tasks after removal", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
        "  - [ ] 1.2.1 Sub one",
      })
      remove.remove_task(buf, 2)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",    lines[1])
      assert.equals("- [ ] 1.1 Task two",     lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one",  lines[3])
    end)

    it("only affects tasks in the same feature", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
        "- [ ] 2.1 Task two",
        "- [ ] 2.2 Task three",
      })
      remove.remove_task(buf, 4)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",   lines[1])
      assert.equals("- [ ] 1.1 Task one",    lines[2])
      assert.equals("## Feature 2: Beta",    lines[3])
      assert.equals("- [ ] 2.1 Task three",  lines[4])
    end)

    it("also removes trailing non-fts lines belonging to the task", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  notes: something",
        "- [ ] 1.2 Task two",
      })
      remove.remove_task(buf, 2)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task two",   lines[2])
    end)

  end)

  describe("remove_task_cursor", function()

    it("removes task when cursor is on the task line", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
      })
      with_cursor(buf, 2, function() remove.remove_task_cursor() end)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task two",   lines[2])
    end)

    it("removes parent task when cursor is on a subtask line", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "- [ ] 1.2 Task two",
      })
      with_cursor(buf, 3, function() remove.remove_task_cursor() end)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task two",   lines[2])
    end)

  end)

end)
