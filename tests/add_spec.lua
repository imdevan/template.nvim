local add    = require("task-manager.add")
local config = require("task-manager.config")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

describe("add", function()

  describe("add_feature", function()

    it("inserts Feature 1 into an empty buffer", function()
      local buf = make_buf({ "" })
      add.add_feature(buf, 1, "First")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: First", lines[1])
    end)

    it("inserts after the end of the current feature block, not at cursor", function()
      -- cursor is on Feature 1 header; Feature 2 should appear after Feature 1's tasks
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
      })
      add.add_feature(buf, 1, "New")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task one",   lines[2])
      assert.equals("",                      lines[3])
      assert.equals("## Feature 2: New",    lines[4])
      assert.equals("## Feature 3: Beta",   lines[5])
    end)

    it("inserts in the middle with correct numbering", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
        "## Feature 3: Gamma",
      })
      -- cursor on Feature 1; new feature goes after Feature 1's last task
      add.add_feature(buf, 1, "Middle")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task one",   lines[2])
      assert.equals("",                      lines[3])
      assert.equals("## Feature 2: Middle", lines[4])
      assert.equals("## Feature 3: Beta",   lines[5])
      assert.equals("## Feature 4: Gamma",  lines[6])
    end)

    it("appends after the last feature without affecting existing numbers", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
        "",
      })
      -- cursor on Feature 2; no tasks below it, blank line already present
      add.add_feature(buf, 2, "Last")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha", lines[1])
      assert.equals("## Feature 2: Beta",  lines[2])
      assert.equals("",                     lines[3])
      assert.equals("## Feature 3: Last",  lines[4])
    end)

    it("does not hijack tasks belonging to the next feature", function()
      -- cursor on Feature 1 which has no tasks; Feature 2 tasks must stay with Feature 2
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
        "- [ ] 2.1 Task two",
      })
      add.add_feature(buf, 1, "New")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("",                      lines[2])
      assert.equals("## Feature 2: New",    lines[3])
      assert.equals("## Feature 3: Beta",   lines[4])
      assert.equals("- [ ] 3.1 Task two",   lines[5])
    end)

    it("always inserts a blank line separator before the new feature (feature_line=false)", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "## Feature 2: Beta",
      })
      add.add_feature(buf, 1, "New")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",    lines[1])
      assert.equals("- [ ] 1.1 Task one",     lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one",  lines[3])
      assert.equals("",                        lines[4])
      assert.equals("## Feature 2: New",      lines[5])
      assert.equals("## Feature 3: Beta",     lines[6])
    end)

    it("also renumbers tasks and subtasks belonging to pushed-down features", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "  - [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "## Feature 2: Beta",
        "  - [ ] 2.1 Task two",
      })
      -- cursor on Feature 2; new feature goes after Feature 2's last task
      add.add_feature(buf, 4, "New")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",    lines[1])
      assert.equals("  - [ ] 1.1 Task one",   lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one",  lines[3])
      assert.equals("## Feature 2: Beta",     lines[4])
      assert.equals("  - [ ] 2.1 Task two",   lines[5])
      assert.equals("",                        lines[6])
      assert.equals("## Feature 3: New",      lines[7])
    end)

    describe("feature_line=true", function()
      before_each(function() config.setup({ feature_line = true }) end)
      after_each(function()  config.setup({}) end)

      it("inserts blank + --- separator after tasks when feature_line=true", function()
        local buf = make_buf({
          "## Feature 1: Alpha",
          "- [ ] 1.1 Task one",
          "## Feature 2: Beta",
        })
        add.add_feature(buf, 1, "New")
        local lines = get_lines(buf)
        assert.equals("## Feature 1: Alpha", lines[1])
        assert.equals("- [ ] 1.1 Task one",  lines[2])
        assert.equals("",                     lines[3])
        assert.equals("---",                  lines[4])
        assert.equals("## Feature 2: New",   lines[5])
        assert.equals("## Feature 3: Beta",  lines[6])
      end)

      it("inserts blank + --- separator when called from within an empty feature", function()
        local buf = make_buf({
          "## Feature 1: Alpha",
          "## Feature 2: Beta",
          "- [ ] 2.1 Task two",
        })
        add.add_feature(buf, 1, "New")
        local lines = get_lines(buf)
        assert.equals("## Feature 1: Alpha", lines[1])
        assert.equals("",                     lines[2])
        assert.equals("---",                  lines[3])
        assert.equals("## Feature 2: New",   lines[4])
        assert.equals("## Feature 3: Beta",  lines[5])
        assert.equals("- [ ] 3.1 Task two",  lines[6])
      end)

      it("inserts --- when cursor is on blank line after a feature (second taf call)", function()
        -- simulates: taf inserts Feature 1, cursor lands on blank below it, taf again
        local buf = make_buf({
          "## Feature 1: Alpha",
          "",
        })
        add.add_feature(buf, 2, "Beta")
        local lines = get_lines(buf)
        assert.equals("## Feature 1: Alpha", lines[1])
        assert.equals("",                     lines[2])
        assert.equals("---",                  lines[3])
        assert.equals("## Feature 2: Beta",  lines[4])
      end)
    end)

  end)

  describe("add_task", function()

    it("returns false when no parent feature exists", function()
      local buf = make_buf({ "" })
      local ok = add.add_task(buf, 1, "Orphan")
      assert.is_false(ok)
    end)

    it("inserts the first task under a feature", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "",
      })
      add.add_task(buf, 2, "First task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",    lines[1])
      assert.equals("- [ ] 1.1 First task",   lines[2])
      assert.equals("",                        lines[3])
    end)

    it("inserts task at cursor and pushes sibling tasks down", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
      })
      add.add_task(buf, 2, "New task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 New task",   lines[2])
      assert.equals("- [ ] 1.2 Task one",   lines[3])
      assert.equals("- [ ] 1.3 Task two",   lines[4])
    end)

    it("inserts task in the middle with correct numbering", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
        "- [ ] 1.3 Task three",
      })
      add.add_task(buf, 3, "Middle task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",    lines[1])
      assert.equals("- [ ] 1.1 Task one",     lines[2])
      assert.equals("- [ ] 1.2 Middle task",  lines[3])
      assert.equals("- [ ] 1.3 Task two",     lines[4])
      assert.equals("- [ ] 1.4 Task three",   lines[5])
    end)

    it("appends task after last task without shifting others", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
        "",
      })
      add.add_task(buf, 4, "Last task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task one",   lines[2])
      assert.equals("- [ ] 1.2 Task two",   lines[3])
      assert.equals("- [ ] 1.3 Last task",  lines[4])
      assert.equals("",                      lines[5])
    end)

    it("only affects tasks in the parent feature, not tasks in other features", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
        "- [ ] 2.1 Task two",
      })
      add.add_task(buf, 2, "New task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 New task",   lines[2])
      assert.equals("- [ ] 1.2 Task one",   lines[3])
      assert.equals("## Feature 2: Beta",   lines[4])
      assert.equals("- [ ] 2.1 Task two",   lines[5])
    end)

    it("inherits indentation from the previous task", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "  - [ ] 1.1 Task one",
        "  - [ ] 1.2 Task two",
      })
      add.add_task(buf, 3, "Middle task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("  - [ ] 1.1 Task one",     lines[2])
      assert.equals("  - [ ] 1.2 Middle task",  lines[3])
      assert.equals("  - [ ] 1.3 Task two",     lines[4])
    end)

    it("inherits indentation from the feature when no task exists above", function()
      local buf = make_buf({
        "  ## Feature 1: Alpha",
        "",
      })
      add.add_task(buf, 2, "First task")
      local lines = get_lines(buf)
      assert.equals("  ## Feature 1: Alpha",   lines[1])
      assert.equals("  - [ ] 1.1 First task",  lines[2])
    end)

    it("uses task indentation, not subtask indentation, when cursor is on a subtask line", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "  - [ ] 1.1 Task one",
        "    - [ ] 1.1.1 Sub one",
      })
      -- Insert at line 4 (below subtask); nearest task or feature is line 2 (indent "  ")
      add.add_task(buf, 4, "Task two")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("  - [ ] 1.1 Task one",     lines[2])
      assert.equals("    - [ ] 1.1.1 Sub one",  lines[3])
      assert.equals("  - [ ] 1.2 Task two",     lines[4])
    end)

    it("also renumbers subtasks belonging to pushed-down tasks", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "- [ ] 1.2 Task two",
      })
      add.add_task(buf, 2, "New task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",    lines[1])
      assert.equals("- [ ] 1.1 New task",     lines[2])
      assert.equals("- [ ] 1.2 Task one",     lines[3])
      assert.equals("  - [ ] 1.2.1 Sub one",  lines[4])
      assert.equals("- [ ] 1.3 Task two",     lines[5])
    end)

    -- 5.3.4: insert after last subtask of current task (not between task and its subtasks)
    it("inserts after last subtask when cursor is on a task with subtasks", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "  - [ ] 1.1.2 Sub two",
        "- [ ] 1.2 Task two",
      })
      -- cursor on line 2 (task one); new task should go after sub two, not between task and subs
      add.add_task(buf, 5, "New task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("- [ ] 1.1 Task one",       lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one",    lines[3])
      assert.equals("  - [ ] 1.1.2 Sub two",    lines[4])
      assert.equals("- [ ] 1.2 New task",       lines[5])
      assert.equals("- [ ] 1.3 Task two",       lines[6])
    end)

    it("inserts after non-fts notes below the current task", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  some note",
        "- [ ] 1.2 Task two",
      })
      add.add_task(buf, 4, "New task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("- [ ] 1.1 Task one",   lines[2])
      assert.equals("  some note",           lines[3])
      assert.equals("- [ ] 1.2 New task",   lines[4])
      assert.equals("- [ ] 1.3 Task two",   lines[5])
    end)

    it("inserts after subtasks and non-fts notes below the current task", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "  a note",
        "- [ ] 1.2 Task two",
      })
      add.add_task(buf, 5, "New task")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("- [ ] 1.1 Task one",       lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one",    lines[3])
      assert.equals("  a note",                  lines[4])
      assert.equals("- [ ] 1.2 New task",       lines[5])
      assert.equals("- [ ] 1.3 Task two",       lines[6])
    end)

  end)

  describe("add_subtask", function()

    -- Helper: create a buffer with shiftwidth=2 so indent+1 is predictable in tests
    local function make_sw2(lines)
      local buf = make_buf(lines)
      vim.bo[buf].shiftwidth = 2
      return buf
    end

    it("returns false when no parent task exists (only a feature above)", function()
      local buf = make_sw2({ "## Feature 1: Alpha", "" })
      assert.is_false(add.add_subtask(buf, 2, "Orphan"))
    end)

    it("inserts first subtask after a task: task indent + shiftwidth", function()
      local buf = make_sw2({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",   -- indent ""
        "",
      })
      add.add_subtask(buf, 3, "First sub")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",       lines[1])
      assert.equals("- [ ] 1.1 Task one",        lines[2])
      assert.equals("  - [ ] 1.1.1 First sub",   lines[3])  -- "" + 2 spaces
      assert.equals("",                           lines[4])
    end)

    it("inserts subtask before siblings: nearest is a task so indent+sw applied", function()
      local buf = make_sw2({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "  - [ ] 1.1.2 Sub two",
      })
      add.add_subtask(buf, 3, "New sub")  -- line above is task → indent + sw
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("- [ ] 1.1 Task one",       lines[2])
      assert.equals("  - [ ] 1.1.1 New sub",    lines[3])
      assert.equals("  - [ ] 1.1.2 Sub one",    lines[4])
      assert.equals("  - [ ] 1.1.3 Sub two",    lines[5])
    end)

    it("appends subtask after last subtask: keeps previous subtask indent", function()
      local buf = make_sw2({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",   -- indent "  "
        "- [ ] 1.2 Task two",
      })
      add.add_subtask(buf, 4, "Sub two")  -- line above is subtask → same indent
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("- [ ] 1.1 Task one",       lines[2])
      assert.equals("  - [ ] 1.1.1 Sub one",    lines[3])
      assert.equals("  - [ ] 1.1.2 Sub two",    lines[4])
      assert.equals("- [ ] 1.2 Task two",       lines[5])
    end)

    it("only affects subtasks in the parent task, not subtasks in other tasks", function()
      local buf = make_sw2({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "- [ ] 1.2 Task two",
        "  - [ ] 1.2.1 Sub two",
      })
      add.add_subtask(buf, 3, "New sub")  -- above is task → indent + sw
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",      lines[1])
      assert.equals("- [ ] 1.1 Task one",       lines[2])
      assert.equals("  - [ ] 1.1.1 New sub",    lines[3])
      assert.equals("  - [ ] 1.1.2 Sub one",    lines[4])
      assert.equals("- [ ] 1.2 Task two",       lines[5])
      assert.equals("  - [ ] 1.2.1 Sub two",    lines[6])
    end)

    it("keeps previous subtask indent when inserting after a subtask", function()
      local buf = make_sw2({
        "## Feature 1: Alpha",
        "  - [ ] 1.1 Task one",
        "    - [ ] 1.1.1 Sub one",   -- indent "    "
        "",
      })
      add.add_subtask(buf, 4, "Sub two")  -- above is subtask → same indent
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",        lines[1])
      assert.equals("  - [ ] 1.1 Task one",       lines[2])
      assert.equals("    - [ ] 1.1.1 Sub one",    lines[3])
      assert.equals("    - [ ] 1.1.2 Sub two",    lines[4])
    end)

    it("adds task indent + shiftwidth when no subtask exists above", function()
      local buf = make_sw2({
        "## Feature 1: Alpha",
        "  - [ ] 1.1 Task one",   -- indent "  "
        "",
      })
      add.add_subtask(buf, 3, "First sub")  -- above is task → "  " + 2 = "    "
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",        lines[1])
      assert.equals("  - [ ] 1.1 Task one",       lines[2])
      assert.equals("    - [ ] 1.1.1 First sub",  lines[3])
    end)

  end)

  describe("zero_index=true", function()
    before_each(function() config.setup({ zero_index = true }) end)
    after_each(function()  config.setup({}) end)

    it("add_feature: first feature on blank buffer starts at 0", function()
      local buf = make_buf({ "" })
      add.add_feature(buf, 1, "Zero")
      assert.equals("## Feature 0: Zero", get_lines(buf)[1])
    end)

    it("add_feature: second feature gets number 1", function()
      local buf = make_buf({ "## Feature 0: Alpha" })
      add.add_feature(buf, 1, "Beta")
      local lines = get_lines(buf)
      assert.equals("## Feature 0: Alpha", lines[1])
      assert.equals("## Feature 1: Beta",  lines[3])
    end)

    it("add_task: first task in feature starts at 0", function()
      local buf = make_buf({ "## Feature 0: Alpha", "" })
      add.add_task(buf, 2, "Zero task")
      assert.equals("- [ ] 0.0 Zero task", get_lines(buf)[2])
    end)

    it("add_subtask: first subtask in task starts at 0", function()
      local buf = make_buf({ "## Feature 0: Alpha", "- [ ] 0.0 Task", "" })
      vim.bo[buf].shiftwidth = 2
      add.add_subtask(buf, 3, "Zero sub")
      assert.equals("  - [ ] 0.0.0 Zero sub", get_lines(buf)[3])
    end)

  end)

end)
