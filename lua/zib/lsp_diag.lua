-- Run with :lua require("zib.lsp_diag")()
return function()
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  print("=== LSP Diagnostic ===")
  print("Buffer: " .. bufnr .. " File: " .. file)

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  print("Clients: " .. #clients)

  -- Show diagnostics (errors/warnings) on this buffer
  local diags = vim.diagnostic.get(bufnr)
  local err_count = 0
  for _, d in ipairs(diags) do
    if d.severity == vim.diagnostic.severity.ERROR then err_count = err_count + 1 end
  end
  print("Diagnostics: " .. #diags .. " total, " .. err_count .. " errors")
  for i, d in ipairs(diags) do
    if i <= 15 then
      print(string.format("  [%s] L%d: %s",
        vim.diagnostic.severity[d.severity] or d.severity,
        d.lnum + 1,
        d.message:sub(1, 140)
      ))
    end
  end

  -- Find the printf line
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local printf_line, printf_col
  for i, line in ipairs(lines) do
    local col = line:find("printf%(")
    if col then
      printf_line = i - 1  -- 0-indexed
      printf_col = col + 6  -- after "printf("
      print(string.format("Found printf( at line %d, col %d", i, printf_col))
      break
    end
  end

  if not printf_line then
    print("No printf( found in buffer!")
    return
  end

  local td = vim.lsp.util.make_text_document_params(bufnr)

  -- Send hover at printf position (to check if clangd can find the declaration)
  local hover_params = {
    textDocument = td,
    position = { line = printf_line, character = printf_col - 3 }, -- on 'printf' word
  }
  print("Sending HOVER at printf word...")
  vim.lsp.buf_request(bufnr, "textDocument/hover", hover_params, function(err, result)
    vim.schedule(function()
      if err then
        print("HOVER ERROR: " .. vim.inspect(err))
      elseif result and result.contents then
        local val = type(result.contents) == "table" and (result.contents.value or vim.inspect(result.contents)) or tostring(result.contents)
        print("HOVER: " .. val:sub(1, 200))
      else
        print("HOVER: nil (can't find printf)")
      end
    end)
  end)

  -- Send signatureHelp at printf( position
  local sig_params = {
    textDocument = td,
    position = { line = printf_line, character = printf_col },
  }
  print("Sending SIGNATURE at printf(...")
  vim.lsp.buf_request(bufnr, "textDocument/signatureHelp", sig_params, function(err, result)
    vim.schedule(function()
      if err then
        print("SIGNATURE ERROR: " .. vim.inspect(err))
      elseif result then
        print("SIGNATURE: " .. vim.inspect(result))
      else
        print("SIGNATURE: nil")
      end
    end)
  end)

  print("=== End (async results follow) ===")
end
