local M = {}

---@class TemplateConfig
---@field keymaps      TemplateKeymaps

---@class TemplateKeymaps
---@field enabled boolean  master switch for all keymaps

M.defaults = {
  keymaps = {
    enabled = true,
  },
}

---@type TemplateConfig
M.options = vim.tbl_deep_extend("force", {}, M.defaults)

---Merge user opts over defaults and store in M.options
---@param opts? TemplateConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
