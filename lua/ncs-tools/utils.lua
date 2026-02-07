-- File: nvim/lua/zib/ncs-tools/utils.lua
local M = {}

function M.get_ncs_versions()
  local ncs_base = "/opt/nordic/ncs"
  local versions = {}

  if vim.fn.isdirectory(ncs_base) == 0 then
    print("NCS directory not found at: " .. ncs_base)
    return {}
  end

  local handle = vim.loop.fs_scandir(ncs_base)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      local full_path = ncs_base .. "/" .. name
      if type == "directory" and vim.fn.isdirectory(full_path) == 1 then
        if name:match("^v%d") or name:match("%d%.%d") then
          table.insert(versions, {
            version = name,
            path = full_path,
          })
        end
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end

  table.sort(versions, function(a, b)
    return a.version > b.version
  end)

  return versions
end

function M.copy_directory(src, dest)
  vim.fn.mkdir(dest, "p")
  local cmd = string.format("cp -r %s/* %s/", vim.fn.shellescape(src), vim.fn.shellescape(dest))
  local result = vim.fn.system(cmd)

  if vim.v.shell_error == 0 then
    print("Successfully copied to: " .. dest)
    return true
  else
    print("Error copying directory: " .. result)
    return false
  end
end

function M.update_nvim_tree(path)
  pcall(function()
    local nvim_tree_api = require("nvim-tree.api")

    if nvim_tree_api.tree.is_visible() then
      nvim_tree_api.tree.close()
    end

    nvim_tree_api.tree.change_root(path)
    nvim_tree_api.tree.open()
  end)

  -- Fallback method
  vim.defer_fn(function()
    vim.cmd("NvimTreeClose")
    vim.cmd("NvimTreeOpen")
  end, 100)
end

function M.configure_project_paths()
  local versions = M.get_ncs_versions()

  if #versions == 0 then
    print("No NCS versions found")
    return
  end

  local version_names = {}
  for _, v in ipairs(versions) do
    table.insert(version_names, v.version)
  end

  vim.ui.select(version_names, {
    prompt = "Select NCS Version for include paths:",
  }, function(choice, idx)
    if not choice or not idx then
      return
    end

    local selected = versions[idx]
    local base_path = selected.path

    -- Clear existing NCS paths
    vim.opt.path:remove("/opt/nordic/ncs/**/include/**")

    -- Add new paths
    local paths = {
      base_path .. "/zephyr/include/**",
      base_path .. "/nrf/include/**",
      base_path .. "/zephyr/boards/**",
      base_path .. "/nrf/boards/**",
      base_path .. "/zephyr/dts/**",
      base_path .. "/nrf/dts/**",
      base_path .. "/modules/**/include/**",
    }

    for _, path in ipairs(paths) do
      vim.opt.path:append(path)
    end

    print("Configured paths for NCS " .. selected.version)
    print("Now 'gf' should work on system includes")
  end)
end

function M.show_project_info()
  local cwd = vim.fn.getcwd()
  local ncs_match = cwd:match("/opt/nordic/ncs/([^/]+)")

  if ncs_match then
    print("Current NCS version: " .. ncs_match)
    print("Working directory: " .. cwd)
  else
    print("Not in an NCS directory")
    print("Current directory: " .. cwd)
  end

  if vim.fn.filereadable("CMakeLists.txt") == 1 or vim.fn.filereadable("prj.conf") == 1 then
    print("Detected NCS project in current directory")
  end
end

return M
