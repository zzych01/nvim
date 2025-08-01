-- Create: lua/zib/plugins/python-syntax.lua
return {
  "vim-python/python-syntax",
  ft = "python",
  config = function()
    vim.g.python_highlight_all = 1
    vim.g.python_highlight_space_errors = 0
  end,
}
