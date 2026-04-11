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

return M
