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

function M.configuration()
  local utils = require("ncs-tools.utils")
  local boards = require("ncs-tools.boards")
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
  }, function(sdk_choice)
    if not sdk_choice then
      return
    end
    config.sdk_version = sdk_choice

    local board_list = boards.get_available_boards()
    vim.ui.select(board_list, {
      prompt = "Board Target:",
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
        config.board = board_choice
        continue_config()
      end
    end)

    local function continue_config()
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

          local build_cmd = "cd " .. vim.fn.getcwd() .. " && "

          if build_choice == "Build" then
            build_cmd = build_cmd .. "west build -b " .. config.board
          elseif build_choice == "Build (pristine)" then
            build_cmd = build_cmd .. "west build -b " .. config.board .. " --pristine"
          elseif build_choice == "Build and Flash" then
            build_cmd = build_cmd .. "west build -b " .. config.board .. " && west flash"
          elseif build_choice == "Build and Debug" then
            build_cmd = build_cmd .. "west build -b " .. config.board .. " && west debug"
          end

          print("Executing: " .. build_cmd)
          vim.cmd("TermExec cmd='" .. build_cmd .. "'")
        end)
      end)
    end
  end)
end

return M
