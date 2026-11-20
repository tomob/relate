module Abi = Relate_abi.Bindings
module Views = Relate_abi_types.Views

type t = { mutable ptr : unit Ctypes.ptr option; mutex : Mutex.t }

let free t =
  Mutex.lock t.mutex;
  let pending = t.ptr in
  t.ptr <- None;
  Mutex.unlock t.mutex;
  (match pending with Some p -> Abi.relate_params_free p | None -> ())

let create () =
  let t = { ptr = Some (Abi.relate_params_new ()); mutex = Mutex.create () } in
  Gc.finalise (fun t -> free t) t;
  t

let with_params f =
  let t = create () in
  match f t with
  | x -> free t; x
  | exception e -> free t; raise e

(* handle is the builder's root handle for relate_query_params; None on a
   freed builder. *)
let handle t = t.ptr

let guarded t call =
  Mutex.lock t.mutex;
  let outcome =
    match t.ptr with
    | None -> `Closed
    | Some p -> (try `Ok (call p) with e -> `Exn e)
  in
  Mutex.unlock t.mutex;
  match outcome with
  | `Ok x -> x
  | `Closed -> raise Error.Closed
  | `Exn e -> raise e

let name_of = function
  | None -> None
  | Some n ->
    if String.contains n '\000' then
      raise
        (Error.Nul
           (Printf.sprintf "parameter name %s holds an interior NUL and cannot cross the C boundary"
              (Wire.quoted n)));
    Some n

let err_slot () = Ctypes.allocate (Ctypes.ptr Ctypes.char) Views.null_char

let put_null ?name t =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check (Abi.relate_params_put_null p name err) err)

let put_bool ?name t v =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check (Abi.relate_params_put_bool p name (if v then 1 else 0) err) err)

let put_int ?name t v =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check (Abi.relate_params_put_int p name v err) err)

let put_float ?name t v =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check (Abi.relate_params_put_float p name v err) err)

(* put_string passes the bytes with their length, so an interior NUL crosses
   whole as data. *)
let put_string ?name t v =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check (Abi.relate_params_put_string p name v (String.length v) err) err)

let put_date ?name t ~year ~month ~day =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check
        (Abi.relate_params_put_date p name
           (Int64.of_int year) (Int64.of_int month) (Int64.of_int day) err)
        err)

let zone_of what = function
  | None -> None
  | Some z ->
    if String.contains z '\000' then
      raise
        (Error.Nul
           (Printf.sprintf "%s %s holds an interior NUL and cannot cross the C boundary" what
              (Wire.quoted z)));
    Some z

let put_time ?name t ~hour ~minute ~second ~nanosecond ~offset_seconds ~(zone : string option) =
  let name = name_of name in
  let zone = zone_of "time zone" zone in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check
        (Abi.relate_params_put_time p name
           (Int64.of_int hour) (Int64.of_int minute) (Int64.of_int second)
           (Int64.of_int nanosecond) (Int64.of_int offset_seconds) zone err)
        err)

let put_local_time ?name t ~hour ~minute ~second ~nanosecond =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check
        (Abi.relate_params_put_local_time p name
           (Int64.of_int hour) (Int64.of_int minute) (Int64.of_int second)
           (Int64.of_int nanosecond) err)
        err)

let put_datetime ?name t ~year ~month ~day ~hour ~minute ~second ~nanosecond
    ~offset_seconds ~(zone : string option) =
  let name = name_of name in
  let zone = zone_of "time zone" zone in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check
        (Abi.relate_params_put_datetime p name
           (Int64.of_int year) (Int64.of_int month) (Int64.of_int day)
           (Int64.of_int hour) (Int64.of_int minute) (Int64.of_int second)
           (Int64.of_int nanosecond) (Int64.of_int offset_seconds) zone err)
        err)

let put_local_datetime ?name t ~year ~month ~day ~hour ~minute ~second ~nanosecond =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check
        (Abi.relate_params_put_local_datetime p name
           (Int64.of_int year) (Int64.of_int month) (Int64.of_int day)
           (Int64.of_int hour) (Int64.of_int minute) (Int64.of_int second)
           (Int64.of_int nanosecond) err)
        err)

let put_duration ?name t ~months ~days ~seconds ~nanos =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      Call.check (Abi.relate_params_put_duration p name months days seconds nanos err) err)

let put_point ?name t ~srid ~x ~y z =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      let z_ptr =
        match z with
        | None -> None
        | Some zv -> Some (Ctypes.allocate Ctypes.double zv)
      in
      Call.check (Abi.relate_params_put_point p name (Int32.of_int srid) x y z_ptr err) err)

let put_vector_float ?name t ~dtype (values : float array) =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      let arr = Ctypes.CArray.make Ctypes.double (Array.length values) in
      Array.iteri (fun i x -> Ctypes.CArray.set arr i x) values;
      Call.check
        (Abi.relate_params_put_vector_float p name dtype
           (Ctypes.CArray.start arr) (Array.length values) err)
        err)

let put_vector_int ?name t ~dtype (values : int64 array) =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      let arr = Ctypes.CArray.make Ctypes.int64_t (Array.length values) in
      Array.iteri (fun i x -> Ctypes.CArray.set arr i x) values;
      Call.check
        (Abi.relate_params_put_vector_int p name dtype
           (Ctypes.CArray.start arr) (Array.length values) err)
        err)

let child_of p = { ptr = Some p; mutex = Mutex.create () }

let put_list ?name t =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      let child = Ctypes.allocate (Ctypes.ptr Ctypes.void) Ctypes.null in
      Call.check (Abi.relate_params_put_list p name child err) err;
      child_of (Ctypes.(!@) child))

let put_map ?name t =
  let name = name_of name in
  guarded t (fun p ->
      let err = err_slot () in
      let child = Ctypes.allocate (Ctypes.ptr Ctypes.void) Ctypes.null in
      Call.check (Abi.relate_params_put_map p name child err) err;
      child_of (Ctypes.(!@) child))

type value =
  | Null
  | Bool of bool
  | Int of int64
  | Float of float
  | String of string
  | List of value list
  | Map of (string * value) list
  | Date of { year : int; month : int; day : int }
  | Time of {
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
    }
  | Zoned_time of { hour : int; minute : int; second : int; nanosecond : int; zone : string }
  | Local_time of { hour : int; minute : int; second : int; nanosecond : int }
  | Datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
    }
  | Zoned_datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      zone : string;
    }
  | Local_datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
    }
  | Duration of { months : int64; days : int64; seconds : int64; nanos : int64 }
  | Point of { srid : int; x : float; y : float; z : float option }
  | Vector_float of { dtype : string; values : float array }
  | Vector_int of { dtype : string; values : int64 array }

let rec bind t name (v : value) =
  match v with
  | Null -> put_null ?name t
  | Bool b -> put_bool ?name t b
  | Int i -> put_int ?name t i
  | Float f -> put_float ?name t f
  | String s -> put_string ?name t s
  | List items ->
    let child = put_list ?name t in
    List.iter (fun item -> bind child None item) items
  | Map entries ->
    let child = put_map ?name t in
    List.iter (fun (k, v) -> bind child (Some k) v) entries
  | Date d -> put_date ?name t ~year:d.year ~month:d.month ~day:d.day
  | Time c ->
    put_time ?name t ~hour:c.hour ~minute:c.minute ~second:c.second
      ~nanosecond:c.nanosecond ~offset_seconds:c.offset_seconds ~zone:None
  | Zoned_time c ->
    put_time ?name t ~hour:c.hour ~minute:c.minute ~second:c.second
      ~nanosecond:c.nanosecond ~offset_seconds:0 ~zone:(Some c.zone)
  | Local_time c ->
    put_local_time ?name t ~hour:c.hour ~minute:c.minute ~second:c.second
      ~nanosecond:c.nanosecond
  | Datetime c ->
    put_datetime ?name t ~year:c.year ~month:c.month ~day:c.day ~hour:c.hour
      ~minute:c.minute ~second:c.second ~nanosecond:c.nanosecond
      ~offset_seconds:c.offset_seconds ~zone:None
  | Zoned_datetime c ->
    put_datetime ?name t ~year:c.year ~month:c.month ~day:c.day ~hour:c.hour
      ~minute:c.minute ~second:c.second ~nanosecond:c.nanosecond
      ~offset_seconds:0 ~zone:(Some c.zone)
  | Local_datetime c ->
    put_local_datetime ?name t ~year:c.year ~month:c.month ~day:c.day
      ~hour:c.hour ~minute:c.minute ~second:c.second ~nanosecond:c.nanosecond
  | Duration d ->
    put_duration ?name t ~months:d.months ~days:d.days ~seconds:d.seconds ~nanos:d.nanos
  | Point pt -> put_point ?name t ~srid:pt.srid ~x:pt.x ~y:pt.y pt.z
  | Vector_float v -> put_vector_float ?name t ~dtype:v.dtype v.values
  | Vector_int v -> put_vector_int ?name t ~dtype:v.dtype v.values

let bind_map t (entries : (string * value) list) =
  List.iter (fun (k, v) -> bind t (Some k) v) entries

let bind_list t (items : value list) = List.iter (fun item -> bind t None item) items
