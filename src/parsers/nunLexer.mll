
(* This file is free software, part of containers. See file "license" for more details. *)

(** {1 Lexer for Nunchaku} *)

{

  exception LexError of string

  open NunParser

}

let printable_char = [^ '\n']
let comment_line = '#' printable_char*

let numeric = ['0' - '9']
let lower_alpha = ['a' - 'z']
let upper_alpha = ['A' - 'Z']
let alpha_numeric = lower_alpha | upper_alpha | numeric | '_'

let upper_word = upper_alpha alpha_numeric*
let lower_word = lower_alpha alpha_numeric*

let zero_numeric = '0'
let non_zero_numeric = ['1' - '9']
let numeric = ['0' - '9']
let sign = ['+' '-']

let dot_decimal = '.' numeric +
let positive_decimal = non_zero_numeric numeric*
let decimal = zero_numeric | positive_decimal
let unsigned_integer = decimal
let signed_integer = sign unsigned_integer
let integer = signed_integer | unsigned_integer

rule token = parse
  | eof { EOI }
  | '\n' { Lexing.new_line lexbuf; token lexbuf }
  | [' ' '\t' '\r'] { token lexbuf }
  | comment_line { token lexbuf }
  | '(' { LEFT_PAREN }
  | ')' { RIGHT_PAREN }
  | '.' { DOT }
  | '_' { WILDCARD }
  | ':' { COLUMN }
  | ":=" { EQDEF }
  | "->" { ARROW }
  | "=>" { DOUBLEARROW }
  | "fun" { FUN }
  | "def" { DEF }
  | "val" { DECL }
  | "axiom" { AXIOM }
  | lower_word { LOWER_WORD(Lexing.lexeme lexbuf) }
  | upper_word { UPPER_WORD(Lexing.lexeme lexbuf) }
  | _ as c { raise (LexError (Printf.sprintf "lexer fails on char '%c'" c)) }

{
  module E = CCError
  module Loc = NunLocation

  type 'a or_error = [`Ok of 'a | `Error of string ]

  type statement = NunAST.statement
  type term = NunAST.term
  type ty = NunAST.ty

  let () = Printexc.register_printer
    (function
      | LexError msg -> Some ("lexing error: " ^ msg )
      | _ -> None
    )

  let parse_file file =
    try
      CCIO.with_in file
        (fun ic ->
          let lexbuf = Lexing.from_channel ic in
          Loc.set_file lexbuf file; (* for error reporting *)
          E.return (NunParser.parse_statement_list token lexbuf)
        )
    with e ->
      E.fail (Printexc.to_string e)

  let parse_str_ p s = p token (Lexing.from_string s)

  let try_parse_ p s =
    try E.return (parse_str_ p s)
    with e -> E.fail (Printexc.to_string e)

  let ty_of_string = try_parse_ NunParser.parse_ty
  let ty_of_string_exn = parse_str_ NunParser.parse_ty

  let term_of_string = try_parse_ NunParser.parse_term
  let term_of_string_exn = parse_str_ NunParser.parse_term

  let statement_of_string = try_parse_ NunParser.parse_statement
  let statement_of_string_exn = parse_str_ NunParser.parse_statement
}