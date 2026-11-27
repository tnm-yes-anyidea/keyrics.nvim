local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local uv = vim.uv or vim.loop

-- Dynamically resolve the compiled Go binary across Linux, macOS, and Windows
local script_path = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script_path, ":p:h:h")
local bin_name = vim.fn.has("win32") == 1 and "keyrics.exe" or "keyrics"
local KEYRICS_BIN = vim.fs.normalize(vim.fs.joinpath(plugin_root, "backend", bin_name))

-- Typr-Style Highlight Groups
vim.api.nvim_set_hl(0, "KeyricsCorrect", { fg = "#a6e3a1", bold = true })
vim.api.nvim_set_hl(0, "KeyricsWrong", { fg = "#f38ba8", undercurl = true })
vim.api.nvim_set_hl(0, "KeyricsTarget", { fg = "#45475a" }) -- Dimmed upcoming text
vim.api.nvim_set_hl(0, "KeyricsHUD", { fg = "#cba6f7", bold = true })
local ns = vim.api.nvim_create_namespace("keyrics_ui")

local function clean_text(str)
    if not str then return "" end
    return vim.trim(str:gsub("\r", ""):gsub("\t", " "):gsub("%s+", " "))
end

local function parse_synced_lyrics(lrc_str)
    local lines = vim.split(lrc_str, "\r?\n", { trimempty = true })
    local parsed, delays = {}, {}
    local prev_time = nil

    for i, line in ipairs(lines) do
        local min, sec, text = line:match("%[(%d%d):(%d%d%.%d%d)%]%s*(.*)")
        if not text or text == "" then text = line:gsub("%[%d%d:%d%d%.%d%d%]%s*", "") end

        text = clean_text(text)
        if text == "" then text = "* Instrumental *" end

        table.insert(parsed, text)
        if min and sec then
            local curr_time = (tonumber(min) * 60) + tonumber(sec)
            if i == 1 then table.insert(delays, 1000)
            elseif prev_time then table.insert(delays, math.floor(math.max(0.1, curr_time - prev_time) * 1000))
            else table.insert(delays, 3000) end
            prev_time = curr_time
        else
            table.insert(delays, 3000)
        end
    end
    return parsed, delays
end

local function start_typing_test(mode, song)
    local width = math.floor(vim.o.columns * 0.6)
    local height = 8
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor", width = width, height = height, row = row, col = col,
        style = "minimal", border = "rounded", title = " Keyrics ", title_pos = "center"
    })

    vim.bo[buf].filetype = "keyrics"

    local lines, delays = {}, {}
    if mode == 3 then
        lines, delays = parse_synced_lyrics(song.syncedLyrics)
    else
        local raw_lines = vim.split(song.plainLyrics, "\r?\n", { trimempty = true })
        for _, l in ipairs(raw_lines) do
            local cl = clean_text(l)
            if cl ~= "" then table.insert(lines, cl) end
        end
    end

    local state = {
        idx = 1,
        start_time = nil,
        total_correct = 0,
        total_errors = 0,
        line_correct = 0,
        line_errors = 0,
        active_timer = nil
    }

    local function get_stats()
        if not state.start_time then return 0, 100, 0 end
        local elapsed = (uv.hrtime() - state.start_time) / 1e9
        local acc_correct = state.total_correct + state.line_correct
        local acc_errors = state.total_errors + state.line_errors
        local wpm = (acc_correct / 5) / (elapsed / 60)
        local accuracy = (acc_correct / math.max(1, acc_correct + acc_errors)) * 100
        return math.max(0, wpm), math.max(0, math.min(100, accuracy)), elapsed
    end

    local function render_end_screen()
        if state.active_timer then state.active_timer:stop(); state.active_timer:close() end
        local wpm, acc, elapsed = get_stats()

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "",
            "                 TEST COMPLETE",
            "",
            string.format("                 Speed    : %d WPM", math.floor(wpm)),
            string.format("                 Accuracy : %.1f%%", acc),
            string.format("                 Time     : %.1f s", elapsed),
            "",
            "                 Press 'q' to close."
        })
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.bo[buf].modifiable = false
        vim.keymap.set("n", "q", ":q<CR>", { buffer = buf, noremap = true })
        vim.cmd("stopinsert")
    end

    local function render_surrounding_lines()
        if state.idx > #lines then return end

        -- Creates the Typr-style scrolling paragraph effect
        local prev1 = state.idx > 1 and lines[state.idx - 1] or ""
        local next1 = state.idx < #lines and lines[state.idx + 1] or ""
        local next2 = state.idx + 1 < #lines and lines[state.idx + 2] or ""
        local next3 = state.idx + 2 < #lines and lines[state.idx + 3] or ""

        vim.api.nvim_buf_set_lines(buf, 0, 2, false, { "", "  " .. prev1 })
        vim.api.nvim_buf_set_lines(buf, 3, 7, false, { "  " .. next1, "  " .. next2, "  " .. next3, "" })

        -- Dim everything except the active typing line (Line 2)
        vim.api.nvim_buf_add_highlight(buf, ns, "KeyricsTarget", 1, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, ns, "KeyricsTarget", 3, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, ns, "KeyricsTarget", 4, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, ns, "KeyricsTarget", 5, 0, -1)
    end

    local function update_active_line()
        if state.idx > #lines then return end
        local target = lines[state.idx]
        local full_line = vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] or "  "

        -- Protect the 2-space left margin padding
        if #full_line < 2 then
            full_line = "  "
            vim.api.nvim_buf_set_lines(buf, 2, 3, false, { full_line })
            vim.api.nvim_win_set_cursor(win, { 3, 2 })
        end

        local typed = full_line:sub(3)
        vim.api.nvim_buf_clear_namespace(buf, ns, 2, 3)

        state.line_correct, state.line_errors = 0, 0

        -- Colorize characters in the buffer
        for i = 1, #typed do
            if i <= #target then
                local ct = target:sub(i, i)
                local cp = typed:sub(i, i)
                local hl = (ct == cp) and "KeyricsCorrect" or "KeyricsWrong"

                if ct == cp then state.line_correct = state.line_correct + 1
                else state.line_errors = state.line_errors + 1 end

                vim.api.nvim_buf_set_extmark(buf, ns, 2, i + 1, { end_col = i + 2, hl_group = hl })
            end
        end

        -- EOL Virtual Text: Project the un-typed target string right in front of the cursor
        local remaining = target:sub(#typed + 1)
        if #remaining > 0 then
            vim.api.nvim_buf_set_extmark(buf, ns, 2, #full_line, {
                virt_text = {{ remaining, "KeyricsTarget" }},
                virt_text_pos = "eol"
            })
        end

        -- Live Floating HUD
        if mode == 2 then
            local wpm, acc, _ = get_stats()
            local hud = string.format(" %d WPM | %.0f%% ", wpm, acc)
            vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
                virt_text = {{ hud, "KeyricsHUD" }},
                virt_text_pos = "right_align"
            })
        end
    end

    local function advance_to_next()
        state.total_correct = state.total_correct + state.line_correct
        state.total_errors = state.total_errors + state.line_errors
        state.line_correct, state.line_errors = 0, 0
        state.idx = state.idx + 1

        if state.idx > #lines then
            render_end_screen()
            return
        end

        -- Reset active line with fresh padding
        vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "  " })
        vim.api.nvim_win_set_cursor(win, { 3, 2 })

        render_surrounding_lines()
        update_active_line()
    end

    -- Initial Setup
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "", "", "  ", "", "", "", "" })
    render_surrounding_lines()
    update_active_line()
    vim.api.nvim_win_set_cursor(win, { 3, 2 })
    vim.cmd("startinsert!")

    vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = buf,
        callback = function()
            if not state.start_time then state.start_time = uv.hrtime() end
            update_active_line()

            -- True exact-length auto advance
            local typed = (vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] or "  "):sub(3)
            local target = lines[state.idx]

            if (mode == 1 or mode == 2) and target and #typed >= #target then
                vim.schedule(advance_to_next)
            end
        end
    })

    if mode == 3 then
        state.active_timer = uv.new_timer()
        local function advance_synced()
            if state.idx > #lines then
                vim.schedule(render_end_screen)
                return
            end
            state.active_timer:start(delays[state.idx], 0, vim.schedule_wrap(function()
                advance_to_next()
                advance_synced()
            end))
        end
        advance_synced()

        vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = buf,
            callback = function()
                if state.active_timer and state.active_timer:is_active() then
                    state.active_timer:stop(); state.active_timer:close()
                end
            end
        })
    end
end

vim.api.nvim_create_user_command("Keyrics", function()
    if not uv.fs_stat(KEYRICS_BIN) then
        vim.notify(
            "keyrics.nvim: Backend binary not found at " .. KEYRICS_BIN .. ". Run :Lazy build keyrics.nvim (requires Go).",
            vim.log.levels.ERROR
        )
        return
    end

    vim.ui.input({ prompt = "Search LRCLIB (Artist or Song): " }, function(query)
        if not query or query == "" then return end

        vim.notify("Fetching data from LRCLIB...", vim.log.levels.INFO)
        vim.system({ KEYRICS_BIN, query }, { text = true }, function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    vim.notify("Error executing Keyrics backend: " .. (obj.stderr or ""), vim.log.levels.ERROR)
                    return
                end

                local ok, data = pcall(vim.json.decode, obj.stdout)
                if not ok or type(data) ~= "table" or #data == 0 then
                    vim.notify("No lyrics found.", vim.log.levels.WARN)
                    return
                end

                pickers.new({}, {
                    prompt_title = "Select Track",
                    finder = finders.new_table({
                        results = data,
                        entry_maker = function(song)
                            local track = (song.trackName and song.trackName ~= vim.NIL) and song.trackName or "Unknown"
                            local artist = (song.artistName and song.artistName ~= vim.NIL) and song.artistName or "Unknown"
                            local display_str = string.format("%s - %s", track, artist)
                            return { value = song, display = display_str, ordinal = display_str }
                        end
                    }),
                    sorter = conf.generic_sorter({}),
                    previewer = previewers.new_buffer_previewer({
                        title = "Lyrics Preview",
                        define_preview = function(self, entry, status)
                            local text = entry.value.plainLyrics or "No lyrics available."
                            local prev_lines = vim.split(text, "\r?\n")
                            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, prev_lines)
                            vim.bo[self.state.bufnr].wrap = true
                        end
                    }),
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            local selection = action_state.get_selected_entry()
                            if not selection then return end

                            actions.close(prompt_bufnr)
                            local song = selection.value
                            local track_title = (song.trackName and song.trackName ~= vim.NIL) and song.trackName or "Track"
                            local opts = { "1. Normal Typing", "2. Endurance Mode (Live Pacing)" }

                            if song.syncedLyrics and song.syncedLyrics ~= vim.NIL then
                                table.insert(opts, "3. Synced Typing (LRC Rhythm)")
                            end

                            vim.ui.select(opts, { prompt = "Mode for " .. track_title }, function(choice)
                                if choice then
                                    local mode = tonumber(choice:sub(1, 1))
                                    start_typing_test(mode, song)
                                end
                            end)
                        end)
                        return true
                    end,
                }):find()
            end)
        end)
    end)
end, {})

return {}
