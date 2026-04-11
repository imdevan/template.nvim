local M = {}

---Return the content of line n (1-indexed) in the given buffer
---@param bufnr integer
---@param n integer
---@return string
function M.get_line(bufnr, n)
	return vim.api.nvim_buf_get_lines(bufnr, n - 1, n, false)[1] or ""
end

---Set the content of line n (1-indexed) in the given buffer
---@param bufnr integer
---@param n integer
---@param text string
function M.set_line(bufnr, n, text)
	vim.api.nvim_buf_set_lines(bufnr, n - 1, n, false, { text })
end

---Return total line count for the given buffer
---@param bufnr integer
---@return integer
function M.line_count(bufnr)
	return vim.api.nvim_buf_line_count(bufnr)
end

---Return the current cursor line (1-indexed) in the current window
---@return integer
function M.cursor_line()
	return vim.api.nvim_win_get_cursor(0)[1]
end

---Move the cursor to line n (1-indexed) in the current window
---@param n integer
function M.set_cursor_line(n)
	local col = vim.api.nvim_win_get_cursor(0)[2]
	vim.api.nvim_win_set_cursor(0, { n, col })
end

-- ---------------------------------------------------------------------------
-- Template helpers
-- ---------------------------------------------------------------------------

---Compile a token template string into a Lua pattern and an ordered list of
---placeholder names.  Placeholders are `{feature}`, `{task}`, `{subtask}`,
---and `{name}`.  A `[ ]` checkbox in the template matches any character in
---that position (i.e. both unchecked and checked states).
---
---Example:
---  compile_template("- [ ] {feature}.{task} {name}")
---  → "^%- %[.%] (%d+)%.(%d+) (.*)$", {"feature", "task", "name"}
---
---@param  tmpl     string
---@return string   pattern
---@return string[] captures  ordered list of placeholder names
function M.compile_template(tmpl)
	local captures = {}

	-- Replace [ ] before escaping ([ and ] are Lua magic chars)
	local s = tmpl:gsub("%[ %]", "\x01")

	-- Escape remaining Lua magic characters in the literal portions
	s = vim.pesc(s)

	-- Replace {placeholder} tokens (braces are not magic, survive vim.pesc)
	s = s:gsub("{(%w+)}", function(name)
		captures[#captures + 1] = name
		if name == "name" then
			return "(.*)"
		else
			return "(%d+)"
		end
	end)

	-- Restore checkbox sentinel as a pattern that matches any char inside [ ]
	s = s:gsub("\x01", "%%[.%%]")

	return "^%s*" .. s .. "$", captures
end

---Format an fts line from a template, substituting numbers and name.
---Pass `checkbox` (single character, e.g. " " or "x") to override the `[ ]`
---in task/subtask templates; omit for feature templates.
---@param  tmpl      string
---@param  fn        integer  feature number
---@param  tn?       integer  task number
---@param  sn?       integer  subtask number
---@param  name?     string
---@param  checkbox? string   single char to put inside [ ]
---@return string
function M.format_fts(tmpl, fn, tn, sn, name, checkbox)
	local line = tmpl
	line = line:gsub("{feature}", tostring(fn or ""))
	line = line:gsub("{task}", tostring(tn or ""))
	line = line:gsub("{subtask}", tostring(sn or ""))
	line = line:gsub("{name}", name or "")
	if checkbox then
		line = line:gsub("%[ %]", "[" .. checkbox .. "]")
	end
	return line
end

return M
