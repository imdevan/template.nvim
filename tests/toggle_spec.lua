local toggle = require("task-manager.toggle")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_line(bufnr, n)
  return vim.api.nvim_buf_get_lines(bufnr, n - 1, n, false)[1]
end

describe("toggle", function()

  describe("toggle_checkbox", function()

    it("toggles unchecked task to checked", function()
      local buf = make_buf({ "- [ ] 1.1 My task" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("- [x] 1.1 My task", get_line(buf, 1))
    end)

    it("toggles checked task to unchecked", function()
      local buf = make_buf({ "- [x] 1.1 My task" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("- [ ] 1.1 My task", get_line(buf, 1))
    end)

    it("toggles unchecked subtask to checked", function()
      local buf = make_buf({ "- [ ] 1.1.1 A subtask" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("- [x] 1.1.1 A subtask", get_line(buf, 1))
    end)

    it("toggles checked subtask to unchecked", function()
      local buf = make_buf({ "- [x] 1.1.1 A subtask" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("- [ ] 1.1.1 A subtask", get_line(buf, 1))
    end)

    it("does nothing on a feature line", function()
      local buf = make_buf({ "## Feature 1: Something" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("## Feature 1: Something", get_line(buf, 1))
    end)

    it("does nothing on a plain line", function()
      local buf = make_buf({ "just some notes" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("just some notes", get_line(buf, 1))
    end)

    it("does nothing on a blank line", function()
      local buf = make_buf({ "" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("", get_line(buf, 1))
    end)

    it("only toggles the checkbox, not the rest of the line", function()
      local buf = make_buf({ "- [ ] 2.3 Task with [ ] in name" })
      toggle.toggle_checkbox(buf, 1)
      assert.equals("- [x] 2.3 Task with [ ] in name", get_line(buf, 1))
    end)

  end)

end)
