-- ================================== Keymaps ==================================
local map = vim.keymap.set
local opts = { noremap = true }

-- ================================== Core ==================================

map("n", "U", "<C-r>", opts)
map("n", "Y", "y$", opts)
map("n", "~", "g~", opts)

-- x/X Free
map("n", "x", "<NOP>", opts)
map("n", "X", "<NOP>", opts)

-- <C-s> -> write
map("n", "<C-s>", "<Cmd>write<CR>", opts)
-- <C-Tab> -> alternate buffer
map("n", "<C-Tab>", "<C-^>", opts)
-- <Space> -> toggle fold
map("n", "<Space>", "za", opts)
-- NOTE: <C-[> -> <C-t> intentionally NOT mapped: <C-[> is <Esc> in the terminal.

-- =================================== Jump ==================================

-- s/S is the jump motion in every mode, operators included: ds<char><char>
map({ "n", "x", "o" }, "s", function()
	vim.cmd("HopChar2AC")
end)
map({ "n", "x", "o" }, "S", function()
	vim.cmd("HopChar2BC")
end)

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		map("n", "gd", vim.lsp.buf.definition, { buffer = event.buf })
		map("n", "gD", vim.lsp.buf.declaration, { buffer = event.buf })
		map("n", "gy", vim.lsp.buf.type_definition, { buffer = event.buf })
		map("n", "gI", vim.lsp.buf.implementation, { buffer = event.buf })
		map("n", "K", function()
			vim.lsp.buf.hover({ border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" } })
		end, { buffer = event.buf })
		map("n", "gr", require("quickfix").references, { buffer = event.buf, nowait = true })
	end,
})

-- ================================== Search ====================================

map("n", "/", "/\\v", opts)
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", opts)

-- ================================== Indent ====================================

-- Normal mode: >/< indent/unindent line (single tap)
-- Visual mode: stay in visual after indent
map("v", ">", ">gv", opts)
map("v", "<", "<gv", opts)

-- ================================== Format ====================================

-- == -> Format line
map("n", "==", "==", opts)
-- =g -> Format entire file
map("n", "=g", function()
	local bufnr = vim.api.nvim_get_current_buf()
	local conform = require("conform")
	local to_run = conform.list_formatters_to_run(bufnr)
	if #to_run > 0 then
		conform.format({ bufnr = bufnr })
	else
		local view = vim.fn.winsaveview()
		vim.cmd("normal! gg=G")
		vim.fn.winrestview(view)
	end
end)
-- =q -> Format to textwidth (was gq)
map("n", "=q", "gq", opts)

-- ================================== Join ========================================

-- <C-j> = Join without space (was gJ)
map("n", "<C-j>", "gJ", opts)

-- =============================== Navigation (]/[) ===============================

-- ]n/[n = Next/prev search + select
-- ]N/[N = Next/prev search (goto only)
-- ]f/[f = Next/prev function
-- ]F/[F = Next/prev function + select
-- ]p/[p = Next/prev paragraph
-- ]P/[P = Next/prev paragraph + select
-- ]t/[t = Next/prev todo (cross-file)
-- ]T/[T = Next/prev todo + select
-- ]c/[c = Next/prev comment
-- ]C/[C = Next/prev comment + select
-- ]g/[g = Next/prev git change (gitsigns, in plugin.lua)
-- ]a/[a = Next/prev parameter (function definition args)
-- ]v/[v = Next/prev variable definition
-- Will be configured with treesitter/textobject plugins

-- Kept at Vim/Neovim default behaviour (intentionally not remapped):
--   [d/]d diagnostic, [z/]z fold, [i/]i include, [[/]] section start,
--   []/][ section end, gf open file.
-- Mapping them to themselves with noremap would shadow Neovim's defaults.

-- treesitter jumps, via nvim-treesitter-textobjects
-- the plugin errors in buffers without a parser (find_best_range returns {}),
-- so skip those
local function ts_move(fn, target)
	return function()
		if vim.treesitter.get_parser(0, nil, { error = false }) then
			require("nvim-treesitter-textobjects.move")[fn](target[1], target[2])
		end
	end
end
for key, target in pairs({
	c = { "@comment.outer", "textobjects" },
	f = { "@function.outer", "textobjects" },
	a = { "@local.definition.parameter", "locals" }, -- definitions only, not call args
	v = { "@local.definition.var", "locals" },
}) do
	map({ "n", "x", "o" }, "]" .. key, ts_move("goto_next_start", target))
	map({ "n", "x", "o" }, "[" .. key, ts_move("goto_previous_start", target))
end

map({ "n", "x", "o" }, "[x", function()
	vim.treesitter.select("parent", vim.v.count1)
end)
map({ "n", "x", "o" }, "]x", function()
	vim.treesitter.select("child", vim.v.count1)
end)

-- ================================= Exchange =====================================
map("n", "cx", function()
	require("substitute").operator()
end)
map("n", "cxx", function()
	require("substitute").line()
end)
map("n", "cX", function()
	require("substitute").eol()
end)
map("x", "X", function()
	require("substitute").visual()
end)

-- =================================== Surround ====================================
-- m is the surround object: ym add, dm delete, cm change
map("n", "ym", "<Plug>(nvim-surround-normal)")
map("n", "ymm", "<Plug>(nvim-surround-normal-cur)")
map("n", "yM", "<Plug>(nvim-surround-normal-line)")
map("n", "yMM", "<Plug>(nvim-surround-normal-cur-line)")
map("x", "m", "<Plug>(nvim-surround-visual)")
map("x", "M", "<Plug>(nvim-surround-visual-line)")
map("n", "dm", "<Plug>(nvim-surround-delete)")
map("n", "cm", "<Plug>(nvim-surround-change)")
map("n", "cM", "<Plug>(nvim-surround-change-line)")

-- =============================== Case (g~ -> ~) ==================================

map("n", "g~", "<NOP>", opts)
map("n", "gu", "<NOP>", opts)
map("n", "gU", "<NOP>", opts)

-- ================================== Emacs-style ==================================

-- Insert mode + Command line
local emacs_maps = {
	["<C-a>"] = "<Home>",
	["<C-b>"] = "<Left>",
	["<C-d>"] = "<Del>",
	["<C-e>"] = "<End>",
	["<C-f>"] = "<Right>",
	["<C-n>"] = "<Down>",
	["<C-p>"] = "<Up>",
	["<M-b>"] = "<S-Left>",
	["<M-f>"] = "<S-Right>",
}

for k, v in pairs(emacs_maps) do
	map("c", k, v, opts)
	map("i", k, v, opts)
end

-- =============================== Picker ========================================
map("n", "<C-p>", function()
	MiniPick.registry.files()
end)

-- TODO: project wide search. <C-f> and <C-S-f> are free until it exists.

-- <C-e>: toggle tree, focus it when opening
map("n", "<C-e>", function()
	local tree = require("nvim-tree.api").tree
	if tree.is_visible() then
		tree.close()
	else
		tree.find_file({ open = true, focus = true })
	end
end)

-- <C-S-e>: switch focus editor <-> tree, opening the tree if needed
map("n", "<C-S-e>", function()
	local tree = require("nvim-tree.api").tree
	if vim.bo.filetype == "NvimTree" then
		vim.cmd("wincmd p")
	else
		tree.find_file({ open = true, focus = true })
	end
end)

-- =============================== Picker ========================================
-- TODO
-- map("n", "<M-C>", ) -> c without override reg
-- map("n", "<M-D>", ) -> d without override reg

-- =========================== Edit Config Files (z prefix) =======================
map("n", "zK", function()
	vim.cmd("edit ~/.config/nvim/lua/keymap.lua")
end)
map("n", "zP", function()
	vim.cmd("edit ~/.config/nvim/lua/plugin.lua")
end)
map("n", "zO", function()
	vim.cmd("edit ~/.config/nvim/lua/option.lua")
end)
map("n", "zC", function()
	vim.cmd("edit ~/.config/nvim/lua/command.lua")
end)
map("n", "zL", function()
	vim.cmd("edit ~/.config/nvim/ftplugin/" .. vim.bo.filetype .. ".lua")
end)
