return {
  "ray-x/lsp_signature.nvim",
  event = "LspAttach",
  config = function()
    local sig = require("lsp_signature")
    local sig_opts = {
      bind = true,
      handler_opts = {
        border = "rounded",
      },
      toggle_key = "<C-g>",
      toggle_key_flip_floatwin_setting = false,
      auto_close_after = nil,
      hint_enable = false,
      floating_window = true,
      check_completion_visible = false,
    }
    sig.setup(sig_opts)
    -- Handle buffers that already had LspAttach fire before this plugin loaded
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and #vim.lsp.get_clients({ bufnr = buf }) > 0 then
        sig.on_attach(sig_opts, buf)
      end
    end
  end,
}
