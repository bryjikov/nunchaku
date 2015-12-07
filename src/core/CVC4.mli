
(* This file is free software, part of nunchaku. See file "license" for more details. *)

(** {1 Interface to CVC4} *)

module Make(F : FO.S) : sig
  include Solver_intf.S
  with module FO_T = F
  and module FOBack = FO.Default

  val print_problem : Format.formatter -> problem -> unit
end

type model_elt = FO.Default.term_or_form

(** list of different available options *)
val options_l : string list

(** Call CVC4 on a problem and obtain a result
  @param options: flags to pass the solver. If several strings are passed,
    they are tried one by one until the deadline is reached or the solver
    returns "SAT"
  @raise Invalid_argument if options=[]
*)
val call :
  (module FO.S with type formula = 'a and type T.t = 'b and type Ty.t = 'c) ->
  ?options:string list ->
  print:bool ->
  print_smt:bool ->
  deadline:float ->
  ('a, 'b, 'c) FO.Problem.t ->
  model_elt Problem.Res.t

(** Close a pipeline by calling CVC4
  @param print if true, print the input problem
  @param print_smt if true, print the SMT problem sent to the prover
  @param deadline absolute time at which the solver should stop (even without an answer)
  @param options list of options to try. IF several options are provided,
    the deadline will still be respected.
*)
val close_pipe :
  (module FO.S with type formula = 'a and type T.t = 'b and type Ty.t = 'c) ->
  ?options:string list ->
  pipe:('d, ('a, 'b, 'c) FO.Problem.t, 'e, 'f) Transform.Pipe.t ->
  print:bool ->
  print_smt:bool ->
  deadline:float ->
  ('d, 'e, 'f, model_elt Problem.Res.t) Transform.ClosedPipe.t
