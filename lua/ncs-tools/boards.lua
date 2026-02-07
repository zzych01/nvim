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

-- Get all board variants using west boards command
local function get_all_board_variants(version_path)
  local boards = {}
  
  -- Try to run west boards command from current workspace (where user is building)
  -- This will give us all board variants with full qualified names
  local current_dir = vim.fn.getcwd()
  local handle = io.popen("cd " .. vim.fn.shellescape(current_dir) .. " && west boards 2>/dev/null")
  if handle then
    for line in handle:lines() do
      line = vim.trim(line)
      if line ~= "" and not line:match("^%s*$") and not line:match("^%s*#") then
        -- Filter out comment lines
        table.insert(boards, line)
      end
    end
    handle:close()
  end
  
  -- If west boards failed or returned no results, fall back to scanning
  if #boards == 0 then
    local scanned_boards = get_all_boards(version_path)
    for _, board in ipairs(scanned_boards) do
      local board_info = get_board_info(board.path)
      if board_info.identifier then
        table.insert(boards, board_info.identifier)
      else
        -- Use display_name as fallback (includes path like zephyr/boards/arm/nrf54l15dk)
        -- Convert to board identifier format
        local display = board.display_name
        -- Try to extract board identifier from path
        -- e.g., "zephyr/boards/arm/nrf54l15dk" -> "nrf54l15dk"
        local board_name = display:match("([^/]+)$")
        if board_name then
          table.insert(boards, board_name)
        end
      end
    end
  end
  
  table.sort(boards)
  return boards
end

-- Export functions for use in other modules
function M.get_all_boards(version_path)
  return get_all_boards(version_path)
end

function M.get_board_info(board_path)
  return get_board_info(board_path)
end

function M.get_all_board_variants(version_path)
  return get_all_board_variants(version_path)
end

-- Get variants for a specific board by scanning _defconfig files
function M.get_board_variants(board_name, version_path)
  local variants = {}
  
  -- Find the board directory by scanning
  local scanned_boards = get_all_boards(version_path)
  local board_path = nil
  
  for _, board in ipairs(scanned_boards) do
    if board.name == board_name then
      board_path = board.path
      break
    end
  end
  
  if not board_path then
    return variants
  end
  
  -- Scan for _defconfig files to find all board variants
  local handle = vim.loop.fs_scandir(board_path)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      if type == "file" and name:match("^" .. board_name .. "_.*_defconfig$") then
        local variant_part = name:match("^" .. board_name .. "_(.+)_defconfig$")
        if variant_part then
          local parts = {}
          for part in variant_part:gmatch("[^_]+") do
            table.insert(parts, part)
          end
          local full_variant = board_name .. "/" .. table.concat(parts, "/")
          
          local exists = false
          for _, v in ipairs(variants) do
            if v == full_variant then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(variants, full_variant)
          end
        end
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end
  
  table.sort(variants)
  return variants
end

return M
