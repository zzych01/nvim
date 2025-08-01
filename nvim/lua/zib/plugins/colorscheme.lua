-- Create a new file: lua/plugins/colorscheme.lua
return {
  "sainnhe/sonokai",
  priority = 1000, -- Make sure to load this before all the other start plugins
  config = function()
    -- Configure Sonokai before loading
    vim.g.sonokai_style = "shusia" -- Options: 'default', 'atlantis', 'andromeda', 'shusia', 'maia', 'espresso'
    vim.g.sonokai_enable_italic = 1
    vim.g.sonokai_disable_italic_comment = 0
    vim.g.sonokai_diagnostic_line_highlight = 1
    vim.g.sonokai_diagnostic_text_highlight = 1
    vim.g.sonokai_diagnostic_virtual_text = "colored"
    vim.g.sonokai_current_word = "grey background"

    -- Better colors for nvim-tree and file explorers
    vim.g.sonokai_better_performance = 1

    -- Load the colorscheme
    vim.cmd.colorscheme("sonokai")

    -- Optional: Additional customizations for nvim-tree integration
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      callback = function()
        -- Customize nvim-tree colors if needed
        vim.api.nvim_set_hl(0, "NvimTreeFolderIcon", { fg = "#a7c080" })
        vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = "#a7c080", bold = true })
        vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = "#d3c6aa" })
        vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = "#544a65" })
        vim.api.nvim_set_hl(0, "NvimTreeGitDirty", { fg = "#dbbc7f" })
        vim.api.nvim_set_hl(0, "NvimTreeGitNew", { fg = "#a7c080" })
        vim.api.nvim_set_hl(0, "NvimTreeGitDeleted", { fg = "#fc5d7c" })
      end,
    })
  end,
}
