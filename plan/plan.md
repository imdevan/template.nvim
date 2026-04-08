# Context

A Neovim plugin (lazy.nvim compatible) for managing structured plan/task files. The plugin operates on markdown files using a defined fts (feature/task/subtask) token format, providing commands and keymaps to add, remove, move, toggle, and navigate fts entries while keeping all numbering consistent.

# Definitions

**fts** — feature/task/subtask; used when referring to an action that could affect any of the three levels

**feature**
```
## Feature {feature_number}: Feature Name
```

**task**
```
- [ ] {feature_number}.{task_number} Task description
```

**subtask**
```
- [ ] {feature_number}.{task_number}.{subtask_number} Subtask description
```

**pushing down** — when inserting an fts above existing entries:
1. determine current fts by inspecting the current line, then scanning upward for the nearest fts token
2. increment the numbering of all fts entries affected by the insertion

**pushing up** — inverse of pushing down; triggered on removal

**ph keys** — placeholder keymaps (to be defined during Feature 11)

**pc keys** — plugin command keymaps (to be defined during Feature 11)

# v0.1.0

## Feature 1: Plugin scaffolding
  - [ ] 1.1 Initialize lazy.nvim-compatible plugin structure
    - notes: follow lazy.nvim plugin spec; expose `setup(opts)` entry point
    - [ ] 1.1.1 Create directory layout (`lua/task-manager/`, `plugin/`, etc.)
    - [ ] 1.1.2 Write `plugin/task-manager.lua` that calls setup on load
  - [ ] 1.2 Define default config table
    - notes: fts tokens and keymaps should be overridable via `setup(opts)`
    - [ ] 1.2.1 Default feature/task/subtask token patterns
    - [ ] 1.2.2 Default keymap toggle flags (enabled/disabled)
  - [ ] 1.3 Set up utils module
    - notes: shared helpers reused across all features; keep allocations minimal for memory efficiency

## Feature 2: Parsing
  - [ ] 2.1 Implement fts token detection for current line
    - notes: must handle feature headers (`## Feature N:`), task lines (`- [ ] N.M`), and subtask lines (`- [ ] N.M.P`)
    - [ ] 2.1.1 Parse feature line → return `{ type="feature", fn=N }`
    - [ ] 2.1.2 Parse task line → return `{ type="task", fn=N, tn=M }`
    - [ ] 2.1.3 Parse subtask line → return `{ type="subtask", fn=N, tn=M, sn=P }`
  - [ ] 2.2 Implement upward scan to resolve fts context from any line
    - notes: used when cursor is on a non-fts line (e.g., a notes line under a task)
  - [ ] 2.3 Implement full document fts index builder
    - notes: returns ordered list of all fts entries with line numbers; used by sort and renumber operations

## Feature 3: Renumbering engine
  - [ ] 3.1 Implement push-down renumbering
    - notes: given an insertion point and fts type, increment all affected tokens below
  - [ ] 3.2 Implement push-up renumbering
    - notes: given a removal point and fts type, decrement all affected tokens below
  - [ ] 3.3 Implement full renumber pass
    - notes: resequences all fts tokens from scratch; used after sort or bulk edits

## Feature 4: Toggle
  - [ ] 4.1 Toggle task checkbox (`[ ]` ↔ `[x]`)
    - notes: operate on current line; if not a task/subtask line, do nothing
  - [ ] 4.2 Toggle list item (`-` prefix presence)
    - notes: convert plain line to list item and back

## Feature 5: Add fts
  - [ ] 5.1 Add feature
    - notes: inserts new feature header at cursor position and pushes all features below down
    - [ ] 5.1.1 Prompt for feature name
    - [ ] 5.1.2 Insert header and trigger push-down
  - [ ] 5.2 Add task
    - notes: inserts task under the feature containing the cursor; pushes sibling tasks down
    - [ ] 5.2.1 Resolve parent feature from cursor context
    - [ ] 5.2.2 Insert task line and trigger push-down
  - [ ] 5.3 Add subtask
    - notes: inserts subtask under the task containing the cursor; pushes sibling subtasks down
    - [ ] 5.3.1 Resolve parent task from cursor context
    - [ ] 5.3.2 Insert subtask line and trigger push-down

## Feature 6: Remove fts
  - [ ] 6.1 Remove feature
    - notes: deletes feature header and all its tasks/subtasks; pushes features below up
  - [ ] 6.2 Remove task
    - notes: deletes task line and all its subtasks; pushes sibling tasks up
  - [ ] 6.3 Remove subtask
    - notes: deletes subtask line; pushes sibling subtasks up

## Feature 7: Move fts
  - [ ] 7.1 Move feature up/down
    - notes: swap feature block (header + all tasks/subtasks) with adjacent feature; renumber both
  - [ ] 7.2 Move task up/down within its feature
    - notes: swap task block (task + all subtasks) with adjacent task; renumber
  - [ ] 7.3 Move subtask up/down within its task
    - notes: swap subtask line with adjacent subtask; renumber

## Feature 8: Eject fts
  - [ ] 8.1 Eject feature
    - notes: strip the `## Feature N:` token, leaving plain heading text; push features above/below up
  - [ ] 8.2 Eject task
    - notes: strip the `- [ ] N.M` token prefix, leaving plain list item or text
  - [ ] 8.3 Eject subtask
    - notes: strip the `- [ ] N.M.P` token prefix, leaving plain text

## Feature 9: Navigation
  - [ ] 9.1 Go to feature by number
    - notes: jump cursor to the feature header line
  - [ ] 9.2 Go to task by number (N.M)
    - notes: jump cursor to the task line
  - [ ] 9.3 Go to subtask by number (N.M.P)
    - notes: jump cursor to the subtask line
  - [ ] 9.4 Go to next/previous fts entry
    - notes: cycle through fts tokens in document order

## Feature 10: Sort
  - [ ] 10.1 Sort document by fts number
    - notes: reorder all feature blocks, then tasks within each feature, then subtasks within each task; run full renumber pass after
  - [ ] 10.2 Preserve non-fts lines (notes, blank lines) attached to their parent fts entry during sort

## Feature 11: Commands & keymaps
  - [ ] 11.1 Register Neovim user commands (`:TaskToggle`, `:TaskAddFeature`, etc.)
    - notes: one command per logical action; commands call into the appropriate module
  - [ ] 11.2 Define ph keys (placeholder keymap stubs)
  - [ ] 11.3 Define pc keys (plugin command keymaps)
  - [ ] 11.4 Conditionally register keymaps based on config flags
  - [ ] 11.5 Expose keymaps to which-key under `<leader>` group if which-key is available
    - notes: use `pcall` to check for which-key; degrade gracefully if absent

## Feature 12: Shadow text (completion counts)
  - [ ] 12.1 Display virtual text on each feature line showing `X/Y tasks complete`
    - notes: use `nvim_buf_set_extmark` with `virt_text`; update on every buffer change
  - [ ] 12.2 Optional: expose completion summary in statusline via a public API function
