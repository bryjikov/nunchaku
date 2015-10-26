
(* This file is free software, part of nunchaku. See file "license" for more details. *)

(** {1 Statements with Locations} *)

module Loc = NunLocation
module ID = NunID
module Var = NunVar
module Statement = NunStatement
module Model = NunModel
module Signature = NunSignature
module Env = NunEnv

type loc = Loc.t
type id = ID.t
type 'a printer = Format.formatter -> 'a -> unit
type 'a or_error = [`Ok of 'a | `Error of string]

let fpf = Format.fprintf

type 'a vec_ro = ('a, CCVector.ro) CCVector.t

type ('t, 'ty) t = {
  statements : ('t, 'ty) Statement.t vec_ro;
}

let statements t = t.statements

let make statements = { statements; }

let of_list l = make (CCVector.of_list l)

let map_statements ~f st = {
  statements=CCVector.map f st.statements;
}

let map_with ?(before=fun _ -> []) ?(after=fun _ -> []) ~term ~ty p = {
  statements=(
    let res = CCVector.create () in
    CCVector.iter
      (fun st ->
        let st' = Statement.map ~term ~ty st in
        CCVector.append_seq res (Sequence.of_list (before ()));
        CCVector.push res st';
        CCVector.append_seq res (Sequence.of_list (after ()));
      ) p.statements;
    CCVector.freeze res
  );
}

let map ~term ~ty pb = map_with ~term ~ty pb

let print pt pty out problem =
  fpf out "{@,%a@,}"
    (CCVector.print ~start:"" ~stop:"" ~sep:"" (Statement.print pt pty))
    problem.statements

exception IllFormed of string
(** Ill-formed problem *)

let () = Printexc.register_printer
  (function
    | IllFormed msg -> Some (Printf.sprintf "problem is ill-formed: %s" msg)
    | _ -> None
  )

let ill_formed_ msg = raise (IllFormed msg)
let ill_formedf_ msg = NunUtils.exn_ksprintf msg ~f:ill_formed_

let goal pb =
  let n = CCVector.length pb.statements in
  let rec aux acc i =
    if i=n
    then match acc with
      | Some g -> g
      | None -> ill_formed_ "no goal"
    else
      match CCVector.get pb.statements i with
      | {Statement.view=Statement.Goal g;_} -> aux (Some g) (i+1)
      | _ -> aux acc (i+1)
  in
  aux None 0

let signature ?(init=Signature.empty) pb =
  let module St = Statement in
  let declare_ ~sigma id ty =
    if Signature.mem ~sigma id
      then ill_formedf_ "symbol %a declared twice" ID.print id;
    Signature.declare ~sigma id ty
  in
  CCVector.fold
    (fun sigma st -> match St.view st with
      | St.Decl (id,_,ty) -> declare_ ~sigma id ty
      | St.TyDef (_,l) ->
          List.fold_left
            (fun sigma tydef ->
              let sigma = declare_ ~sigma tydef.St.ty_id tydef.St.ty_type in
              List.fold_left
                (fun sigma c -> declare_ ~sigma c.St.cstor_name c.St.cstor_type)
                sigma tydef.St.ty_cstors
            ) sigma l
      | St.Goal _
      | St.Axiom _ -> sigma
    ) init pb.statements

let env ?init:(env=Env.create()) pb =
  let module St = Statement in
  try
    CCVector.iter
      (fun st -> match St.view st with
        | St.Decl (id,_,ty) ->
            Env.declare ~env ~id ~ty
        | St.TyDef (kind,l) ->
            Env.def_data ~env ~kind l
        | St.Goal _ -> ()
        | St.Axiom (St.Axiom_std _) -> ()
        | St.Axiom (St.Axiom_spec l)
        | St.Axiom (St.Axiom_rec l) ->
            Env.def_funs ~env l
      ) pb.statements;
    env
  with Env.InvalidDef _ as e ->
    ill_formedf_ "invalid env: %a" Env.pp_invalid_def_ e

module Res = struct
  type 't model = 't Model.t

  type 't t =
    | Unsat
    | Sat of 't model  (** model maps terms to values *)
    | Timeout

  let map ~f t = match t with
    | Unsat -> Unsat
    | Timeout -> Timeout
    | Sat model -> Sat (Model.map ~f model)

  let fpf = Format.fprintf

  let print pt out = function
    | Unsat -> fpf out "unsat"
    | Timeout -> fpf out "timeout"
    | Sat m ->
        fpf out "@[<2>sat {@,%a}@]" (Model.print pt) m
end
