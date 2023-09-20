local M = {}

---@class TwinWindow
---@field buf_game integer
---@field buf_usr integer
---@field win_usr integer
---@field win_game integer
---@field width integer
---@field height integer

--- Returns the window dimensions for creating two side by side nvim windows
function M.dimension()
    local current_width, current_height = vim.api.nvim_win_get_width(0), vim.api.nvim_win_get_height(0)
    local height_border, width_border, middle_border = 10, 10, 2
    if current_width < 80 then
        width_border, middle_border = 1, 1
    else
        width_border = math.floor((current_width - 80) / 2)
    end
    if current_height < 40 then
        height_border = 1
    else
        height_border = math.floor((current_height - 40) / 2)
    end
    local width, height =
        math.floor((current_width - middle_border) / 2) - width_border, current_height - 2 * height_border
    local row1, col1, width1, height1 = height_border, width_border, width, height
    local row2, col2, width2, height2 = height_border, width_border + width + middle_border, width, height
    return {
            row = row1,
            col = col1,
            width = width1,
            height = height1,
        }, {
            row = row2,
            col = col2,
            width = width2,
            height = height2,
        }
end

---@return TwinWindow
function M.new()
    -- The buffer for the user to write text in
    local buf_usr = vim.api.nvim_create_buf(false, true)
    -- The buffer where the target text is written
    local buf_game = vim.api.nvim_create_buf(false, true)

    local usr_dim, game_dim = M.dimension()

    local win_game = vim.api.nvim_open_win(buf_game, false, {
            relative = "win",
            row = game_dim.row,
            col = game_dim.col,
            width = game_dim.width,
            height = game_dim.height,
            style = "minimal",
            title = "type",
            title_pos = "left",
            border = "single",
            noautocmd = true,
        })
    local win_usr = vim.api.nvim_open_win(buf_usr, true, {
            relative = "win",
            row = usr_dim.row,
            col = usr_dim.col,
            width = usr_dim.width,
            height = usr_dim.height,
            style = "minimal",
            title = "Stereo",
            title_pos = "right",
            border = "single",
            noautocmd = true,
        })

    local win = {
        buf_usr = buf_usr,
        buf_game = buf_game,
        win_usr = win_usr,
        win_game = win_game,
        width = game_dim.width,
        height = game_dim.height,
    }

    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = buf_usr,
        callback = function(_)
            M.close(win)
        end,
    })
    return win
end

---@param win TwinWindow
function M.close(win)
    if vim.api.nvim_buf_is_valid(win.buf_game) then
        vim.api.nvim_buf_delete(win.buf_game, {})
    end
    if vim.api.nvim_buf_is_valid(win.buf_usr) then
        vim.api.nvim_buf_delete(win.buf_usr, {})
    end
    if vim.api.nvim_win_is_valid(win.win_game) then
        vim.api.nvim_win_close(win.win_game, true)
    end
    if vim.api.nvim_win_is_valid(win.win_usr) then
        vim.api.nvim_win_close(win.win_usr, true)
    end

    -- end up in normal mode
    local key = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
end

return M
