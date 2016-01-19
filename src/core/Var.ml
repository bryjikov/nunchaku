
(* This file is free software, part of nunchaku. See file "license" for more details. *)

module ID = ID

type id = ID.t

type +'ty t = {
  id: id;
  ty: 'ty;
}

let equal v1 v2 = ID.equal v1.id v2.id
let compare v1 v2 = ID.compare v1.id v2.id

let make ~ty ~name =
  let id = ID.make name in
  { ty; id }

let fresh_copy v =
  { v with id=ID.fresh_copy v.id }

let fresh_copies l = List.map fresh_copy l

let of_id ~ty id = {id;ty}

let ty t = t.ty
let id t = t.id
let name t = ID.name t.id

let fresh_update_ty v ~f =
  let ty = f v.ty in
  make ~ty ~name:(ID.name v.id)

let update_ty v ~f =
  let ty = f v.ty in
  { id=v.id; ty }

let print oc v = ID.print oc v.id
let to_string v = ID.to_string v.id
let print_full oc v = ID.print_full oc v.id

(** {2 Substitutions} *)

module Subst = struct
  type 'ty var = 'ty t

  module M = ID.Map

  type ('ty,'a) t = ('ty var * 'a) M.t

  let empty = M.empty
  let is_empty = M.is_empty
  let singleton v x = M.singleton v.id (v,x)
  let size = M.cardinal

  let add ~subst v x = M.add v.id (v,x) subst

  let rec add_list ~subst v t = match v, t with
    | [], [] -> subst
    | [], _
    | _, [] -> invalid_arg "Subst.add_list"
    | v :: v', t :: t' -> add_list ~subst:(add ~subst v t) v' t'

  let remove ~subst v = M.remove v.id subst

  let mem ~subst v = M.mem v.id subst

  let find_exn ~subst v = snd (M.find v.id subst)

  let find ~subst v = try Some (find_exn ~subst v) with Not_found -> None

  let rec deref_rec ~subst v = match find ~subst v with
    | None -> v
    | Some v' -> deref_rec ~subst v'

  let to_list s = M.fold (fun _ (v,x) acc -> (v,x)::acc) s []

  let print pt out s =
    let pp_pair out (v,t) =
      Format.fprintf out "@[<2>%a →@ @[%a@]@]" print_full v pt t in
    Format.fprintf out "{@[<hv>%a@]}"
      (CCFormat.seq ~start:"" ~stop:"" ~sep:", " pp_pair)
      (M.to_seq s |> Sequence.map snd)
end

module Set(Ty : sig type t end) = CCSet.Make(struct
  type 'a _t = 'a t
  type t = Ty.t _t
  let compare = compare
end)
