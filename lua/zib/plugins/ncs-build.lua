return {
  "akinsho/toggleterm.nvim",
  config = function()
    -- Your existing toggleterm config...

    -- NCS build functions
    local Terminal = require("toggleterm.terminal").Terminal

    -- West build terminal with board selection
    local function west_build()
      local board = vim.fn.input("Board (nrf52840dk_nrf52840): ", "nrf52840dk_nrf52840")
      if board == "" then
        return
      end

      local build_type = vim.fn.input("Build type [build/pristine]: ", "build")
      local pristine_flag = build_type == "pristine" and " --pristine" or ""

      local build_terminal = Terminal:new({
        cmd = string.format("cd %s && west build -b %s%s", vim.fn.getcwd(), board, pristine_flag),
        direction = "horizontal",
        close_on_exit = false,
        on_open = function(term)
          vim.cmd("startinsert!")
        end,
      })
      build_terminal:toggle()
    end

    -- West flash
    local function west_flash()
      local flash_terminal = Terminal:new({
        cmd = string.format("cd %s && west flash", vim.fn.getcwd()),
        direction = "horizontal",
        close_on_exit = false,
      })
      flash_terminal:toggle()
    end

    -- West debug server
    local function west_debug()
      local debug_terminal = Terminal:new({
        cmd = string.format("cd %s && west debug", vim.fn.getcwd()),
        direction = "horizontal",
        close_on_exit = false,
      })
      debug_terminal:toggle()
    end

    -- Serial monitor
    local function serial_monitor()
      local device = vim.fn.input("Serial device (/dev/cu.usbmodem*): ", "/dev/cu.usbmodem")
      if device == "" then
        return
      end

      local baud = vim.fn.input("Baud rate (115200): ", "115200")
      if baud == "" then
        baud = "115200"
      end

      local serial_terminal = Terminal:new({
        cmd = string.format("screen %s %s", device, baud),
        direction = "horizontal",
        close_on_exit = false,
      })
      serial_terminal:toggle()
    end

    -- Make functions globally available
    _G.west_build = west_build
    _G.west_flash = west_flash
    _G.west_debug = west_debug
    _G.serial_monitor = serial_monitor

    -- Keymaps for NCS
    local keymap = vim.keymap
    keymap.set("n", "<leader>wb", "<cmd>lua west_build()<CR>", { desc = "West Build" })
    keymap.set("n", "<leader>wf", "<cmd>lua west_flash()<CR>", { desc = "West Flash" })
    keymap.set("n", "<leader>wd", "<cmd>lua west_debug()<CR>", { desc = "West Debug" })
    keymap.set("n", "<leader>wm", "<cmd>lua serial_monitor()<CR>", { desc = "Serial Monitor" })

    -- Quick build current project
    keymap.set("n", "<leader>wq", function()
      vim.cmd("TermExec cmd='west build'")
    end, { desc = "Quick West Build" })

    -- West commands menu using Telescope
    local function west_commands_menu()
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local conf = require("telescope.config").values
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      local commands = {
        { "Build", "west build" },
        { "Build Pristine", "west build --pristine" },
        { "Flash", "west flash" },
        { "Debug", "west debug" },
        { "Clean", "west build -t clean" },
        { "Menuconfig", "west build -t menuconfig" },
        { "Update", "west update" },
      }

      pickers
        .new({}, {
          prompt_title = "West Commands",
          finder = finders.new_table({
            results = commands,
            entry_maker = function(entry)
              return {
                value = entry,
                display = entry[1],
                ordinal = entry[1],
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              vim.cmd("TermExec cmd='" .. selection.value[2] .. "'")
            end)
            return true
          end,
        })
        :find()
    end

    _G.west_commands_menu = west_commands_menu
    keymap.set("n", "<leader>wc", "<cmd>lua west_commands_menu()<CR>", { desc = "West Commands Menu" })
  end,
}
