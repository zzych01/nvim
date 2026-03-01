-- File: nvim/lua/zib/ncs-tools/init.lua
local M = {}

function M.setup(opts)
  opts = opts or {}

  -- Setup keymaps
  local keymap = vim.keymap

  local samples = require("ncs-tools.samples")
  local boards = require("ncs-tools.boards")
  local build = require("ncs-tools.build")
  local utils = require("ncs-tools.utils")

  keymap.set("n", "<leader>ns", samples.browser, { desc = "NCS Sample Browser" })
  keymap.set("n", "<leader>nb", build.configuration, { desc = "NCS Build Configuration" })
  keymap.set("n", "<leader>nB", boards.browser, { desc = "NCS Board Browser" })
  keymap.set("n", "<leader>np", utils.configure_project_paths, { desc = "NCS Configure Project Paths" })

  -- Keep existing build shortcuts (with venv activation if .venv exists in cwd)
  keymap.set("n", "<leader>nf", function()
    vim.cmd("TermExec cmd='" .. utils.get_venv_prefix() .. "west flash'")
  end, { desc = "NCS Flash" })
  keymap.set("n", "<leader>nc", function()
    vim.cmd("TermExec cmd='" .. utils.get_venv_prefix() .. "west build -t clean'")
  end, { desc = "NCS Clean" })
  keymap.set("n", "<leader>nm", function()
    vim.cmd("TermExec cmd='" .. utils.get_venv_prefix() .. "west build -t menuconfig'")
  end, { desc = "NCS Menuconfig" })
  keymap.set("n", "<leader>ni", utils.show_project_info, { desc = "Show NCS project info" })
  keymap.set("n", "<leader>nl", utils.link_compile_commands, { desc = "NCS Link compile_commands.json" })
end

return M
