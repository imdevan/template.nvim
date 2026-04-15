local renumber = require("task-manager.renumber")
local parser   = require("task-manager.parser")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

describe("renumber", function()

  describe("push_down", function()

    it("increments all feature numbers below insertion line", function()
      local buf = make_buf({
        "## Feature 1: Alpha",   -- line 1  ← new feature inserted here (lnum=1)
        "## Feature 2: Beta",    -- line 2  → should become Feature 3
        "## Feature 3: Gamma",   -- line 3  → should become Feature 4
      })
      renumber.push_down(buf, 1, "feature")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha", lines[1])  -- untouched
      assert.equals("## Feature 3: Beta",  lines[2])
      assert.equals("## Feature 4: Gamma", lines[3])
    end)

    it("increments only tasks within the same feature", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",    -- lnum=2, insertion point → not shifted
        "- [ ] 1.2 Task two",    -- → 1.3
        "- [ ] 1.3 Task three",  -- → 1.4
        "## Feature 2: Beta",
        "- [ ] 2.1 Other task",  -- unaffected
      })
      renumber.push_down(buf, 2, "task", 1)
      local lines = get_lines(buf)
      assert.equals("- [ ] 1.1 Task one",   lines[2])
      assert.equals("- [ ] 1.3 Task two",   lines[3])
      assert.equals("- [ ] 1.4 Task three", lines[4])
      assert.equals("- [ ] 2.1 Other task", lines[6])
    end)

    it("increments only subtasks within the same feature+task", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.1.1 Sub one",   -- insertion point → not shifted
        "- [ ] 1.1.2 Sub two",   -- → 1.1.3
        "- [ ] 1.2 Task two",
        "- [ ] 1.2.1 Other sub", -- unaffected
      })
      renumber.push_down(buf, 3, "subtask", 1, 1)
      local lines = get_lines(buf)
      assert.equals("- [ ] 1.1.1 Sub one",   lines[3])
      assert.equals("- [ ] 1.1.3 Sub two",   lines[4])
      assert.equals("- [ ] 1.2.1 Other sub", lines[6])
    end)

  end)

  describe("push_up", function()

    it("decrements all feature numbers below removal line", function()
      local buf = make_buf({
        "## Feature 2: Beta",   -- line 1 (feature 1 was removed above)
        "## Feature 3: Gamma",  -- → 2
      })
      renumber.push_up(buf, 0, "feature")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Beta",  lines[1])
      assert.equals("## Feature 2: Gamma", lines[2])
    end)

    it("decrements only tasks within the same feature", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.2 Task two",   -- task 1.1 was removed; this becomes 1.1
        "- [ ] 1.3 Task three", -- → 1.2
        "- [ ] 2.1 Other",      -- unaffected
      })
      renumber.push_up(buf, 1, "task", 1)
      local lines = get_lines(buf)
      assert.equals("- [ ] 1.1 Task two",   lines[2])
      assert.equals("- [ ] 1.2 Task three", lines[3])
      assert.equals("- [ ] 2.1 Other",      lines[4])
    end)

    it("decrements only subtasks within the same feature+task", function()
      local buf = make_buf({
        "- [ ] 1.1 Task one",
        "- [ ] 1.1.2 Sub two",   -- sub 1.1.1 was removed → becomes 1.1.1
        "- [ ] 1.1.3 Sub three", -- → 1.1.2
        "- [ ] 1.2.1 Other sub", -- unaffected
      })
      renumber.push_up(buf, 1, "subtask", 1, 1)
      local lines = get_lines(buf)
      assert.equals("- [ ] 1.1.1 Sub two",   lines[2])
      assert.equals("- [ ] 1.1.2 Sub three", lines[3])
      assert.equals("- [ ] 1.2.1 Other sub", lines[4])
    end)

  end)

  describe("renumber (full pass)", function()

    it("resequences features from 1", function()
      local buf = make_buf({
        "## Feature 3: Alpha",
        "## Feature 7: Beta",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha", lines[1])
      assert.equals("## Feature 2: Beta",  lines[2])
    end)

    it("resequences tasks within each feature independently", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.5 Task A",
        "- [ ] 1.9 Task B",
        "## Feature 2: Beta",
        "- [ ] 2.3 Task C",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("- [ ] 1.1 Task A", lines[2])
      assert.equals("- [ ] 1.2 Task B", lines[3])
      assert.equals("- [ ] 2.1 Task C", lines[5])
    end)

    it("resequences subtasks and resets counter per task", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.1.4 Sub A",
        "- [ ] 1.1.7 Sub B",
        "- [ ] 1.2 Task two",
        "- [ ] 1.2.2 Sub C",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("- [ ] 1.1.1 Sub A", lines[3])
      assert.equals("- [ ] 1.1.2 Sub B", lines[4])
      assert.equals("- [ ] 1.2.1 Sub C", lines[6])
    end)

    it("preserves non-fts lines unchanged", function()
      local buf = make_buf({
        "## Feature 2: Alpha",
        "  - notes: some detail",
        "- [ ] 2.1 Task",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("  - notes: some detail", lines[2])
    end)

  end)

  describe("renumber (full pass) zero_index=true", function()
    local config = require("task-manager.config")
    before_each(function() config.setup({ zero_index = true }) end)
    after_each(function()  config.setup({}) end)

    it("resequences features from 0", function()
      local buf = make_buf({
        "## Feature 3: Alpha",
        "## Feature 7: Beta",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("## Feature 0: Alpha", lines[1])
      assert.equals("## Feature 1: Beta",  lines[2])
    end)

    it("resequences tasks from 0 within each feature", function()
      local buf = make_buf({
        "## Feature 0: Alpha",
        "- [ ] 0.5 Task A",
        "- [ ] 0.9 Task B",
        "## Feature 1: Beta",
        "- [ ] 1.3 Task C",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("- [ ] 0.0 Task A", lines[2])
      assert.equals("- [ ] 0.1 Task B", lines[3])
      assert.equals("- [ ] 1.0 Task C", lines[5])
    end)

    it("resequences subtasks from 0 and resets per task", function()
      local buf = make_buf({
        "## Feature 0: Alpha",
        "- [ ] 0.0 Task one",
        "- [ ] 0.0.4 Sub A",
        "- [ ] 0.0.7 Sub B",
        "- [ ] 0.1 Task two",
        "- [ ] 0.1.2 Sub C",
      })
      renumber.renumber(buf)
      local lines = get_lines(buf)
      assert.equals("- [ ] 0.0.0 Sub A", lines[3])
      assert.equals("- [ ] 0.0.1 Sub B", lines[4])
      assert.equals("- [ ] 0.1.0 Sub C", lines[6])
    end)

  end)

end)
