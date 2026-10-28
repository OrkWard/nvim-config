local M = {}

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
	callback = function()
		local window = vim.api.nvim_get_current_win()
		local buffer = vim.api.nvim_get_current_buf()
		if vim.api.nvim_win_get_config(window).relative ~= "" then
			return
		end
		if not vim.bo[buffer].buflisted or vim.bo[buffer].filetype == "NvimTree" then
			vim.wo.winbar = ""
			return
		end
		local buffers = vim.w.buffer_bar_buffers or {}
		if not vim.tbl_contains(buffers, buffer) then
			table.insert(buffers, buffer)
		end
		vim.w.buffer_bar_buffers = buffers
		vim.wo.winbar = "%!v:lua.require'buffers'.bar()"
	end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
	callback = function(event)
		for _, window in ipairs(vim.api.nvim_list_wins()) do
			local buffers = vim.w[window].buffer_bar_buffers or {}
			for index = #buffers, 1, -1 do
				if buffers[index] == event.buf then
					table.remove(buffers, index)
				end
			end
			vim.w[window].buffer_bar_buffers = buffers
		end
	end,
})

vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufFilePost", "BufWritePost" }, {
	callback = function()
		vim.cmd.redrawstatus({ bang = true })
	end,
})

vim.api.nvim_create_autocmd("SessionWritePost", {
	callback = function()
		local lines = {}
		for tab_index, tab in ipairs(vim.api.nvim_list_tabpages()) do
			for window_index, window in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				local names = {}
				for _, buffer in ipairs(vim.w[window].buffer_bar_buffers or {}) do
					if
						vim.api.nvim_buf_is_valid(buffer)
						and vim.bo[buffer].buflisted
						and vim.bo[buffer].buftype == ""
					then
						local name = vim.api.nvim_buf_get_name(buffer)
						if name ~= "" and not name:match("^%a[%w+.-]*://") then
							table.insert(names, name)
						end
					end
				end
				if #names > 0 then
					table.insert(
						lines,
						("call settabwinvar(%d, %d, 'buffer_bar_buffers', map(%s, 'bufnr(v:val)'))"):format(
							tab_index,
							window_index,
							vim.fn.string(names)
						)
					)
				end
			end
		end
		vim.fn.writefile(lines, vim.v.this_session, "a")
	end,
})

function M.bar()
	local window = vim.g.statusline_winid or vim.api.nvim_get_current_win()
	local current = vim.api.nvim_win_get_buf(window)
	local items, active = {}, 1
	for _, buffer in ipairs(vim.w[window].buffer_bar_buffers or {}) do
		if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buflisted then
			local name = vim.api.nvim_buf_get_name(buffer)
			local label = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
			local scheme = name:match("^(%a[%w+.-]*)://")
			if scheme then
				label = scheme .. ": " .. label
			end
			if vim.bo[buffer].modified then
				label = label .. " ●"
			end
			local highlight = "BufferBarInactive"
			if buffer == current then
				highlight = window == vim.api.nvim_get_current_win() and "BufferBarActive" or "BufferBarCurrent"
				active = #items + 1
			end
			table.insert(items, {
				text = ("%%#%s#%%%d@v:lua.require'buffers'.select@ %s %%X"):format(
					highlight,
					buffer,
					label:gsub("%%", "%%%%")
				),
				width = vim.fn.strdisplaywidth(label) + 2,
			})
		end
	end
	if #items == 0 then
		return ""
	end
	local first, last = active, active
	local width = items[active].width
	while first > 1 and width + items[first - 1].width <= vim.api.nvim_win_get_width(window) - 4 do
		first = first - 1
		width = width + items[first].width
	end
	while last < #items and width + items[last + 1].width <= vim.api.nvim_win_get_width(window) - 4 do
		last = last + 1
		width = width + items[last].width
	end
	local bar = { "%#WinBar#", first > 1 and "‹ " or "" }
	for index = first, last do
		table.insert(bar, items[index].text)
	end
	table.insert(bar, "%#WinBar#" .. (last < #items and " ›" or "") .. "%= ")
	return table.concat(bar)
end

function M.select(buffer, _, button)
	if button == "l" then
		vim.api.nvim_set_current_win(vim.fn.getmousepos().winid)
		vim.api.nvim_set_current_buf(buffer)
	end
end

function M.delete()
	local buffer = vim.api.nvim_get_current_buf()
	if not vim.bo[buffer].buflisted then
		return
	end
	if vim.bo[buffer].modified then
		vim.notify("Buffer has unsaved changes; save it before closing", vim.log.levels.WARN)
		return
	end
	for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
		local buffers = vim.w[window].buffer_bar_buffers or {}
		local replacement
		for index = #buffers, 1, -1 do
			local candidate = buffers[index]
			if candidate ~= buffer and vim.api.nvim_buf_is_valid(candidate) and vim.bo[candidate].buflisted then
				replacement = candidate
				break
			end
		end
		vim.api.nvim_win_set_buf(window, replacement or vim.api.nvim_create_buf(true, false))
	end
	if not vim.api.nvim_buf_is_valid(buffer) then
		return
	end
	if vim.bo[buffer].buftype == "" and not vim.api.nvim_buf_get_name(buffer):match("^%a[%w+.-]*://") then
		vim.cmd.bdelete(buffer)
	else
		vim.api.nvim_buf_delete(buffer, {})
	end
end

return M
