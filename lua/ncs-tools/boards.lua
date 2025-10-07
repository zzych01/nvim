-- File: nvim/lua/zib/ncs-tools/boards.lua
local M = {}

local function is_board_directory(path)
  local board_files = {
    "board.yml",
    "board.yaml",
    "Kconfig.board",
    "Kconfig.defconfig",
  }

  for _, file in ipairs(board_files) do
    if vim.fn.filereadable(path .. "/" .. file) == 1 then
      return true
    end
  end

  -- Also check for .conf files
  local handle = vim.loop.fs_scandir(path)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      if type == "file" and name:match("%.conf$") then
        return true
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end

  return false
end

local function scan_boards_recursive(base_path, prefix, boards, max_depth)
  if max_depth <= 0 or vim.fn.isdirectory(base_path) == 0 then
    return
  end

  local handle = vim.loop.fs_scandir(base_path)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      local full_path = base_path .. "/" .. name
      if type == "directory" then
        if is_board_directory(full_path) then
          table.insert(boards, {
            display_name = prefix .. "/" .. name,
            path = full_path,
            name = name,
          })
        else
          scan_boards_recursive(full_path, prefix .. "/" .. name, boards, max_depth - 1)
        end
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end
end

local function get_all_boards(version_path)
  local boards = {}

  scan_boards_recursive(version_path .. "/nrf/boards/nordic", "nrf/nordic", boards, 2)
  scan_boards_recursive(version_path .. "/nrf/boards/shields", "nrf/shields", boards, 2)
  scan_boards_recursive(version_path .. "/zephyr/boards", "zephyr", boards, 3)

  table.sort(boards, function(a, b)
    return a.display_name < b.display_name
  end)

  return boards
end

local function get_board_info(board_path)
  local info = {
    name = vim.fn.fnamemodify(board_path, ":t"),
    path = board_path,
    configs = {},
  }

  local handle = vim.loop.fs_scandir(board_path)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      if type == "file" and name:match("%.conf$") then
        table.insert(info.configs, name)
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end

  local board_yml = board_path .. "/board.yml"
  if vim.fn.filereadable(board_yml) == 1 then
    local content = vim.fn.readfile(board_yml)
    for _, line in ipairs(content) do
      local identifier = line:match("identifier:%s*(.+)")
      if identifier then
        info.identifier = vim.trim(identifier)
        break
      end
    end
  end

  return info
end

function M.browser()
  local utils = require("ncs-tools.utils")
  local versions = utils.get_ncs_versions()

  if #versions == 0 then
    print("No NCS versions found")
    return
  end

  local version_items = {}
  for _, v in ipairs(versions) do
    table.insert(version_items, "NCS " .. v.version)
  end

  vim.ui.select(version_items, {
    prompt = "Select NCS Version:",
  }, function(choice, idx)
    if not choice or not idx then
      return
    end

    local selected_version = versions[idx]
    print("Scanning boards in " .. selected_version.version .. "...")

    local boards = get_all_boards(selected_version.path)

    if #boards == 0 then
      print("No boards found in " .. selected_version.version)
      return
    end

    local board_names = {}
    for _, board in ipairs(boards) do
      table.insert(board_names, board.display_name)
    end

    vim.ui.select(board_names, {
      prompt = "Select Board (" .. selected_version.version .. ") [" .. #boards .. " boards]:",
    }, function(board_choice, board_idx)
      if not board_choice or not board_idx then
        return
      end

      local selected_board = boards[board_idx]
      local board_info = get_board_info(selected_board.path)

      print("Board: " .. selected_board.name)
      print("Path: " .. selected_board.path)
      if board_info.identifier then
        print("Identifier: " .. board_info.identifier)
      end
      if #board_info.configs > 0 then
        print("Configurations: " .. table.concat(board_info.configs, ", "))
      end

      if board_info.identifier then
        vim.fn.setreg("+", board_info.identifier)
        print("Board identifier copied to clipboard: " .. board_info.identifier)
      elseif selected_board.name then
        vim.fn.setreg("+", selected_board.name)
        print("Board name copied to clipboard: " .. selected_board.name)
      end
    end)
  end)
end

function M.get_available_boards()
  return {
    "nrf52840dk_nrf52840",
    "nrf52833dk_nrf52833",
    "nrf52dk_nrf52832",
    "nrf5340dk_nrf5340_cpuapp",
    "nrf5340dk_nrf5340_cpunet",
    "nrf9160dk_nrf9160_ns",
    "thingy91_nrf9160_ns",
    "thingy52_nrf52832",
    "custom",
  }
end

return M
