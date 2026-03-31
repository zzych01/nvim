-- File: nvim/lua/zib/ncs-tools/build.lua
local M = {}

local function get_optimization_levels()
  return {
    "Use project default",
    "No optimization (-O0)",
    "Optimize for size (-Os)",
    "Optimize for speed (-O2)",
    "Optimize for debugging (-Og)",
  }
end

local function get_build_actions()
  return { "Build", "Build (pristine)", "Build and Flash", "Build and Debug" }
end

local function reorder_first(list, value)
  if not value then
    return list
  end
  local result, found_idx = {}, nil
  for i, item in ipairs(list) do
    if item == value then
      found_idx = i
    end
  end
  if not found_idx then
    return list
  end
  table.insert(result, list[found_idx])
  for i, item in ipairs(list) do
    if i ~= found_idx then
      table.insert(result, item)
    end
  end
  return result
end

local function scan_build_directories(base_path, max_depth)
  max_depth = max_depth or 3
  local directories = {}

  local function scan_recursive(path, relative_path, depth)
    if depth > max_depth or vim.fn.isdirectory(path) == 0 then
      return
    end
    if vim.fn.filereadable(path .. "/CMakeLists.txt") == 1 then
      table.insert(directories, {
        path = path,
        display = relative_path == "." and "." or relative_path,
        relative = relative_path,
      })
    end
    local handle = vim.loop.fs_scandir(path)
    if handle then
      local name, type = vim.loop.fs_scandir_next(handle)
      while name do
        if type == "directory" and name ~= "." and name ~= ".." then
          local full_path = path .. "/" .. name
          local new_relative = relative_path == "." and name or relative_path .. "/" .. name
          scan_recursive(full_path, new_relative, depth + 1)
        end
        name, type = vim.loop.fs_scandir_next(handle)
      end
    end
  end

  scan_recursive(base_path, ".", 0)
  table.sort(directories, function(a, b)
    return a.display < b.display
  end)
  return directories
end

-- Keep a module-level reference to prevent the timer from being garbage collected
local _debug_timer = nil

-- Poll port 2331 until J-Link GDB server is ready, then launch nvim-dap
local function launch_dap_when_ready(build_dir, gdb_path)
  local attempts = 0
  local max_attempts = 40 -- 2s initial + 40 * 500ms = up to 22s

  if _debug_timer then
    _debug_timer:stop()
    _debug_timer:close()
  end
  _debug_timer = vim.loop.new_timer()
  vim.notify("nRF: waiting for debug server on :2331...", vim.log.levels.INFO)

  _debug_timer:start(2000, 500, vim.schedule_wrap(function()
    attempts = attempts + 1
    local tcp = vim.loop.new_tcp()
    tcp:connect("127.0.0.1", 2331, function(err)
      tcp:close()
      if not err then
        _debug_timer:stop()
        _debug_timer:close()
        _debug_timer = nil
        vim.schedule(function()
          local elf = require("ncs-tools.utils").find_elf(build_dir)
          if not elf then
            vim.notify("DAP: could not find zephyr.elf in " .. build_dir, vim.log.levels.ERROR)
            return
          end
          require("dap").run({
            name = "nRF: Attach (J-Link :2331)",
            type = "cppdbg",
            request = "launch",
            program = elf,
            MIMode = "gdb",
            miDebuggerPath = gdb_path,
            miDebuggerServerAddress = "localhost:2331",
            serverLaunchTimeout = 10000,
            stopAtEntry = false,
            cwd = vim.fn.getcwd(),
            postRemoteConnectCommands = {
              { text = "monitor reset", ignoreFailures = true },
              { text = "load", ignoreFailures = true },
            },
          })
        end)
      elseif attempts >= max_attempts then
        _debug_timer:stop()
        _debug_timer:close()
        _debug_timer = nil
        vim.schedule(function()
          vim.notify("nRF: debug server did not start in time", vim.log.levels.WARN)
        end)
      end
    end)
  end))
end

local function execute_build(config, utils)
  local venv_prefix = utils.get_venv_prefix()
  local zephyr_base_flag = "ZEPHYR_BASE=" .. config.sdk_path .. "/zephyr "
  local source_flag, build_dir_flag = "", ""
  local abs_build_dir = vim.fn.getcwd() .. "/build"
  if config.source_dir_relative and config.source_dir_relative ~= "." then
    source_flag = " -s " .. config.source_dir_relative
    abs_build_dir = vim.fn.getcwd() .. "/" .. config.source_dir_relative .. "/build"
    build_dir_flag = " --build-dir " .. abs_build_dir
  end

  local flash_cmd = "(cd " .. config.sdk_path .. " && west flash --build-dir " .. abs_build_dir .. ")"

  local build_cmd = ""
  local launch_dap = false
  if config.build_action == "Build" then
    build_cmd = venv_prefix .. zephyr_base_flag .. "west build -b " .. config.board .. source_flag .. build_dir_flag
  elseif config.build_action == "Build (pristine)" then
    build_cmd = venv_prefix
      .. zephyr_base_flag
      .. "west build -b "
      .. config.board
      .. source_flag
      .. build_dir_flag
      .. " --pristine"
  elseif config.build_action == "Build and Flash" then
    build_cmd = venv_prefix
      .. zephyr_base_flag
      .. "west build -b "
      .. config.board
      .. source_flag
      .. build_dir_flag
      .. " && "
      .. flash_cmd
  elseif config.build_action == "Build and Debug" then
    -- Build + flash only; JLinkGDBServer is started separately without -singlerun
    build_cmd = venv_prefix
      .. zephyr_base_flag
      .. "west build -b "
      .. config.board
      .. source_flag
      .. build_dir_flag
      .. " && "
      .. flash_cmd
    launch_dap = true
  end

  utils.save_recent_build(config)
  print("Executing: " .. build_cmd)

  local escaped = build_cmd:gsub("'", "'\\''")
  local function run_build()
    vim.cmd("TermExec cmd='" .. escaped .. "'")
    if launch_dap then
      -- Read device + gdb from runners.yaml, start GDB server directly
      vim.defer_fn(function()
        local jlink_cfg = utils.get_jlink_config(abs_build_dir)
        if not jlink_cfg then
          vim.notify("nRF: could not read runners.yaml from " .. abs_build_dir, vim.log.levels.ERROR)
          return
        end
        -- Kill any lingering J-Link GDB server, then start a fresh one in terminal 2
        vim.fn.system("pkill -f JLinkGDBServer")
        local srv_cmd = string.format(
          "JLinkGDBServerCLExe -select USB -device %s -if SWD -speed 4000 -port 2331 -nogui",
          jlink_cfg.device
        )
        local escaped_srv = srv_cmd:gsub("'", "'\\''")
        vim.cmd("TermExec cmd='" .. escaped_srv .. "' id=2")
        launch_dap_when_ready(abs_build_dir, jlink_cfg.gdb)
      end, 500) -- small delay so the flash command is sent to the terminal first
    end
  end

  -- Send C-a C-x to gracefully exit picocom only if it's actually running
  local picocom_pid = vim.fn.system("pgrep -x picocom"):gsub("%s+", "")
  if picocom_pid ~= "" then
    local ok, terms = pcall(require, "toggleterm.terminal")
    if ok then
      local term = terms.get(1)
      if term and term.job_id and term.job_id > 0 then
        vim.fn.chansend(term.job_id, "\x01\x18")
        vim.defer_fn(run_build, 800)
        return
      end
    end
  end
  run_build()
end

-- Edit a single field, then reopen the editor
local function show_config_editor(utils, boards, config, on_run)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local fields = {
    { key = "sdk_version", label = "SDK", value = config.sdk_version or "?" },
    { key = "board", label = "Board", value = config.board or "?" },
    { key = "source_dir_relative", label = "Source", value = config.source_dir_relative or "." },
    { key = "build_action", label = "Action", value = config.build_action or "?" },
    { key = "optimization", label = "Optim", value = config.optimization or "?" },
  }

  local function edit_field(field_key, callback)
    if field_key == "sdk_version" then
      local versions = utils.get_ncs_versions()
      local names = {}
      for _, v in ipairs(versions) do
        table.insert(names, v.version)
      end
      names = reorder_first(names, config.sdk_version)
      vim.ui.select(names, { prompt = "SDK Version:" }, function(choice)
        if not choice then
          callback(config)
          return
        end
        config.sdk_version = choice
        for _, v in ipairs(versions) do
          if v.version == choice then
            config.sdk_path = v.path
            break
          end
        end
        callback(config)
      end)
    elseif field_key == "board" then
      local versions = utils.get_ncs_versions()
      local sdk_path = config.sdk_path
      if not sdk_path then
        for _, v in ipairs(versions) do
          if v.version == config.sdk_version then
            sdk_path = v.path
            break
          end
        end
      end
      local board_list = boards.get_all_board_variants(sdk_path or versions[1].path)
      board_list = reorder_first(board_list, config.board)
      table.insert(board_list, "custom")
      vim.ui.select(board_list, { prompt = "Board:" }, function(choice)
        if not choice then
          callback(config)
          return
        end
        if choice == "custom" then
          vim.ui.input({ prompt = "Custom board: ", default = config.board or "" }, function(val)
            if val and val ~= "" then
              config.board = val
            end
            callback(config)
          end)
        else
          config.board = choice
          callback(config)
        end
      end)
    elseif field_key == "source_dir_relative" then
      local build_dirs = scan_build_directories(vim.fn.getcwd(), 3)
      local options = {}
      for _, d in ipairs(build_dirs) do
        table.insert(options, d.display)
      end
      options = reorder_first(options, config.source_dir_relative)
      table.insert(options, "Custom path...")
      vim.ui.select(options, { prompt = "Source Directory:" }, function(choice, idx)
        if not choice then
          callback(config)
          return
        end
        if choice == "Custom path..." then
          vim.ui.input({ prompt = "Path: ", default = config.source_dir_relative or "" }, function(val)
            if val and val ~= "" then
              config.source_dir_relative = val
              config.source_dir = vim.fn.fnamemodify(val, ":p")
            end
            callback(config)
          end)
        else
          local dir = build_dirs[idx] or build_dirs[1]
          config.source_dir_relative = dir.relative
          config.source_dir = dir.path
          callback(config)
        end
      end)
    elseif field_key == "build_action" then
      local actions_list = reorder_first(get_build_actions(), config.build_action)
      vim.ui.select(actions_list, { prompt = "Build Action:" }, function(choice)
        if choice then
          config.build_action = choice
        end
        callback(config)
      end)
    elseif field_key == "optimization" then
      local opt_list = reorder_first(get_optimization_levels(), config.optimization)
      vim.ui.select(opt_list, { prompt = "Optimization:" }, function(choice)
        if choice then
          config.optimization = choice
        end
        callback(config)
      end)
    end
  end

  pickers
    .new({}, {
      prompt_title = "Build Config  [CR: run | e: change]",
      finder = finders.new_table({
        results = fields,
        entry_maker = function(f)
          return {
            value = f,
            display = string.format("%-8s  %s", f.label, f.value),
            ordinal = f.label .. " " .. f.value,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          on_run(config)
        end)

        map("n", "e", function()
          local sel = action_state.get_selected_entry()
          if not sel then
            return
          end
          actions.close(prompt_bufnr)
          edit_field(sel.value.key, function(updated)
            show_config_editor(utils, boards, updated, on_run)
          end)
        end)

        return true
      end,
    })
    :find()
end

local function run_new_wizard(utils, boards)
  local versions = utils.get_ncs_versions()
  if #versions == 0 then
    print("No NCS versions found")
    return
  end

  local version_names = {}
  for _, v in ipairs(versions) do
    table.insert(version_names, v.version)
  end

  vim.ui.select(version_names, { prompt = "SDK Version:" }, function(sdk_choice, idx)
    if not sdk_choice or not idx then
      return
    end
    local selected_version = versions[idx]
    local config = { sdk_version = sdk_choice, sdk_path = selected_version.path }

    print("Scanning boards in " .. selected_version.version .. "...")
    local board_list = boards.get_all_board_variants(selected_version.path)
    if #board_list == 0 then
      print("No boards found")
      return
    end
    table.insert(board_list, "custom")

    local function ask_source()
      local build_dirs = scan_build_directories(vim.fn.getcwd(), 3)
      local options = {}
      for _, d in ipairs(build_dirs) do
        table.insert(options, d.display)
      end
      table.insert(options, "Custom path...")
      vim.ui.select(options, { prompt = "Source Directory:" }, function(choice, sidx)
        if not choice then
          return
        end
        if choice == "Custom path..." then
          vim.ui.input({ prompt = "Path: " }, function(val)
            if val and val ~= "" then
              config.source_dir_relative = val
              config.source_dir = vim.fn.fnamemodify(val, ":p")
            else
              config.source_dir_relative = "."
            end
            ask_action()
          end)
        else
          local dir = build_dirs[sidx] or build_dirs[1]
          config.source_dir_relative = dir and dir.relative or "."
          config.source_dir = dir and dir.path or nil
          ask_action()
        end
      end)
    end

    function ask_action()
      vim.ui.select(get_build_actions(), { prompt = "Build Action:" }, function(choice)
        if not choice then
          return
        end
        config.build_action = choice
        ask_optimization()
      end)
    end

    function ask_optimization()
      vim.ui.select(get_optimization_levels(), { prompt = "Optimization:" }, function(choice)
        if not choice then
          return
        end
        config.optimization = choice
        execute_build(config, utils)
      end)
    end

    local function continue_with_board(board_choice)
      local variants = boards.get_board_variants(board_choice, selected_version.path)
      if #variants > 0 then
        table.insert(variants, "Use base name: " .. board_choice)
        vim.ui.select(variants, { prompt = "Board Variant:" }, function(variant_choice)
          if not variant_choice then
            return
          end
          if variant_choice:match("^Use base name:") then
            config.board = board_choice
          else
            config.board = variant_choice
          end
          ask_source()
        end)
      else
        config.board = board_choice
        ask_source()
      end
    end

    vim.ui.select(board_list, { prompt = "Board Target (" .. (#board_list - 1) .. " boards):" }, function(board_choice)
      if not board_choice then
        return
      end
      if board_choice == "custom" then
        vim.ui.input({ prompt = "Custom board name: " }, function(val)
          if val and val ~= "" then
            continue_with_board(val)
          end
        end)
      else
        continue_with_board(board_choice)
      end
    end)
  end)
end

function M.configuration()
  local utils = require("ncs-tools.utils")
  local boards = require("ncs-tools.boards")

  local recent = utils.load_recent_builds()
  if #recent == 0 then
    run_new_wizard(utils, boards)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local items = {}
  for _, b in ipairs(recent) do
    table.insert(items, b)
  end
  table.insert(items, { label = "New configuration...", _new = true })

  pickers
    .new({}, {
      prompt_title = "Build  [CR: run | e: edit | f: flash | p: pristine | d: debug]",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return { value = item, display = item.label, ordinal = item.label }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local sel = action_state.get_selected_entry()
          if not sel then
            return
          end
          if sel.value._new then
            run_new_wizard(utils, boards)
          else
            execute_build(sel.value, utils)
          end
        end)

        map("n", "e", function()
          local sel = action_state.get_selected_entry()
          if not sel or sel.value._new then
            return
          end
          actions.close(prompt_bufnr)
          show_config_editor(utils, boards, sel.value, function(c)
            execute_build(c, utils)
          end)
        end)

        local function run_with_action(action)
          local sel = action_state.get_selected_entry()
          if not sel or sel.value._new then
            return
          end
          actions.close(prompt_bufnr)
          local config = vim.tbl_extend("force", {}, sel.value)
          config.build_action = action
          execute_build(config, utils)
        end

        map("n", "f", function()
          run_with_action("Build and Flash")
        end)
        map("n", "p", function()
          run_with_action("Build (pristine)")
        end)
        map("n", "d", function()
          run_with_action("Build and Debug")
        end)

        return true
      end,
    })
    :find()
end

return M
