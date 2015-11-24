(* This file is free software, part of nunchaku. See file "license" for more details. *)

(** {1 Top-level statement} *)

type id = NunID.t
type loc = NunLocation.t
type 'a var = 'a NunVar.t
type 'a printer = Format.formatter -> 'a -> unit

type decl =
  | Decl_type
  | Decl_fun
  | Decl_prop

type 'ty defined = {
  defined_head: id; (* symbol being defined *)
  defined_ty: 'ty; (* type of the head symbol *)
}

type ('t, 'ty, 'kind) equations =
  | Eqn_linear :
      ('ty var list (* universally quantified vars, also arguments to [f] *)
      * 't (* right-hand side of equation *)
      * 't list (* side conditions *)
      ) list
      -> ('t, 'ty, <eqn:[`Linear];..>) equations
  | Eqn_nested :
      ('ty var list (* universally quantified vars *)
      * 't list (* arguments (patterns) to the defined term *)
      * 't  (* right-hand side of equation *)
      * 't list (* additional conditions *)
      ) list
      -> ('t, 'ty, <eqn:[`Nested];..>) equations
  | Eqn_single :
      'ty var list (* function arguments *)
      *  't (* RHS *)
      -> ('t, 'ty, <eqn:[`Single];..>) equations

type ('t,'ty,'kind) rec_def = {
  rec_defined: 'ty defined;
  rec_kind: decl;
  rec_vars: 'ty var list; (* type variables in definitions *)
  rec_eqns: ('t, 'ty,'kind) equations; (* list of equations defining the term *)
}

type ('t, 'ty,'kind) rec_defs = ('t, 'ty,'kind) rec_def list

type ('t, 'ty) spec_defs = {
  spec_vars: 'ty var list; (* type variables used by defined terms *)
  spec_defined: 'ty defined list;  (* terms being specified together *)
  spec_axioms: 't list;  (* free-form axioms *)
}

(** A type constructor: name + type of arguments *)
type 'ty ty_constructor = {
  cstor_name: id; (** Name *)
  cstor_args: 'ty list; (** type arguments *)
  cstor_type: 'ty; (** type of the constructor (shortcut) *)
}

(** A (co)inductive type. The type variables [ty_vars] occur freely in
    the constructors' types. *)
type 'ty tydef = {
  ty_id : id;
  ty_vars : 'ty NunVar.t list;
  ty_type : 'ty; (** shortcut for [type -> type -> ... -> type] *)
  ty_cstors : 'ty ty_constructor NunID.Map.t;
}

(** Mutual definitions of several types *)
type 'ty mutual_types = 'ty tydef list

(** Flavour of axiom *)
type ('t,'ty,'kind) axiom =
  | Axiom_std of 't list
    (** Axiom list that can influence consistency (no assumptions) *)
  | Axiom_spec of ('t,'ty) spec_defs
    (** Axioms can be safely ignored, they are consistent *)
  | Axiom_rec of ('t,'ty,'kind) rec_defs
    (** Axioms are part of an admissible (partial) definition *)

type ('term, 'ty, 'inv) view =
  | Decl of id * decl * 'ty
  | Axiom of ('term, 'ty, 'inv) axiom
  | TyDef of [`Data | `Codata] * 'ty mutual_types
  | Goal of 'term

(** Additional informations on the statement *)
type info = {
  loc: loc option;
  name: string option;
}

type ('term, 'ty, 'inv) t = private {
  view: ('term, 'ty, 'inv) view;
  info: info;
}

val tydef_vars : 'ty tydef -> 'ty NunVar.t list
val tydef_id : _ tydef -> id
val tydef_type : 'ty tydef -> 'ty
val tydef_cstors : 'ty tydef -> 'ty ty_constructor NunID.Map.t

val info_default : info

val view : ('term,'ty,'inv) t -> ('term, 'ty,'inv) view
val loc : _ t -> loc option
val name : _ t -> string option
val info : _ t -> info

val mk_decl : info:info  -> id -> decl -> 'ty -> ('t,'ty,'inv) t
val mk_axiom : info:info -> ('a,'ty,'inv) axiom -> ('a, 'ty,'inv) t
val mk_ty_def : info:info -> [`Data | `Codata] -> 'ty mutual_types -> (_, 'ty,_) t

val ty_decl : info:info -> id -> 'a -> (_, 'a, _) t
(** declare a type constructor *)

val decl : info:info -> id -> 'a -> (_, 'a, _) t
(** declare a function symbol *)

val prop_decl : info:info -> id -> 'a -> (_, 'a, _) t
(** Declare a proposition ([prop] must be provided) *)

val axiom : info:info -> 'a list -> ('a,_,_) t
(** Axioms without additional assumptions *)

val axiom1 : info:info -> 'a -> ('a,_,_) t

val axiom_spec : info:info -> ('a,'ty) spec_defs -> ('a,'ty,_) t
(** Axiom that can be ignored if not explicitely depended upon by the goal *)

val axiom_rec : info:info -> ('a,'ty,'inv) rec_defs -> ('a,'ty,'inv) t
(** Axiom that is part of an admissible (mutual, partial) definition. *)

val data : info:info -> 'ty mutual_types -> (_, 'ty, _) t

val codata : info:info -> 'ty mutual_types -> (_, 'ty, _) t

val goal : info:info -> 'a -> ('a,_,_) t
(** The goal of the problem *)

val map_defined:
  f:('ty -> 'ty2) ->
  'ty defined ->
  'ty2 defined

val map_eqns:
  term:('t -> 't2) ->
  ty:('ty -> 'ty2) ->
  ('t, 'ty, <eqn:'inv;..>) equations ->
  ('t2, 'ty2, <eqn:'inv;..>) equations

val map_rec_def :
  term:('t -> 't2) ->
  ty:('ty -> 'ty2) ->
  ('t, 'ty, <eqn:'inv;..>) rec_def ->
  ('t2, 'ty2, <eqn:'inv;..>) rec_def

val map_rec_defs :
  term:('t -> 't2) ->
  ty:('ty -> 'ty2) ->
  ('t, 'ty, <eqn:'inv;..>) rec_defs ->
  ('t2, 'ty2, <eqn:'inv;..>) rec_defs

val map_spec_defs :
  term:('t -> 't2) ->
  ty:('ty -> 'ty2) ->
  ('t, 'ty) spec_defs ->
  ('t2, 'ty2) spec_defs

val map :
  term:('t -> 't2) ->
  ty:('ty -> 'ty2) ->
  ('t, 'ty, <eqn:'inv;..>) t ->
  ('t2, 'ty2, <eqn:'inv;..>) t

val fold :
  term:('a -> 't -> 'a) ->
  ty:('a -> 'ty -> 'a) ->
  'a -> ('t, 'ty, 'inv) t -> 'a

(** {2 Print} *)

val print : 'a NunTermInner.print -> 'b NunTermInner.print ->
            ('a,'b,_) t printer
(** [print pt ptr] is a statement printer that relies upon [pt] to print
    terms/formulas and [pty] to print types.
*)

module Print(Pt : NunTermInner.PRINT)(Pty : NunTermInner.PRINT) : sig
  val print : (Pt.t, Pty.t, _) t printer
end

