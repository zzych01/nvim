-- File: nvim/lua/zib/ncs-tools/utils.lua
local M = {}

local ncs_search_paths = {
  vim.env.HOME .. "/ncs",
  "/opt/nordic/ncs",
}

function M.get_ncs_versions()
  local versions = {}

  for _, ncs_base in ipairs(ncs_search_paths) do
    if vim.fn.isdirectory(ncs_base) == 1 then
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
    end
  end

  if #versions == 0 then
    print("NCS directory not found in: " .. table.concat(ncs_search_paths, ", "))
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
    for _, ncs_base in ipairs(ncs_search_paths) do
      vim.opt.path:remove(ncs_base .. "/**/include/**")
    end

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

local MAX_RECENT_BUILDS = 5

function M.load_recent_builds()
  local builds_file = vim.fn.getcwd() .. "/.ncs_builds.json"
  if vim.fn.filereadable(builds_file) == 0 then
    return {}
  end
  local content = table.concat(vim.fn.readfile(builds_file), "\n")
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or type(data) ~= "table" then
    return {}
  end
  return data
end

function M.save_recent_build(config)
  local source_display = config.source_dir_relative == "." and vim.fn.fnamemodify(vim.fn.getcwd(), ":t") or config.source_dir_relative
  config.label = config.board .. " · " .. source_display .. " · " .. config.build_action

  local builds = M.load_recent_builds()
  local new_builds = {}
  for _, b in ipairs(builds) do
    if b.label ~= config.label then
      table.insert(new_builds, b)
    end
  end
  table.insert(new_builds, 1, config)
  while #new_builds > MAX_RECENT_BUILDS do
    table.remove(new_builds)
  end
  local ok, encoded = pcall(vim.fn.json_encode, new_builds)
  if ok then
    vim.fn.writefile({ encoded }, vim.fn.getcwd() .. "/.ncs_builds.json")
  end
end

function M.get_venv_prefix()
  local cwd = vim.fn.getcwd()
  local venv_activate = cwd .. "/.venv/bin/activate"
  if vim.fn.filereadable(venv_activate) == 1 then
    return "source " .. venv_activate .. " && "
  end
  return ""
end

function M.link_compile_commands()
  local build_dir = vim.fn.getcwd() .. "/build"
  if vim.fn.isdirectory(build_dir) == 0 then
    print("No build/ directory found — run a build first")
    return
  end

  -- Collect all compile_commands.json files one level deep in build/
  local found = {}
  local handle = vim.loop.fs_scandir(build_dir)
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      if type == "directory" then
        local candidate = build_dir .. "/" .. name .. "/compile_commands.json"
        if vim.fn.filereadable(candidate) == 1 then
          table.insert(found, { label = name, path = candidate })
        end
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end

  if #found == 0 then
    print("No compile_commands.json found in build/ subdirectories")
    return
  end

  local function do_link(entry)
    local target = build_dir .. "/compile_commands.json"
    vim.fn.system("ln -sf " .. vim.fn.shellescape(entry.path) .. " " .. vim.fn.shellescape(target))
    if vim.v.shell_error == 0 then
      print("Linked: build/compile_commands.json -> build/" .. entry.label .. "/compile_commands.json")
      vim.cmd("LspRestart")
    else
      print("Failed to create symlink")
    end
  end

  if #found == 1 then
    do_link(found[1])
  else
    local labels = {}
    for _, e in ipairs(found) do
      table.insert(labels, e.label)
    end
    vim.ui.select(labels, { prompt = "Link compile_commands.json from:" }, function(choice, idx)
      if choice then
        do_link(found[idx])
      end
    end)
  end
end

function M.show_project_info()
  local cwd = vim.fn.getcwd()
  local ncs_match = nil
  for _, ncs_base in ipairs(ncs_search_paths) do
    ncs_match = cwd:match(vim.pesc(ncs_base) .. "/([^/]+)")
    if ncs_match then break end
  end

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
