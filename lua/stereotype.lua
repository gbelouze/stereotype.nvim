local tw = require("twin_window")
local gm = require("game")

local M = {}

M.config = {
	n_words = 10,
}

function M.setup(config)
	config = config or {}
	M.config = vim.tbl_extend("force", M.config, config)
end

---@param game Game
local function should_start_game(game)
	if game.start_time == nil then
		local lines_usr = vim.api.nvim_buf_get_lines(game.win.buf_usr, 0, -1, false)
		local tot_typed = 0
		for _, line in pairs(lines_usr) do
			tot_typed = tot_typed + string.len(line)
		end
		return tot_typed > 0
	end
	return false
end

---@param game Game
local function should_end_game(game)
	local lines_usr = vim.api.nvim_buf_get_lines(game.win.buf_usr, 0, -1, false)
	return #lines_usr > #game.lines
end

function M.new()
	local win = tw.new()
	local game = gm.new(win, M.config.n_words)

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = win.buf_usr,
		callback = function(_)
			gm.render(game)
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = win.buf_usr,
		callback = function(_)
			if should_start_game(game) then
				gm.start(game)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = win.buf_usr,
		callback = function(_)
			if should_end_game(game) then
				gm._end(game)
				tw.close(game.win)
			end
		end,
	})
end

return M
