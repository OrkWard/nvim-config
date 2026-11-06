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

-- search buffer -> source buffer -> 0-indexed line -> { { start_col, end_col } }
local search_matches = {}
local search_namespace = vim.api.nvim_create_namespace("search_matches")
-- multibuffer rewrites its lines on every reload, so matches are drawn per redraw
vim.api.nvim_set_decoration_provider(search_namespace, {
	on_win = function(_, _, buffer, top, bottom)
		if not search_matches[buffer] then
			return false
		end
		for row = top, bottom do
			local source, line = multibuffer.multibuf_get_buf_at_line(buffer, row)
			local ranges = source and line and search_matches[buffer][source] and search_matches[buffer][source][line]
			for _, range in ipairs(ranges or {}) do
				vim.api.nvim_buf_set_extmark(buffer, search_namespace, row, range[1], {
					end_col = range[2],
					hl_group = "Search",
					ephemeral = true,
				})
			end
		end
		return false
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
			-- multibuffer loads real lines on redraw; placeholders would clamp the column
			vim.cmd.redraw()
			vim.schedule(function()
				vim.api.nvim_win_set_cursor(window, { row + 1, math.max(first.col - 1, 0) })
			end)
		end,
	})
end

function M.definition()
	local query = vim.fn.expand("<cword>")
	local window = vim.api.nvim_get_current_win()
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
				return
			end

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

			vim.fn.setqflist({}, " ", { title = "Definitions: " .. query, items = list.items })
			local buffer = multibuffer.create_multibuf({
				header = { ("Definitions: %s (%d matches)"):format(query, #list.items) },
			})
			vim.api.nvim_buf_set_name(buffer, "definitions://" .. buffer .. "/" .. query)
			multibuffer.win_set_multibuf(window, buffer)
			multibuffer.multibuf_add_bufs(buffer, buffers)
			local first = list.items[1]
			local row = multibuffer.multibuf_buf_get_line(buffer, buffers[1].buf, first.lnum - 1)
			-- multibuffer loads real lines on redraw; placeholders would clamp the column
			vim.cmd.redraw()
			vim.schedule(function()
				vim.api.nvim_win_set_cursor(window, { row + 1, math.max(first.col - 1, 0) })
			end)
		end,
	})
end

-- input is `query` or `query/flags`, flags: c = case sensitive, w = whole word, r = regex.
-- `buffer` reruns the search in an existing search buffer instead of creating one.
function M.search(input, paths, buffer)
	input = vim.fn.input({ prompt = "/", default = input })
	local query, flags = input:match("^(.*)/([cwr]*)$")
	if not query then
		query, flags = input, ""
	end
	if query == "" then
		return
	end

	local window = vim.api.nvim_get_current_win()
	if not buffer then
		buffer = multibuffer.create_multibuf({ header = { "Search: " .. input } })
		multibuffer.win_set_multibuf(window, buffer)
	end
	vim.api.nvim_buf_set_name(buffer, "search://" .. buffer .. "/" .. query)
	vim.b[buffer].search_input = input
	vim.b[buffer].search_paths = paths

	local command = { "rg", "--json", flags:find("c") and "--case-sensitive" or "--ignore-case" }
	if flags:find("w") then
		table.insert(command, "--word-regexp")
	end
	if not flags:find("r") then
		table.insert(command, "--fixed-strings")
	end
	vim.list_extend(command, { "--regexp", query, "--" })
	vim.list_extend(command, paths or {})
	vim.system(command, { text = true }, vim.schedule_wrap(function(result)
		if not multibuffer.multibuf_is_valid(buffer) then
			return
		end
		if result.code == 2 then
			multibuffer.multibuf_clear_bufs(buffer)
			multibuffer.multibuf_set_header(buffer, { "Search: " .. input, (vim.trim(result.stderr):gsub("%s+", " ")) })
			return
		end

		local items = {}
		for _, line in ipairs(vim.split(result.stdout, "\n", { trimempty = true })) do
			local message = vim.json.decode(line)
			if message.type == "match" then
				-- rg gives base64 `bytes` instead of `text` for non-UTF-8 content
				local path = message.data.path.text or vim.base64.decode(message.data.path.bytes)
				local text = message.data.lines.text or vim.base64.decode(message.data.lines.bytes)
				for _, submatch in ipairs(message.data.submatches) do
					table.insert(items, {
						filename = path,
						lnum = message.data.line_number,
						col = submatch.start + 1,
						end_col = submatch["end"] + 1,
						text = text:gsub("\n$", ""),
					})
				end
			end
		end
		vim.fn.setqflist({}, " ", { title = "Search: " .. input, items = items })
		items = vim.fn.getqflist()
		local sources, buffers, matches = {}, {}, {}
		for _, item in ipairs(items) do
			if not sources[item.bufnr] then
				sources[item.bufnr] = { buf = item.bufnr, regions = {} }
				table.insert(buffers, sources[item.bufnr])
				matches[item.bufnr] = {}
			end
			matches[item.bufnr][item.lnum - 1] = matches[item.bufnr][item.lnum - 1] or {}
			table.insert(matches[item.bufnr][item.lnum - 1], { item.col - 1, item.end_col - 1 })
			table.insert(sources[item.bufnr].regions, {
				start_row = math.max(0, item.lnum - 2),
				end_row = item.lnum,
			})
		end

		search_matches[buffer] = matches
		multibuffer.multibuf_clear_bufs(buffer)
		multibuffer.multibuf_set_header(
			buffer,
			{ ("Search: %s (%d matches in %d files)"):format(input, #items, #buffers) }
		)
		if #items == 0 then
			return
		end
		multibuffer.multibuf_add_bufs(buffer, buffers)
		local first = items[1]
		local row = multibuffer.multibuf_buf_get_line(buffer, buffers[1].buf, first.lnum - 1)
		-- multibuffer loads real lines on redraw; placeholders would clamp the column
		vim.cmd.redraw()
		vim.schedule(function()
			vim.api.nvim_win_set_cursor(window, { row + 1, math.max(first.col - 1, 0) })
		end)
	end))
end

return M
