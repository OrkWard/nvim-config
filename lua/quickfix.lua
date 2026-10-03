local M = {}

vim.g.qf_disable_statusline = true

local border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" }
local namespace = vim.api.nvim_create_namespace("QuickfixSourceHighlights")
local prompt_namespace = vim.api.nvim_create_namespace("QuickfixPrompt")
local context = {}
local highlights = {}
local parsers = {}
local sources = {}
local versions = {}
local frame_window
local prompt_window
local quickfix_window
local prompt_buffer
local source_window
local process
local stdout
local autocmds = {}
local generation = 0

function M.close()
	generation = generation + 1
	vim.cmd.stopinsert()
	for _, autocmd in ipairs(autocmds) do
		pcall(vim.api.nvim_del_autocmd, autocmd)
	end
	autocmds = {}
	if stdout and stdout:is_active() then
		stdout:read_stop()
	end
	if stdout and not stdout:is_closing() then
		stdout:close()
	end
	if process and process:is_active() then
		process:kill()
	end
	if prompt_window and vim.api.nvim_win_is_valid(prompt_window) then
		vim.api.nvim_win_close(prompt_window, true)
	end
	if quickfix_window and vim.api.nvim_win_is_valid(quickfix_window) then
		vim.api.nvim_win_close(quickfix_window, true)
	end
	if frame_window and vim.api.nvim_win_is_valid(frame_window) then
		vim.api.nvim_win_close(frame_window, true)
	end
	prompt_window = nil
	quickfix_window = nil
	frame_window = nil
	prompt_buffer = nil
	vim.api.nvim__redraw({ valid = false, flush = true })
end

local function highlight_line(path, line)
	local stat = vim.uv.fs_stat(path)
	local version = stat and stat.size .. ":" .. stat.mtime.sec .. ":" .. stat.mtime.nsec
	if versions[path] ~= version then
		context[path] = vim.fn.readfile(path)
		sources[path] = table.concat(context[path], "\n")
		highlights[path] = {}
		local filetype = vim.filetype.match({ filename = path })
		local language = filetype and (vim.treesitter.language.get_lang(filetype) or filetype)
		local ok, parser = pcall(vim.treesitter.get_string_parser, sources[path], language)
		parsers[path] = ok and parser or false
		if ok and not pcall(parser.parse, parser) then
			parsers[path] = false
		end
		versions[path] = version
	end

	highlights[path] = highlights[path] or {}
	if highlights[path][line] == nil then
		local bytes = {}
		if parsers[path] then
			pcall(function()
				parsers[path]:for_each_tree(function(tree, language_tree)
					local language = language_tree:lang()
					local query = vim.treesitter.query.get(language, "highlights")
					if not query then
						return
					end
					for id, node, metadata in query:iter_captures(tree:root(), sources[path], line - 1, line) do
						local capture = query.captures[id]
						if capture and capture:sub(1, 1) ~= "_" then
							local range = vim.treesitter.get_range(node, sources[path], metadata[id])
							local start_row, start_col, end_row, end_col = range[1], range[2], range[4], range[5]
							local start = start_row == line - 1 and start_col or 0
							local finish = end_row == line - 1 and end_col or #(context[path][line] or "")
							local priority = tonumber(metadata.priority or metadata[id] and metadata[id].priority)
								or vim.hl.priorities.treesitter
							for col = start + 1, finish do
								if not bytes[col] or priority >= bytes[col][2] then
									bytes[col] = { "@" .. capture .. "." .. language, priority }
								end
							end
						end
					end
				end)
			end)
		end
		highlights[path][line] = bytes
	end
	return highlights[path][line]
end

local function highlight_visible()
	if not quickfix_window or not vim.api.nvim_win_is_valid(quickfix_window) then
		return
	end
	local buffer = vim.api.nvim_win_get_buf(quickfix_window)
	local items = vim.fn.getqflist({ items = 0 }).items
	local visible = vim.api.nvim_win_call(quickfix_window, function()
		return { vim.fn.line("w0"), vim.fn.line("w$") }
	end)
	vim.api.nvim_buf_clear_namespace(buffer, namespace, visible[1] - 1, visible[2])
	for row = visible[1], visible[2] do
		local item = items[row]
		if item and item.bufnr > 0 and item.lnum > 0 then
			local path = vim.api.nvim_buf_get_name(item.bufnr)
			local display = vim.api.nvim_buf_get_lines(buffer, row - 1, row, false)[1] or ""
			local separator = display:find(" ", 1, true)
			if separator and path ~= "" then
				local offset = separator - 1 + #" "
				local bytes = highlight_line(path, item.lnum)
				local col = 1
				while col <= #(context[path][item.lnum] or "") do
					local highlight = bytes[col] and bytes[col][1] or "QuickFixText"
					local to = col
					while
						to < #(context[path][item.lnum] or "")
						and (bytes[to + 1] and bytes[to + 1][1] or "QuickFixText") == highlight
					do
						to = to + 1
					end
					vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, offset + col - 1, {
						end_col = offset + to,
						hl_group = highlight,
						priority = 200,
						strict = false,
					})
					col = to + 1
				end
				if item.valid == 1 and item.col > 0 then
					local start_col = offset + item.col - 1
					if start_col < #display then
						vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, start_col, {
							end_col = math.min(#display, offset + math.max(item.col, item.end_col - 1)),
							hl_group = "MiniPickMatchRanges",
							priority = 300,
							strict = false,
						})
					end
				end
			end
		end
	end
end

local function move(direction)
	if not quickfix_window or not vim.api.nvim_win_is_valid(quickfix_window) then
		return
	end
	local current = vim.api.nvim_win_get_cursor(quickfix_window)[1]
	local items = vim.fn.getqflist({ items = 0 }).items
	local target
	if direction > 0 then
		for row = current + 1, #items do
			if items[row].valid == 1 then
				target = row
				break
			end
		end
		if not target then
			for row, item in ipairs(items) do
				if item.valid == 1 then
					target = row
					break
				end
			end
		end
	else
		for row = current - 1, 1, -1 do
			if items[row].valid == 1 then
				target = row
				break
			end
		end
		if not target then
			for row = #items, 1, -1 do
				if items[row].valid == 1 then
					target = row
					break
				end
			end
		end
	end
	if target then
		vim.api.nvim_win_set_cursor(quickfix_window, { target, 0 })
		vim.api.nvim__redraw({ win = quickfix_window, cursor = true, flush = true })
	end
end

local function open_selected()
	if not quickfix_window or not vim.api.nvim_win_is_valid(quickfix_window) then
		return
	end
	local row = vim.api.nvim_win_get_cursor(quickfix_window)[1]
	local item = vim.fn.getqflist({ items = 0 }).items[row]
	if not item or item.bufnr == 0 or item.lnum == 0 then
		return
	end
	local window = source_window
	vim.cmd.stopinsert()
	M.close()
	if window and vim.api.nvim_win_is_valid(window) then
		vim.api.nvim_set_current_win(window)
	end
	vim.cmd("normal! m'")
	vim.bo[item.bufnr].buflisted = true
	vim.api.nvim_win_set_buf(0, item.bufnr)
	vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
end

local function open(title, items, prompt, on_change, match_count)
	M.close()
	vim.cmd.stopinsert()
	source_window = vim.api.nvim_get_current_win()
	vim.fn.setqflist({}, " ", { title = title, items = items })
	vim.cmd("silent copen")
	local normal_quickfix_window = vim.fn.getqflist({ winid = 0 }).winid
	local quickfix_buffer = vim.api.nvim_win_get_buf(normal_quickfix_window)

	local height = math.floor(0.618 * vim.o.lines)
	local width = math.floor(0.618 * vim.o.columns)
	local row = math.floor(0.5 * (vim.o.lines - height))
	local col = math.floor(0.5 * (vim.o.columns - width))
	local frame_buffer = vim.api.nvim_create_buf(false, true)
	frame_window = vim.api.nvim_open_win(frame_buffer, false, {
		border = border,
		col = col,
		focusable = false,
		footer = { { " " .. (match_count or #items) .. " matches ", "MiniPickBorderText" } },
		footer_pos = "right",
		height = height,
		relative = "editor",
		row = row,
		style = "minimal",
		title = { { " " .. title .. " ", "MiniPickBorderText" } },
		title_pos = "left",
		width = width,
		zindex = 50,
	})
	vim.bo[frame_buffer].bufhidden = "wipe"
	vim.wo[frame_window].winhighlight =
		"NormalFloat:MiniPickNormal,FloatBorder:MiniPickBorder,FloatTitle:MiniPickBorderText"

	quickfix_window = normal_quickfix_window
	vim.api.nvim_win_set_config(quickfix_window, {
		col = col + 1,
		height = height - (prompt and 2 or 0),
		relative = "editor",
		row = row + (prompt and 3 or 1),
		style = "minimal",
		width = width,
		zindex = 51,
	})
	vim.wo[quickfix_window].cursorline = true
	vim.wo[quickfix_window].scrolloff = 5
	vim.wo[quickfix_window].statusline = ""
	vim.wo[quickfix_window].winhighlight = "Normal:MiniPickNormal,CursorLine:CursorLine"

	if prompt then
		prompt_buffer = vim.api.nvim_create_buf(false, true)
		vim.bo[prompt_buffer].bufhidden = "wipe"
		vim.bo[prompt_buffer].buftype = "nofile"
		vim.bo[prompt_buffer].swapfile = false
		vim.api.nvim_buf_set_lines(prompt_buffer, 0, -1, false, { prompt })
		vim.api.nvim_buf_set_extmark(prompt_buffer, prompt_namespace, 0, 0, {
			right_gravity = false,
			virt_text = { { " Search: ", "MiniPickPromptPrefix" } },
			virt_text_pos = "inline",
		})
		prompt_window = vim.api.nvim_open_win(prompt_buffer, true, {
			col = col + 1,
			height = 1,
			relative = "editor",
			row = row + 1,
			style = "minimal",
			width = width,
			zindex = 52,
		})
		vim.wo[prompt_window].winhighlight = "Normal:MiniPickNormal"
		vim.api.nvim_win_set_cursor(prompt_window, { 1, #prompt })
		table.insert(
			autocmds,
			vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
				buffer = prompt_buffer,
				callback = function()
					on_change(vim.api.nvim_buf_get_lines(prompt_buffer, 0, 1, false)[1] or "")
				end,
			})
		)
		vim.keymap.set({ "i", "n" }, "<C-n>", function()
			move(1)
		end, { buffer = prompt_buffer })
		vim.keymap.set({ "i", "n" }, "<C-p>", function()
			move(-1)
		end, { buffer = prompt_buffer })
		vim.keymap.set({ "i", "n" }, "<CR>", open_selected, { buffer = prompt_buffer })
		vim.keymap.set({ "i", "n" }, "<Esc>", M.close, { buffer = prompt_buffer })
		vim.cmd.startinsert()
	end

	vim.keymap.set({ "i", "n" }, "<C-n>", function()
		move(1)
	end, { buffer = quickfix_buffer, nowait = true })
	vim.keymap.set({ "i", "n" }, "<C-p>", function()
		move(-1)
	end, { buffer = quickfix_buffer, nowait = true })
	vim.keymap.set({ "i", "n" }, "<CR>", open_selected, { buffer = quickfix_buffer, nowait = true })
	vim.keymap.set({ "i", "n" }, "<Esc>", M.close, { buffer = quickfix_buffer, nowait = true })
	vim.keymap.set("n", "q", M.close, { buffer = quickfix_buffer, nowait = true })
	vim.keymap.set("n", "i", function()
		if prompt_window and vim.api.nvim_win_is_valid(prompt_window) then
			vim.api.nvim_set_current_win(prompt_window)
			vim.api.nvim_win_set_cursor(prompt_window, { 1, #(vim.api.nvim_get_current_line()) })
			vim.cmd.startinsert()
		end
	end, { buffer = quickfix_buffer })

	table.insert(
		autocmds,
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = quickfix_buffer,
			callback = highlight_visible,
		})
	)
	table.insert(
		autocmds,
		vim.api.nvim_create_autocmd("WinScrolled", {
			pattern = tostring(quickfix_window),
			callback = highlight_visible,
		})
	)
	table.insert(
		autocmds,
		vim.api.nvim_create_autocmd("WinClosed", {
			pattern = tostring(quickfix_window),
			callback = M.close,
		})
	)
	vim.defer_fn(highlight_visible, 40)
	return frame_window
end

function M.search(initial_query, cwd)
	cwd = cwd or vim.fn.getcwd()
	local function start(query)
		generation = generation + 1
		local request = generation
		if stdout and stdout:is_active() then
			stdout:read_stop()
		end
		if stdout and not stdout:is_closing() then
			stdout:close()
		end
		if process and process:is_active() then
			process:kill()
		end
		vim.defer_fn(function()
			if request ~= generation or not frame_window or not vim.api.nvim_win_is_valid(frame_window) then
				return
			end
			local items = {}
			local count = 0
			local tail = ""
			local previous
			local waiting
			local update_scheduled = false
			local finished = false
			vim.fn.setqflist({}, "r", { title = "Search", items = {} })
			vim.api.nvim_win_set_config(frame_window, {
				footer = { { " 0 matches ", "MiniPickBorderText" } },
				footer_pos = "right",
			})
			if query == "" then
				return
			end

			local refresh = function()
				if request ~= generation then
					return
				end
				update_scheduled = false
				vim.fn.setqflist({}, "r", { title = "Search", items = items })
				vim.api.nvim_win_set_config(frame_window, {
					footer = { { " " .. count .. " matches ", "MiniPickBorderText" } },
					footer_pos = "right",
				})
				vim.api.nvim__redraw({ win = quickfix_window, valid = false, flush = true })
				vim.defer_fn(highlight_visible, finished and 40 or 20)
			end

			local case = vim.o.ignorecase and (vim.o.smartcase and "--smart-case" or "--ignore-case")
				or "--case-sensitive"
			local pipe = vim.uv.new_pipe()
			local handle
			handle = vim.uv.spawn("rg", {
				args = {
					"--column",
					"--fixed-strings",
					"--line-number",
					"--no-heading",
					"--with-filename",
					"--context",
					"1",
					"--no-context-separator",
					"--field-match-separator",
					"\\x00",
					"--field-context-separator",
					"\\x00",
					"--color=never",
					case,
					"--",
					query,
				},
				cwd = cwd,
				stdio = { nil, pipe, nil },
			}, function()
				if handle and not handle:is_closing() then
					handle:close()
				end
			end)
			process = handle
			stdout = pipe
			if not handle then
				pipe:close()
				return
			end

			local function append(item)
				local path = vim.fs.joinpath(cwd, item.path)
				local header = count > 0 and (items[#items].filename == path and "soft" or "hard") or nil
				if item.before then
					table.insert(items, {
						filename = path,
						lnum = item.line - 1,
						text = item.before,
						valid = 0,
						user_data = { header = header, source = "grep" },
					})
					header = nil
				end
				table.insert(items, {
					col = item.column,
					end_col = item.column + #query,
					filename = path,
					lnum = item.line,
					text = item.text,
					user_data = { header = header, source = "grep" },
					valid = 1,
				})
				if item.after then
					table.insert(items, {
						filename = path,
						lnum = item.line + 1,
						text = item.after,
						valid = 0,
						user_data = { source = "grep" },
					})
				end
				count = count + 1
			end

			local read
			read = function(_, data)
				pipe:read_stop()
				vim.defer_fn(function()
					if request ~= generation then
						return
					end
					local eof = data == nil
					if data then
						data = tail .. data
					elseif tail ~= "" then
						data = tail .. "\n"
						tail = ""
					end
					if data then
						local from = 1
						while true do
							local line_start, line_end = data:find("\r?\n", from)
							if not line_start then
								break
							end
							local record = data:sub(from, line_start - 1)
							local path, line, column, text = record:match("^(.-)%z(%d+)%z(%d+)%z(.*)$")
							if not path then
								path, line, text = record:match("^(.-)%z(%d+)%z(.*)$")
							end
							line = tonumber(line)
							column = tonumber(column)
							if path and line then
								if waiting then
									if path == waiting.path and line == waiting.line + 1 then
										waiting.after = text
									end
									append(waiting)
									waiting = nil
								end
								if column then
									waiting = {
										before = previous
												and previous.path == path
												and previous.line == line - 1
												and previous.text
											or nil,
										column = column,
										line = line,
										path = path,
										text = text,
									}
								end
								previous = { line = line, path = path, text = text }
							end
							from = line_end + 1
						end
						tail = data:sub(from)
					end
					if eof and waiting then
						append(waiting)
						waiting = nil
					end
					finished = eof
					if eof and not pipe:is_closing() then
						pipe:close()
					elseif not pipe:is_closing() then
						pipe:read_start(read)
					end
					if not update_scheduled then
						update_scheduled = true
						vim.defer_fn(refresh, eof and 0 or 16)
					end
				end, 1)
			end
			pipe:read_start(read)
		end, 120)
	end

	open("Search", {}, initial_query or "", start)
	if initial_query and initial_query ~= "" then
		start(initial_query)
	end
end

function M.references()
	local query = vim.fn.expand("<cword>")
	local window = vim.api.nvim_get_current_win()
	vim.lsp.buf.references(nil, {
		on_list = function(list)
			vim.schedule(function()
				M.close()
				source_window = window
				vim.fn.setqflist({}, " ", { title = "References: " .. query, items = list.items })

				local buffer = vim.api.nvim_create_buf(false, true)
				local lines = {}
				local header_rows = {}
				local match_rows = {}
				local locations = {}
				local code_rows = {}
				local files = {}
				local cwd = vim.fn.getcwd()
				for _, item in ipairs(list.items) do
					local path = item.filename or vim.api.nvim_buf_get_name(item.bufnr)
					if not files[path] then
						local bufnr = vim.fn.bufnr(path)
						files[path] = bufnr > 0
								and vim.api.nvim_buf_is_loaded(bufnr)
								and vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
							or vim.fn.readfile(path)
					end
					table.insert(lines, vim.fs.relpath(cwd, path) or path)
					table.insert(header_rows, #lines)
					if files[path][item.lnum - 1] then
						table.insert(lines, string.format("%6d │ %s", item.lnum - 1, files[path][item.lnum - 1]))
						table.insert(code_rows, { line = item.lnum - 1, path = path, row = #lines })
					end
					table.insert(
						lines,
						string.format("%6d │ %s", item.lnum, files[path][item.lnum] or item.text or "")
					)
					table.insert(code_rows, { item = item, line = item.lnum, path = path, row = #lines })
					table.insert(match_rows, #lines)
					locations[#lines] = item
					if files[path][item.lnum + 1] then
						table.insert(lines, string.format("%6d │ %s", item.lnum + 1, files[path][item.lnum + 1]))
						table.insert(code_rows, { line = item.lnum + 1, path = path, row = #lines })
					end
				end

				vim.bo[buffer].bufhidden = "wipe"
				vim.bo[buffer].buftype = "nofile"
				vim.bo[buffer].swapfile = false
				vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
				local height = math.floor(0.618 * vim.o.lines)
				local width = math.floor(0.618 * vim.o.columns)
				quickfix_window = vim.api.nvim_open_win(buffer, true, {
					border = border,
					col = math.floor(0.5 * (vim.o.columns - width)),
					footer = { { " " .. #list.items .. " matches ", "MiniPickBorderText" } },
					footer_pos = "right",
					height = height,
					relative = "editor",
					row = math.floor(0.5 * (vim.o.lines - height)),
					style = "minimal",
					title = { { " References: " .. query .. " ", "MiniPickBorderText" } },
					title_pos = "left",
					width = width,
				})
				vim.wo[quickfix_window].cursorline = true
				vim.wo[quickfix_window].scrolloff = 5
				vim.wo[quickfix_window].winhighlight =
					"NormalFloat:MiniPickNormal,FloatBorder:MiniPickBorder,FloatTitle:MiniPickBorderText"
				vim.wo[quickfix_window].wrap = false

				for _, row in ipairs(header_rows) do
					vim.api.nvim_buf_set_extmark(buffer, namespace, row - 1, 0, {
						end_col = 0,
						hl_eol = true,
						hl_group = "Directory",
					})
				end
				for _, info in ipairs(code_rows) do
					local text = files[info.path][info.line] or ""
					local prefix = string.format("%6d │ ", info.line)
					local bytes = highlight_line(info.path, info.line)
					local col = 1
					while col <= #text do
						local highlight = bytes[col] and bytes[col][1] or "MiniPickNormal"
						local to = col
						while to < #text and (bytes[to + 1] and bytes[to + 1][1] or "MiniPickNormal") == highlight do
							to = to + 1
						end
						vim.api.nvim_buf_set_extmark(buffer, namespace, info.row - 1, #prefix + col - 1, {
							end_col = #prefix + to,
							hl_group = highlight,
							priority = 200,
						})
						col = to + 1
					end
					if info.item and info.item.col > 0 then
						vim.api.nvim_buf_set_extmark(buffer, namespace, info.row - 1, #prefix + info.item.col - 1, {
							end_col = math.min(
								#prefix + #text,
								#prefix + math.max(info.item.col, info.item.end_col - 1)
							),
							hl_group = "MiniPickMatchRanges",
							priority = 300,
						})
					end
				end
				vim.bo[buffer].modifiable = false
				if match_rows[1] then
					vim.api.nvim_win_set_cursor(quickfix_window, { match_rows[1], 0 })
				end

				vim.keymap.set("n", "<C-n>", function()
					local current = vim.api.nvim_win_get_cursor(quickfix_window)[1]
					local target = match_rows[1]
					for _, row in ipairs(match_rows) do
						if row > current then
							target = row
							break
						end
					end
					vim.api.nvim_win_set_cursor(quickfix_window, { target, 0 })
				end, { buffer = buffer })
				vim.keymap.set("n", "<C-p>", function()
					local current = vim.api.nvim_win_get_cursor(quickfix_window)[1]
					local target = match_rows[#match_rows]
					for index = #match_rows, 1, -1 do
						if match_rows[index] < current then
							target = match_rows[index]
							break
						end
					end
					vim.api.nvim_win_set_cursor(quickfix_window, { target, 0 })
				end, { buffer = buffer })
				vim.keymap.set("n", "<CR>", function()
					local item = locations[vim.api.nvim_win_get_cursor(quickfix_window)[1]]
					if not item then
						return
					end
					M.close()
					vim.api.nvim_set_current_win(window)
					vim.cmd("normal! m'")
					local bufnr = item.bufnr and item.bufnr > 0 and item.bufnr or vim.fn.bufadd(item.filename)
					vim.fn.bufload(bufnr)
					vim.bo[bufnr].buflisted = true
					vim.api.nvim_win_set_buf(window, bufnr)
					vim.api.nvim_win_set_cursor(window, { item.lnum, math.max(item.col - 1, 0) })
				end, { buffer = buffer })
				vim.keymap.set("n", "<Esc>", M.close, { buffer = buffer })
				vim.keymap.set("n", "q", M.close, { buffer = buffer })
				vim.api.nvim_create_autocmd("WinClosed", {
					pattern = tostring(quickfix_window),
					once = true,
					callback = function()
						quickfix_window = nil
						vim.api.nvim__redraw({ valid = false, flush = true })
					end,
				})
			end)
		end,
	})
end

return M
