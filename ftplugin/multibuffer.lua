local multibuffer = require("multibuffer")

vim.bo.matchpairs = ""

vim.keymap.set("n", "<CR>", function()
	local bufnr, line = multibuffer.multibuf_get_origin_at_cursor(0)
	if bufnr then
		local col = vim.api.nvim_win_get_cursor(0)[2]
		vim.cmd("normal! m'")
		vim.fn.bufload(bufnr)
		vim.bo[bufnr].buflisted = true
		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { line, col })
	end
end, { buffer = true })
vim.keymap.set("n", "q", "<Cmd>buffer #<CR>", { buffer = true })
vim.keymap.set("n", "+", function()
	multibuffer.multibuf_slice_expand(vim.api.nvim_get_current_buf(), vim.v.count1, vim.v.count1)
end, { buffer = true })
vim.keymap.set("n", "-", function()
	multibuffer.multibuf_slice_expand(vim.api.nvim_get_current_buf(), -vim.v.count1, -vim.v.count1)
end, { buffer = true })
