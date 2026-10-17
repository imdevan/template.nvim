local M = {}

---Setup the plugin with optional user configuration
---@param opts? TemplateConfig
function M.setup(opts)
  require("template.config").setup(opts)

  vim.api.nvim_create_user_command("HelloWorld", function()
    require("template.hello_world").hello_world()
  end, { desc = "Print Hello World at cursor" })

  local cfg = require("template.config").options

  if cfg.keymaps.enabled then
    local map = require("template.utils").map
    local prefix = cfg.keymaps.prefix or ""
    map("n", "hw", "HelloWorld", "Print 'Hello World'")

    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({ { "<leader>" .. prefix .. "h", group = "Hello" } })
    end
  end
end

return M
