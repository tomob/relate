module Abi = Relate_abi.Bindings
module Views = Relate_abi_types.Views

let kind_null = 0
let kind_bool = 1
let kind_int = 2
let kind_float = 3
let kind_string = 4
let kind_node = 5
let kind_relationship = 6
let kind_path = 7
let kind_list = 8
let kind_map = 9
let kind_point = 10
let kind_date = 11
let kind_time = 12
let kind_local_time = 13
let kind_datetime = 14
let kind_local_datetime = 15
let kind_duration = 16
let kind_vector = 17

[@@@warning "-30"]

type node = {
  element_id : string;
  id : int64;
  labels : string list;
  properties : (string * value) list;
}

and relationship = {
  element_id : string;
  start_element_id : string;
  end_element_id : string;
  id : int64;
  start_id : int64;
  end_id : int64;
  typ : string;
  properties : (string * value) list;
}

and point = {
  srid : int;
  dimension : int;
  x : float;
  y : float;
  z : float option;
}

and vector = {
  dtype : string;
  ints : int64 array option;
  floats : float array option;
}

and value =
  | Null
  | Bool of bool
  | Int of int64
  | Float of float
  | String of string
  | Node of node
  | Relationship of relationship
  | Path of value list
  | List of value list
  | Map of (string * value) list
  | Point of point
  | Date of { year : int; month : int; day : int }
  | Time of {
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
    }
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
  | Vector of vector

let describe = function
  | Null -> "null"
  | Bool _ -> "bool"
  | Int _ -> "int"
  | Float _ -> "float"
  | String _ -> "string"
  | Node _ -> "node"
  | Relationship _ -> "relationship"
  | Path _ -> "path"
  | List _ -> "list"
  | Map _ -> "map"
  | Point _ -> "point"
  | Date _ -> "date"
  | Time _ -> "time"
  | Local_time _ -> "local time"
  | Datetime _ -> "datetime"
  | Local_datetime _ -> "local datetime"
  | Duration _ -> "duration"
  | Vector _ -> "vector"

let refused what = raise (Error.Abi (Printf.sprintf "walker refused %s" what))

let read_i64 v call what =
  let slot = Ctypes.allocate Ctypes.int64_t 0L in
  if call v slot <> 0 then refused what;
  Ctypes.(!@) slot

let read_bool v call what =
  let slot = Ctypes.allocate Views.uint8 0 in
  if call v slot <> 0 then refused what;
  Ctypes.(!@) slot <> 0

let read_clock v =
  let hour = Int64.to_int (read_i64 v Abi.relate_value_hour "hour") in
  let minute = Int64.to_int (read_i64 v Abi.relate_value_minute "minute") in
  let second = Int64.to_int (read_i64 v Abi.relate_value_second "second") in
  let nanosecond = Int64.to_int (read_i64 v Abi.relate_value_nanosecond "nanosecond") in
  (hour, minute, second, nanosecond)

let read_date v =
  let year = Int64.to_int (read_i64 v Abi.relate_value_year "year") in
  let month = Int64.to_int (read_i64 v Abi.relate_value_month "month") in
  let day = Int64.to_int (read_i64 v Abi.relate_value_day "day") in
  (year, month, day)

let string_of v call =
  let len = Ctypes.allocate Views.size_t 0 in
  let p = call v len in
  if Ctypes.ptr_compare p Views.null_char = 0 then
    raise (Error.Abi "walker returned no string payload");
  Ctypes.string_from_ptr p ~length:(Ctypes.(!@) len)

let or_empty = function Some s -> s | None -> ""

let rec list_items v =
  let n = Int64.to_int (Abi.relate_value_list_len v) in
  if n < 0 then raise (Error.Abi "walker refused list length");
  let rec loop i acc =
    if i >= n then List.rev acc
    else
      match Abi.relate_value_list_get v (Int64.of_int i) with
      | None -> raise (Error.Abi (Printf.sprintf "list item %d has no handle" i))
      | Some child -> loop (i + 1) (of_handle child :: acc)
  in
  loop 0 []

and properties v =
  let n = Int64.to_int (Abi.relate_value_map_len v) in
  if n < 0 then raise (Error.Abi "walker refused map length");
  let rec loop i acc =
    if i >= n then List.rev acc
    else
      let key = string_of v (fun v len -> Abi.relate_value_map_key v (Int64.of_int i) len) in
      if String.contains key '\000' then
        raise
          (Error.Nul
             (Printf.sprintf "map key %s holds an interior NUL and cannot cross the C boundary"
                (Wire.quoted key)));
      (match Abi.relate_value_map_get v key with
      | None -> raise (Error.Abi (Printf.sprintf "walker lost map key %s" (Wire.quoted key)))
      | Some child -> loop (i + 1) ((key, of_handle child) :: acc))
  in
  loop 0 []

and node_labels v =
  List.map
    (function
      | String s -> s
      | other ->
        raise (Error.Abi (Printf.sprintf "node label is not a string: %s" (Wire.quoted (describe other)))))
    (list_items v)

and vector_of v =
  let dtype =
    match Abi.relate_value_vector_dtype v with
    | None -> raise (Error.Abi "walker returned no vector dtype")
    | Some d -> d
  in
  let dim = Int64.to_int (Abi.relate_value_vector_dim v) in
  if dim < 0 then raise (Error.Abi "walker refused vector dimension");
  match dtype with
  | "INTEGER8" | "INTEGER16" | "INTEGER32" | "INTEGER" ->
    let ints =
      Array.init dim (fun i ->
          let slot = Ctypes.allocate Ctypes.int64_t 0L in
          if Abi.relate_value_vector_int v (Int64.of_int i) slot <> 0 then
            refused "vector coordinate";
          Ctypes.(!@) slot)
    in
    { dtype; ints = Some ints; floats = None }
  | "FLOAT16" | "BFLOAT16" | "FLOAT32" | "FLOAT" ->
    let floats =
      Array.init dim (fun i ->
          let slot = Ctypes.allocate Ctypes.double 0.0 in
          if Abi.relate_value_vector_float v (Int64.of_int i) slot <> 0 then
            refused "vector coordinate";
          Ctypes.(!@) slot)
    in
    { dtype; ints = None; floats = Some floats }
  | other -> raise (Error.Abi (Printf.sprintf "unsupported vector dtype %s" (Wire.quoted other)))

and of_handle v =
  match Abi.relate_value_kind v with
  | k when k = kind_null -> Null
  | k when k = kind_bool -> Bool (read_bool v Abi.relate_value_bool "bool")
  | k when k = kind_int -> Int (read_i64 v Abi.relate_value_int "int")
  | k when k = kind_float ->
    let slot = Ctypes.allocate Ctypes.double 0.0 in
    if Abi.relate_value_float v slot <> 0 then refused "float";
    Float (Ctypes.(!@) slot)
  | k when k = kind_string -> String (string_of v Abi.relate_value_string)
  | k when k = kind_node ->
    let id = read_i64 v Abi.relate_value_id "id" in
    Node {
      element_id = or_empty (Abi.relate_value_element_id v);
      id;
      labels = node_labels v;
      properties = properties v;
    }
  | k when k = kind_relationship ->
    let id = read_i64 v Abi.relate_value_id "id" in
    let start_id = read_i64 v Abi.relate_value_start_id "start id" in
    let end_id = read_i64 v Abi.relate_value_end_id "end id" in
    Relationship {
      element_id = or_empty (Abi.relate_value_element_id v);
      start_element_id = or_empty (Abi.relate_value_start_element_id v);
      end_element_id = or_empty (Abi.relate_value_end_element_id v);
      id;
      start_id;
      end_id;
      typ = string_of v Abi.relate_value_string;
      properties = properties v;
    }
  | k when k = kind_path -> Path (list_items v)
  | k when k = kind_list -> List (list_items v)
  | k when k = kind_map -> Map (properties v)
  | k when k = kind_point ->
    let srid = Ctypes.allocate Ctypes.int32_t 0l in
    let dim = Ctypes.allocate Ctypes.int32_t 0l in
    let x = Ctypes.allocate Ctypes.double 0.0 in
    let y = Ctypes.allocate Ctypes.double 0.0 in
    let z = Ctypes.allocate Ctypes.double 0.0 in
    if Abi.relate_value_point v srid dim x y z <> 0 then refused "point";
    let dimension = Int32.to_int (Ctypes.(!@) dim) in
    Point {
      srid = Int32.to_int (Ctypes.(!@) srid);
      dimension;
      x = Ctypes.(!@) x;
      y = Ctypes.(!@) y;
      z = if dimension = 3 then Some (Ctypes.(!@) z) else None;
    }
  | k when k = kind_date ->
    let year, month, day = read_date v in
    Date { year; month; day }
  | k when k = kind_time ->
    let hour, minute, second, nanosecond = read_clock v in
    let offset_seconds =
      Int64.to_int (read_i64 v Abi.relate_value_offset_seconds "offset_seconds")
    in
    Time { hour; minute; second; nanosecond; offset_seconds }
  | k when k = kind_local_time ->
    let hour, minute, second, nanosecond = read_clock v in
    Local_time { hour; minute; second; nanosecond }
  | k when k = kind_datetime ->
    let year, month, day = read_date v in
    let hour, minute, second, nanosecond = read_clock v in
    let offset_seconds =
      Int64.to_int (read_i64 v Abi.relate_value_offset_seconds "offset_seconds")
    in
    Datetime {
      year; month; day; hour; minute; second; nanosecond; offset_seconds;
      zone = or_empty (Abi.relate_value_zone v);
    }
  | k when k = kind_local_datetime ->
    let year, month, day = read_date v in
    let hour, minute, second, nanosecond = read_clock v in
    Local_datetime { year; month; day; hour; minute; second; nanosecond }
  | k when k = kind_duration ->
    let months = Ctypes.allocate Ctypes.int64_t 0L in
    let days = Ctypes.allocate Ctypes.int64_t 0L in
    let seconds = Ctypes.allocate Ctypes.int64_t 0L in
    let nanos = Ctypes.allocate Ctypes.int64_t 0L in
    if Abi.relate_value_duration v months days seconds nanos <> 0 then refused "duration";
    Duration {
      months = Ctypes.(!@) months;
      days = Ctypes.(!@) days;
      seconds = Ctypes.(!@) seconds;
      nanos = Ctypes.(!@) nanos;
    }
  | k when k = kind_vector -> Vector (vector_of v)
  | k -> raise (Error.Abi (Printf.sprintf "unsupported value kind %d" k))
