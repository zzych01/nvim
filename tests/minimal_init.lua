-- Minimal init for headless testing of lsp_signature
-- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/lsp_sig_spec.lua"

local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazy_path)

local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
vim.opt.rtp:prepend(plenary_path)

local lsp_sig_path = vim.fn.stdpath("data") .. "/lazy/lsp_signature.nvim"
vim.opt.rtp:prepend(lsp_sig_path)
