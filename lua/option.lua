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

-- Behavior
opt.hidden = true -- allow vim make a dirty buffer hidden, but not unloaded (not so clear)
opt.splitbelow = true -- sp default bellow
opt.splitright = true -- vsp default right
opt.laststatus = 2 -- always keep the statusline
opt.linebreak = true -- line warp
opt.virtualedit = "block" -- vblock mode
opt.autoread = true -- re-read when focus
opt.ttimeoutlen = 50 -- timeout before escape string
opt.wildmode = "longest:full,full" -- command complete mode
opt.completeopt = "menuone,noselect,popup"

local diagnostic_set = vim.diagnostic.set
local pending_diagnostics = {}

vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
	local current_buf = vim.api.nvim_get_current_buf()
	if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" and (bufnr == 0 or bufnr == current_buf) then
		pending_diagnostics[current_buf] = pending_diagnostics[current_buf] or {}
		pending_diagnostics[current_buf][namespace] = { diagnostics = diagnostics, opts = opts }
		return
	end
	diagnostic_set(namespace, bufnr, diagnostics, opts)
end

vim.api.nvim_create_autocmd("InsertLeave", {
	callback = function(event)
		local pending = pending_diagnostics[event.buf]
		pending_diagnostics[event.buf] = nil
		if not pending then
			return
		end
		for namespace, update in pairs(pending) do
			diagnostic_set(namespace, event.buf, update.diagnostics, update.opts)
		end
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

-- Session
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,terminal"

-- UI
opt.termguicolors = true
opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor"
vim.api.nvim_command("colorscheme zed_onelight")

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
