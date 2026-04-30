local hide   = require("task-manager.hide")
local config = require("task-manager.config")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

-- Convert ranges list to a set of hidden line numbers for easy assertion.
local function hidden_lines(bufnr)
  local ranges = hide._hidden_ranges(bufnr)
  local set = {}
  for _, r in ipairs(ranges) do
    for l = r[1], r[2] do
      set[l] = true
    end
  end
  return set
end

describe("hide", function()
  before_each(function()
    config.setup()
  end)

  describe("hidden_ranges", function()

    it("hides a completed task line", function()
      local buf = make_buf({
        "## Feature 1: Auth",
        "- [x] 1.1 Done task",
        "- [ ] 1.2 Pending task",
      })
      local hidden = hidden_lines(buf)
      assert.is_true(hidden[2])   -- completed task hidden
      assert.is_nil(hidden[3])    -- incomplete task visible
    end)

    it("hides a completed subtask line", function()
      local buf = make_buf({
        "## Feature 1: Auth",
        "- [ ] 1.1 Pending task",
        "  - [x] 1.1.1 Done subtask",
        "  - [ ] 1.1.2 Pending subtask",
      })
      local hidden = hidden_lines(buf)
      assert.is_true(hidden[3])   -- completed subtask hidden
      assert.is_nil(hidden[4])    -- incomplete subtask visible
    end)

    it("hides a feature when all its tasks are complete", function()
      local buf = make_buf({
        "## Feature 1: Done feature",
        "- [x] 1.1 Done task",
        "## Feature 2: Active feature",
        "- [ ] 2.1 Pending task",
      })
      local hidden = hidden_lines(buf)
      assert.is_true(hidden[1])   -- feature 1 hidden (all tasks done)
      assert.is_true(hidden[2])   -- its task hidden
      assert.is_nil(hidden[3])    -- feature 2 visible
      assert.is_nil(hidden[4])    -- its task visible
    end)

    it("does not hide a feature with at least one incomplete task", function()
      local buf = make_buf({
        "## Feature 1: Mixed",
        "- [x] 1.1 Done task",
        "- [ ] 1.2 Pending task",
      })
      local hidden = hidden_lines(buf)
      assert.is_nil(hidden[1])    -- feature visible (has incomplete task)
      assert.is_true(hidden[2])   -- completed task hidden
      assert.is_nil(hidden[3])    -- incomplete task visible
    end)

    it("hides a feature with no tasks", function()
      local buf = make_buf({
        "## Feature 1: Empty",
        "## Feature 2: Active",
        "- [ ] 2.1 Pending task",
      })
      local hidden = hidden_lines(buf)
      assert.is_true(hidden[1])   -- empty feature hidden
      assert.is_nil(hidden[2])    -- active feature visible
    end)

    it("returns empty when nothing is complete", function()
      local buf = make_buf({
        "## Feature 1: Active",
        "- [ ] 1.1 Pending task",
        "  - [ ] 1.1.1 Pending subtask",
      })
      local hidden = hidden_lines(buf)
      assert.is_nil(next(hidden))
    end)

  end)
end)
