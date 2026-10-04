-- ================================= Big files =================================
-- Two tiers of degradation so huge buffers stay responsive.
--   tier 1: drop treesitter, syntax, LSP, indent guides, 'list' and paren matching
--   tier 2: additionally drop folds, undo/swap, and unload when hidden
local M = {}

M.config = {
	tier1_bytes = 1 * 1024 * 1024,
	tier2_bytes = 10 * 1024 * 1024,
	tier1_line = 2000,
	tier2_line = 20000,
	probe_bytes = 256 * 1024,
}

-- Longest line within the first chunk of the file. A minified blob on a single
-- line is far more expensive than its byte size suggests, so probe for it.
local function probe_longest_line(path)
	local fd = vim.uv.fs_open(path, "r", 438)
	if not fd then
		return 0
	end
	local ok, chunk = pcall(vim.uv.fs_read, fd, M.config.probe_bytes, 0)
	vim.uv.fs_close(fd)
	if not ok or not chunk or chunk == "" then
		return 0
	end

	local longest, offset = 0, 1
	while true do
		local stop = chunk:find("\n", offset, true)
		if not stop then
			longest = math.max(longest, #chunk - offset + 1)
			break
		end
		longest = math.max(longest, stop - offset)
		offset = stop + 1
	end
	return longest
end

--- Returns 0 (normal), 1 or 2 for the given path.
function M.tier(path)
	local stat = path ~= "" and vim.uv.fs_stat(path) or nil
	if not stat or stat.type ~= "file" then
		return 0
	end

	local tier = 0
	if stat.size >= M.config.tier2_bytes then
		tier = 2
	elseif stat.size >= M.config.tier1_bytes then
		tier = 1
	end

	if stat.size >= M.config.probe_bytes then
		local longest = probe_longest_line(path)
		if longest >= M.config.tier2_line then
			tier = 2
		elseif longest >= M.config.tier1_line then
			tier = math.max(tier, 1)
		end
	end

	return tier
end

-- Classify before the file is read so that FileType/LspAttach consumers can see
-- the verdict through b:bigfile.
vim.api.nvim_create_autocmd("BufReadPre", {
	callback = function(event)
		local tier = M.tier(vim.api.nvim_buf_get_name(event.buf))
		if tier == 0 then
			return
		end
		vim.b[event.buf].bigfile = tier

		if tier >= 2 then
			vim.bo[event.buf].swapfile = false
			vim.bo[event.buf].undofile = false
			vim.bo[event.buf].undolevels = -1
			-- free the memory as soon as the buffer leaves the screen
			vim.bo[event.buf].bufhidden = "unload"
		end
	end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(event)
		local tier = vim.b[event.buf].bigfile
		if not tier then
			return
		end

		pcall(require("ibl").setup_buffer, event.buf, { enabled = false })

		vim.notify(
			("Big file (tier %d): reduced features"):format(tier),
			tier >= 2 and vim.log.levels.WARN or vim.log.levels.INFO
		)
	end,
})

-- Window-local options have to follow the buffer into every window it enters.
vim.api.nvim_create_autocmd("BufWinEnter", {
	callback = function(event)
		local tier = vim.b[event.buf].bigfile
		if not tier then
			return
		end

		-- syntax is cleared here, not in BufReadPost, because syntax.vim would
		-- otherwise turn it back on during filetype detection
		vim.bo[event.buf].syntax = "off"
		-- empty 'matchpairs' makes the matchparen plugin bail out immediately,
		-- so no searchpairpos() runs on every cursor move
		vim.bo[event.buf].matchpairs = ""
		vim.opt_local.list = false
		if tier >= 2 then
			vim.opt_local.relativenumber = false
			vim.opt_local.cursorline = false
			vim.opt_local.foldenable = false
			vim.opt_local.foldmethod = "manual"
			vim.opt_local.wrap = false
		end
	end,
})

return M
