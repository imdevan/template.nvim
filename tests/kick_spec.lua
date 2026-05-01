local kick   = require("task-manager.kick")
local config = require("task-manager.config")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- Use a temp file for the kicked output so tests don't pollute the filesystem.
local tmp_path

local function setup_tmp()
  tmp_path = os.tmpname() .. ".md"
  -- Remove the file so we start fresh (kicked_path creates it on write)
  os.remove(tmp_path)
  config.setup({ kicked = tmp_path })
end

local function read_kicked()
  local f = io.open(tmp_path, "r")
  if not f then return {} end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  return lines
end

describe("kick", function()
  before_each(function()
    setup_tmp()
  end)

  after_each(function()
    os.remove(tmp_path)
    config.setup()
  end)

  describe("kick feature", function()
    it("copies feature block to kicked file", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
      })
      kick.kick(buf, 1)
      local kicked = read_kicked()
      assert.equals("## Feature 1: Alpha", kicked[1])
      assert.equals("- [ ] 1.1 Task one",  kicked[2])
    end)

    it("removes feature from buffer and renumbers below", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "## Feature 2: Beta",
      })
      kick.kick(buf, 1)
      local lines = get_lines(buf)
      assert.equals("## Feature 1: Beta", lines[1])
    end)

    it("appends to existing kicked file with blank separator", function()
      local buf1 = make_buf({ "## Feature 1: Alpha" })
      kick.kick(buf1, 1)

      local buf2 = make_buf({ "## Feature 1: Beta" })
      kick.kick(buf2, 1)

      local kicked = read_kicked()
      assert.equals("## Feature 1: Alpha", kicked[1])
      assert.equals("",                    kicked[2])
      assert.equals("## Feature 1: Beta",  kicked[3])
    end)
  end)

  describe("kick task", function()
    it("copies task under its feature header in kicked file (feature not present)", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
      })
      kick.kick(buf, 2)
      local kicked = read_kicked()
      assert.equals("## Feature 1: Alpha", kicked[1])
      assert.equals("- [ ] 1.1 Task one",  kicked[2])
    end)

    it("removes task from buffer and renumbers siblings", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
      })
      kick.kick(buf, 2)
      local lines = get_lines(buf)
      -- Task two should now be 1.1
      assert.equals("- [ ] 1.1 Task two", lines[2])
    end)

    it("inserts task under existing feature in kicked file", function()
      -- Pre-populate kicked file with the feature
      local f = io.open(tmp_path, "w")
      f:write("## Feature 1: Alpha\n")
      f:write("- [ ] 1.1 Task one\n")
      f:close()

      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "- [ ] 1.2 Task two",
      })
      kick.kick(buf, 3)  -- kick task two
      local kicked = read_kicked()
      assert.equals("## Feature 1: Alpha", kicked[1])
      assert.equals("- [ ] 1.1 Task one",  kicked[2])
      assert.equals("- [ ] 1.2 Task two",  kicked[3])
    end)
  end)

  describe("kick subtask", function()
    it("copies subtask under its feature header in kicked file", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
      })
      kick.kick(buf, 3)
      local kicked = read_kicked()
      assert.equals("## Feature 1: Alpha",    kicked[1])
      assert.equals("  - [ ] 1.1.1 Sub one",  kicked[2])
    end)

    it("removes subtask from buffer", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 Task one",
        "  - [ ] 1.1.1 Sub one",
        "  - [ ] 1.1.2 Sub two",
      })
      kick.kick(buf, 3)
      local lines = get_lines(buf)
      assert.equals("  - [ ] 1.1.1 Sub two", lines[3])
    end)
  end)

  describe("kicked config", function()
    it("appends .md when no extension given", function()
      config.setup({ kicked = "/tmp/task_kick_test_noext" })
      os.remove("/tmp/task_kick_test_noext.md")
      local buf = make_buf({ "## Feature 1: Alpha" })
      kick.kick(buf, 1)
      local f = io.open("/tmp/task_kick_test_noext.md", "r")
      assert.is_not_nil(f)
      if f then f:close() end
      os.remove("/tmp/task_kick_test_noext.md")
    end)
  end)
end)
