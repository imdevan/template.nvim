local utils  = require("task-manager.utils")
local parser = require("task-manager.parser")

local M = {}

---Parse a navigation target string like "3", "3.2", or "3.2.1"
---@param target string
---@return table|nil  { fn=N } or { fn=N, tn=M } or { fn=N, tn=M, sn=P }
local function parse_target(target)
  local parts = vim.split(target, ".", { plain = true })
  
  if #parts == 1 then
    local fn = tonumber(parts[1])
    if fn then
      return { type = "feature", fn = fn }
    end
  elseif #parts == 2 then
    local fn = tonumber(parts[1])
    local tn = tonumber(parts[2])
    if fn and tn then
      return { type = "task", fn = fn, tn = tn }
    end
  elseif #parts == 3 then
    local fn = tonumber(parts[1])
    local tn = tonumber(parts[2])
    local sn = tonumber(parts[3])
    if fn and tn and sn then
      return { type = "subtask", fn = fn, tn = tn, sn = sn }
    end
  end
  
  return nil
end

---Check if two tokens match (same type and numbers)
---@param token table
---@param target table
---@return boolean
local function tokens_match(token, target)
  if token.type ~= target.type then
    return false
  end
  
  if token.fn ~= target.fn then
    return false
  end
  
  if target.type == "task" or target.type == "subtask" then
    if token.tn ~= target.tn then
      return false
    end
  end
  
  if target.type == "subtask" then
    if token.sn ~= target.sn then
      return false
    end
  end
  
  return true
end

---Go to a specific feature, task, or subtask by number
---If the target is not found, try to fall back to the parent (task -> feature, subtask -> task)
---@param bufnr integer
---@param target string  e.g. "3", "3.2", or "3.2.1"
---@return boolean  true if found and jumped, false otherwise
function M.goto_target(bufnr, target)
  local parsed = parse_target(target)
  if not parsed then
    vim.notify("Invalid target format. Use: # or #.# or #.#.#", vim.log.levels.ERROR)
    return false
  end
  
  local index = parser.build_index(bufnr)
  
  -- Try to find exact match
  for _, token in ipairs(index) do
    if tokens_match(token, parsed) then
      utils.set_cursor_line(token.lnum)
      return true
    end
  end
  
  -- If not found, try fallback to parent
  if parsed.type == "subtask" then
    -- Fallback: subtask -> task
    local task_target = { type = "task", fn = parsed.fn, tn = parsed.tn }
    for _, token in ipairs(index) do
      if tokens_match(token, task_target) then
        utils.set_cursor_line(token.lnum)
        vim.notify(string.format("Subtask %d.%d.%d not found, jumped to task %d.%d", 
          parsed.fn, parsed.tn, parsed.sn, parsed.fn, parsed.tn), vim.log.levels.INFO)
        return true
      end
    end
    -- If task not found either, try feature
    local feature_target = { type = "feature", fn = parsed.fn }
    for _, token in ipairs(index) do
      if tokens_match(token, feature_target) then
        utils.set_cursor_line(token.lnum)
        vim.notify(string.format("Subtask %d.%d.%d and task %d.%d not found, jumped to feature %d", 
          parsed.fn, parsed.tn, parsed.sn, parsed.fn, parsed.tn, parsed.fn), vim.log.levels.INFO)
        return true
      end
    end
  elseif parsed.type == "task" then
    -- Fallback: task -> feature
    local feature_target = { type = "feature", fn = parsed.fn }
    for _, token in ipairs(index) do
      if tokens_match(token, feature_target) then
        utils.set_cursor_line(token.lnum)
        vim.notify(string.format("Task %d.%d not found, jumped to feature %d", 
          parsed.fn, parsed.tn, parsed.fn), vim.log.levels.INFO)
        return true
      end
    end
  end
  
  vim.notify(string.format("Target %s not found", target), vim.log.levels.WARN)
  return false
end

---Prompt user for a target and jump to it
function M.goto_target_prompt()
  vim.ui.input({
    prompt = "Go to (# or #.# or #.#.#): ",
  }, function(input)
    if input and input ~= "" then
      M.goto_target(vim.api.nvim_get_current_buf(), input)
    end
  end)
end

---Check if a line contains an incomplete (unchecked) task or subtask
---@param bufnr integer
---@param lnum integer
---@return boolean
local function is_incomplete(bufnr, lnum)
  local line = utils.get_line(bufnr, lnum)
  local token = parser.parse_line(line)
  
  -- Only tasks and subtasks can be incomplete (features don't have checkboxes)
  if not token or token.type == "feature" then
    return false
  end
  
  -- Check if the line contains [ ] (unchecked)
  return line:match("%[ %]") ~= nil
end

---Check if a line contains a complete (checked) task or subtask
---@param bufnr integer
---@param lnum integer
---@return boolean
local function is_complete(bufnr, lnum)
  local line = utils.get_line(bufnr, lnum)
  local token = parser.parse_line(line)
  
  -- Only tasks and subtasks can be complete (features don't have checkboxes)
  if not token or token.type == "feature" then
    return false
  end
  
  -- Check if the line contains [x] (checked)
  return line:match("%[x%]") ~= nil
end

---Go to the next incomplete (unchecked) task or subtask
---@param bufnr integer
---@param start_line integer  line to start searching from (exclusive)
---@param wrap boolean  whether to wrap around to the beginning
---@return boolean  true if found and jumped, false otherwise
function M.goto_next_incomplete(bufnr, start_line, wrap)
  local total_lines = utils.line_count(bufnr)
  
  -- Search from start_line + 1 to end of buffer
  for lnum = start_line + 1, total_lines do
    if is_incomplete(bufnr, lnum) then
      utils.set_cursor_line(lnum)
      return true
    end
  end
  
  -- If wrap is enabled, search from beginning to start_line
  if wrap then
    for lnum = 1, start_line do
      if is_incomplete(bufnr, lnum) then
        utils.set_cursor_line(lnum)
        return true
      end
    end
  end
  
  return false
end

---Go to the previous incomplete (unchecked) task or subtask
---@param bufnr integer
---@param start_line integer  line to start searching from (exclusive)
---@param wrap boolean  whether to wrap around to the end
---@return boolean  true if found and jumped, false otherwise
function M.goto_prev_incomplete(bufnr, start_line, wrap)
  -- Search from start_line - 1 to beginning of buffer
  for lnum = start_line - 1, 1, -1 do
    if is_incomplete(bufnr, lnum) then
      utils.set_cursor_line(lnum)
      return true
    end
  end
  
  -- If wrap is enabled, search from end to start_line
  if wrap then
    local total_lines = utils.line_count(bufnr)
    for lnum = total_lines, start_line, -1 do
      if is_incomplete(bufnr, lnum) then
        utils.set_cursor_line(lnum)
        return true
      end
    end
  end
  
  return false
end

---Go to the next incomplete entry from the cursor position (with wrapping)
function M.goto_next_incomplete_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.cursor_line()
  
  if not M.goto_next_incomplete(bufnr, cursor_line, true) then
    vim.notify("No incomplete tasks found", vim.log.levels.INFO)
  end
end

---Go to the previous incomplete entry from the cursor position (with wrapping)
function M.goto_prev_incomplete_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.cursor_line()
  
  if not M.goto_prev_incomplete(bufnr, cursor_line, true) then
    vim.notify("No incomplete tasks found", vim.log.levels.INFO)
  end
end

---Go to the next complete (checked) task or subtask
---@param bufnr integer
---@param start_line integer  line to start searching from (exclusive)
---@param wrap boolean  whether to wrap around to the beginning
---@return boolean  true if found and jumped, false otherwise
function M.goto_next_complete(bufnr, start_line, wrap)
  local total_lines = utils.line_count(bufnr)
  
  -- Search from start_line + 1 to end of buffer
  for lnum = start_line + 1, total_lines do
    if is_complete(bufnr, lnum) then
      utils.set_cursor_line(lnum)
      return true
    end
  end
  
  -- If wrap is enabled, search from beginning to start_line
  if wrap then
    for lnum = 1, start_line do
      if is_complete(bufnr, lnum) then
        utils.set_cursor_line(lnum)
        return true
      end
    end
  end
  
  return false
end

---Go to the previous complete (checked) task or subtask
---@param bufnr integer
---@param start_line integer  line to start searching from (exclusive)
---@param wrap boolean  whether to wrap around to the end
---@return boolean  true if found and jumped, false otherwise
function M.goto_prev_complete(bufnr, start_line, wrap)
  -- Search from start_line - 1 to beginning of buffer
  for lnum = start_line - 1, 1, -1 do
    if is_complete(bufnr, lnum) then
      utils.set_cursor_line(lnum)
      return true
    end
  end
  
  -- If wrap is enabled, search from end to start_line
  if wrap then
    local total_lines = utils.line_count(bufnr)
    for lnum = total_lines, start_line, -1 do
      if is_complete(bufnr, lnum) then
        utils.set_cursor_line(lnum)
        return true
      end
    end
  end
  
  return false
end

---Go to the next complete entry from the cursor position (with wrapping)
function M.goto_next_complete_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.cursor_line()
  
  if not M.goto_next_complete(bufnr, cursor_line, true) then
    vim.notify("No complete tasks found", vim.log.levels.INFO)
  end
end

---Go to the previous complete entry from the cursor position (with wrapping)
function M.goto_prev_complete_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = utils.cursor_line()
  
  if not M.goto_prev_complete(bufnr, cursor_line, true) then
    vim.notify("No complete tasks found", vim.log.levels.INFO)
  end
end

return M
