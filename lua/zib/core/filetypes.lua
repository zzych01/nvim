-- nvim/lua/zib/core/filetypes.lua
local function is_zephyr_project(path)
  return vim.fs.find({ "west.yml", "Kconfig" }, { upward = true, path = vim.fn.fnamemodify(path, ":h") })[1] ~= nil
end

vim.filetype.add({
  pattern = {
    [".*%.conf"] = function(path)
      if is_zephyr_project(path) then return "kconfig" end
    end,
    [".*defconfig"] = function(path)
      if is_zephyr_project(path) then return "kconfig" end
    end,
    ["Kconfig%..*"] = "kconfig",
  },
})
