-- File: nvim/lua/zib/plugins/ncs-tools.lua
return {
  "ncs-tools.nvim",
  dev = true,
  dir = vim.fn.stdpath("config") .. "/lua/ncs-tools",
  config = function()
    require("ncs-tools").setup()
  end,
}
