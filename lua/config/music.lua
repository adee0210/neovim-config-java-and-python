local M = {}

-- Lưu trạng thái playlist cho các thư mục
M.playlists = {
    coloi = nil,
    khongloi = nil,
}
M.active_playlist = nil
M.repeat_current = false
M.paths = {
    coloi = "/home/duc/Music/Coloi",
    khongloi = "/home/duc/Music/Khongloi",
}

-- Hàm xáo trộn (Fisher-Yates)
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

-- Hàm chạy mpv với file hoặc danh sách file
local function play_current_song(playlist_type, files, is_single_file)
    vim.fn.system("pkill -9 mpv")
    local cmd = { "mpv", "--no-video" }
    if M.repeat_current and is_single_file then
        table.insert(cmd, "--loop-file=inf")
    elseif not is_single_file then
        table.insert(cmd, "--loop-playlist=no")
    end
    if is_single_file then
        table.insert(cmd, files)
    else
        vim.list_extend(cmd, files)
    end
    vim.fn.jobstart(cmd, { detach = true })
    vim.notify("Đang phát: " .. (is_single_file and vim.fn.fnamemodify(files, ":t") or "Playlist " .. playlist_type),
        vim.log.levels.INFO)
end

-- Hàm thay đổi đường dẫn playlist
local function change_playlist_path()
    vim.ui.select({ "coloi", "khongloi" }, { prompt = "Chọn playlist để thay đổi đường dẫn:" }, function(choice)
        if not choice then return end
        vim.ui.input({ prompt = "Nhập đường dẫn mới cho " .. choice .. ": " }, function(input)
            if not input or input == "" then return end
            if vim.fn.isdirectory(input) == 0 then
                vim.notify("Đường dẫn không tồn tại: " .. input, vim.log.levels.ERROR)
                return
            end
            M.paths[choice] = input
            M.playlists[choice] = nil -- Xóa playlist hiện tại để khởi tạo lại
            vim.notify("Đã cập nhật đường dẫn cho " .. choice .. ": " .. input, vim.log.levels.INFO)
        end)
    end)
end

-- Hàm bắt đầu playlist
local function start_playlist(playlist_type)
    local path = M.paths[playlist_type]
    if not path then
        vim.notify("Playlist type không hợp lệ", vim.log.levels.ERROR)
        return
    end

    if vim.fn.isdirectory(path) == 0 then
        vim.notify("Thư mục không tồn tại: " .. path, vim.log.levels.ERROR)
        return
    end

    local files = vim.fn.glob(path .. "/*", true, true)
    if not files or type(files) ~= "table" or #files == 0 then
        vim.notify("Không tìm thấy file nhạc trong " .. path, vim.log.levels.ERROR)
        return
    end

    shuffle(files)
    M.playlists[playlist_type] = { files = files, index = 1, dir = path }
    M.active_playlist = playlist_type

    play_current_song(playlist_type, files, false)
end

-- Hàm phát bài tiếp theo
local function play_next_song()
    if not M.active_playlist then
        vim.notify("Không có playlist nào đang hoạt động", vim.log.levels.ERROR)
        return
    end

    local playlist = M.playlists[M.active_playlist]
    if not playlist then
        vim.notify("Playlist không tồn tại", vim.log.levels.ERROR)
        return
    end

    playlist.index = playlist.index + 1
    if playlist.index > #playlist.files then
        vim.notify("Đã phát hết danh sách nhạc", vim.log.levels.INFO)
        M.active_playlist = nil
        return
    end
    play_current_song(M.active_playlist, playlist.files[playlist.index], true)
end

-- Hàm tìm kiếm bài hát
local function search_song()
    if not M.active_playlist then
        vim.notify("Không có playlist nào đang hoạt động để tìm kiếm", vim.log.levels.ERROR)
        return
    end

    local playlist = M.playlists[M.active_playlist]
    if not playlist or not playlist.files then
        vim.notify("Playlist chưa được khởi tạo", vim.log.levels.ERROR)
        return
    end

    local items = {}
    for _, file in ipairs(playlist.files) do
        table.insert(items, vim.fn.fnamemodify(file, ":t"))
    end

    vim.ui.select(items, { prompt = "Chọn bài muốn phát:" }, function(choice, idx)
        if choice and idx then
            playlist.index = idx
            local play_files = {}
            for i = idx, #playlist.files do
                table.insert(play_files, playlist.files[i])
            end
            for i = 1, idx - 1 do
                table.insert(play_files, playlist.files[i])
            end
            play_current_song(M.active_playlist, play_files, false)
        end
    end)

    vim.ui.input({ prompt = "Nhập từ khóa tìm bài (.mp3): " }, function(input)
        if not input or input == "" then return end

        local results = {}
        for i, file in ipairs(playlist.files) do
            if file:lower():find("%.mp3") and file:lower():find(input:lower()) then
                table.insert(results, { index = i, file = file })
            end
        end

        if #results == 0 then
            vim.notify("Không tìm thấy bài nào phù hợp từ khóa: " .. input, vim.log.levels.INFO)
            return
        end

        local items = {}
        for _, r in ipairs(results) do
            table.insert(items, vim.fn.fnamemodify(r.file, ":t"))
        end

        vim.ui.select(items, { prompt = "Chọn bài muốn phát:" }, function(choice, idx)
            if choice and idx and results[idx] then
                playlist.index = results[idx].index
                local play_files = {}
                for i = results[idx].index, #playlist.files do
                    table.insert(play_files, playlist.files[i])
                end
                for i = 1, results[idx].index - 1 do
                    table.insert(play_files, playlist.files[i])
                end
                play_current_song(M.active_playlist, play_files, false)
            end
        end)
    end)
end

-- Hàm phát file theo đường dẫn
local function play_file_by_path()
    vim.ui.input({ prompt = "Nhập đường dẫn file nhạc: " }, function(input)
        if not input or input == "" then return end
        if vim.fn.filereadable(input) == 0 then
            vim.notify("Không tìm thấy file: " .. input, vim.log.levels.ERROR)
            return
        end
        play_current_song("manual", input, true)
        M.active_playlist = nil
    end)
end

-- Hàm tạm dừng/tiếp tục nhạc
local function toggle_music()
    local check_running = vim.fn.system("pgrep mpv")
    if vim.v.shell_error ~= 0 then
        vim.notify("Không có mpv đang chạy", vim.log.levels.WARN)
        return
    end

    local check_paused = vim.fn.system("ps -C mpv -o state | grep T")
    if vim.v.shell_error == 0 then
        vim.fn.system("pkill -SIGCONT mpv")
        vim.notify("Tiếp tục phát nhạc", vim.log.levels.INFO)
    else
        vim.fn.system("pkill -SIGSTOP mpv")
        vim.notify("Đã tạm dừng nhạc", vim.log.levels.INFO)
    end
end

-- Hàm tắt nhạc
local function kill_music()
    vim.fn.system("pkill -9 mpv")
    vim.notify("Đã tắt hoàn toàn nhạc", vim.log.levels.INFO)
    M.active_playlist = nil
end

-- Hàm bật/tắt chế độ lặp
local function toggle_repeat()
    M.repeat_current = not M.repeat_current
    vim.notify("Chế độ lặp lại: " .. (M.repeat_current and "BẬT" or "TẮT"), vim.log.levels.INFO)
end

-- Hàm thiết lập plugin
function M.setup()
    vim.api.nvim_set_keymap("n", "<leader>Mp", "", {
        callback = function() start_playlist("coloi") end,
        noremap = true,
        silent = true,
        desc = "Phát playlist Coloi"
    })
    vim.api.nvim_set_keymap("n", "<leader>Mk", "", {
        callback = function() start_playlist("khongloi") end,
        noremap = true,
        silent = true,
        desc = "Phát playlist Khongloi"
    })
    vim.api.nvim_set_keymap("n", "<leader>Mn", "", {
        callback = play_next_song,
        noremap = true,
        silent = true,
        desc = "Bài tiếp theo"
    })
    vim.api.nvim_set_keymap("n", "<leader>Mr", "", {
        callback = toggle_repeat,
        noremap = true,
        silent = true,
        desc = "Bật/Tắt lặp bài"
    })
    vim.api.nvim_set_keymap("n", "<leader>Mf", "", {
        callback = search_song,
        noremap = true,
        silent = true,
        desc = "Tìm bài"
    })
    vim.api.nvim_set_keymap("n", "<leader>Mc", "", {
        callback = play_file_by_path,
        noremap = true,
        silent = true,
        desc = "Phát theo đường dẫn"
    })
    vim.api.nvim_set_keymap("n", "<leader>Mt", "", {
        callback = toggle_music,
        noremap = true,
        silent = true,
        desc = "Tạm dừng / tiếp tục"
    })
    vim.api.nvim_set_keymap("n", "<leader>Ms", "", {
        callback = kill_music,
        noremap = true,
        silent = true,
        desc = "Tắt nhạc"
    })
    vim.api.nvim_set_keymap("n", "<leader>Md", "", {
        callback = change_playlist_path,
        noremap = true,
        silent = true,
        desc = "Đổi đường dẫn playlist"
    })
end

M.setup()
return M
