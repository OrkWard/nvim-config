local M = {}

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

vim.lsp.config("ts_ls", {
	init_options = {
		preferences = {
			preferGoToSourceDefinition = true,
			jsxAttributeCompletionStyle = "none",
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

vim.lsp.semantic_tokens.enable(false)
vim.lsp.enable({ "ts_ls", "denols", "rust_analyzer", "gopls", "harper_ls" })
vim.lsp.log.set_level("info")

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
		vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
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
