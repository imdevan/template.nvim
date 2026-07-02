-- Minimal Neovim init for running tests with plenary.nvim in headless mode.
-- Adds the plugin root and a local plenary clone to the runtime path.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

-- Add plugin root so `require("template")` resolves
vim.opt.rtp:prepend(root)

-- Resolve plenary: prefer a local vendor copy, fall back to the system path
local plenary_path = root .. "/vendor/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
  -- Try common plugin manager locations
  local fallbacks = {
    vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
    vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
  }
  for _, p in ipairs(fallbacks) do
    if vim.fn.isdirectory(p) == 1 then
      plenary_path = p
      break
    end
  end
end

vim.opt.rtp:prepend(plenary_path)

-- Ensure termination after suite completes
vim.o.swapfile = false
