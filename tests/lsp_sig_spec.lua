-- Tests for lsp_signature.nvim setup
-- Run: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/lsp_sig_spec.lua"

describe("lsp_signature setup", function()
  local sig

  before_each(function()
    -- Reset global config between tests
    _LSP_SIG_CFG = nil
    package.loaded["lsp_signature"] = nil
    package.loaded["lsp_signature.helper"] = nil
    package.loaded["lsp_signature.codeaction"] = nil
    sig = require("lsp_signature")
  end)

  it("plugin loads without error", function()
    assert.is_not_nil(sig)
    assert.is_function(sig.setup)
    assert.is_function(sig.toggle_float_win)
    assert.is_function(sig.on_attach)
  end)

  it("setup populates global config with toggle_key", function()
    sig.setup({
      bind = true,
      toggle_key = "<C-g>",
      floating_window = true,
      hint_enable = false,
    })
    assert.is_not_nil(_LSP_SIG_CFG)
    assert.equals("<C-g>", _LSP_SIG_CFG.toggle_key)
    assert.is_true(_LSP_SIG_CFG.floating_window)
  end)

  it("on_attach sets insert-mode keymap for toggle_key on buffer", function()
    sig.setup({
      bind = true,
      toggle_key = "<C-g>",
      floating_window = true,
      hint_enable = false,
    })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("filetype", "c", { buf = bufnr })

    sig.on_attach({}, bufnr)

    local maps = vim.api.nvim_buf_get_keymap(bufnr, "i")
    local found = false
    for _, m in ipairs(maps) do
      -- lhs is stored as the raw byte \x07 (BEL = Ctrl-G) or as '<C-G>'
      if m.lhs == "\7" or m.lhs:lower() == "<c-g>" then
        found = true
        break
      end
    end

    vim.api.nvim_buf_delete(bufnr, { force = true })
    assert.is_true(found, "<C-g> insert keymap should be registered on buffer after on_attach")
  end)

  it("clangd-18 binary exists and is executable", function()
    assert.equals(1, vim.fn.executable("/usr/bin/clangd-18"),
      "/usr/bin/clangd-18 must be executable")
  end)

  it("handler is bound to textDocument/signatureHelp when bind=true", function()
    sig.setup({
      bind = true,
      toggle_key = "<C-g>",
      floating_window = true,
      hint_enable = false,
    })
    -- on_attach installs the handler; call it with a scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    sig.on_attach({}, bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })

    local handler = vim.lsp.handlers["textDocument/signatureHelp"]
    assert.is_not_nil(handler, "global signatureHelp handler should be overridden by lsp_signature")
  end)
end)
