-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

--- Break lines at word boundaries
vim.opt.wrap = true
vim.opt.linebreak = true

--- Copy the indent of the current line when inserting a new line
vim.opt.autoindent = true

vim.g.lazygit_config = {
  cwd = vim.fn.expand("%:p:h"),
}
