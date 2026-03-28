-- nvim/lua/zib/plugins/telescope.lua
return {
  "nvim-telescope/telescope.nvim",
  branch = "master",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    "folke/todo-comments.nvim",
  },
  config = function()
    -- Shim removed nvim-treesitter APIs that telescope still depends on
    local ok_parsers, ts_parsers = pcall(require, "nvim-treesitter.parsers")
    if ok_parsers and not ts_parsers.ft_to_lang then
      ts_parsers.ft_to_lang = function(ft)
        return vim.treesitter.language.get_lang(ft) or ft
      end
    end
    local ok_configs, ts_configs = pcall(require, "nvim-treesitter.configs")
    if ok_configs and not ts_configs.is_enabled then
      ts_configs.is_enabled = function(mod, lang, bufnr)
        if mod == "highlight" then
          local ok = pcall(vim.treesitter.get_parser, bufnr, lang)
          return ok
        end
        return false
      end
    end

    local telescope = require("telescope")
    local actions = require("telescope.actions")
    local transform_mod = require("telescope.actions.mt").transform_mod

    local trouble = require("trouble")
    local trouble_telescope = require("trouble.sources.telescope")

    -- or create your custom action
    local custom_actions = transform_mod({
      open_trouble_qflist = function(prompt_bufnr)
        trouble.toggle("quickfix")
      end,
    })

    telescope.setup({
      defaults = {
        path_display = { "smart" },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous, -- move to prev result
            ["<C-j>"] = actions.move_selection_next, -- move to next result
            ["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
            ["<C-t>"] = trouble_telescope.open,
          },
        },
      },
    })

    telescope.load_extension("fzf")

    -- set keymaps
    local keymap = vim.keymap -- for conciseness

    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
    keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
    keymap.set("n", "<leader>fT", "<cmd>Telescope treesitter<cr>", { desc = "Find symbols (treesitter)" })
    keymap.set("n", "<leader>fS", "<cmd>Telescope symbols<cr>", { desc = "Find symbols (all)" })
    keymap.set(
      "n",
      "<leader>fo",
      "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
      { desc = "Find symbols dynamically" }
    )
  end,
}
