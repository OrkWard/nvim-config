-- ================================== Commands ==================================
function create_command(name, fun)
    vim.api.nvim_create_user_command(name, fun, {})
end

create_command('EditFileType', function()
  local ft = vim.bo.filetype
  if ft ~= '' then
    vim.cmd('edit ~/.config/nvim/after/ftplugin/' .. ft .. '.lua')
  end
end)

create_command('Lsp', function()
  require('lsp').open()
end)
