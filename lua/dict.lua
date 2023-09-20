local M = {}

---@type table<string>
M.dict = require("data").default_dictionnary

--- @param n_words integer
--- @return string[]
function M.sample(n_words)
	local sampled = {}
	for _ = 1, n_words do
		table.insert(sampled, M.dict[math.random(1, #M.dict)])
	end
	return sampled
end

function M.extend_dict(words)
	M.dict = vim.tbl_extend("force", M.dict, words)
end

return M
