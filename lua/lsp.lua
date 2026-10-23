local M = {}

local lsp_start = vim.lsp.start
vim.lsp.start = function(config, opts)
	local bufnr = opts and opts.bufnr or 0
	if vim.api.nvim_buf_get_name(bufnr) == "" and config.name ~= "mini.snippets" then
		return
	end
	return lsp_start(config, opts)
end

-- Shared LSP settings. Named configs below incrementally override this block.
vim.lsp.config("*", {
	capabilities = {
		textDocument = {
			completion = {
				completionItem = { snippetSupport = true },
			},
		},
	},
})

local lsp_to_complete_items = vim.lsp.completion._lsp_to_complete_items
vim.lsp.completion._lsp_to_complete_items = function(result, prefix, ...)
	local matches = lsp_to_complete_items(result, prefix, ...)
	if #matches == 1 and matches[1].word == prefix then
		local item = matches[1].user_data.nvim.lsp.completion_item
		if
			(item.insertTextFormat == nil or item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.PlainText)
			and (type(item.additionalTextEdits) ~= "table" or next(item.additionalTextEdits) == nil)
			and not item.command
		then
			return {}
		end
	end
	return matches
end

vim.lsp.config("tsc", {
	settings = {
		["js/ts"] = {
			preferGoToSourceDefinition = true,
		preferences = {
				jsxAttributeCompletionStyle = "none",
			},
		},
	},
})

vim.lsp.config("rust_analyzer", {
	cmd = function(dispatchers, config)
		return vim.lsp.rpc.start({ "rust-analyzer" }, dispatchers, { cwd = config.root_dir })
	end,
})

vim.lsp.config("harper_ls", {
	filetypes = { "asciidoc" },
	settings = {
		["harper-ls"] = vim.empty_dict(),
	},
})

vim.lsp.config("nim_langserver", {
	handlers = {
		["window/showMessage"] = function(err, result, context, config)
			if
				result
				and result.type == vim.lsp.protocol.MessageType.Info
				and (vim.startswith(result.message, "Nimsuggest initialized for ") or vim.startswith(result.message, "Opening file://"))
			then
				return
			end
			return vim.lsp.handlers["window/showMessage"](err, result, context, config)
		end,
	},
	settings = {
		nim = {
			nimsuggestPath = vim.fn.expand("~/.local/bin/nimsuggest"),
		},
	},
})

vim.lsp.semantic_tokens.enable(false)
vim.lsp.enable({ "tsc", "denols", "rust_analyzer", "gopls", "zls", "harper_ls", "sourcekit", "nim_langserver" })
vim.api.nvim_create_autocmd("BufFilePost", {
	callback = function(event)
		if vim.api.nvim_buf_get_name(event.buf) ~= "" and vim.bo[event.buf].filetype ~= "" then
			vim.api.nvim_exec_autocmds("FileType", {
				group = "nvim.lsp.enable",
				buffer = event.buf,
				modeline = false,
			})
		end
	end,
})
vim.lsp.log.set_level("info")

local document_highlight_handler = vim.lsp.handlers["textDocument/documentHighlight"]
vim.lsp.handlers["textDocument/documentHighlight"] = function(err, result, context, config)
	vim.lsp.util.buf_clear_references(context.bufnr)
	return document_highlight_handler(err, result, context, config)
end

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if not client then
			return
		end
		if vim.b[event.buf].bigfile then
			vim.schedule(function()
				vim.lsp.buf_detach_client(event.buf, client.id)
			end)
			return
		end
		client._log_prefix = ("LSP[%s:%d]"):format(client.name, client.id)
		if client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
			local group = vim.api.nvim_create_augroup("lsp-completion-input-" .. event.buf, { clear = false })
			if #vim.api.nvim_get_autocmds({ group = group, event = "TextChangedI", buffer = event.buf }) == 0 then
				local accepted_tick
				vim.api.nvim_create_autocmd("CompleteDone", {
					group = group,
					buffer = event.buf,
					callback = function()
						if vim.v.event.reason == "accept" or vim.v.event.reason == "cancel" then
							accepted_tick = vim.b[event.buf].changedtick
						end
					end,
				})
				vim.api.nvim_create_autocmd("TextChangedI", {
					group = group,
					buffer = event.buf,
					callback = function()
						vim.schedule(function()
							if accepted_tick == vim.b[event.buf].changedtick then
								accepted_tick = nil
								return
							end
							local col = vim.api.nvim_win_get_cursor(0)[2]
							if col > 0 and vim.api.nvim_get_current_line():sub(col, col):match("[%w_]") then
								vim.lsp.completion.get()
							end
						end)
					end,
				})
			end
		end
		if client:supports_method("textDocument/documentHighlight") then
			local group = vim.api.nvim_create_augroup("lsp-document-highlight-" .. event.buf, { clear = true })
			vim.api.nvim_create_autocmd("CursorMoved", {
				group = group,
				buffer = event.buf,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd("ModeChanged", {
				group = group,
				buffer = event.buf,
				callback = function()
					local highlights = vim.opt_local.winhighlight:get()
					if vim.v.event.new_mode == "n" then
						highlights.LspReferenceText = nil
						highlights.LspReferenceRead = nil
						highlights.LspReferenceWrite = nil
						vim.lsp.buf.document_highlight()
					else
						highlights.LspReferenceText = "LspReferenceHidden"
						highlights.LspReferenceRead = "LspReferenceHidden"
						highlights.LspReferenceWrite = "LspReferenceHidden"
					end
					vim.opt_local.winhighlight = highlights
				end,
			})
			vim.lsp.buf.document_highlight()
		end
	end,
})

require("mini.snippets").start_lsp_server({
	before_attach = function(bufnr)
		return vim.bo[bufnr].filetype == "zig"
	end,
})

function M.open()
	local items = {}
	for _, client in ipairs(vim.lsp.get_clients()) do
		local state = client.initialized and "running" or "starting"
		local root = client.root_dir and vim.fn.fnamemodify(client.root_dir, ":~") or "[single file]"
		items[#items + 1] = {
			text = ("%-18s #%d  %-8s  %s"):format(client.name, client.id, state, root),
			client_id = client.id,
		}
	end

	if #items == 0 then
		vim.notify("No active LSP servers", vim.log.levels.INFO)
		return
	end

	table.sort(items, function(a, b)
		return a.text < b.text
	end)

	local selected = require("mini.pick").start({
		source = {
			name = "LSP servers",
			items = items,
			show = require("mini.pick").default_show,
			choose = function() end,
		},
	})
	if not selected then
		return
	end
	local client = vim.lsp.get_client_by_id(selected.client_id)
	if not client then
		vim.notify("LSP server stopped before it was selected", vim.log.levels.WARN)
		return
	end

	local action = require("mini.pick").start({
		source = {
			name = client.name .. " #" .. client.id,
			items = {
				{ text = "View logs", action = "logs" },
				{ text = "Restart server", action = "restart" },
				{ text = "Stop server", action = "stop" },
			},
			show = require("mini.pick").default_show,
			choose = function() end,
		},
	})
	if not action then
		return
	end

	if action.action == "restart" then
		client:_restart()
		vim.notify(("Restarting %s #%d"):format(client.name, client.id))
	elseif action.action == "stop" then
		client:stop()
		vim.notify(("Stopping %s #%d"):format(client.name, client.id))
	else
		local prefix = ("LSP[%s:%d]"):format(client.name, client.id)
		local result = vim.system({ "rg", "--fixed-strings", prefix, vim.lsp.log.get_filename() }, { text = true }):wait()
		local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
		table.insert(lines, 1, "Log file: " .. vim.lsp.log.get_filename())
		table.insert(lines, 1, "Root: " .. (client.root_dir or "[single file]"))
		table.insert(lines, 1, ("%s #%d"):format(client.name, client.id))
		vim.cmd("tabnew")
		vim.api.nvim_buf_set_name(0, ("lsp://log/%s-%d-%d"):format(client.name, client.id, vim.uv.hrtime()))
		vim.bo.buftype = "nofile"
		vim.bo.bufhidden = "wipe"
		vim.bo.swapfile = false
		vim.bo.filetype = "log"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.bo.modified = false
		vim.bo.modifiable = false
	end
end

return M
