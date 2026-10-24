-- runtime ships no elvish ftplugin or indent script; indentation comes from queries/elvish/indents.scm
vim.bo.shiftwidth = 2
vim.bo.commentstring = "# %s"
vim.bo.comments = ":#"
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
vim.bo.indentkeys = "0},0],0),!^F,o,O"
