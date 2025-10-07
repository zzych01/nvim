return {
  "Civitasv/cmake-tools.nvim",
  ft = { "cmake", "c", "cpp" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("cmake-tools").setup({
      cmake_command = "cmake",
      cmake_build_directory = "build",
      cmake_build_directory_prefix = "",
      cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
      cmake_build_options = {},
      cmake_console_size = 10,
      cmake_show_console = "always",
      cmake_dap_configuration = {
        name = "cpp",
        type = "codelldb",
        request = "launch",
      },
      cmake_variants_message = {
        short = { show = true },
        long = { show = true, max_length = 40 },
      },
    })

    -- Keymaps
    local keymap = vim.keymap
    keymap.set("n", "<leader>cg", "<cmd>CMakeGenerate<cr>", { desc = "CMake Generate" })
    keymap.set("n", "<leader>cb", "<cmd>CMakeBuild<cr>", { desc = "CMake Build" })
    keymap.set("n", "<leader>cr", "<cmd>CMakeRun<cr>", { desc = "CMake Run" })
    keymap.set("n", "<leader>cd", "<cmd>CMakeDebug<cr>", { desc = "CMake Debug" })
    keymap.set("n", "<leader>cc", "<cmd>CMakeClean<cr>", { desc = "CMake Clean" })
    keymap.set("n", "<leader>ct", "<cmd>CMakeSelectBuildTarget<cr>", { desc = "CMake Select Build Target" })
    keymap.set("n", "<leader>cT", "<cmd>CMakeSelectBuildType<cr>", { desc = "CMake Select Build Type" })
  end,
}
