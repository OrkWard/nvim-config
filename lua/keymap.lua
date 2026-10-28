-- ================================== Keymaps ==================================
local map = vim.keymap.set
local opts = { noremap = true }

-- ================================== Core ==================================

map("n", "U", "<C-r>", opts)
map("n", "~", "g~", opts)

-- ================================== Yank ==================================

-- Vim parks the cursor on the first yanked character, so a backwards yank
-- drags the cursor away from where you were reading. Remember the position
-- before the operator runs and put it back afterwards. The mapping is an
-- expression so counts, registers and operator pending motions keep working.
local yank_position
local function remember(keys)
	return function()
		yank_position = vim.api.nvim_win_get_cursor(0)
		return keys
	end
end
map({ "n", "x" }, "y", remember("y"), { expr = true })
map("n", "Y", remember("y$"), { expr = true })
map("x", "Y", remember("Y"), { expr = true })

-- Flash the yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		local event = vim.v.event
		if event.operator ~= "y" then
			return
		end
		vim.hl.on_yank({ higroup = "YankFlash", timeout = 200 })
		if yank_position then
			pcall(vim.api.nvim_win_set_cursor, 0, yank_position)
			yank_position = nil
		end
	end,
})

-- x/X Free
map("n", "x", "<NOP>", opts)
map("n", "X", "<NOP>", opts)

-- <C-s> -> write
map("n", "<C-s>", "<Cmd>write<CR>", opts)
map("n", "<M-w>", function()
	require("buffers").delete()
end)
map("n", "<C-c>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	vim.fn.setreg("+", ("%s:%d:%d"):format(vim.api.nvim_buf_get_name(0), cursor[1], cursor[2] + 1))
end)
-- <C-Tab> -> alternate buffer
map("n", "<C-Tab>", "<C-^>", opts)
-- <Space> -> toggle fold
map("n", "<Space>", "za", opts)
-- NOTE: <C-[> -> <C-t> intentionally NOT mapped: <C-[> is <Esc> in the terminal.

vim.api.nvim_create_autocmd("WinLeave", {
	callback = function()
		vim.w.insert_mode = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
		if vim.w.insert_mode then
			vim.w.insert_eol = vim.api.nvim_win_get_cursor(0)[2] == #vim.api.nvim_get_current_line()
		end
	end,
})
vim.api.nvim_create_autocmd("WinEnter", {
	callback = function()
		if vim.w.insert_mode then
			if vim.w.insert_eol then
				vim.cmd("startinsert!")
			else
				vim.cmd.startinsert()
			end
		else
			vim.cmd.stopinsert()
		end
	end,
})

map({ "n", "i" }, "<M-h>", "<Cmd>wincmd h<CR>", opts)
map({ "n", "i" }, "<M-j>", "<Cmd>wincmd j<CR>", opts)
map({ "n", "i" }, "<M-k>", "<Cmd>wincmd k<CR>", opts)
map({ "n", "i" }, "<M-l>", "<Cmd>wincmd l<CR>", opts)

map("i", "<Tab>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-y>"
	end
	if MiniSnippets.session.get() then
		return "<Cmd>lua MiniSnippets.session.jump('next')<CR>"
	end
	return "<Tab>"
end, { expr = true })
map("i", "<S-Tab>", function()
	return MiniSnippets.session.get() and "<Cmd>lua MiniSnippets.session.jump('prev')<CR>" or "<C-d>"
end, { expr = true })
map("i", "<C-Space>", vim.lsp.completion.get)
map("i", "<C-g>", function()
	return vim.fn.pumvisible() == 1 and "<C-e>" or "<C-g>"
end, { expr = true })

-- =================================== Jump ==================================

-- s/S is the jump motion in every mode, operators included: ds<char><char>
map({ "n", "x", "o" }, "s", function()
	vim.cmd("HopChar2AC")
end)
map({ "n", "x", "o" }, "S", function()
	vim.cmd("HopChar2BC")
end)

map("n", "<M-o>", function()
	local jumps, index = unpack(vim.fn.getjumplist())
	local bufnr = vim.api.nvim_get_current_buf()
	for i = index, 1, -1 do
		if jumps[i].bufnr ~= bufnr then
			vim.cmd.normal({ args = { (index - i + 1) .. vim.keycode("<C-o>") }, bang = true })
			return
		end
	end
end)
map("n", "<M-i>", function()
	local jumps, index = unpack(vim.fn.getjumplist())
	local bufnr = vim.api.nvim_get_current_buf()
	for i = index + 2, #jumps do
		if jumps[i].bufnr ~= bufnr then
			vim.cmd.normal({ args = { (i - index - 1) .. vim.keycode("<C-i>") }, bang = true })
			return
		end
	end
end)

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		map("n", "gd", function()
			vim.lsp.buf.definition({
				on_list = function(list)
					if #list.items == 1 then
						local item = list.items[1]
						local position = { line = item.lnum - 1, character = item.col - 1 }
						vim.lsp.util.show_document({
							uri = vim.uri_from_bufnr(item.bufnr or vim.fn.bufadd(item.filename)),
							range = { start = position, ["end"] = position },
						}, "utf-8")
						vim.cmd("normal! zz")
					else
						vim.fn.setqflist({}, " ", list)
						vim.cmd("botright copen")
					end
				end,
			})
		end, { buffer = event.buf })
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
map("n", "<Esc>", function()
	vim.cmd("nohlsearch")
	local win = vim.b.lsp_floating_preview
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end, opts)

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
		conform.format({ bufnr = bufnr }, function(err)
			vim.b[bufnr].format_error = err and "E:format:" .. err:match("^Formatter '([^']+)'") or nil
			require("lualine").refresh({ place = { "statusline" }, force = true })
		end)
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

--[[
-- Alt-h/l: parent start/end; Alt-j/k: next/previous sibling; Alt-c: first named child
for _, key in ipairs({ "h", "l", "j", "k", "c" }) do
	map("n", "<M-" .. key .. ">", function()
		local ok, node = pcall(vim.treesitter.get_node)
		if not ok then
			return
		end
		for _ = 1, vim.v.count1 do
			if not node then
				return
			end
			if key == "h" or key == "l" then
				node = node:parent()
			elseif key == "j" then
				node = node:next_named_sibling()
			elseif key == "k" then
				node = node:prev_named_sibling()
			else
				node = node:named_child(0)
			end
		end
		if not node then
			return
		end
		local row, col
		if key == "l" then
			row, col = node:end_()
			if col == 0 and row > 0 then
				row = row - 1
				col = #vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
			end
			col = math.max(col - 1, 0)
		else
			row, col = node:start()
		end
		vim.api.nvim_win_set_cursor(0, { row + 1, col })
	end)
end

map("x", "<M-o>", function()
	vim.treesitter.select("parent", vim.v.count1)
end)
]]

-- ================================= Exchange =====================================
-- zx is a sub prefix so every z builtin (scrolling, folds, spell) keeps working
map("n", "zx", function()
	require("substitute.exchange").operator()
end)
map("n", "zxx", function()
	require("substitute.exchange").line()
end)
map("n", "zxc", function()
	require("substitute.exchange").cancel()
end)
map("x", "zx", function()
	require("substitute.exchange").visual()
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
	["<M-b>"] = "<S-Left>",
	["<M-f>"] = "<S-Right>",
}

for k, v in pairs(emacs_maps) do
	map("c", k, v, opts)
	map("i", k, v, opts)
end

map("i", "<C-n>", function()
	if vim.fn.pumvisible() == 0 then
		return "<Down>"
	end
	local info = vim.fn.complete_info({ "items", "selected" })
	local selected = (info.selected + 1) % #info.items
	if selected ~= info.selected then
		vim.api.nvim_select_popupmenu_item(selected, false, false, {})
	end
	return ""
end, { expr = true })
map("i", "<C-p>", function()
	if vim.fn.pumvisible() == 0 then
		return "<Up>"
	end
	local info = vim.fn.complete_info({ "items", "selected" })
	local selected = info.selected == -1 and #info.items - 1 or (info.selected - 1) % #info.items
	if selected ~= info.selected then
		vim.api.nvim_select_popupmenu_item(selected, false, false, {})
	end
	return ""
end, { expr = true })
vim.api.nvim_create_autocmd("CompleteChanged", {
	callback = function()
		if vim.fn.complete_info({ "selected" }).selected == -1 then
			vim.schedule(function()
				if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected == -1 then
					vim.api.nvim_select_popupmenu_item(0, false, false, {})
				end
			end)
		end
	end,
})

-- =============================== Picker ========================================
for key, step in pairs({ n = -1, m = 1 }) do
	map("n", "<M-" .. key .. ">", function()
		local buffers = vim.w.buffer_bar_buffers or {}
		local index = vim.fn.index(buffers, vim.api.nvim_get_current_buf())
		if index >= 0 then
			vim.api.nvim_set_current_buf(buffers[(index + step * vim.v.count1) % #buffers + 1])
		end
	end)
end

map("n", "<M-p>", function()
	if vim.bo.filetype == "NvimTree" then
		vim.cmd("wincmd p")
	end
	MiniPick.registry.files()
end)

-- TODO: project wide search. <C-f> and <C-S-f> are free until it exists.

-- <M-e>: toggle tree, focus it when opening
map("n", "<M-e>", function()
	local tree = require("nvim-tree.api").tree
	if tree.is_visible() then
		tree.close()
	else
		tree.find_file({ open = true, focus = true })
	end
end)

-- <C-M-e>: switch focus editor <-> tree, opening the tree if needed
map("n", "<C-M-e>", function()
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
