local M = {}

vim.g.qf_disable_statusline = true

local border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" }
local namespace = vim.api.nvim_create_namespace("QuickfixSourceHighlights")
local context = {}
local highlights = {}
local parsers = {}
local sources = {}
local versions = {}
local quickfix_window

function M.close()
	vim.cmd.stopinsert()
	if quickfix_window and vim.api.nvim_win_is_valid(quickfix_window) then
		vim.api.nvim_win_close(quickfix_window, true)
	end
	quickfix_window = nil
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

function M.references()
	local query = vim.fn.expand("<cword>")
	local window = vim.api.nvim_get_current_win()
	vim.lsp.buf.references(nil, {
		on_list = function(list)
			vim.schedule(function()
				M.close()
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
