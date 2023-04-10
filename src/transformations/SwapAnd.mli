(* This file is free software, part of nunchaku. See file "license" for more details. *)

(** Swap terms in an And statement
    
    Example:
    [a && b] becomes [b && a]
    [a && (b && c)] becomes [(c && b) && a]
*)

open Nunchaku_core

type term = Term.t
type problem = (term, term) Problem.t

val name : string (* The name of the transformation...will be "swap_and" *)

val swap_and_term : term -> term

val swap_and_problem : (term, term) Problem.t -> (term, term) Problem.t

(* Swapping the order in and statements doesn't really...change the logic we're in,
 * so I think a trivial decoder is acceptable here *)

(** Pipeline component *)
val pipe :
  print:bool ->
  check:bool ->
  ((term, term) Problem.t,
   (term, term) Problem.t,
   (term, term) Problem.Res.t,
   (term, term) Problem.Res.t) Transform.t
