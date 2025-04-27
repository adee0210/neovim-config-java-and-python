local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Terminal Python
local python_term = nil
local function run_python_in_terminal()
    local file = vim.fn.expand("%:p")
    local cmd = "~/.python_envs/global_env/bin/python " .. file
    local term = require("toggleterm.terminal").Terminal

    if not python_term then
        python_term = term:new({
            hidden = true,
            direction = "horizontal",
            on_open = function(t)
                t:clear()
                t:send(cmd, false)
            end,
            on_close = function()
                python_term = nil
            end,
        })
    end
    python_term:toggle()
end

-- Hàm để thay đổi đường dẫn Python
local function change_python_path(bufnr)
    -- Nhập đường dẫn Python mới từ người dùng
    vim.ui.input({
        prompt = "Nhập đường dẫn Python (ví dụ: ~/.python_envs/my_env/bin/python): ",
        default = vim.fn.expand("~/.python_envs/global_env/bin/python"),
    }, function(input)
        if input and input ~= "" then
            local new_python_path = vim.fn.expand(input)
            local new_extra_paths = { vim.fn.expand(input:gsub("/bin/python$", "/lib/python3.12/site-packages")) }

            -- Cập nhật cấu hình Pyright
            lspconfig.pyright.setup({
                capabilities = capabilities,
                filetypes = { "python" },
                settings = {
                    python = {
                        analysis = {
                            extraPaths = new_extra_paths, -- Cập nhật extraPaths
                        },
                        pythonPath = new_python_path,     -- Cập nhật pythonPath
                    },
                },
                on_attach = function(client, bufnr)
                    python_keymaps(bufnr) -- Gắn lại phím tắt
                end,
            })

            -- Thông báo thành công
            vim.notify("Đã cập nhật đường dẫn Python: " .. new_python_path, vim.log.levels.INFO)

            -- Khởi động lại LSP nếu đang chạy
            vim.lsp.stop_client(vim.lsp.get_active_clients({ name = "pyright" }))
            vim.defer_fn(function()
                vim.cmd("LspRestart pyright")
            end, 500)
        else
            vim.notify("Hủy thay đổi đường dẫn Python", vim.log.levels.WARN)
        end
    end)
end

-- Keymaps
local function python_keymaps(bufnr)
    local opts = { buffer = bufnr }
    vim.keymap.set("n", "<leader>Pd", "<Cmd>lua require('dap').continue()<CR>",
        vim.tbl_extend("force", opts, { desc = "Chạy gỡ lỗi" }))
    vim.keymap.set("n", "<leader>Pb", "<Cmd>lua require('dap').toggle_breakpoint()<CR>",
        vim.tbl_extend("force", opts, { desc = "Bật/Tắt điểm ngắt" }))
    vim.keymap.set("n", "<leader>Pv", "<Cmd>lua require('refactoring').refactor('Extract Variable')<CR>",
        vim.tbl_extend("force", opts, { desc = "Trích xuất biến" }))
    vim.keymap.set("n", "<leader>Pr", run_python_in_terminal,
        vim.tbl_extend("force", opts, { desc = "Chạy file Python" }))
    vim.keymap.set("n", "<leader>Pp", function() change_python_path(bufnr) end,
        vim.tbl_extend("force", opts, { desc = "Đổi đường dẫn Python" })) -- Phím tắt mới
end

-- Cấu hình Pyright
local function setup_pyright()
    lspconfig.pyright.setup({
        capabilities = capabilities,
        filetypes = { "python" },
        settings = {
            python = {
                analysis = {
                    extraPaths = { vim.fn.expand("~/.python_envs/global_env/lib/python3.12/site-packages") },
                },
                pythonPath = vim.fn.expand("~/.python_envs/global_env/bin/python"),
            },
        },
        on_attach = function(client, bufnr)
            python_keymaps(bufnr)
        end,
    })
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python" },
    callback = function()
        if not lspconfig.pyright.document_config then
            setup_pyright()
        end
    end,
})

return { setup_pyright = setup_pyright }
