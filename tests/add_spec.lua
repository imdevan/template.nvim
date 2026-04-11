local add = require("task-manager.add")

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

    it("inserts at line 1 and pushes existing features down", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
      })
      add.add_feature(buf, 1, "New")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: New",   lines[1])
      assert.equals("## Feature 2: Alpha", lines[2])
      assert.equals("## Feature 3: Beta",  lines[3])
    end)

    it("inserts in the middle with correct numbering", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
        "## Feature 3: Gamma",
      })
      add.add_feature(buf, 2, "Middle")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha",  lines[1])
      assert.equals("## Feature 2: Middle", lines[2])
      assert.equals("## Feature 3: Beta",   lines[3])
      assert.equals("## Feature 4: Gamma",  lines[4])
    end)

    it("appends after the last feature without affecting existing numbers", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "## Feature 2: Beta",
        "",
      })
      add.add_feature(buf, 3, "Last")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Alpha", lines[1])
      assert.equals("## Feature 2: Beta",  lines[2])
      assert.equals("## Feature 3: Last",  lines[3])
    end)

    it("also renumbers tasks and subtasks belonging to pushed-down features", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "  - [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "## Feature 2: Beta",
        "  - [ ] 2.1 Task two",
      })
      add.add_feature(buf, 1, "New")
      local lines = get_lines(buf)
      assert.equals("## Feature 1: New",     lines[1])
      assert.equals("## Feature 2: Alpha",   lines[2])
      assert.equals("  - [ ] 2.1 Task one",  lines[3])
      assert.equals("  - [ ] 2.1.1 Sub one", lines[4])
      assert.equals("## Feature 3: Beta",    lines[5])
      assert.equals("  - [ ] 3.1 Task two",  lines[6])
    end)

  end)

end)
