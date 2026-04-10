test:
    nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

install:
    #!/usr/bin/env bash
    set -euo pipefail
    PLUGIN_DIR="$HOME/.config/nvim/lua/plugins"
    SPEC="$PLUGIN_DIR/task-manager.lua"
    REPO_PATH="$(pwd)"

    if [ -f "$SPEC" ]; then
        echo "task-manager.lua already exists at $SPEC — skipping"
        exit 0
    fi

    cat > "$SPEC" <<EOF
    return {
      dir = "$REPO_PATH",
      name = "task-manager.nvim",
      opts = {},
    }
    EOF

    echo "Installed: $SPEC"
    echo "Restart Neovim (or run :Lazy reload task-manager.nvim) to activate."
