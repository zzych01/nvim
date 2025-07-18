-- ~/.config/nvim/lua/zib/plugins/nvim-dap.lua
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "nvim-neotest/nvim-nio",
    "williamboman/mason.nvim",
    "jay-babu/mason-nvim-dap.nvim",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")
    local mason_nvim_dap = require("mason-nvim-dap")

    -- Mason DAP setup
    mason_nvim_dap.setup({
      automatic_setup = true,
      handlers = {},
      ensure_installed = {
        "python",
        "debugpy",
      },
    })

    -- DAP UI setup
    dapui.setup({
      icons = { expanded = "▾", collapsed = "▸" },
      mappings = {
        expand = { "<CR>", "<2-LeftMouse>" },
        open = "o",
        remove = "d",
        edit = "e",
        repl = "r",
        toggle = "t",
      },
      expand_lines = vim.fn.has("nvim-0.7"),
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.25 },
            "breakpoints",
            "stacks",
            "watches",
          },
          size = 40,
          position = "left",
        },
        {
          elements = {
            "repl",
            "console",
          },
          size = 0.25,
          position = "bottom",
        },
      },
      controls = {
        enabled = true,
        element = "repl",
        icons = {
          pause = "",
          play = "",
          step_into = "",
          step_over = "",
          step_out = "",
          step_back = "",
          run_last = "↻",
          terminate = "□",
        },
      },
      floating = {
        max_height = nil,
        max_width = nil,
        border = "single",
        mappings = {
          close = { "q", "<Esc>" },
        },
      },
      windows = { indent = 1 },
      render = {
        max_type_length = nil,
        max_value_lines = 100,
      },
    })

    -- Virtual text setup
    require("nvim-dap-virtual-text").setup({
      enabled = true,
      enabled_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = false,
      show_stop_reason = true,
      commented = false,
      only_first_definition = true,
      all_references = false,
      filter_references_pattern = "<module",
      virt_text_pos = "eol",
      all_frames = false,
      virt_lines = false,
      virt_text_win_col = nil,
    })

    -- Python configuration
    dap.adapters.python = {
      type = "executable",
      command = "python3",
      args = { "-m", "debugpy.adapter" },
    }

    dap.configurations.python = {
      {
        type = "python",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        pythonPath = function()
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
            return cwd .. "/venv/bin/python"
          elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
            return cwd .. "/.venv/bin/python"
          else
            return "/usr/bin/python3"
          end
        end,
      },
      {
        type = "python",
        request = "launch",
        name = "Launch file with arguments",
        program = "${file}",
        args = function()
          local args_string = vim.fn.input("Arguments: ")
          return vim.split(args_string, " +")
        end,
        pythonPath = function()
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
            return cwd .. "/venv/bin/python"
          elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
            return cwd .. "/.venv/bin/python"
          else
            return "/usr/bin/python3"
          end
        end,
      },
      {
        type = "python",
        request = "attach",
        name = "Attach remote",
        connect = function()
          local host = vim.fn.input("Host [127.0.0.1]: ")
          host = host ~= "" and host or "127.0.0.1"
          local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
          return { host = host, port = port }
        end,
      },
      {
        type = "python",
        request = "launch",
        name = "Launch Django",
        program = "${workspaceFolder}/manage.py",
        args = {
          "runserver",
        },
        pythonPath = function()
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
            return cwd .. "/venv/bin/python"
          elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
            return cwd .. "/.venv/bin/python"
          else
            return "/usr/bin/python3"
          end
        end,
        django = true,
      },
      {
        type = "python",
        request = "launch",
        name = "Launch Flask",
        module = "flask",
        env = {
          FLASK_APP = "app.py",
        },
        args = {
          "run",
        },
        pythonPath = function()
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
            return cwd .. "/venv/bin/python"
          elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
            return cwd .. "/.venv/bin/python"
          else
            return "/usr/bin/python3"
          end
        end,
        jinja = true,
      },
      {
        type = "python",
        request = "launch",
        name = "Launch FastAPI",
        module = "uvicorn",
        args = {
          "main:app",
          "--reload",
        },
        pythonPath = function()
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
            return cwd .. "/venv/bin/python"
          elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
            return cwd .. "/.venv/bin/python"
          else
            return "/usr/bin/python3"
          end
        end,
      },
    }

    -- Auto open/close UI
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    -- dap.listeners.before.event_terminated["dapui_config"] = function()
    --   dapui.close()
    -- end
    -- dap.listeners.before.event_exited["dapui_config"] = function()
    --   dapui.close()
    -- end

    -- Keymaps (VS Code style)
    local keymap = vim.keymap

    -- Debug controls
    keymap.set("n", "<F5>", dap.continue, { desc = "Debug: Start/Continue" })
    keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })
    keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })
    keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step Out" })
    keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
    keymap.set("n", "<leader>dB", function()
      dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, { desc = "Debug: Set Conditional Breakpoint" })
    keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
    keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run Last" })
    keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: Terminate" })

    -- DAP UI
    keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
    keymap.set("n", "<leader>de", dapui.eval, { desc = "Debug: Evaluate" })
    keymap.set("v", "<leader>de", dapui.eval, { desc = "Debug: Evaluate Selection" })

    -- VS Code style shortcuts
    keymap.set("n", "<C-F5>", dap.restart, { desc = "Debug: Restart" })
    keymap.set("n", "<S-F5>", dap.terminate, { desc = "Debug: Stop" })
    keymap.set("n", "<C-S-F5>", dap.run_last, { desc = "Debug: Run Last" })

    -- Quick run current file
    keymap.set("n", "<leader>dp", function()
      dap.run({
        type = "python",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        pythonPath = function()
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
            return cwd .. "/venv/bin/python"
          elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
            return cwd .. "/.venv/bin/python"
          else
            return "/usr/bin/python3"
          end
        end,
      })
    end, { desc = "Debug: Run Python file" })

    -- Signs
    vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "DapBreakpoint", linehl = "", numhl = "" })
    vim.fn.sign_define(
      "DapBreakpointCondition",
      { text = "🟡", texthl = "DapBreakpointCondition", linehl = "", numhl = "" }
    )
    vim.fn.sign_define("DapLogPoint", { text = "📝", texthl = "DapLogPoint", linehl = "", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "🔵", texthl = "DapStopped", linehl = "DapStoppedLine", numhl = "" })
    vim.fn.sign_define(
      "DapBreakpointRejected",
      { text = "❌", texthl = "DapBreakpointRejected", linehl = "", numhl = "" }
    )
  end,
}
