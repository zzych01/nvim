-- ~/.config/nvim/lua/zib/plugins/toggleterm.lua
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      direction = "horizontal", -- 'vertical' | 'horizontal' | 'tab' | 'float'
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
    })

    -- Custom terminal functions
    local Terminal = require("toggleterm.terminal").Terminal

    -- Python terminal
    local python_terminal = Terminal:new({
      cmd = "python3",
      dir = "git_dir",
      direction = "horizontal",
      float_opts = {
        border = "double",
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
      end,
      on_close = function(term)
        vim.cmd("startinsert!")
      end,
    })

    -- Lazygit terminal
    local lazygit = Terminal:new({
      cmd = "lazygit",
      dir = "git_dir",
      direction = "float",
      float_opts = {
        border = "double",
      },
      on_open = function(term)
        vim.cmd("startinsert!")
      end,
      on_close = function(term)
        vim.cmd("startinsert!")
      end,
    })

    -- Node terminal
    local node = Terminal:new({
      cmd = "node",
      dir = "git_dir",
      direction = "horizontal",
      on_open = function(term)
        vim.cmd("startinsert!")
      end,
    })

    -- Htop terminal
    local htop = Terminal:new({
      cmd = "htop",
      direction = "float",
      float_opts = {
        border = "double",
      },
    })

    -- Custom functions
    function _G.set_terminal_keymaps()
      local opts = { buffer = 0 }
      vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
      vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
    end

    -- Auto command to set terminal keymaps
    vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

    -- Public functions for keymaps
    function _G.python_toggle()
      python_terminal:toggle()
    end

    function _G.lazygit_toggle()
      lazygit:toggle()
    end

    function _G.node_toggle()
      node:toggle()
    end

    function _G.htop_toggle()
      htop:toggle()
    end

    -- Keymaps
    local keymap = vim.keymap
    keymap.set("n", "<leader>tt", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
    keymap.set("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Toggle floating terminal" })
    keymap.set("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Toggle horizontal terminal" })
    keymap.set(
      "n",
      "<leader>tv",
      "<cmd>ToggleTerm direction=vertical size=80<cr>",
      { desc = "Toggle vertical terminal" }
    )
    keymap.set("n", "<leader>tp", "<cmd>lua python_toggle()<CR>", { desc = "Toggle Python terminal" })
    keymap.set("n", "<leader>tg", "<cmd>lua lazygit_toggle()<CR>", { desc = "Toggle LazyGit" })
    keymap.set("n", "<leader>tn", "<cmd>lua node_toggle()<CR>", { desc = "Toggle Node terminal" })
    keymap.set("n", "<leader>th", "<cmd>lua htop_toggle()<CR>", { desc = "Toggle Htop" })

    -- VS Code like keybinds
    keymap.set("n", "<C-`>", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
    keymap.set("n", "<C-S-`>", "<cmd>ToggleTerm direction=float<cr>", { desc = "New terminal" })

    -- Run current file in terminal
    keymap.set("n", "<leader>tr", function()
      local filetype = vim.bo.filetype
      local filename = vim.fn.expand("%")

      if filetype == "python" then
        vim.cmd("ToggleTerm")
        vim.cmd("TermExec cmd='python3 " .. filename .. "'")
      elseif filetype == "javascript" then
        vim.cmd("ToggleTerm")
        vim.cmd("TermExec cmd='node " .. filename .. "'")
      elseif filetype == "sh" then
        vim.cmd("ToggleTerm")
        vim.cmd("TermExec cmd='bash " .. filename .. "'")
      else
        print("No run command defined for filetype: " .. filetype)
      end
    end, { desc = "Run current file in terminal" })
  end,
}
