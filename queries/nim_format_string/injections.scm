; copy of nvim-treesitter's query, but an empty {} (a zero-width MISSING
; nim_expression) is not injected: its zero-width nim tree breaks
; ultimate-autopair's <BS> inside fmt"" and &""
((matching_curlies
  (nim_expression
    !escaped_curly) @injection.content)
  (#lua-match? @injection.content "%S")
  (#set! injection.language "nim"))
