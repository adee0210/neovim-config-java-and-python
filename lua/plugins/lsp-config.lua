return {
    -- mason.nvim
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },
    -- mason-lspconfig.nvim
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "pyright",  -- lsp cho python
                    "lua_ls",   -- lua
                    "ts_ls",    -- typescript/javascript
                    "html",     -- html
                    "cssls",    -- css
                    "groovyls", -- groovy
                    "jdtls",    -- lsp cho java
                    "kotlin_language_server",
                },
                automatic_installation = true, -- tự động cài đặt khi khởi động
            })
        end,
    },
    -- mason dap (for debug adapters)
    {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = {
            "williamboman/mason.nvim",
            "mfussenegger/nvim-dap",
        },
        config = function()
            require("mason-nvim-dap").setup({
                ensure_installed = {
                    "java-debug-adapter",
                    "java-test"
                },
                automatic_installation = true,
            })
        end,
    },
    -- plugin nvim-lspconfig
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "mfussenegger/nvim-jdtls",
            "stevearc/conform.nvim",
            "akinsho/toggleterm.nvim",
            "hrsh7th/cmp-nvim-lsp", -- giữ lại để tích hợp với nvim-cmp
        },
        config = function()
            -- cấu hình conform.nvim để dùng black cho python
            require("conform").setup({
                formatters_by_ft = {
                    python = { "black" }, -- dùng black để định dạng python
                },
                format_on_save = {
                    timeout_ms = 500,
                    lsp_fallback = true, -- dùng lsp nếu formatter không khả dụng
                },
            })

            local lspconfig = require("lspconfig")
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- cấu hình lsp
            require("config.pyright").setup_pyright()
            lspconfig.lua_ls.setup({ capabilities = capabilities })
            lspconfig.ts_ls.setup({ capabilities = capabilities })
            lspconfig.html.setup({ capabilities = capabilities })
            lspconfig.cssls.setup({ capabilities = capabilities })
            lspconfig.groovyls.setup({
                capabilities = capabilities,
                filetypes = { "groovy" },
                root_dir = lspconfig.util.root_pattern(".git", "gradlew", "build.gradle", "pom.xml"),
            })
            lspconfig.kotlin_language_server.setup({
                capabilities = capabilities,
                filetypes = { "kotlin", "kts" },
                root_dir = lspconfig.util.root_pattern(".git", "build.gradle.kts", "pom.xml"),
            })

            -- phím tắt lsp
            vim.keymap.set("n", "<leader>ch", vim.lsp.buf.hover, { desc = "tài liệu khi di chuột qua mã" })
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "hành động mã" })
            vim.keymap.set("n", "<leader>cr", require("telescope.builtin").lsp_references,
                { desc = "đi đến tham chiếu mã" })
            vim.keymap.set("n", "<leader>ci", require("telescope.builtin").lsp_implementations,
                { desc = "đi đến triển khai mã" })
            vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "đổi tên mã" })
            vim.keymap.set("n", "<leader>cd", vim.lsp.buf.declaration, { desc = "đi đến khai báo mã" })
            vim.keymap.set("n", "gd", vim.lsp.buf.definition,
                { desc = "Đi đến định nghĩa", noremap = true, silent = true })

            -- autocommands
            vim.api.nvim_create_autocmd("filetype", {
                pattern = "java",
                callback = function()
                    require("config.jdtls").setup_jdtls()
                end,
            })
            vim.api.nvim_create_autocmd("filetype", {
                pattern = { "kotlin", "kts" },
                callback = function()
                    require("config.jdtls").setup_kotlin()
                end,
            })
        end,
    },
}
