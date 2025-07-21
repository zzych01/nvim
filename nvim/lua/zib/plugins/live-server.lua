return {
  {
    "barrett-ruth/live-server.nvim",
    build = "npm add -g live-server",
    cmd = { "LiveServerStart", "LiveServerStop" },
    keys = {
      { "<leader>ls", ":LiveServerStart<CR>", desc = "Start Live Server" },
      { "<leader>lx", ":LiveServerStop<CR>", desc = "Stop Live Server" },
      {
        "<leader>lr",
        function()
          vim.cmd("LiveServerStop")
          vim.defer_fn(function()
            vim.cmd("LiveServerStart")
          end, 1000)
        end,
        desc = "Restart Live Server",
      },
      {
        "<leader>lo",
        function()
          local url = "http://localhost:3000"
          if vim.fn.has("mac") == 1 then
            vim.fn.system("open " .. url)
          elseif vim.fn.has("unix") == 1 then
            vim.fn.system("xdg-open " .. url)
          end
        end,
        desc = "Open Live Server in Browser",
      },
    },
    config = function()
      require("live-server").setup({
        port = 3000,
        browser_command = "", -- Empty to use system default
        quiet = false,
        no_css_inject = false, -- Set to true to disable CSS injection
      })
    end,
  },
}
