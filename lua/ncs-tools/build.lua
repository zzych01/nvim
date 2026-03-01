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

local function execute_build(config, utils)
  local venv_prefix = utils.get_venv_prefix()
  local zephyr_base_flag = "ZEPHYR_BASE=" .. config.sdk_path .. "/zephyr "
  local source_flag = ""
  if config.source_dir_relative ~= "." then
    source_flag = " -s " .. config.source_dir_relative
  end

  local build_cmd = ""
  if config.build_action == "Build" then
    build_cmd = venv_prefix .. zephyr_base_flag .. "west build -b " .. config.board .. source_flag
  elseif config.build_action == "Build (pristine)" then
    build_cmd = venv_prefix .. zephyr_base_flag .. "west build -b " .. config.board .. source_flag .. " --pristine"
  elseif config.build_action == "Build and Flash" then
    build_cmd = venv_prefix .. zephyr_base_flag .. "west build -b " .. config.board .. source_flag .. " && west flash"
  elseif config.build_action == "Build and Debug" then
    build_cmd = venv_prefix .. zephyr_base_flag .. "west build -b " .. config.board .. source_flag .. " && west debug"
  end

  utils.save_recent_build(config)
  print("Executing: " .. build_cmd)
  vim.cmd("TermExec cmd='" .. build_cmd .. "'")
end

local function run_wizard(utils, boards)
  local config = {}

  local versions = utils.get_ncs_versions()
  if #versions == 0 then
    print("No NCS versions found")
    return
  end

  local version_names = {}
  for _, v in ipairs(versions) do
    table.insert(version_names, v.version)
  end

  vim.ui.select(version_names, {
    prompt = "SDK Version:",
  }, function(sdk_choice, idx)
    if not sdk_choice or not idx then
      return
    end
    config.sdk_version = sdk_choice

    local selected_version = versions[idx]
    config.sdk_path = selected_version.path
    print("Scanning boards in " .. selected_version.version .. "...")

    local board_list = boards.get_all_board_variants(selected_version.path)

    if #board_list == 0 then
      print("No boards found in " .. selected_version.version)
      return
    end

    table.insert(board_list, "custom")

    local function continue_with_optimization()
      local opt_levels = get_optimization_levels()
      vim.ui.select(opt_levels, {
        prompt = "Optimization Level:",
      }, function(opt_choice)
        if not opt_choice then
          return
        end
        config.optimization = opt_choice

        local build_types = {
          "Build",
          "Build (pristine)",
          "Build and Flash",
          "Build and Debug",
        }

        vim.ui.select(build_types, {
          prompt = "Build Action:",
        }, function(build_choice)
          if not build_choice then
            return
          end
          config.build_action = build_choice
          execute_build(config, utils)
        end)
      end)
    end

    local function continue_config()
      local current_dir = vim.fn.getcwd()
      print("Scanning for build directories...")
      local build_dirs = scan_build_directories(current_dir, 3)

      if #build_dirs == 0 then
        print("No directories with CMakeLists.txt found. Using current directory.")
        config.source_dir = current_dir
        config.source_dir_relative = "."
        continue_with_optimization()
        return
      end

      local dir_options = {}
      for _, dir in ipairs(build_dirs) do
        table.insert(dir_options, dir.display)
      end
      table.insert(dir_options, "Custom path...")

      vim.ui.select(dir_options, {
        prompt = "Source Directory (" .. #build_dirs .. " found):",
      }, function(dir_choice, dir_idx)
        if not dir_choice then
          return
        end

        if dir_choice == "Custom path..." then
          vim.ui.input({
            prompt = "Custom source directory path: ",
            default = current_dir,
            completion = "dir",
          }, function(custom_path)
            if custom_path and custom_path ~= "" then
              config.source_dir = vim.fn.fnamemodify(custom_path, ":p")
              config.source_dir_relative = custom_path
              continue_with_optimization()
            end
          end)
        else
          local selected_dir = build_dirs[dir_idx]
          config.source_dir = selected_dir.path
          config.source_dir_relative = selected_dir.relative
          continue_with_optimization()
        end
      end)
    end

    vim.ui.select(board_list, {
      prompt = "Board Target (" .. (#board_list - 1) .. " boards):",
    }, function(board_choice)
      if not board_choice then
        return
      end

      if board_choice == "custom" then
        vim.ui.input({
          prompt = "Custom board name: ",
        }, function(custom_board)
          if custom_board and custom_board ~= "" then
            config.board = custom_board
            continue_config()
          end
        end)
      else
        local variants = boards.get_board_variants(board_choice, selected_version.path)

        if #variants > 0 then
          table.insert(variants, "Use base name: " .. board_choice)
          vim.ui.select(variants, {
            prompt = "Board Variant:",
          }, function(variant_choice)
            if not variant_choice then
              return
            end

            if variant_choice:match("^Use base name:") then
              config.board = board_choice
            else
              config.board = variant_choice
            end
            continue_config()
          end)
        else
          config.board = board_choice
          continue_config()
        end
      end
    end)
  end)
end

function M.configuration()
  local utils = require("ncs-tools.utils")
  local boards = require("ncs-tools.boards")

  local recent = utils.load_recent_builds()
  if #recent == 0 then
    run_wizard(utils, boards)
    return
  end

  local options = {}
  for _, b in ipairs(recent) do
    table.insert(options, b.label)
  end
  table.insert(options, "New configuration...")

  vim.ui.select(options, {
    prompt = "Build:",
  }, function(choice, idx)
    if not choice then
      return
    end
    if choice == "New configuration..." then
      run_wizard(utils, boards)
    else
      execute_build(recent[idx], utils)
    end
  end)
end

return M
