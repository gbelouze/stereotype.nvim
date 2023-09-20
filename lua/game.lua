local dict = require("dict")
local _ = require("twin_window")
local log = require("log")

local M = {}

---@class Game
---@field start_time integer
---@field end_time integer
---@field win TwinWindow
---@field lines table<integer, string>
---@field words_done table<string, boolean>
---@field words_attempted table<string, boolean>
---@field n_words integer
---@field hl_ns_id integer

--- @param words string[]
--- @param sep string
--- @param width integer
--- @return string[]
local function concat_as_lines(words, sep, width)
	local lines = {}
	local from, to = 1, 0
	local current_length = 0
	for i, word in ipairs(words) do
		if current_length + string.len(sep) + string.len(word) > width then
			local line = table.concat(words, sep, from, to)
			table.insert(lines, line)
			from, to = i, i
			current_length = string.len(word)
		else
			to = i
			current_length = current_length + string.len(sep) + string.len(word)
		end
	end
	local line = table.concat(words, sep, from, to)
	table.insert(lines, line)
	return lines
end

---@param twin_win TwinWindow
---@param n_words integer
---@return Game
function M.new(twin_win, n_words)
    local words = dict.sample(n_words)
    local words_done, words_attempted = {}, {}
    for _, word in pairs(words) do
        words_done[word] = false
        words_attempted[word] = false
    end
    local lines = {}
    for i, line in ipairs(concat_as_lines(words, " ", twin_win.width - 1)) do
        lines[i] = line
        vim.api.nvim_buf_set_lines(twin_win.buf_game, i - 1, i - 1, false, { line .. "↵" })
    end
    vim.api.nvim_buf_set_option(twin_win.buf_game, "modifiable", false)
    local ns_id = vim.api.nvim_create_namespace("stereotype_namespace")

    return {
        start_time = nil,
        end_time = nil,
        win = twin_win,
        lines = lines,
        words_done = words_done,
        words_attempted = words_attempted,
        n_words = n_words,
        hl_ns_id = ns_id,
    }
end

---@param game Game
function M.start(game)
    if game.start_time ~= nil then
        log.error("Game has already started")
    end
    game.start_time = os.time()
end

---@param game Game
function M._end(game)
    if game.end_time ~= nil then
        log.error("Game has already ended")
    end
    game.end_time = os.time()
end

---@param game Game
---@return number
function M.speed(game)
    if game.start_time == nil then
        log.error("Cannot compute the speed of a game that has not started")
    end

    local n_words_done = 0
    for word, done in pairs(game.words_done) do
        if done then
            n_words_done = n_words_done + string.len(word) + 1 -- blank characters are accounted for
        end
    end
    n_words_done = n_words_done / 5

    if game.end_time == nil then
        local current_time = os.time()
        return n_words_done * 60 / (current_time - game.start_time)
    else
        return n_words_done * 60 / (game.end_time - game.start_time)
    end
end

---@param game Game
---@return number
function M.accuracy(game)
    if game.start_time == nil then
        log.error("Cannot compute the accuracy of a game that has not started")
    end
    local n_attempted, n_done = 0, 0
    for _, attempted in pairs(game.words_attempted) do
        if attempted then
            n_attempted = n_attempted + 1
        end
    end
    for _, done in pairs(game.words_done) do
        if done then
            n_done = n_done + 1
        end
    end
    if n_done == 0 then
        return 100
    end
    return 100 * n_done / n_attempted
end

---@param game Game
---@param line_index integer
---@param line_usr string
---@param line_game string
local function highlight_line(game, line_index, line_usr, line_game)
    line_index = line_index - 1 -- highlight uses 0-based indexing
    local index_usr, index_game = 0, 0
    while true do
        local _, end_usr, word_usr = string.find(line_usr, "(%S+)", index_usr)
        local start_game, end_game, word_game = string.find(line_game, "(%S+)", index_game)
        if word_usr == nil or word_game == nil then
            break
        end
        game.words_attempted[word_game] = true
        if word_usr == word_game then
            vim.api.nvim_buf_add_highlight(
                game.win.buf_game,
                game.hl_ns_id,
                "DiagnosticSignOk",
                line_index,
                start_game - 1,
                end_game
            )
            game.words_done[word_usr] = true
        end
        for i = 1, math.min(string.len(word_usr), string.len(word_game)) do
            if string.sub(word_usr, i, i) == string.sub(word_game, i, i) then
                vim.api.nvim_buf_add_highlight(
                    game.win.buf_game,
                    game.hl_ns_id,
                    "DiagnosticSignOk",
                    line_index,
                    start_game - 1 + (i - 1),
                    start_game - 1 + i
                )
            else
                vim.api.nvim_buf_add_highlight(
                    game.win.buf_game,
                    game.hl_ns_id,
                    "DiagnosticSignError",
                    line_index,
                    start_game - 1 + (i - 1),
                    start_game - 1 + i
                )
            end
            index_usr, index_game = end_usr + 1, end_game + 1
        end
    end
end

---@param game Game
function M.render(game)
    local lines_usr = vim.api.nvim_buf_get_lines(game.win.buf_usr, 0, -1, false)

    -- we highlight in priority the line where the cursor is
    local current_line_index, _ = unpack(vim.api.nvim_win_get_cursor(game.win.win_usr))
    local current_line_usr = lines_usr[current_line_index] -- nvim_buf_get_lines uses 1-indexed convention
    if current_line_index <= #game.lines then
        local current_line_game = game.lines[current_line_index]
        vim.api.nvim_buf_clear_namespace(game.win.buf_game, game.hl_ns_id, current_line_index - 1, current_line_index)
        highlight_line(game, current_line_index, current_line_usr, current_line_game)
    end

    -- then we highlight the rest of the lines in case the user is doing some voodoo magic (like using snippets)
    for line_index, line_usr in ipairs(lines_usr) do
        if line_index ~= current_line_index and line_index <= #game.lines then
            local line_game = game.lines[line_index]
            vim.api.nvim_buf_clear_namespace(game.win.buf_game, game.hl_ns_id, line_index - 1, line_index)
            highlight_line(game, line_index, line_usr, line_game)
        end
    end
end

return M
