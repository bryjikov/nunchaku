
(* This file is free software, part of nunchaku. See file "license" for more details. *)

(** {1 Type Checking of a problem} *)

module TI = TermInner
module Stmt = Statement

let section = Utils.Section.(make ~parent:root "ty_check")

exception Error of string

let () = Printexc.register_printer
    (function
      | Error msg -> Some (Utils.err_sprintf "@[<2>broken invariant:@ %s@]" msg)
      | _ -> None)

let error_ msg = raise (Error msg)
let errorf_ msg = CCFormat.ksprintf ~f:error_ msg

module Make(T : TI.S) = struct
  module U = TI.Util(T)
  module P = TI.Print(T)

  type 'inv env = (T.t, T.t, 'inv) Env.t

  let empty_env () = Env.create ()

  let prop = U.ty_prop
  let prop1 = U.ty_arrow prop prop
  let prop2 = U.ty_arrow prop (U.ty_arrow prop prop)

  let find_ty_ ~env id =
    try Env.find_ty_exn ~env id
    with Not_found ->
      errorf_ "identifier %a not defined in scope" ID.print_full id

  let err_ty_mismatch t exp act =
    errorf_ "@[<2>type of `@[%a@]` should be `@[%a@]`,@ but is `@[%a@]`@]"
      P.print t P.print exp P.print act

  (* check that [ty = prop] *)
  let check_prop t ty =
    if not (U.ty_is_Prop ty)
    then err_ty_mismatch t prop ty

  (* check that [ty_a = ty_b] *)
  let check_same_ a b ty_a ty_b =
    if not (U.equal ty_a ty_b)
    then errorf_
        "@[<2>expected `@[%a@]` : `@[%a@]@ and@ \
        `@[%a@]` : `@[%a@]` to have the same type@]"
        P.print a P.print ty_a P.print b P.print ty_b;
    ()

  module VarSet = U.VarSet

  (* check invariants recursively, return type of term *)
  let rec check ~env bound t =
    match T.repr t with
    | TI.Const id -> find_ty_ ~env id
    | TI.Builtin b ->
        begin match b with
          | `Imply -> prop2
          | `Or
          | `And -> assert false (* should be handled below *)
          | `Not -> prop1
          | `True
          | `False -> prop
          | `Ite (a,b,c) ->
              let tya = check ~env bound a in
              let tyb = check ~env bound b in
              let tyc = check ~env bound c in
              check_prop a tya;
              check_same_ b c tyb tyc;
              tyb
          | `Equiv (a,b) ->
              let tya = check ~env bound a in
              let tyb = check ~env bound b in
              check_prop a tya;
              check_prop b tyb;
              prop
          | `Eq (a,b) ->
              let tya = check ~env bound a in
              let tyb = check ~env bound b in
              check_same_ a b tya tyb;
              prop
          | `DataTest id ->
              (* id: a->b->tau, where tau inductive; is-id: tau->prop *)
              let ty = find_ty_ ~env id in
              U.ty_arrow (U.ty_returns ty) prop
          | `DataSelect (id,n) ->
              (* id: a_1->a_2->tau, where tau inductive; select-id-i: tau->a_i*)
              let ty = find_ty_ ~env id in
              begin match U.get_ty_arg ty n with
              | Some ty_arg ->
                  U.ty_arrow (U.ty_returns ty) ty_arg
              | _ ->
                  error_ "cannot infer type, wrong argument to DataSelect"
              end
          | `Undefined (_,t) -> check ~env bound t
          | `Guard (t, g) ->
              List.iter (check_is_prop ~env bound) g.TI.Builtin.asserting;
              List.iter (check_is_prop ~env bound) g.TI.Builtin.assuming;
              check ~env bound t
        end
    | TI.Var v ->
        if not (VarSet.mem v bound)
        then errorf_ "variable %a not bound in scope" Var.print_full v;
        Var.ty v
    | TI.App (f,l) ->
        begin match T.repr f with
          | TI.Builtin (`And | `Or) ->
              List.iter (check_is_prop ~env bound) l;
              prop
          | _ ->
              U.ty_apply (check ~env bound f)
                ~terms:l ~tys:(List.map (check ~env bound) l)
        end
    | TI.Bind (b,v,body) ->
        begin match b with
        | `Forall
        | `Exists
        | `Mu ->
            let bound' = check_var ~env bound v in
            check ~env bound' body
        | `Fun ->
            let bound' = check_var ~env bound v in
            let ty_body = check ~env bound' body in
            if U.ty_returns_Type (Var.ty v)
            then U.ty_forall v ty_body
            else U.ty_arrow (Var.ty v) ty_body
        | `TyForall ->
            (* type of [pi a:type. body] is [type],
               and [body : type] is mandatory *)
            check_ty_forall_var ~env bound t v;
            check_is_ty ~env (VarSet.add v bound) body
        end
    | TI.Let (v,t',u) ->
        let ty_t' = check ~env bound t' in
        let bound' = check_var ~env bound v in
        check_same_ (U.var v) t' (Var.ty v) ty_t';
        check ~env bound' u
    | TI.Match (_,m) ->
        (* TODO: check that each constructor is present, and only once *)
        let id, (vars, rhs) = ID.Map.choose m in
        let bound' = List.fold_left (check_var ~env) bound vars in
        (* reference type *)
        let ty = check ~env bound' rhs in
        (* check other branches *)
        ID.Map.iter
          (fun id' (vars, rhs') ->
             if not (ID.equal id id')
             then (
               let bound' = List.fold_left (check_var ~env) bound vars in
               let ty' = check ~env bound' rhs' in
               check_same_ rhs rhs' ty ty'
             ))
          m;
        ty
    | TI.TyMeta _ -> assert false
    | TI.TyBuiltin b ->
        begin match b with
        | `Kind -> failwith "Term_ho.ty: kind has no type"
        | `Type -> U.ty_kind
        | `Prop -> U.ty_type
        end
    | TI.TyArrow (a,b) ->
        (* TODO: if a=type, then b=type is mandatory *)
        ignore (check_is_ty_or_Type ~env bound a);
        let ty_b = check_is_ty_or_Type ~env bound b in
        ty_b

  and check_is_prop ~env bound t =
    let ty = check ~env bound t in
    check_prop t ty;
    ()

  and check_var ~env bound v =
    let _ = check ~env bound (Var.ty v) in
    VarSet.add v bound

  (* check that [v] is a proper type var *)
  and check_ty_forall_var ~env bound t v =
    let tyv = check ~env bound (Var.ty v) in
    if not (U.ty_is_Type (Var.ty v)) && not (U.ty_is_Type tyv)
    then
      errorf_
        "@[<2>type of `@[%a@]` in `@[%a@]`@ should be a type or `type`,@ but is `@[%a@]`@]"
        Var.print_full v P.print t P.print tyv;
    ()

  and check_is_ty ~env bound t =
    let ty = check ~env bound t in
    if not (U.ty_is_Type ty) then err_ty_mismatch t U.ty_type ty;
    U.ty_type

  and check_is_ty_or_Type ~env bound t =
    let ty = check ~env bound t in
    if not (U.ty_returns_Type t) && not (U.ty_returns_Type ty)
      then err_ty_mismatch t U.ty_type ty;
    ty

  let check_eqns (type a) ~env ~bound id (eqn:(_,_,a) Stmt.equations) =
    match eqn with
      | Stmt.Eqn_single (vars, rhs) ->
          (* check that [freevars rhs ⊆ vars] *)
          let free_rhs = U.free_vars ~bound rhs in
          let diff = VarSet.diff free_rhs (VarSet.of_list vars) in
          if not (VarSet.is_empty diff)
          then (
            let module PStmt = Statement.Print(P)(P) in
            errorf_ "in equation `@[%a@]`,@ variables @[%a@]@ occur in RHS-term but are not bound"
              (PStmt.print_eqns id) eqn (VarSet.print Var.print_full) diff
          );
          let bound' = List.fold_left (check_var ~env) bound vars in
          check_is_prop ~env bound'
             (U.eq
                (U.app (U.const id) (List.map U.var vars))
                rhs)
      | Stmt.Eqn_nested l ->
          List.iter
            (fun (vars, args, rhs, side) ->
              let bound' = List.fold_left (check_var ~env) bound vars in
              check_is_prop ~env bound'
                (U.eq
                   (U.app (U.const id) args)
                   rhs);
              List.iter (check_is_prop ~env bound') side)
            l
      | Stmt.Eqn_app (_, vars, lhs, rhs) ->
          let bound' = List.fold_left (check_var ~env) bound vars in
          check_is_prop ~env bound' (U.eq lhs rhs)

  let check_statement env st =
    Utils.debugf ~section 2 "@[<2>type check@ `@[%a@]`@]"
      (fun k-> let module PStmt = Statement.Print(P)(P) in k PStmt.print st);
    let check_top env bound () t = ignore (check ~env bound t) in
    (* update env *)
    let env = Env.add_statement ~env st in
    (* check types *)
    begin match Stmt.view st with
      | Stmt.Axiom (Stmt.Axiom_rec defs) ->
          (* special checks *)
          List.iter
            (fun def ->
               let tyvars = def.Stmt.rec_vars in
               let bound = List.fold_left (check_var ~env) VarSet.empty tyvars
               in
               let {Stmt.defined_head=id; _} = def.Stmt.rec_defined in
               check_eqns ~env ~bound id def.Stmt.rec_eqns)
            defs
      | _ ->
        Stmt.fold_bind VarSet.empty () st
          ~bind:(check_var ~env)
          ~term:(check_top env) ~ty:(check_top env);
    end;
    env

  let check_problem ?(env=empty_env ()) pb =
    let _ = CCVector.fold check_statement env (Problem.statements pb) in
    ()
end
