return {
  "ray-x/lsp_signature.nvim",
  event = "InsertEnter",
  opts = {
    bind = true,
    handler_opts = {
      border = "rounded",
    },
    toggle_key = "<C-g>",
    toggle_key_flip_floatwin_setting = true,
    auto_close_after = nil,
    hint_enable = false, -- disable inline hint, popup only
  },
}
