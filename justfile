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
# usage: just rename new_name
# 
# Renames all template files and content to given package name.
# Convience for usting this template to jumpstart your plugin.
#
# Details:
# Look at plugin/old_name.lua -> rename to plugin/new_name.lua
# Replace all instances of OldName... and *old_name* with NewName and *new_name*
# Replace lua/old_name/** with lua/new_name/**
rename new_name:
    #!/usr/bin/env bash
    set -euo pipefail

    to_camel_case() {
        local input="$1"
        local temp="${input//[-_]/ }"
        local result=""
        for word in $temp; do
            result+="${word^}"
        done
        echo "$result"
    }

    OLD_FILE="$(find plugin -maxdepth 1 -name '*.lua' | head -n1 || true)"
    if [ -z "$OLD_FILE" ]; then
        OLD_NAME="template"
    else
        OLD_NAME="$(basename "$OLD_FILE" .lua)"
    fi

    NEW_NAME="{{new_name}}"
    OLD_CAMEL="$(to_camel_case "$OLD_NAME")"
    NEW_CAMEL="$(to_camel_case "$NEW_NAME")"

    if [ "$OLD_NAME" = "$NEW_NAME" ]; then
        echo "Already named '$NEW_NAME' — nothing to do"
        exit 0
    fi

    # Check for name collisions before renaming
    if [ -e "plugin/${NEW_NAME}.lua" ] || [ -e "lua/${NEW_NAME}.lua" ] || [ -e "lua/${NEW_NAME}" ]; then
        echo "Error: Cannot rename to '$NEW_NAME'. A file or directory with that name already exists under plugin/ or lua/." >&2
        exit 1
    fi

    echo "Renaming '$OLD_NAME' ($OLD_CAMEL) -> '$NEW_NAME' ($NEW_CAMEL)"

    # Replace occurrences in all files
    (grep -rlZ --exclude-dir=.git --exclude-dir=vendor -e "$OLD_NAME" -e "$OLD_CAMEL" . || true) | while IFS= read -r -d '' f; do
        sed -i "s/${OLD_CAMEL}/${NEW_CAMEL}/g; s/${OLD_NAME}/${NEW_NAME}/g" "$f"
    done

    # Rename plugin file
    if [ -f "plugin/${OLD_NAME}.lua" ]; then
        mv "plugin/${OLD_NAME}.lua" "plugin/${NEW_NAME}.lua"
        echo "Done. Renamed plugin/${OLD_NAME}.lua -> plugin/${NEW_NAME}.lua"
    fi

    # Rename lua file if it exists
    if [ -f "lua/${OLD_NAME}.lua" ]; then
        mv "lua/${OLD_NAME}.lua" "lua/${NEW_NAME}.lua"
        echo "Done. Renamed lua/${OLD_NAME}.lua -> lua/${NEW_NAME}.lua"
    fi

    # Rename lua directory if it exists
    if [ -d "lua/${OLD_NAME}" ]; then
        mv "lua/${OLD_NAME}" "lua/${NEW_NAME}"
        echo "Done. Renamed lua/${OLD_NAME} -> lua/${NEW_NAME}"
    fi
