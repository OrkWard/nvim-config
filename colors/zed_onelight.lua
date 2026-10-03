-- Zed OneLight colorscheme for Neovim
-- Converted from Helix theme: contrib/themes/zed_onelight.toml

local colors = {
  -- Palette colors
  yellow = "#dabb7e",
  red = "#d36151",
  orange = "#d3604f",
  blue = "#5b79e3",
  dark_blue = "#4a62db",
  purple = "#a449ab",
  violet = "#9294be",
  green = "#649f57",
  gold = "#ad6e25",
  cyan = "#3882b7",
  light_black = "#2e323a",
  gray = "#eaeaed",
  dark_gray = "#ebebec",
  light_gray = "#a2a3a7",
  blue_gray = "#d9dcea",
  faint_gray = "#efefef",
  whitespace = "#d4d4d8",
  linenr = "#b0b1b3",
  black = "#383a41",
  white = "#fafafa",
  ui_text = "#383a41",
  ui_text_reversed = "#fafafa",
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "zed_onelight"

local hl = vim.api.nvim_set_hl

-- Editor UI
hl(0, "Normal", { fg = colors.black, bg = colors.white })
hl(0, "NormalNC", { fg = colors.black, bg = colors.white })
hl(0, "Whitespace", { fg = colors.whitespace })
hl(0, "Cursor", { fg = colors.dark_blue, reverse = true })
hl(0, "CursorIM", { fg = colors.dark_blue, reverse = true })
hl(0, "CursorLine", { bg = colors.faint_gray })
hl(0, "CursorColumn", { bg = colors.faint_gray })
hl(0, "LineNr", { fg = colors.linenr, bg = colors.white })
hl(0, "CursorLineNr", { fg = colors.black, bg = colors.faint_gray, bold = true })
hl(0, "SignColumn", { bg = colors.white })
hl(0, "ColorColumn", { bg = colors.faint_gray })

-- Selection
hl(0, "Visual", { bg = colors.blue_gray })
hl(0, "VisualNOS", { bg = colors.blue_gray })
hl(0, "Search", { fg = colors.black, bg = colors.blue_gray })
hl(0, "IncSearch", { fg = colors.black, bg = colors.faint_gray, bold = true })
hl(0, "CurSearch", { fg = colors.black, bg = colors.gray, bold = true })
hl(0, "MatchParen", { fg = colors.dark_blue, bold = true })

-- Status line
hl(0, "StatusLine", { fg = colors.black, bg = colors.gray })
hl(0, "StatusLineNC", { fg = colors.white, bg = colors.light_black })
hl(0, "ModeMsg", { fg = colors.black })
hl(0, "MsgArea", { fg = colors.black, bg = colors.white })
hl(0, "MsgSeparator", { fg = colors.light_gray })

-- Split windows
hl(0, "VertSplit", { fg = colors.dark_gray })
hl(0, "WinSeparator", { fg = colors.dark_gray })

-- Popups and floating windows
hl(0, "Pmenu", { fg = colors.black, bg = colors.dark_gray })
hl(0, "PmenuSel", { fg = colors.ui_text, bg = colors.gray, bold = true })
hl(0, "PmenuSbar", { bg = colors.gray })
hl(0, "PmenuThumb", { bg = colors.light_gray })
hl(0, "NormalFloat", { fg = colors.black, bg = colors.white })
hl(0, "FloatBorder", { fg = colors.linenr, bg = colors.white })
hl(0, "FloatTitle", { fg = colors.purple, bg = colors.white, bold = true })

-- Folds
hl(0, "Folded", { fg = colors.light_gray, bg = colors.faint_gray })
hl(0, "FoldColumn", { fg = colors.linenr, bg = colors.white })

-- Syntax highlighting
hl(0, "Comment", { fg = colors.light_gray, italic = true })
hl(0, "Constant", { fg = colors.green })
hl(0, "String", { fg = colors.green })
hl(0, "Character", { fg = colors.green })
hl(0, "Number", { fg = colors.gold })
hl(0, "Boolean", { fg = colors.green })
hl(0, "Float", { fg = colors.gold })

hl(0, "Identifier", { fg = colors.black })
hl(0, "Function", { fg = colors.blue })
hl(0, "Variable", { fg = colors.black })
hl(0, "Builtin", { fg = colors.gold })

hl(0, "Statement", { fg = colors.purple })
hl(0, "Conditional", { fg = colors.purple })
hl(0, "Repeat", { fg = colors.purple })
hl(0, "Label", { fg = colors.purple })
hl(0, "Operator", { fg = colors.black })
hl(0, "Keyword", { fg = colors.purple })
hl(0, "Exception", { fg = colors.purple })

hl(0, "PreProc", { fg = colors.purple })
hl(0, "Include", { fg = colors.purple })
hl(0, "Define", { fg = colors.purple })
hl(0, "Macro", { fg = colors.purple })
hl(0, "PreCondit", { fg = colors.purple })

hl(0, "Type", { fg = colors.gold })
hl(0, "StorageClass", { fg = colors.purple })
hl(0, "Structure", { fg = colors.gold })
hl(0, "Typedef", { fg = colors.gold })

hl(0, "Special", { fg = colors.orange })
hl(0, "SpecialChar", { fg = colors.orange })
hl(0, "Tag", { fg = colors.orange })
hl(0, "Delimiter", { fg = colors.black })
hl(0, "SpecialComment", { fg = colors.light_gray })
hl(0, "Debug", { fg = colors.red })

hl(0, "Underlined", { fg = colors.blue, underline = true })
hl(0, "Ignore", { fg = colors.light_gray })
hl(0, "Error", { fg = colors.red, bold = true })
hl(0, "Todo", { fg = colors.gold, bold = true })

-- Treesitter highlights
hl(0, "@attribute", { fg = colors.green })
hl(0, "@constant", { fg = colors.green })
hl(0, "@constant.numeric", { fg = colors.gold })
hl(0, "@constant.builtin", { fg = colors.gold })
hl(0, "@constant.builtin.boolean", { fg = colors.green })
hl(0, "@variable.builtin", { fg = colors.gold })
hl(0, "@variable.member", { fg = colors.orange })
hl(0, "@property", { fg = colors.orange })
hl(0, "@field", { fg = colors.orange })

hl(0, "@markup.heading", { fg = colors.orange })
hl(0, "@markup.list", { fg = colors.orange })
hl(0, "@markup.quote", { fg = colors.green })
hl(0, "@markup.raw", { fg = colors.green })
hl(0, "@markup.link", { fg = colors.blue, underline = true })

hl(0, "@function", { fg = colors.blue })
hl(0, "@function.builtin", { fg = colors.blue })
hl(0, "@function.macro", { fg = colors.blue })
hl(0, "@method", { fg = colors.blue })
hl(0, "@constructor", { fg = colors.gold })

hl(0, "@keyword", { fg = colors.purple })
hl(0, "@keyword.function", { fg = colors.purple })
hl(0, "@keyword.operator", { fg = colors.purple })
hl(0, "@keyword.import", { fg = colors.purple })
hl(0, "@keyword.return", { fg = colors.purple })
hl(0, "@conditional", { fg = colors.purple })
hl(0, "@repeat", { fg = colors.purple })
hl(0, "@debug", { fg = colors.red })
hl(0, "@label", { fg = colors.purple })
hl(0, "@include", { fg = colors.purple })
hl(0, "@exception", { fg = colors.purple })

hl(0, "@type", { fg = colors.gold })
hl(0, "@type.builtin", { fg = colors.gold })
hl(0, "@type.definition", { fg = colors.gold })
hl(0, "@type.qualifier", { fg = colors.purple })
hl(0, "@storageclass", { fg = colors.purple })

hl(0, "@namespace", { fg = colors.gold })
hl(0, "@symbol", { fg = colors.green })

hl(0, "@text", { fg = colors.black })
hl(0, "@text.strong", { bold = true })
hl(0, "@text.emphasis", { italic = true })
hl(0, "@text.underline", { underline = true })
hl(0, "@text.strike", { strikethrough = true })
hl(0, "@text.title", { fg = colors.orange, bold = true })
hl(0, "@text.literal", { fg = colors.green })
hl(0, "@text.uri", { fg = colors.blue, underline = true })
hl(0, "@text.math", { fg = colors.gold })
hl(0, "@text.environment", { fg = colors.purple })
hl(0, "@text.environment.name", { fg = colors.purple })
hl(0, "@text.reference", { fg = colors.blue })
hl(0, "@text.todo", { fg = colors.gold, bold = true })
hl(0, "@text.note", { fg = colors.blue })
hl(0, "@text.warning", { fg = colors.yellow })
hl(0, "@text.danger", { fg = colors.red })
hl(0, "@text.diff.add", { fg = colors.green })
hl(0, "@text.diff.delete", { fg = colors.red })

hl(0, "@tag", { fg = colors.orange })
hl(0, "@tag.attribute", { fg = colors.gold })
hl(0, "@tag.delimiter", { fg = colors.black })

hl(0, "@conceal", { fg = colors.light_gray })
hl(0, "@define", { fg = colors.purple })
hl(0, "@macro", { fg = colors.purple })
hl(0, "@preproc", { fg = colors.purple })

-- LSP highlights
hl(0, "LspReferenceText", { bg = colors.blue_gray })
hl(0, "LspReferenceRead", { bg = colors.blue_gray })
hl(0, "LspReferenceWrite", { bg = colors.blue_gray })
hl(0, "LspCodeLens", { fg = colors.light_gray })
hl(0, "LspCodeLensSeparator", { fg = colors.light_gray })
hl(0, "LspSignatureActiveParameter", { fg = colors.dark_blue, bold = true })

-- Diagnostics
hl(0, "DiagnosticError", { fg = colors.red })
hl(0, "DiagnosticWarn", { fg = colors.yellow })
hl(0, "DiagnosticInfo", { fg = colors.blue })
hl(0, "DiagnosticHint", { fg = colors.cyan })
hl(0, "DiagnosticOk", { fg = colors.green })

hl(0, "DiagnosticVirtualTextError", { fg = colors.red, bg = colors.faint_gray })
hl(0, "DiagnosticVirtualTextWarn", { fg = colors.yellow, bg = colors.faint_gray })
hl(0, "DiagnosticVirtualTextInfo", { fg = colors.blue, bg = colors.faint_gray })
hl(0, "DiagnosticVirtualTextHint", { fg = colors.cyan, bg = colors.faint_gray })
hl(0, "DiagnosticVirtualTextOk", { fg = colors.green, bg = colors.faint_gray })

hl(0, "DiagnosticUnderlineError", { sp = colors.red, underline = true })
hl(0, "DiagnosticUnderlineWarn", { sp = colors.yellow, underline = true })
hl(0, "DiagnosticUnderlineInfo", { sp = colors.blue, underline = true })
hl(0, "DiagnosticUnderlineHint", { sp = colors.cyan, underline = true })
hl(0, "DiagnosticUnderlineOk", { sp = colors.green, underline = true })

hl(0, "DiagnosticFloatingError", { fg = colors.red })
hl(0, "DiagnosticFloatingWarn", { fg = colors.yellow })
hl(0, "DiagnosticFloatingInfo", { fg = colors.blue })
hl(0, "DiagnosticFloatingHint", { fg = colors.cyan })
hl(0, "DiagnosticFloatingOk", { fg = colors.green })

hl(0, "DiagnosticSignError", { fg = colors.red })
hl(0, "DiagnosticSignWarn", { fg = colors.yellow })
hl(0, "DiagnosticSignInfo", { fg = colors.blue })
hl(0, "DiagnosticSignHint", { fg = colors.cyan })
hl(0, "DiagnosticSignOk", { fg = colors.green })

-- Git highlights
hl(0, "GitSignsAdd", { fg = colors.green })
hl(0, "GitSignsChange", { fg = colors.yellow })
hl(0, "GitSignsDelete", { fg = colors.red })
hl(0, "GitSignsAddNr", { fg = colors.green })
hl(0, "GitSignsChangeNr", { fg = colors.yellow })
hl(0, "GitSignsDeleteNr", { fg = colors.red })
hl(0, "GitSignsAddLn", { bg = colors.faint_gray })
hl(0, "GitSignsChangeLn", { bg = colors.faint_gray })
hl(0, "GitSignsDeleteLn", { bg = colors.faint_gray })

-- Indent blankline
hl(0, "IblIndent", { fg = colors.gray })
hl(0, "IblScope", { fg = colors.light_gray })

-- Telescope
hl(0, "TelescopeNormal", { fg = colors.black, bg = colors.dark_gray })
hl(0, "TelescopeBorder", { fg = colors.dark_gray })
hl(0, "TelescopePromptNormal", { fg = colors.black, bg = colors.gray })
hl(0, "TelescopePromptBorder", { fg = colors.gray })
hl(0, "TelescopePromptTitle", { fg = colors.ui_text_reversed, bg = colors.blue })
hl(0, "TelescopePreviewTitle", { fg = colors.ui_text_reversed, bg = colors.green })
hl(0, "TelescopeResultsTitle", { fg = colors.ui_text_reversed, bg = colors.purple })
hl(0, "TelescopeSelection", { fg = colors.ui_text, bg = colors.gray, bold = true })
hl(0, "TelescopeSelectionCaret", { fg = colors.blue })
hl(0, "TelescopeMatching", { fg = colors.blue, bold = true })

-- MiniPick
hl(0, "MiniPickNormal", { fg = colors.black, bg = colors.white })
hl(0, "MiniPickBorder", { fg = colors.linenr, bg = colors.white })
hl(0, "MiniPickBorderBusy", { fg = colors.yellow, bg = colors.white })
hl(0, "MiniPickBorderText", { fg = colors.purple, bg = colors.white, bold = true })
hl(0, "MiniPickCursor", { blend = 100, nocombine = true })
hl(0, "MiniPickPrompt", { fg = colors.black, bg = colors.white })
hl(0, "MiniPickPromptCaret", { fg = colors.blue, bg = colors.white, bold = true })
hl(0, "MiniPickPromptPrefix", { fg = colors.blue, bg = colors.white })
hl(0, "MiniPickHeader", { fg = colors.orange, bold = true })
hl(0, "MiniPickMatchCurrent", { fg = colors.red, bg = colors.white })
hl(0, "MiniPickMatchMarked", { fg = colors.black, bg = colors.blue_gray })
hl(0, "MiniPickMatchRanges", { fg = colors.blue, bold = true })
hl(0, "MiniPickPreviewLine", { bg = colors.faint_gray })
hl(0, "MiniPickPreviewRegion", { bg = colors.blue_gray })
hl(0, "MiniPickIconDirectory", { fg = colors.blue })
hl(0, "MiniPickIconFile", { fg = colors.light_gray })

-- Inlay hints
hl(0, "LspInlayHint", { fg = colors.violet, bold = true })
