local M = {}

---@param msg string
function M.info(msg)
    vim.notify(msg, vim.log.levels.INFO)
end

---@param msg string
function M.warning(msg)
    vim.notify(msg, vim.log.levels.WARN)
end

---@param msg string
function M.error(msg)
    vim.notify(msg, vim.log.levels.ERROR)
end

return M
