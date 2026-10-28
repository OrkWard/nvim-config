-- ================================== Options ==================================
local opt = vim.opt

-- Indentation
opt.tabstop = 4 -- personal prefer
opt.expandtab = true -- default space
opt.shiftwidth = 4 -- default space sw
opt.softtabstop = -1 -- follow sw
opt.autoindent = true -- inherit indent from last line. this has no confict to si / ci / inde
-- si / ci / inde is dumb and should not be used here

-- Line numbers
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes" -- always reserve space so git signs don't shift text
opt.foldcolumn = "1"
opt.foldtext = "" -- closed fold shows its first line with normal highlighting
opt.fillchars:append({ fold = " ", foldsep = " ", foldinner = " " })
opt.statuscolumn = "%s%l %C " -- fold column after the line number, like zed

-- Behavior
opt.hidden = true -- allow vim make a dirty buffer hidden, but not unloaded (not so clear)
opt.jumpoptions:remove("clean") -- keep jumps to closed files; wiped virtual buffers still lose their marks
opt.splitbelow = true -- sp default bellow
opt.splitright = true -- vsp default right
opt.laststatus = 2 -- always keep the statusline
opt.linebreak = true -- line warp
opt.virtualedit = "block" -- vblock mode
opt.autoread = true -- re-read when focus
opt.ttimeoutlen = 50 -- timeout before escape string
opt.wildmode = "longest:full,full" -- command complete mode
opt.completeopt = "menuone,noinsert,popup"
opt.pumborder = "single"
opt.pummaxwidth = 48
opt.winborder = "single"

vim.api.nvim_create_autocmd("CompleteChanged", {
	callback = function()
		vim.schedule(function()
			local winid = vim.fn.complete_info().preview_winid
			if winid and vim.api.nvim_win_is_valid(winid) then
				vim.api.nvim_win_set_config(winid, { border = "single" })
			end
		end)
	end,
})

local complete_set = vim.api.nvim__complete_set
vim.api.nvim__complete_set = function(...)
	local result = complete_set(...)
	if result.winid and vim.api.nvim_win_is_valid(result.winid) then
		vim.api.nvim_win_set_config(result.winid, { border = "single" })
	end
	return result
end

local diagnostic_set = vim.diagnostic.set
local pending_diagnostics = {}

vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
	local current_buf = vim.api.nvim_get_current_buf()
	local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
	if (mode == "i" or mode == "s") and (bufnr == 0 or bufnr == current_buf) then
		pending_diagnostics[current_buf] = pending_diagnostics[current_buf] or {}
		pending_diagnostics[current_buf][namespace] = { diagnostics = diagnostics, opts = opts }
		return
	end
	diagnostic_set(namespace, bufnr, diagnostics, opts)
end

vim.api.nvim_create_autocmd("ModeChanged", {
	pattern = "*:n",
	callback = function(event)
		vim.schedule(function()
			if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "n" then
				return
			end
			local pending = pending_diagnostics[event.buf]
			pending_diagnostics[event.buf] = nil
			if not pending then
				return
			end
			for namespace, update in pairs(pending) do
				diagnostic_set(namespace, event.buf, update.diagnostics, update.opts)
			end
		end)
	end,
})

vim.diagnostic.config({
	float = {
		border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
		header = "",
		title = " Diagnostic ",
		title_pos = "left",
		max_width = 60,
		prefix = function(diagnostic)
			local name = vim.diagnostic.severity[diagnostic.severity]:lower()
			return name:sub(1, 1):upper() .. "  ", "DiagnosticFloating" .. name:sub(1, 1):upper() .. name:sub(2)
		end,
		suffix = function(diagnostic)
			return diagnostic.code and "  · " .. diagnostic.code or "", "Comment"
		end,
	},
	jump = {
		on_jump = function(diagnostic, bufnr)
			if diagnostic then
				vim.diagnostic.open_float({
					bufnr = bufnr,
					scope = "cursor",
					focus = false,
					title = diagnostic.source and " " .. diagnostic.source .. " " or " Diagnostic ",
				})
			end
		end,
	},
})

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Fold: files open unfolded
opt.foldlevelstart = 99

-- Session
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,terminal"

-- UI
opt.termguicolors = true
opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor"
vim.api.nvim_create_autocmd("ModeChanged", {
	callback = function()
		local mode = vim.api.nvim_get_mode().mode
		if mode == "s" or mode == "S" or mode == "\19" then
			vim.o.guicursor = "n-c:block,v:ver25,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor"
		elseif vim.v.event.old_mode == "s" or vim.v.event.old_mode == "S" or vim.v.event.old_mode == "\19" then
			vim.o.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor"
		end
	end,
})
vim.api.nvim_command("colorscheme zed_onelight")

local function highlight_enclosing_pair()
	if vim.w.enclosing_matchparen_id then
		pcall(vim.fn.matchdelete, vim.w.enclosing_matchparen_id)
		vim.w.enclosing_matchparen_id = nil
	end

	local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
	if (mode ~= "n" and mode ~= "i" and mode ~= "R") or vim.bo.matchpairs == "" or vim.fn.pumvisible() == 1 then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local char = line:sub(cursor[2] + 1, cursor[2] + 1)
	local before = line:sub(cursor[2], cursor[2])
	if char:find("[(){}%[%]]") or ((mode == "i" or mode == "R") and before:find("[(){}%[%]]")) then
		return
	end

	local ok, node = pcall(vim.treesitter.get_node, { bufnr = 0, ignore_injections = false })
	if not ok then
		return
	end
	local pairs = { ["("] = ")", ["["] = "]", ["{"] = "}" }
	while node do
		local child_count = node:child_count()
		if child_count >= 2 then
			local open = node:child(0)
			local close = node:child(child_count - 1)
			if pairs[open:type()] == close:type() then
				local open_row, open_col = open:start()
				local close_row, close_col = close:start()
				vim.w.enclosing_matchparen_id = vim.fn.matchaddpos("MatchParen", {
					{ open_row + 1, open_col + 1, 1 },
					{ close_row + 1, close_col + 1, 1 },
				}, 10)
				return
			end
		end
		node = node:parent()
	end
end

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinEnter", "BufWinEnter", "TextChanged", "TextChangedI" }, {
	callback = highlight_enclosing_pair,
})

-- Keep cursor away from screen edges (scroll offset)
opt.scrolloff = 5 -- Keep 5 lines above/below cursor
opt.sidescrolloff = 10 -- Keep 10 columns left/right of cursor

-- Whitespace display
opt.list = true
opt.listchars = {
	tab = "│ ",
	space = "·",
	trail = "~",
}

-- Disable unused providers
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
