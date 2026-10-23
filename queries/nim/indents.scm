; Layout blocks
((if
  alternative: (elif_branch)* @indent.branch
  alternative: (else_branch)? @indent.branch) @indent.begin
  (#set! indent.immediate 1))

((when
  alternative: (elif_branch)* @indent.branch
  alternative: (else_branch)? @indent.branch) @indent.begin
  (#set! indent.immediate 1))

(case
  (of_branch) @indent.begin
  (#set! indent.immediate 1))

(case
  (elif_branch) @indent.begin
  (#set! indent.immediate 1))

(case
  (else_branch) @indent.begin
  (#set! indent.immediate 1))

(try
  (except_branch)? @indent.branch
  (finally_branch)? @indent.branch
  (#set! indent.immediate 1)) @indent.begin

(variant_declaration
  (of_branch) @indent.begin
  (#set! indent.immediate 1))

(variant_declaration
  (else_branch) @indent.begin
  (#set! indent.immediate 1))

((conditional_declaration
  alternative: (elif_branch)* @indent.branch
  alternative: (else_branch)? @indent.branch) @indent.begin
  (#set! indent.immediate 1))

; A bare section keyword opens an indented declaration section. Inline
; declarations are complete statements and do not indent the following line.
((const_section "const" @indent.begin)
  (#set! indent.immediate 1))
((let_section "let" @indent.begin)
  (#set! indent.immediate 1))
((var_section "var" @indent.begin)
  (#set! indent.immediate 1))
((type_section "type" @indent.begin)
  (#set! indent.immediate 1))
((using_section "using" @indent.begin)
  (#set! indent.immediate 1))

(([
  (const_section)
  (let_section)
  (var_section)
  (type_section)
  (using_section)
] @indent.begin)
  (#lua-match? @indent.begin "\n"))

([
  (object_declaration)
  (tuple_type)
  (enum_declaration)
  (for)
  (while)
  (block)
  (static_statement)
  (defer)
  (do_block)
  (call
    (argument_list
      (statement_list)))
] @indent.begin
  (#set! indent.immediate 1))

((proc_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))
((func_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))
((method_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))
((iterator_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))
((converter_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))
((template_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))
((macro_declaration "=" @indent.begin body: (statement_list) @indent.begin)
  (#set! indent.immediate 1))

(proc_expression "=" @indent.begin body: (statement_list) @indent.begin)
(func_expression "=" @indent.begin body: (statement_list) @indent.begin)
(iterator_expression "=" @indent.begin body: (statement_list) @indent.begin)

[
  (break_statement)
  (continue_statement)
] @indent.dedent

; At the old indentation level, branch keywords parse as identifiers until
; indentation is corrected.
((identifier) @indent.branch
  (#any-of? @indent.branch "elif" "else" "of" "except" "finally"))

; During incomplete declarations these keywords are parsed as type nodes.
((var_type "var") @indent.begin
  (#set! indent.immediate 1))

((enum_type "enum") @indent.begin
  (#set! indent.immediate 1))

(array_construction "]" @indent.dedent @indent.branch) @indent.begin
(tuple_construction ")" @indent.dedent @indent.branch) @indent.begin
(curly_construction "}" @indent.dedent @indent.branch) @indent.begin

(tuple_type
  (field_declaration_list "]" @indent.dedent @indent.branch)) @indent.begin

(parenthesized ")" @indent.dedent @indent.branch) @indent.begin
(generic_parameter_list "]" @indent.dedent @indent.branch) @indent.begin
(parameter_declaration_list ")" @indent.dedent @indent.branch) @indent.begin
(bracket_expression "]" @indent.dedent @indent.branch) @indent.begin
(argument_list ")" @indent.dedent @indent.branch) @indent.begin
(tuple_deconstruct_declaration ")" @indent.dedent @indent.branch) @indent.begin
(pragma_list ["}" ".}"] @indent.dedent @indent.branch) @indent.begin

[
  (ERROR "(")
  (ERROR "[")
  (ERROR "{")
  (ERROR "{.")
] @indent.begin

; A leading dot initially parses as an error at the old indentation. Reindent
; that line, after which it becomes part of the preceding dot expression. Keep
; this after the generic ERROR captures so its metadata wins.
((ERROR ".") @indent.begin
  (#set! indent.immediate 1)
  (#set! indent.start_at_same_line 1))

[
  (interpreted_string_literal)
  (long_string_literal)
  (raw_string_literal)
  (generalized_string)
] @indent.auto
