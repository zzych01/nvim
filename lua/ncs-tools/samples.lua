-- File: nvim/lua/zib/ncs-tools/samples.lua
local M = {}

local function scan_samples_recursive(base_path, prefix, samples)
  if vim.fn.isdirectory(base_path) == 0 then
    return
  end

  local handle = vim.loop.fs_scandir(base_path)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      local full_path = base_path .. "/" .. name
      if type == "directory" then
        local has_cmakelists = vim.fn.filereadable(full_path .. "/CMakeLists.txt") == 1
        local has_prj_conf = vim.fn.filereadable(full_path .. "/prj.conf") == 1

        if has_cmakelists or has_prj_conf then
          table.insert(samples, {
            display_name = prefix .. "/" .. name,
            path = full_path,
            name = name,
          })
        else
          scan_samples_recursive(full_path, prefix .. "/" .. name, samples)
        end
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end
end

local function get_all_samples(version_path)
  local samples = {}

  scan_samples_recursive(version_path .. "/nrf/samples", "nrf", samples)
  scan_samples_recursive(version_path .. "/zephyr/samples", "zephyr", samples)

  table.sort(samples, function(a, b)
    return a.display_name < b.display_name
  end)

  return samples
end

local function handle_sample_action(sample_path, sample_name)
  local utils = require("ncs-tools.utils")

  local actions = {
    "Navigate to sample",
    "Copy to current directory",
    "Copy to custom location",
  }

  vim.ui.select(actions, {
    prompt = "Action for " .. sample_name .. ":",
  }, function(choice)
    if not choice then
      return
    end

    if choice == "Navigate to sample" then
      vim.cmd("cd " .. sample_path)
      print("Navigated to: " .. sample_path)
      utils.update_nvim_tree(sample_path)
    elseif choice == "Copy to current directory" then
      local current_dir = vim.fn.getcwd()
      local dest = current_dir .. "/" .. sample_name

      if vim.fn.isdirectory(dest) == 1 then
        print("Directory already exists: " .. dest)
        return
      end

      utils.copy_directory(sample_path, dest)
      vim.cmd("NvimTreeRefresh")
    elseif choice == "Copy to custom location" then
      vim.ui.input({
        prompt = "Destination path: ",
        default = vim.fn.getcwd() .. "/" .. sample_name,
        completion = "dir",
      }, function(dest_path)
        if dest_path and dest_path ~= "" then
          if vim.fn.isdirectory(dest_path) == 1 then
            print("Directory already exists: " .. dest_path)
            return
          end
          utils.copy_directory(sample_path, dest_path)
        end
      end)
    end
  end)
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
    local samples = get_all_samples(selected_version.path)

    if #samples == 0 then
      print("No samples found in " .. selected_version.version)
      return
    end

    local sample_names = {}
    for _, sample in ipairs(samples) do
      table.insert(sample_names, sample.display_name)
    end

    vim.ui.select(sample_names, {
      prompt = "Select Sample (" .. selected_version.version .. "):",
    }, function(sample_choice, sample_idx)
      if not sample_choice or not sample_idx then
        return
      end

      local selected_sample = samples[sample_idx]
      handle_sample_action(selected_sample.path, selected_sample.name)
    end)
  end)
end

return M
