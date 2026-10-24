; Elvish blocks are all bracketed. The closing "}" of an if/try body belongs to
; the if/elif/try/catch node, so only the outer node opens a level; elif, else,
; catch and finally lines start with "}" and branch back.
[
  (lambda)
  (if)
  (for)
  (while)
  (try)
  (list)
  (map)
  (braced_list)
  (output_capture)
  (exception_capture)
  (indices)
] @indent.begin

[
  "}"
  "]"
  ")"
] @indent.branch @indent.end

; An unclosed bracket while typing parses as an error node.
[
  (ERROR "{")
  (ERROR "[")
  (ERROR "(")
] @indent.begin

[
  (comment)
  (string)
] @indent.auto
