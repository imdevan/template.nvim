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
  - [x] 1.1 Initialize lazy.nvim-compatible plugin structure
    - notes: follow lazy.nvim plugin spec; expose `setup(opts)` entry point
    - [x] 1.1.1 Create directory layout (`lua/task-manager/`, `plugin/`, etc.)
    - [x] 1.1.2 Write `plugin/task-manager.lua` that calls setup on load
  - [x] 1.2 Define default config table
    - notes: fts tokens and keymaps should be overridable via `setup(opts)`
    - [x] 1.2.1 Default feature/task/subtask token patterns
    - [x] 1.2.2 Default keymap toggle flags (enabled/disabled)
  - [x] 1.3 Set up utils module
    - notes: shared helpers reused across all features; keep allocations minimal for memory efficiency
  - [x] 1.4 Create just install script that will install the plugin into my local nvim config

## Feature 2: Parsing
  - [x] 2.1 Implement fts token detection for current line
    - notes: must handle feature headers (`## Feature N:`), task lines (`- [ ] N.M`), and subtask lines (`- [ ] N.M.P`)
    - [x] 2.1.1 Parse feature line → return `{ type="feature", fn=N }`
    - [x] 2.1.2 Parse task line → return `{ type="task", fn=N, tn=M }`
    - [x] 2.1.3 Parse subtask line → return `{ type="subtask", fn=N, tn=M, sn=P }`
    - [x] 2.1.4 fts token detection should include the number. see the following sudo code example
      - use whatever template formatting is recommended with lua
```
feature = "## Feature {feature}: {name}",
task    = "- [ ] {feature}.{task} {name}",
subtask = "- [ ] {feature}.{task}.{subtask} {name}",
```
this would allow the user to use different naming conventions such as
```
feature = "# Feature {feature}",
task    = "- [ ] {feature}.{task}) {name}",
subtask = "- [ ] {feature}.{task}.{subtask}) {name}",
```
  - [x] 2.2 Implement upward scan to resolve fts context from any line
    - notes: used when cursor is on a non-fts line (e.g., a notes line under a task)
  - [x] 2.3 Implement full document fts index builder
    - notes: returns ordered list of all fts entries with line numbers; used by sort and renumber operations
    - [ ] 2.4 config options for line after feature; line after task; and line after subtask

## Feature 3: Renumbering engine
  - [x] 3.1 Implement push-down renumbering
    - notes: given an insertion point and fts type, increment all affected tokens below
  - [x] 3.2 Implement push-up renumbering
    - notes: given a removal point and fts type, decrement all affected tokens below
  - [x] 3.3 Implement full renumber pass
    - notes: resequences all fts tokens from scratch; used after sort or bulk edits

## Feature 4: Toggle
  - [x] 4.1 Toggle task checkbox (`[x]` ↔ `[x]`)
    - notes: operate on current line; if not a task/subtask line, do nothing
    - [x] 4.1.1 Create `toggle.lua` with `toggle_checkbox(bufnr, lnum)` and `toggle_checkbox_cursor()`
    - [x] 4.1.2 Write unit tests (`tests/toggle_spec.lua`): unchecked→checked, checked→unchecked, no-op on feature/plain/blank lines, name preserved
    - [x] 4.1.3 Fix `config.options` to initialize from defaults on load so parser works without explicit `setup()` call
  - [ ] 4.2 Toggle list item (`-` prefix presence)
    - notes: convert plain line to list item and back

## Feature 5: Add fts
  - [x] 5.1 Add feature
    - notes: inserts new feature header at cursor position and pushes all features below down
    - [x] 5.1.1 Prompt for feature name via `vim.ui.input` in `add_feature_cursor()`
    - [x] 5.1.2 Insert header and trigger push-down; tasks/subtasks of shifted features renumbered
    - [x] 5.1.3 Register `:TaskAddFeature` command in `init.lua`
      - notes: butts
    - [x] 5.1.4 Write unit tests (`tests/add_spec.lua`) covering empty buffer, insert at start/middle/end, and task renumbering
  - [x] 5.2 Add task
    - notes: inserts task under the feature containing the cursor; pushes sibling tasks down
    - [x] 5.2.1 Resolve parent feature from cursor context
    - [x] 5.2.2 Insert task line and trigger push-down
    - [x] 5.2.3 Task should be added at line below current; and use the same indention as the previous  task (or feature if feature is the next fts above the added task)
  - [x] 5.3 Add subtask
    - notes: inserts subtask under the task containing the cursor; pushes sibling subtasks down
    - when adding sub task: 
      - if added after a task; indent + 1
      - when added after another subtask maintain indent of previous sub task
    - [x] 5.3.1 Resolve parent task from cursor context
    - [x] 5.3.2 Insert subtask line and trigger push-down

## Feature 6: Remove fts
  - [x] 6.1 Remove feature
    - notes: deletes feature header and all its tasks/subtasks; pushes features below up
    - should work when called from task or sub task of feature
    - [x] 6.1.1 Create `remove.lua` with `remove_feature(bufnr, lnum)` and `remove_feature_cursor()`
    - [x] 6.1.2 Delete header + all owned tasks/subtasks + trailing non-fts lines
    - [x] 6.1.3 Trigger push-up to renumber features below
    - [x] 6.1.4 Register `:TaskRemoveFeature` command in `init.lua`
    - [x] 6.1.5 Write unit tests (`tests/remove_spec.lua`)
    - [x] 6.1.6 `remove_feature_cursor` resolves parent feature from task/subtask context
  - [x] 6.2 Remove task
    - notes: deletes task line and all its subtasks; pushes sibling tasks up
    - [x] 6.2.1 `remove_task(bufnr, lnum)` deletes task + subtasks + trailing non-fts lines
    - [x] 6.2.2 Trigger push-up to renumber sibling tasks
    - [x] 6.2.3 `remove_task_cursor()` resolves parent task from subtask context
    - [x] 6.2.4 Register `:TaskRemoveTask` command in `init.lua`
    - [x] 6.2.5 Write unit tests
  - [x] 6.3 Remove subtask
    - notes: deletes subtask line; pushes sibling subtasks up
    - [x] 6.3.1 `remove_subtask(bufnr, lnum)` deletes the subtask line and triggers push-up
    - [x] 6.3.2 `remove_subtask_cursor()` acts only when cursor is on a subtask line
    - [x] 6.3.3 Register `:TaskRemoveSubtask` command in `init.lua`
    - [x] 6.3.4 Write unit tests

## Feature 7: Move fts
  - [x] 7.1 Move feature up/down
    - notes: swap feature block (header + all tasks/subtasks) with adjacent feature; renumber both
    - [x] 7.1.1 Create `move.lua` with `move_feature_up`, `move_feature_down`, and cursor variants
    - [x] 7.1.2 Implement feature range detection to find all lines belonging to a feature
    - [x] 7.1.3 Swap feature blocks and add blank line separator between features
    - [x] 7.1.4 Call full renumber pass after swap to fix all numbering
    - [x] 7.1.5 Register `:TaskMoveFeatureUp` and `:TaskMoveFeatureDown` commands in `init.lua`
    - [x] 7.1.6 Write unit tests (`tests/move_spec.lua`) covering swap up/down, boundary conditions, cursor variants
  - [x] 7.2 Move task up/down within its feature
    - notes: swap task block (task + all subtasks) with adjacent task; renumber
    - [x] 7.2.1 `get_task_range` helper finds task line + subtasks + trailing non-fts lines
    - [x] 7.2.2 `move_task_up/down` swap adjacent task blocks and call full renumber
    - [x] 7.2.3 Boundary guards: no-op at top/bottom of feature; no crossing feature boundaries
    - [x] 7.2.4 Cursor variants resolve parent task from subtask context
    - [x] 7.2.5 Register `:TaskMoveTaskUp` and `:TaskMoveTaskDown` commands in `init.lua`
    - [x] 7.2.6 Write unit tests covering swap, block-with-subtasks, boundaries, cursor variants
  - [x] 7.3 Move subtask up/down within its task
    - notes: swap subtask line with adjacent subtask; renumber
    - [x] 7.3.1 Add `move_subtask_up` and `move_subtask_down` functions to `move.lua`
    - [x] 7.3.2 Implement simple line swap for subtasks (no trailing content like tasks have)
    - [x] 7.3.3 Only swap within the same parent task (check fn and tn match)
    - [x] 7.3.4 Call full renumber pass after swap to fix subtask numbering
    - [x] 7.3.5 Add cursor variants `move_subtask_up_cursor` and `move_subtask_down_cursor`
    - [x] 7.3.6 Register `:TaskMoveSubtaskUp` and `:TaskMoveSubtaskDown` commands in `init.lua`
    - [x] 7.3.7 Write unit tests covering swap up/down, boundary conditions, task isolation, checkbox/indentation preservation

## Feature 8: Eject fts
  - [x] 8.1 Eject feature
    - notes: strip the `## Feature N:` token, leaving plain heading text; push features above/below up
    - [x] 8.1.1 Create `eject.lua` with `eject_feature` function
    - [x] 8.1.2 Extract feature name from token and replace with plain heading (`## Name`)
    - [x] 8.1.3 Find all tasks and subtasks belonging to the feature and eject them (strip tokens)
    - [x] 8.1.4 Call `push_up` to renumber features below the ejected feature
    - [x] 8.1.5 Add `eject_feature_cursor` that works from any line within the feature
    - [x] 8.1.6 Register `:TaskEjectFeature` command in `init.lua`
    - [x] 8.1.7 Write unit tests (`tests/eject_spec.lua`) covering ejection, renumbering, indentation, cursor variants
  - [x] 8.2 Eject task
    - notes: strip the `- [ ] N.M` token prefix, leaving plain list item or text
    - [x] 8.2.1 Add `eject_task` function to `eject.lua`
    - [x] 8.2.2 Extract task name from token and replace with just the name
    - [x] 8.2.3 Find all subtasks belonging to the task and eject them (strip tokens)
    - [x] 8.2.4 Call `push_up` to renumber sibling tasks below the ejected task
    - [x] 8.2.5 Add `eject_task_cursor` that works from task or subtask line
    - [x] 8.2.6 Register `:TaskEjectTask` command in `init.lua`
    - [x] 8.2.7 Write unit tests covering ejection, renumbering, indentation, cursor variants
  - [x] 8.3 Eject subtask
    - notes: strip the `- [ ] N.M.P` token prefix, leaving plain text
    - [x] 8.3.1 Add `eject_subtask` function to `eject.lua`
    - [x] 8.3.2 Extract subtask name from token and replace with just the name
    - [x] 8.3.3 Call `push_up` to renumber sibling subtasks below the ejected subtask
    - [x] 8.3.4 Add `eject_subtask_cursor` that works only when cursor is on a subtask line
    - [x] 8.3.5 Register `:TaskEjectSubtask` command in `init.lua`
    - [x] 8.3.6 Write unit tests covering ejection, renumbering, indentation, cursor variants

## Feature 9: Navigation
  - [x] 9.1 Go to task
    - `#` (no decimal) - go to feature line
    - `#.#` - go to task 
    - `#.#.#` - go to subtask
    - [x] 9.1.1 Create navigate.lua module with goto_target function
    - [x] 9.1.2 Parse target strings (e.g., "3", "3.2", "3.2.1")
    - [x] 9.1.3 Find matching fts token in buffer and jump to it
    - [x] 9.1.4 Add goto_target_prompt for user input
    - [x] 9.1.5 Register :TaskGoto command in init.lua
    - [x] 9.1.6 Write unit tests (tests/navigate_spec.lua)
    - [x] 9.1.7 If no task go to parent feature if able
  - [x] 9.2 Go to next/previous incomplete entry
    - notes: cycle through fts tokens in document order
    - [x] 9.2.1 Create is_incomplete helper to check for unchecked tasks/subtasks
    - [x] 9.2.2 Implement goto_next_incomplete with wrap support
    - [x] 9.2.3 Implement goto_prev_incomplete with wrap support
    - [x] 9.2.4 Add cursor variants that wrap by default
    - [x] 9.2.5 Register :TaskNextIncomplete and :TaskPrevIncomplete commands
    - [x] 9.2.6 Write comprehensive tests for both directions and wrapping behavior
  - [x] 9.3 Go to next/previous complete entry
    - notes: cycle through fts tokens in document order
    - [x] 9.3.1 Create is_complete helper to check for checked tasks/subtasks
    - [x] 9.3.2 Implement goto_next_complete with wrap support
    - [x] 9.3.3 Implement goto_prev_complete with wrap support
    - [x] 9.3.4 Add cursor variants that wrap by default
    - [x] 9.3.5 Register :TaskNextComplete and :TaskPrevComplete commands
    - [x] 9.3.6 Write comprehensive tests for both directions and wrapping behavior

## Feature 10: Sort
  - [x] 10.1 Sort document by fts number
    - notes: reorder all feature blocks, then tasks within each feature, then subtasks within each task; run full renumber pass after
  - [x] 10.2 do not remove content before first feature
    - [x] 10.2.1 Find minimum start_lnum across all features to identify preamble boundary
    - [x] 10.2.2 Extract and preserve all lines before first feature
    - [x] 10.2.3 Add test case for preamble preservation
  - [x] 10.3 Preserve non-fts lines (notes, blank lines) attached to their parent fts entry during sort
    - [x] 10.3.1 preserve content after features as well

## Feature 11: Commands & keymaps
  - [x] 11.1 Register Neovim user commands (`:TaskToggle`, `:TaskAddFeature`, etc.)
    - notes: one command per logical action; commands call into the appropriate module
  - [ ] 11.2 Define ph keys (placeholder keymap stubs)
  - [ ] 11.3 Define pc keys (plugin command keymaps)
  - [ ] 11.4 Conditionally register keymaps based on config flags
  - [ ] 11.5 Expose keymaps to which-key under `<leader>` group if which-key is available
    - notes: use `pcall` to check for which-key; degrade gracefully if absent

## Feature 12: Shadow text (completion counts)
  - [x] 12.1 Display virtual text on each feature line showing `X/Y tasks complete`
    - notes: use `nvim_buf_set_extmark` with `virt_text`; update on every buffer change
    - [x] 12.1.1 Create `shadow.lua` with `refresh(bufnr)` using `nvim_buf_set_extmark` eol virt_text
    - [x] 12.1.2 Add `attach(bufnr)` to wire `TextChanged`/`TextChangedI` autocmds and call initial refresh
    - [x] 12.1.3 Register `:TaskShadowAttach` command in `init.lua`
    - [x] 12.1.4 Write tests for shadow virtual text counts
  - [ ] 12.2 Optional: expose completion summary in statusline via a public API function

## Feature 13: Testing infrastructure
  - [x] 13.1 Choose and configure test runner
    - notes: use plenary.nvim busted wrapper; tests run in headless Neovim
    - [x] 13.1.1 Create `tests/minimal_init.lua` to bootstrap plenary and the plugin
      - note: butt
    - [x] 13.1.2 Document local run command in README
  - [x] 13.2 Write unit tests for config module
    - [x] 13.2.1 Default values are set correctly
    - [x] 13.2.2 User opts are deep-merged over defaults
  - [x] 13.3 Write unit tests for parsing (Feature 2)
    - [x] 13.3.1 Feature line detection
    - [x] 13.3.2 Task line detection
    - [x] 13.3.3 Subtask line detection
    - [x] 13.3.4 Upward scan resolves correct fts context
    - [x] 13.3.5 build_index returns ordered token list with correct lnum
  - [x] 13.4 Write unit tests for renumbering engine (Feature 3)
    - [x] 13.4.1 Push-down increments correct tokens
    - [x] 13.4.2 Push-up decrements correct tokens
    - [x] 13.4.3 Full renumber pass resequences correctly
    - [x] 13.4.4 Non-fts lines preserved unchanged during full pass
  - [ ] 13.5 Write integration tests for add/remove/move/eject (Features 5–8)
    - notes: each test sets up a buffer with known content, runs the operation, and asserts the resulting buffer state
  - [ ] 13.6 Set up GitHub Actions CI
    - notes: install stable Neovim, run `nvim --headless -c "PlenaryBustedDirectory tests/"`
    - [ ] 13.6.1 Create `.github/workflows/ci.yml`
    - [ ] 13.6.2 Run on push and pull_request to main
