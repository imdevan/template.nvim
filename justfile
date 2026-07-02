test:
    nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

install:
    #!/usr/bin/env bash
    set -euo pipefail
    PLUGIN_DIR="$HOME/.config/nvim/lua/plugins"
    SPEC="$PLUGIN_DIR/template.lua"
    REPO_PATH="$(pwd)"

    if [ -f "$SPEC" ]; then
        echo "template.lua already exists at $SPEC — skipping"
        exit 0
    fi

    cat > "$SPEC" <<EOF
    return {
      dir = "$REPO_PATH",
      name = "template.nvim",
      opts = {},
    }
    EOF

    echo "Installed: $SPEC"
    echo "Restart Neovim (or run :Lazy reload template.nvim) to activate."

reinstall:
    #!/usr/bin/env bash
    set -euo pipefail
    SPEC="$HOME/.config/nvim/lua/plugins/template.lua"
    rm -f "$SPEC"
    just install

# Rename the project 
# args: accepts 1 arg: name
# look at plugin/file_name.lua based on the file_name (for testing assume "template.lua")
# replace all instances of file_name with name and all instances of FileName with Template (camel case if more than one word or _ -)
# use grep or similar for inline replacement, DO NOT manual parse. 
# rename  plugin/file_name.lua to name.lua
# rename lua/file_name dir to lua/name
rename: 
    #!/usr/bin/env bash
