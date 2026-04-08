local utils  = require("task-manager.utils")
local parser = require("task-manager.parser")

local M = {}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

---Rewrite the fts token numbers on a single buffer line in-place.
---Only the numeric tokens in the fts prefix are rewritten; text after the
---prefix is preserved verbatim.
---@param bufnr  integer
---@param lnum   integer  1-indexed
---@param token  table    the parsed token for that line
---@param fn     integer  new feature number
---@param tn?    integer  new task number   (task / subtask only)
---@param sn?    integer  new subtask number (subtask only)
local function rewrite(bufnr, lnum, token, fn, tn, sn)
  local line = utils.get_line(bufnr, lnum)

  if token.type == "feature" then
    -- Replace the old feature number, keep everything else
    line = line:gsub("^(## Feature )%d+", "%1" .. fn, 1)

  elseif token.type == "task" then
    -- Replace N.M prefix after "- [.] "
    line = line:gsub("^(%-  ?%[.%] )%d+%.%d+", "%1" .. fn .. "." .. tn, 1)

  elseif token.type == "subtask" then
    -- Replace N.M.P prefix after "- [.] "
    line = line:gsub(
      "^(%-  ?%[.%] )%d+%.%d+%.%d+",
      "%1" .. fn .. "." .. tn .. "." .. sn, 1
    )
  end

  utils.set_line(bufnr, lnum, line)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Push-down: increment numbering of all fts tokens at or below `lnum` that
---are affected by inserting one entry of `insert_type` at `lnum`.
---
---  insert_type = "feature"  → increment fn of every feature/task/subtask below
---  insert_type = "task"     → within the same feature, increment tn (and sn) below
---  insert_type = "subtask"  → within the same feature+task, increment sn below
---
---@param bufnr       integer
---@param lnum        integer  line of the new entry (tokens ON this line are NOT shifted)
---@param insert_type string   "feature" | "task" | "subtask"
---@param ref_fn?     integer  parent feature number (required for task/subtask)
---@param ref_tn?     integer  parent task number    (required for subtask)
function M.push_down(bufnr, lnum, insert_type, ref_fn, ref_tn)
  local index = parser.build_index(bufnr)
  for _, t in ipairs(index) do
    if t.lnum <= lnum then goto continue end

    if insert_type == "feature" then
      rewrite(bufnr, t.lnum, t, t.fn + 1, t.tn, t.sn)

    elseif insert_type == "task" and t.fn == ref_fn then
      if t.type == "task" or t.type == "subtask" then
        rewrite(bufnr, t.lnum, t, t.fn, t.tn + 1, t.sn)
      end

    elseif insert_type == "subtask" and t.fn == ref_fn and t.tn == ref_tn then
      if t.type == "subtask" then
        rewrite(bufnr, t.lnum, t, t.fn, t.tn, t.sn + 1)
      end
    end

    ::continue::
  end
end

---Push-up: decrement numbering of all fts tokens below `lnum` that are
---affected by removing one entry of `remove_type` at `lnum`.
---@param bufnr       integer
---@param lnum        integer  line of the removed entry
---@param remove_type string   "feature" | "task" | "subtask"
---@param ref_fn?     integer
---@param ref_tn?     integer
function M.push_up(bufnr, lnum, remove_type, ref_fn, ref_tn)
  local index = parser.build_index(bufnr)
  for _, t in ipairs(index) do
    if t.lnum <= lnum then goto continue end

    if remove_type == "feature" then
      rewrite(bufnr, t.lnum, t, t.fn - 1, t.tn, t.sn)

    elseif remove_type == "task" and t.fn == ref_fn then
      if t.type == "task" or t.type == "subtask" then
        rewrite(bufnr, t.lnum, t, t.fn, t.tn - 1, t.sn)
      end

    elseif remove_type == "subtask" and t.fn == ref_fn and t.tn == ref_tn then
      if t.type == "subtask" then
        rewrite(bufnr, t.lnum, t, t.fn, t.tn, t.sn - 1)
      end
    end

    ::continue::
  end
end

---Full renumber pass: resequence every fts token in the buffer from scratch.
---Features are numbered 1..N, tasks within each feature 1..M, subtasks 1..P.
---@param bufnr integer
function M.renumber(bufnr)
  local index = parser.build_index(bufnr)

  local feat_seq = 0
  local task_seq = 0
  local sub_seq  = 0
  local cur_fn   = nil
  local cur_tn   = nil

  for _, t in ipairs(index) do
    if t.type == "feature" then
      feat_seq = feat_seq + 1
      task_seq = 0
      sub_seq  = 0
      cur_fn   = feat_seq
      cur_tn   = nil
      rewrite(bufnr, t.lnum, t, cur_fn)

    elseif t.type == "task" then
      task_seq = task_seq + 1
      sub_seq  = 0
      cur_tn   = task_seq
      rewrite(bufnr, t.lnum, t, cur_fn, cur_tn)

    elseif t.type == "subtask" then
      sub_seq = sub_seq + 1
      rewrite(bufnr, t.lnum, t, cur_fn, cur_tn, sub_seq)
    end
  end
end

return M
