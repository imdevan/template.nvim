# Task manager

lazy nvim plugin to manage tasks/plan.md files
##  definitions:

**feature**
```
## feature {feature_number}: Feature Name
```

**task**
```
- [ ] {feature_number}.{task_number} Task description
```

**subtask**
```
- [ ] {feature_number}.{task_number}.{sub_task_number} Subtask description
```

**fts**
featue/task/subtask # used when referring to an action that could affect a feature task or subtask

**pushing down**
1. determine current fts by looking at current line; then checking above lines for next possible fts token
2. increment the values of all fts affected by change

## features:

- toggle task
- toggle list item
- ph keys
- pc keys
- add feature
  - adds feature and pushes all down
- add task
  - adds task and pushes all down
- add subtask
  - adds subtask and pushes all down
- remove feature
  - removes feature and pushes all up
- remove task
  - removes task and pushes all up
- remove subtask
  - removes subtask and pushes all up
- move feature/task/subtask
  - adjust feature/task/subtask accordingly
- eject feature/task/subtask
  - remove any feature/task/subtask accordingly tokens leave remaining text
- eject feature/task/subtask
  - remove any feature/task/subtask accordingly tokens leave remaining text
- go to feature/task/subtask
- sort
  - sorts the document by feature task and subtask number
- possible feature: use "shadow text" to show tasks completed and out of how many on each feature and possibly include in status bar

## architecture

- easily packaged and installed via lazyvim
  - code is optimized to be memory efficient for the package user
- plugin creates set of nvim commands that can be called via nvim command line ':'
- keymaps
  - to determine: 
    - should keymaps come predefined, togglable via config, or provided via documentation but execulded from package build
  - should appear in whichkey if keymaps defined via <leader>
- fts tokens should be adjustmble via config
  - reuse logic via utils when possible

