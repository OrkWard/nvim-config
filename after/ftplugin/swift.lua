-- runtime has no swift indent script and falls back to 'smartindent'
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
