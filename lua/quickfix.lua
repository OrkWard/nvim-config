local M = {}
local multibuffer = require("multibuffer")

vim.g.qf_disable_statusline = true

multibuffer.setup({
	region_hl_odd_adjust = 0,
	render_multibuf_title = function(bufnr)
		local path = " " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")
		path = path .. string.rep(" ", math.max(0, vim.o.columns - vim.fn.strdisplaywidth(path)))
		return { { { path, "MultibufFileHeader" } } }
	end,
	render_expand_lines = function(opts)
		if opts.expand_direction == "both" then
			return { { { string.rep("-", vim.api.nvim_win_get_width(opts.window)), "Comment" } } }
		end
		return {}
	end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = "*",
	callback = function(event)
		if vim.bo[event.buf].filetype ~= "multibuffer" then
			return
		end
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "yes:3"
		vim.opt_local.statuscolumn = "%s "
		vim.opt_local.foldcolumn = "0"
		vim.opt_local.foldenable = false
		vim.opt_local.wrap = false
		vim.opt_local.list = false
		vim.opt_local.cursorline = true
		multibuffer.multibuf_reload(event.buf)
	end,
})

function M.references()
	local query = vim.fn.expand("<cword>")
	local window = vim.api.nvim_get_current_win()
	vim.lsp.buf.references(nil, {
		on_list = function(list)
			local sources, buffers = {}, {}
			for _, item in ipairs(list.items) do
				local bufnr = item.bufnr or vim.fn.bufadd(item.filename)
				if not sources[bufnr] then
					sources[bufnr] = { buf = bufnr, regions = {} }
					table.insert(buffers, sources[bufnr])
				end
				table.insert(sources[bufnr].regions, {
					start_row = math.max(0, item.lnum - 2),
					end_row = item.end_lnum or item.lnum,
				})
			end

			vim.fn.setqflist({}, " ", { title = "References: " .. query, items = list.items })
			local buffer = multibuffer.create_multibuf({
				header = { ("References: %s (%d matches)"):format(query, #list.items) },
			})
			vim.api.nvim_buf_set_name(buffer, "references://" .. buffer .. "/" .. query)
			multibuffer.win_set_multibuf(window, buffer)
			multibuffer.multibuf_add_bufs(buffer, buffers)
			local first = list.items[1]
			local row = multibuffer.multibuf_buf_get_line(buffer, buffers[1].buf, first.lnum - 1)
			vim.api.nvim_win_set_cursor(window, { row + 1, math.max(first.col - 1, 0) })
		end,
	})
end

return M
