local parser = require("task-manager.parser")

-- helper: create a scratch buffer pre-populated with lines
local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

describe("parser", function()

  describe("parse_line", function()

    describe("feature lines", function()
      it("parses '## Feature N:' with colon", function()
        local t = parser.parse_line("## Feature 3: Do stuff")
        assert.equals("feature", t.type)
        assert.equals(3, t.fn)
      end)

      it("returns nil for '## Feature N ' without colon (default template requires ':')", function()
        assert.is_nil(parser.parse_line("## Feature 7 Some name"))
      end)

      it("returns nil for a non-feature heading", function()
        assert.is_nil(parser.parse_line("## Something else"))
      end)
    end)

    describe("task lines", function()
      it("parses unchecked task", function()
        local t = parser.parse_line("- [ ] 2.4 My task")
        assert.equals("task", t.type)
        assert.equals(2, t.fn)
        assert.equals(4, t.tn)
      end)

      it("parses checked task", function()
        local t = parser.parse_line("- [x] 1.1 Done task")
        assert.equals("task", t.type)
        assert.equals(1, t.fn)
        assert.equals(1, t.tn)
      end)

      it("returns nil for a plain list item", function()
        assert.is_nil(parser.parse_line("- just a bullet"))
      end)
    end)

    describe("subtask lines", function()
      it("parses unchecked subtask", function()
        local t = parser.parse_line("- [ ] 1.2.3 A subtask")
        assert.equals("subtask", t.type)
        assert.equals(1, t.fn)
        assert.equals(2, t.tn)
        assert.equals(3, t.sn)
      end)

      it("parses checked subtask", function()
        local t = parser.parse_line("- [x] 4.5.6 Done subtask")
        assert.equals("subtask", t.type)
        assert.equals(4, t.fn)
        assert.equals(5, t.tn)
        assert.equals(6, t.sn)
      end)

      it("does not misparse task as subtask", function()
        local t = parser.parse_line("- [ ] 1.2 Not a subtask")
        assert.equals("task", t.type)
      end)
    end)

    it("returns nil for a blank line", function()
      assert.is_nil(parser.parse_line(""))
    end)

    it("returns nil for a prose line", function()
      assert.is_nil(parser.parse_line("some notes here"))
    end)
  end)

  describe("context_at", function()
    it("returns the token on the current line", function()
      local buf = make_buf({
        "## Feature 1: Foo",
        "- [ ] 1.1 Task",
      })
      local t = parser.context_at(buf, 2)
      assert.equals("task", t.type)
      assert.equals(2, t.lnum)
    end)

    it("scans upward past a notes line", function()
      local buf = make_buf({
        "- [ ] 1.1 Task",
        "  - notes: some detail",
        "  - notes: more detail",
      })
      local t = parser.context_at(buf, 3)
      assert.equals("task", t.type)
      assert.equals(1, t.lnum)
    end)

    it("returns nil when no fts token exists above", function()
      local buf = make_buf({
        "# Context",
        "some prose",
      })
      assert.is_nil(parser.context_at(buf, 2))
    end)
  end)

  describe("build_index", function()
    it("returns tokens in document order with correct lnum", function()
      local buf = make_buf({
        "## Feature 1: Alpha",
        "- [ ] 1.1 First task",
        "- [ ] 1.1.1 First subtask",
        "  - notes: ignored",
        "- [ ] 1.2 Second task",
        "## Feature 2: Beta",
      })
      local idx = parser.build_index(buf)
      assert.equals(5, #idx)
      assert.equals("feature", idx[1].type) ; assert.equals(1, idx[1].lnum)
      assert.equals("task",    idx[2].type) ; assert.equals(2, idx[2].lnum)
      assert.equals("subtask", idx[3].type) ; assert.equals(3, idx[3].lnum)
      assert.equals("task",    idx[4].type) ; assert.equals(5, idx[4].lnum)
      assert.equals("feature", idx[5].type) ; assert.equals(6, idx[5].lnum)
    end)

    it("returns empty table for a buffer with no fts tokens", function()
      local buf = make_buf({ "# Context", "just prose" })
      assert.same({}, parser.build_index(buf))
    end)

    it("ignores fts tokens inside fenced code blocks", function()
      local buf = make_buf({
        "## Feature 1: Real",
        "- [ ] 1.1 Real task",
        "```",
        "## Feature 2: Fake",
        "- [ ] 2.1 Fake task",
        "```",
        "- [ ] 1.2 Also real",
      })
      local idx = parser.build_index(buf)
      assert.equals(3, #idx)
      assert.equals("feature", idx[1].type) ; assert.equals(1, idx[1].lnum)
      assert.equals("task",    idx[2].type) ; assert.equals(2, idx[2].lnum)
      assert.equals("task",    idx[3].type) ; assert.equals(7, idx[3].lnum)
    end)
  end)

  describe("context_at (code fence)", function()
    it("skips fts tokens inside fenced code blocks when scanning upward", function()
      local buf = make_buf({
        "## Feature 1: Real",
        "```",
        "## Feature 99: Fake",
        "```",
        "  some note",
      })
      -- scanning from line 5 (a note); nearest real fts above is Feature 1 on line 1
      local t = parser.context_at(buf, 5)
      assert.equals("feature", t.type)
      assert.equals(1, t.fn)
      assert.equals(1, t.lnum)
    end)
  end)

end)
