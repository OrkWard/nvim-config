-- ================================== Plugins ==================================
vim.pack.add({
	"https://github.com/nvim-mini/mini.pick",
	"https://github.com/kylechui/nvim-surround",
	"https://github.com/stevearc/conform.nvim.git",
	"https://github.com/tpope/vim-sleuth.git",
	"https://github.com/lukas-reineke/indent-blankline.nvim.git",
	"https://github.com/gbprod/substitute.nvim.git",
	"https://github.com/nvim-lualine/lualine.nvim.git",
	"https://github.com/nvim-tree/nvim-web-devicons.git",
	"https://github.com/nvim-tree/nvim-tree.lua.git",
	"https://github.com/smoka7/hop.nvim.git",
	"https://github.com/altermo/ultimate-autopair.nvim.git",
	"https://github.com/neovim/nvim-lspconfig.git",
	"https://github.com/nvim-treesitter/nvim-treesitter.git",
	"https://github.com/stevearc/quicker.nvim.git",
	"https://github.com/lewis6991/gitsigns.nvim.git",
	"https://github.com/nvim-lua/plenary.nvim.git",
	"https://github.com/NeogitOrg/neogit.git",
})

require("nvim-web-devicons").set_icon({
	go = { icon = "󰟓", color = "#00ADD8", cterm_color = "38", name = "Go" },
	["go.mod"] = { icon = "󰟓", color = "#00ADD8", cterm_color = "38", name = "GoMod" },
	["go.sum"] = { icon = "󰟓", color = "#00ADD8", cterm_color = "38", name = "GoSum" },
})
vim.api.nvim_set_hl(0, "NvimTreeHiddenCursor", { bg = "#000000", blend = 100 })

-- nvim-tree links its git icons to syntax groups by default, which says nothing
-- about git. Give every state its own colour from the theme palette instead.
for group, color in pairs({
	NvimTreeGitNewIcon = "#649f57",
	NvimTreeGitStagedIcon = "#5b79e3",
	NvimTreeGitDirtyIcon = "#dabb7e",
	NvimTreeGitDeletedIcon = "#d36151",
	NvimTreeGitRenamedIcon = "#a449ab",
	NvimTreeGitMergeIcon = "#ad6e25",
	NvimTreeGitIgnoredIcon = "#a2a3a7",
}) do
	vim.api.nvim_set_hl(0, group, { fg = color })
end

-- The built-in Visual highlight stops at the end of the entry name and the
-- Cursor highlight punches a hole into it, which is useless with a hidden
-- cursor. Repaint the selection with line extmarks instead: those span the full
-- window width and win over the cursor cell.
local tree_visual_ns = vim.api.nvim_create_namespace("nvim_tree_visual")

local function tree_visual_paint(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, tree_visual_ns, 0, -1)

	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		return
	end

	local first, last = vim.fn.line("v"), vim.fn.line(".")
	if first > last then
		first, last = last, first
	end
	for line = first, last do
		vim.api.nvim_buf_set_extmark(bufnr, tree_visual_ns, line - 1, 0, { line_hl_group = "Visual" })
	end
end

require("nvim-tree").setup({
	disable_netrw = false,
	hijack_netrw = false,
	hijack_directories = { enable = false },
	on_attach = function(bufnr)
		local api = require("nvim-tree.api")
		vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			buffer = bufnr,
			command = "set guicursor=a:block-NvimTreeHiddenCursor",
		})
		vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
			buffer = bufnr,
			command = "set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor",
		})
		vim.api.nvim_create_autocmd("CmdlineEnter", {
			buffer = bufnr,
			command = "set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor",
		})
		vim.api.nvim_create_autocmd("CmdlineLeave", {
			buffer = bufnr,
			command = "set guicursor=a:block-NvimTreeHiddenCursor",
		})
		vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
			buffer = bufnr,
			callback = function()
				tree_visual_paint(bufnr)
			end,
		})

		-- character-wise selection is meaningless on a tree of file names
		vim.keymap.set("n", "v", "V", { buffer = bufnr, nowait = true })
		vim.keymap.set("n", "<CR>", function()
			local node = api.tree.get_node_under_cursor()
			if node and node.parent then
				api.node.open.edit(node)
			end
		end, { buffer = bufnr })
		-- <Space>: toggle on a folder, open on a file
		vim.keymap.set("n", "<Space>", function()
			local node = api.tree.get_node_under_cursor()
			if node and node.parent then
				api.node.open.edit(node)
			end
		end, { buffer = bufnr, nowait = true })
		vim.keymap.set("n", "<2-LeftMouse>", api.node.open.edit, { buffer = bufnr })
		vim.keymap.set("n", "l", function()
			local node = api.tree.get_node_under_cursor()
			if node and node.parent then
				api.node.open.edit(node)
			end
		end, { buffer = bufnr })
		vim.keymap.set("n", "h", api.node.navigate.parent_close, { buffer = bufnr })
		vim.keymap.set("n", "<C-h>", "zh", { buffer = bufnr })
		vim.keymap.set("n", "<C-l>", "zl", { buffer = bufnr })
		vim.keymap.set("n", "%", api.fs.create, { buffer = bufnr })
		vim.keymap.set("n", "d", function()
			local node = api.tree.get_node_under_cursor()
			local directory = node.type == "directory" and node.absolute_path or node.parent.absolute_path
			vim.ui.input({ prompt = "Create directory: " }, function(name)
				if not name or name == "" then
					return
				end
				local ok, error = vim.uv.fs_mkdir(vim.fs.joinpath(directory, name), 493)
				if not ok then
					vim.notify(error, vim.log.levels.ERROR)
					return
				end
				api.tree.reload()
			end)
		end, { buffer = bufnr, nowait = true })
		vim.keymap.set("n", "/", function()
			local node = api.tree.get_node_under_cursor()
			local directory = node.type == "directory" and node.absolute_path or node.parent.absolute_path
			vim.cmd("wincmd p")
			require("quickfix").search(nil, directory)
		end, { buffer = bufnr })
		vim.keymap.set("n", "x", function()
			local node = api.tree.get_node_under_cursor()
			vim.system({ "open", "-R", node.absolute_path }, { detach = true })
		end, { buffer = bufnr })
		vim.keymap.set("n", "R", api.tree.reload, { buffer = bufnr })
		vim.keymap.set("n", "q", api.tree.close, { buffer = bufnr })
	end,
	view = {
		cursorline = true,
		cursorlineopt = "line",
		side = "left",
		signcolumn = "no",
		width = 30,
	},
	renderer = {
		root_folder_label = ":t",
		indent_markers = { enable = true },
		icons = {
			-- same language as the editor: one solid bar on the right, the state
			-- is carried by the colour alone
			git_placement = "right_align",
			glyphs = {
				git = {
					unstaged = "\u{258e}",
					staged = "\u{258e}",
					unmerged = "\u{258e}",
					renamed = "\u{258e}",
					untracked = "\u{258e}",
					deleted = "\u{258e}",
					ignored = "\u{258e}",
				},
			},
			show = {
				file = true,
				folder = true,
				folder_arrow = true,
				git = true,
				modified = true,
				hidden = false,
				diagnostics = false,
				bookmarks = false,
			},
		},
	},
	filters = { git_ignored = true },
})

if vim.fn.has("nvim-0.13") == 0 then
	vim.api.nvim_create_autocmd("SessionWritePost", {
		callback = function()
			require("nvim-tree.session").save()
		end,
	})
	vim.api.nvim_create_autocmd("SessionLoadPost", {
		once = true,
		callback = function()
			if vim.v.startreason == "restart" then
				local api = require("nvim-tree.api")
				for _, window in ipairs(vim.api.nvim_list_wins()) do
					if api.tree.is_tree_buf(vim.api.nvim_win_get_buf(window)) then
						local pending = true
						api.events.subscribe(api.events.Event.TreeOpen, function()
							if pending then
								pending = false
								vim.schedule(function()
									if vim.bo.filetype == "NvimTree" then
										vim.cmd("wincmd p")
									end
									vim.o.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor"
								end)
							end
						end)
						break
					end
				end
			end
			require("nvim-tree.session").restore()
			vim.schedule(function()
				if vim.bo.filetype == "NvimTree" then
					vim.o.guicursor = "a:block-NvimTreeHiddenCursor"
				else
					vim.o.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:Cursor"
				end
			end)
		end,
	})
end

vim.api.nvim_create_autocmd("WinClosed", {
	callback = function()
		vim.schedule(function()
			local windows = {}
			for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.api.nvim_win_get_config(window).relative == "" then
					table.insert(windows, window)
				end
			end
			if #windows == 1 and vim.bo[vim.api.nvim_win_get_buf(windows[1])].filetype == "NvimTree" then
				vim.api.nvim_set_current_win(windows[1])
				vim.cmd("quit")
			end
		end)
	end,
})

require("quicker").setup({
	constrain_cursor = false,
	edit = { enabled = false },
	follow = { enabled = false },
	highlight = { treesitter = false, lsp = false, load_buffers = false },
	keys = {},
	trim_leading_whitespace = false,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "TSUpdate",
	callback = function()
		local parsers = require("nvim-treesitter.parsers")
		parsers.asciidoc = {
			install_info = {
				url = "https://github.com/cathaysia/tree-sitter-asciidoc",
				revision = "ade998931aeac0a10ca592b421cdb1f2f088f6c9",
				location = "tree-sitter-asciidoc",
				queries = "tree-sitter-asciidoc/queries",
			},
			requires = { "asciidoc_inline" },
		}
		parsers.asciidoc_inline = {
			install_info = {
				url = "https://github.com/cathaysia/tree-sitter-asciidoc",
				revision = "ade998931aeac0a10ca592b421cdb1f2f088f6c9",
				location = "tree-sitter-asciidoc_inline",
				queries = "tree-sitter-asciidoc_inline/queries",
			},
		}
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	callback = function(event)
		if vim.b[event.buf].bigfile then
			return
		end
		pcall(vim.treesitter.start, event.buf)
	end,
})

require("mini.pick").setup({
	window = {
		config = function()
			local height = math.floor(0.618 * vim.o.lines)
			local width = math.floor(0.618 * vim.o.columns)
			return {
				anchor = "NW",
				border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
				height = height,
				width = width,
				row = math.floor(0.5 * (vim.o.lines - height)),
				col = math.floor(0.5 * (vim.o.columns - width)),
			}
		end,
		prompt_prefix = "",
	},
})
vim.api.nvim_create_autocmd("User", {
	pattern = "MiniPickStart",
	callback = function()
		vim.wo[MiniPick.get_picker_state().windows.main].scrolloff = 5
	end,
})
do
	local pick = require("mini.pick")

	local function buffers_recent(local_opts)
		local_opts =
			vim.tbl_deep_extend("force", { include_current = false, include_unlisted = false }, local_opts or {})
		local cur_buf = vim.api.nvim_get_current_buf()
		local infos = vim.fn.getbufinfo()
		local items = {}
		for _, info in ipairs(infos) do
			if
				(local_opts.include_unlisted or info.listed == 1)
				and (local_opts.include_current or info.bufnr ~= cur_buf)
			then
				local name = info.name ~= "" and vim.fn.fnamemodify(info.name, ":~:.") or "[No Name]"
				table.insert(items, { text = name, bufnr = info.bufnr, _lastused = info.lastused or 0 })
			end
		end

		table.sort(items, function(a, b)
			return a._lastused > b._lastused
		end)
		for _, item in ipairs(items) do
			item._lastused = nil
		end

		return pick.start({ source = { name = "Buffers", items = items, show = pick.default_show } })
	end

	local function files_recent()
		local open = {}
		local cwd = vim.fn.getcwd()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			local path = vim.api.nvim_buf_get_name(bufnr)
			local relative = path ~= "" and vim.fs.relpath(cwd, path) or nil
			if vim.bo[bufnr].buflisted and relative then
				open[relative] = true
			end
		end

		return pick.builtin.cli({
			command = { "rg", "--files", "--color=never" },
			postprocess = function(paths)
				local buffers, files = {}, {}
				for _, path in ipairs(paths) do
					if path ~= "" then
						table.insert(open[path] and buffers or files, path)
					end
				end
				vim.list_extend(buffers, files)
				return buffers
			end,
		}, {
			source = {
				name = "Files",
				show = function(buf_id, items, query)
					pick.default_show(buf_id, items, query, { show_icons = true })
				end,
			},
		})
	end

	pick.registry.buffers = buffers_recent
	pick.registry.files = files_recent
	pick.registry.search = require("quickfix").search
end

require("nvim-surround").setup({})

do
	local prettier = { "prettierd", "prettier", stop_after_first = true }

	require("conform").setup({
		formatters_by_ft = {
			lua = { "stylua" },
			python = { "isort", "black" },
			rust = { "rustfmt", lsp_format = "fallback" },
			javascript = prettier,
			javascriptreact = prettier,
			typescript = prettier,
			typescriptreact = prettier,
			json = prettier,
			jsonc = prettier,
			css = prettier,
			scss = prettier,
			less = prettier,
			html = prettier,
			yaml = prettier,
			markdown = prettier,
			["markdown.mdx"] = prettier,
			graphql = prettier,
		},
	})
end

require("ibl").setup({
	indent = { char = "│" },
})

require("substitute").setup()
do
	local colors = {
		yellow = "#dabb7e",
		red = "#d36151",
		orange = "#d3604f",
		blue = "#5b79e3",
		dark_blue = "#4a62db",
		purple = "#a449ab",
		violet = "#9294be",
		green = "#649f57",
		gold = "#ad6e25",
		cyan = "#3882b7",
		light_black = "#2e323a",
		gray = "#eaeaed",
		dark_gray = "#ebebec",
		light_gray = "#a2a3a7",
		blue_gray = "#d9dcea",
		faint_gray = "#efefef",
		linenr = "#b0b1b3",
		black = "#383a41",
		white = "#fafafa",
	}

	local zed_onelight = {
		normal = {
			a = { fg = colors.white, bg = colors.blue, gui = "bold" },
			b = { fg = colors.black, bg = colors.gray },
			c = { fg = colors.black, bg = colors.dark_gray },
		},
		insert = {
			a = { fg = colors.white, bg = colors.green, gui = "bold" },
			b = { fg = colors.black, bg = colors.gray },
			c = { fg = colors.black, bg = colors.dark_gray },
		},
		visual = {
			a = { fg = colors.white, bg = colors.purple, gui = "bold" },
			b = { fg = colors.black, bg = colors.gray },
			c = { fg = colors.black, bg = colors.dark_gray },
		},
		replace = {
			a = { fg = colors.white, bg = colors.red, gui = "bold" },
			b = { fg = colors.black, bg = colors.gray },
			c = { fg = colors.black, bg = colors.dark_gray },
		},
		command = {
			a = { fg = colors.white, bg = colors.orange, gui = "bold" },
			b = { fg = colors.black, bg = colors.gray },
			c = { fg = colors.black, bg = colors.dark_gray },
		},
		inactive = {
			a = { fg = colors.light_gray, bg = colors.faint_gray },
			b = { fg = colors.light_gray, bg = colors.faint_gray },
			c = { fg = colors.light_gray, bg = colors.faint_gray },
		},
	}

	require("lualine").setup({
		options = {
			theme = zed_onelight,
			component_separators = { left = "/", right = "/" },
			icons_enabled = false,
		},
		sections = {
			lualine_c = { { "filename", path = 1, shorting_target = 0 } },
			lualine_x = { "lsp_status", "encoding", "fileformat", "filetype" },
		},
	})
end

local border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" }

-- Gitsigns can only draw into the sign column on the left, so render the hunk
-- bars ourselves as right aligned virtual text.
local git_sign_ns = vim.api.nvim_create_namespace("gitsigns_right")
local git_sign_hl = {
	add = "GitSignsAdd",
	change = "GitSignsChange",
	delete = "GitSignsDelete",
}

local function git_signs_right(bufnr)
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, git_sign_ns, 0, -1)

	local ok, hunks = pcall(require("gitsigns").get_hunks, bufnr)
	if not ok or not hunks then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	for _, hunk in ipairs(hunks) do
		local hl = git_sign_hl[hunk.type] or "GitSignsChange"
		-- a pure deletion owns no line, so mark the line it happened after
		for offset = 0, math.max(hunk.added.count, 1) - 1 do
			local line = math.min(math.max(hunk.added.start + offset, 1), line_count)
			pcall(vim.api.nvim_buf_set_extmark, bufnr, git_sign_ns, line - 1, 0, {
				virt_text = { { "\u{258e}", hl } },
				virt_text_pos = "right_align",
				hl_mode = "combine",
			})
		end
	end
end

vim.api.nvim_create_autocmd("User", {
	pattern = "GitSignsUpdate",
	callback = function(event)
		local bufnr = event.data and event.data.buffer
		if bufnr then
			git_signs_right(bufnr)
		end
	end,
})

require("gitsigns").setup({
	signcolumn = false,
	preview_config = { border = border },
	on_attach = function(bufnr)
		-- large buffers are already running without treesitter/LSP
		if vim.b[bufnr].bigfile then
			return false
		end

		local gitsigns = require("gitsigns")
		local function map(lhs, rhs)
			vim.keymap.set("n", lhs, rhs, { buffer = bufnr })
		end

		map("]h", function()
			gitsigns.nav_hunk("next")
		end)
		map("[h", function()
			gitsigns.nav_hunk("prev")
		end)
		map("ghp", gitsigns.preview_hunk)
		map("ghs", gitsigns.stage_hunk)
		map("ghr", gitsigns.reset_hunk)
		map("ghd", gitsigns.diffthis)
		map("ghb", function()
			gitsigns.blame_line({ full = true })
		end)
	end,
})

require("neogit").setup({
	disable_hint = true,
	graph_style = "unicode",
	signs = {
		hunk = { "", "" },
		item = { "", "" },
		section = { "", "" },
	},
})

require("hop").setup()

require("ultimate-autopair").setup({
	-- the split pair into three lines only triggers when no extra token between
	cr = {
		conf = {
			cond = function(fn, o)
				if fn.in_lisp() then
					return false
				end
				local prev = o.col > 1 and o.line:sub(o.col - 1, o.col - 1) or ""
				local nextc = o.line:sub(o.col, o.col)
				local pairs = { ["("] = ")", ["["] = "]", ["{"] = "}" }
				return pairs[prev] == nextc
			end,
		},
	},
	bs = {
		delete_from_end = false,
	},
})
