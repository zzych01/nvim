-- nvim/lua/zib/plugins/treesitter.lua
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = {
    "windwp/nvim-ts-autotag",
  },
  config = function()
    -- new nvim-treesitter only handles parser installation
    -- highlight/indent are built into Neovim 0.11+
    require("nvim-treesitter").setup({})

    -- install parsers
    require("nvim-treesitter").install({
      "json",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "html",
      "css",
      "prisma",
      "markdown",
      "markdown_inline",
      "svelte",
      "graphql",
      "bash",
      "lua",
      "vim",
      "devicetree",
      "kconfig",
      "dockerfile",
      "gitignore",
      "query",
      "vimdoc",
      "c",
    })
  end,
}
