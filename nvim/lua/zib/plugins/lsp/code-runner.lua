-- ~/.config/nvim/lua/zib/plugins/code-runner.lua
return {
  "CRAG666/code_runner.nvim",
  config = function()
    require("code_runner").setup({
      filetype = {
        java = {
          "cd $dir &&",
          "javac $fileName &&",
          "java $fileNameWithoutExt",
        },
        python = {
          "cd $dir &&",
          "python3 -u $fileName",
        },
        typescript = "deno run",
        rust = {
          "cd $dir &&",
          "rustc $fileName &&",
          "$dir/$fileNameWithoutExt",
        },
        javascript = "node",
        c = function(...)
          local c_base = {
            "cd $dir &&",
            "gcc $fileName -o",
            "/tmp/$fileNameWithoutExt",
          }
          local c_exec = {
            "&& /tmp/$fileNameWithoutExt &&",
            "rm /tmp/$fileNameWithoutExt",
          }
          vim.ui.input({ prompt = "Add more args:" }, function(input)
            c_base[4] = input
            vim.print(vim.tbl_extend("force", c_base, c_exec))
            require("code_runner.commands").run_from_fn(vim.list_extend(c_base, c_exec))
          end)
        end,
      },
      mode = "term",
      focus = true,
      startinsert = true,
      term = {
        position = "bot",
        size = 12,
      },
      float = {
        border = "rounded",
        height = 0.8,
        width = 0.8,
        x = 0.5,
        y = 0.5,
      },
      better_term = { -- Toggle mode replacement
        number = 10,
        -- To use a different terminal, add:
        -- init = function()
        --   vim.cmd("set shell=powershell")
        -- end,
      },
      project = {
        ["~/projects/flutter_projects"] = {
          name = "Flutter",
          description = "Flutter project",
          file_name = "lib/main.dart",
          command = "flutter run",
        },
        ["~/projects/python_projects/django"] = {
          name = "Django",
          description = "Django project",
          file_name = "manage.py",
          command = "python manage.py runserver",
        },
        ["~/projects/python_projects/flask"] = {
          name = "Flask",
          description = "Flask project",
          file_name = "app.py",
          command = "flask run",
        },
      },
    })

    -- Keymaps
    local keymap = vim.keymap
    keymap.set("n", "<leader>rc", ":RunCode<CR>", { desc = "Run code" })
    keymap.set("n", "<leader>rf", ":RunFile<CR>", { desc = "Run file" })
    keymap.set("n", "<leader>rft", ":RunFile tab<CR>", { desc = "Run file in tab" })
    keymap.set("n", "<leader>rp", ":RunProject<CR>", { desc = "Run project" })
    keymap.set("n", "<leader>rc", ":RunClose<CR>", { desc = "Close runner" })
    keymap.set("n", "<leader>crf", ":CRFiletype<CR>", { desc = "Open CRFiletype" })
    keymap.set("n", "<leader>crp", ":CRProjects<CR>", { desc = "Open CRProjects" })

    -- VS Code style
    keymap.set("n", "<C-F5>", ":RunCode<CR>", { desc = "Run code" })
  end,
}
