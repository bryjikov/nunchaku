(* This file is free software, part of nunchaku. See file "license" for more details. *)

(** Swap terms in an And statement
    
    Example:
    [a && b] becomes [b && a]
    [a && (b && c)] becomes [(c && b) && a]
*)

open Nunchaku_core

module TI = TermInner
module T = Term
type term = T.t
type problem = (term, term) Problem.t

let name = "swap_and"

let rec swap_and_term (t : term) : term =
  match T.repr t with
    | TI.Builtin (`And l) -> T.build (TI.Builtin (`And (List.rev l)))
    | _ -> t

let swap_and_problem (prob : problem) : problem =
  Problem.map prob ~term:swap_and_term ~ty:(fun x -> x)

let pipe ~print ~check =
  let on_encoded =
    Utils.singleton_if print () ~f:(fun () ->
      let module PPb = Problem.P in
      Format.printf "@[<v2>@{<Yellow>after swapping clauses in `and` expressions@}: %a@]@." PPb.pp)
    @
      Utils.singleton_if check () ~f:(fun () ->
        let module C = TypeCheck.Make(T) in
        C.empty () |> C.check_problem)
  in
  Transform.make
    ~on_encoded
    ~name
    ~encode:(fun p ->
      swap_and_problem p, ())
    ~decode:(fun () x -> x)
    ()
