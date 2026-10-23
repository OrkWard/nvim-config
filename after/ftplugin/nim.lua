-- runtime ftplugin only configures comments; indentation comes from queries/nim/indents.scm
vim.bo.shiftwidth = 2
vim.bo.commentstring = "# %s"
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
vim.opt_local.indentkeys:append({ "<:>", "." })
