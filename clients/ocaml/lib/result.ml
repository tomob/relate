module Abi = Relate_abi.Bindings

type query_type =
  | Read
  | Write
  | Read_write
  | Schema

type namespace = Neo4j | System | System_ontologies

type stats = {
  nodes_created : int64;
  nodes_deleted : int64;
  relationships_created : int64;
  relationships_deleted : int64;
  properties_set : int64;
  labels_added : int64;
  labels_removed : int64;
  indexes_added : int64;
  indexes_removed : int64;
  constraints_added : int64;
  constraints_removed : int64;
}

type notification = Notification.t

type plan_actual = {
  rows : int64;
  time_ms : float;
  db_hits : int64;
  memory_bytes : int64;
  hops : int64;
  neighbor_walks : int64;
  node_reads : int64;
  start : (int64 * bool * string) option;
}
type plan_node = {
  operator : string;
  details : string;
  identifiers : string list;
  estimated_rows : int64 option;
  actual : plan_actual option;
  children : plan_node list;
  warnings : notification list;
}

type plan_document = {
  schema : string;
  profiled : bool;
  statement : string option;
  root : plan_node;
}

type t = {
  handle : unit Ctypes.ptr;
  columns : string array;
  row_count : int;
  query_type : query_type;
  namespace : namespace;
  bookmark : string;
  stats : stats;
  notifications : notification list;
  plan : plan_document option;
  mutable destroyed : bool;
  mutex : Mutex.t;
}

let query_type_vocabulary =
  [ (Read, "r"); (Write, "w"); (Read_write, "rw"); (Schema, "s") ]

let namespace_vocabulary =
  [ (Neo4j, "neo4j"); (System, "system"); (System_ontologies, "system_ontologies") ]

let decode_closed what vocabulary raw =
  match List.assoc_opt raw (List.map (fun (v, s) -> (s, v)) vocabulary) with
  | Some v -> v
  | None -> raise (Error.Abi (Printf.sprintf "%s %s" what (Wire.quoted raw)))

let decode_query_type raw = decode_closed "query type" query_type_vocabulary raw

let decode_namespace raw = decode_closed "namespace" namespace_vocabulary raw

let required_int key kvs =
  match List.assoc_opt key kvs with
  | Some (`Int n) -> Int64.of_int n
  | None | Some `Null ->
    raise (Error.Abi (Printf.sprintf "stats payload is missing %S" key))
  | Some other ->
    raise
      (Error.Abi
         (Printf.sprintf "stats payload: %s is not an integer: %s" key
            (Wire.quoted (Yojson.Safe.to_string other))))

(* decode_stats reads the canonical eleven counters, zeros included: a
   missing or null key is an ABI contract violation naming it, never a zero
   value in its place; keys outside the canonical set are ignored. *)
let decode_stats (raw : string) : stats =
  let json = try Yojson.Safe.from_string raw with _ -> raise (Error.Abi (Printf.sprintf "decoding stats counters: %s" (Wire.safe raw))) in
  match json with
  | `Assoc kvs ->
    {
      nodes_created = required_int "nodes_created" kvs;
      nodes_deleted = required_int "nodes_deleted" kvs;
      relationships_created = required_int "relationships_created" kvs;
      relationships_deleted = required_int "relationships_deleted" kvs;
      properties_set = required_int "properties_set" kvs;
      labels_added = required_int "labels_added" kvs;
      labels_removed = required_int "labels_removed" kvs;
      indexes_added = required_int "indexes_added" kvs;
      indexes_removed = required_int "indexes_removed" kvs;
      constraints_added = required_int "constraints_added" kvs;
      constraints_removed = required_int "constraints_removed" kvs;
    }
  | other ->
    raise
      (Error.Abi
         (Printf.sprintf "stats payload is not a JSON object: %s"
            (Wire.safe (Yojson.Safe.to_string other))))

let optional_string kvs key = match List.assoc_opt key kvs with Some (`String s) -> s | _ -> ""

let optional_bool kvs key = match List.assoc_opt key kvs with Some (`Bool b) -> b | _ -> false

let rec string_list what key kvs =
  match List.assoc_opt key kvs with
  | Some (`List items) ->
    List.map
      (function
        | `String s -> s
        | other ->
          raise
            (Error.Abi
               (Printf.sprintf "%s: %s carries a non-string entry: %s" what key
                  (Wire.quoted (Yojson.Safe.to_string other)))))
      items
  | _ -> []

and decode_plan_actual kvs =
  let int_field key = match List.assoc_opt key kvs with Some (`Int n) -> Int64.of_int n | _ -> 0L in
  let float_field key = match List.assoc_opt key kvs with Some (`Float f) -> f | Some (`Int n) -> float_of_int n | _ -> 0.0 in
  let start =
    match List.assoc_opt "start" kvs with
    | Some (`Assoc skvs) ->
      let element = int_field_of skvs "element" in
      let backward = optional_bool skvs "backward" in
      let reason = optional_string skvs "reason" in
      Some (element, backward, reason)
    | _ -> None
  in
  {
    rows = int_field "rows";
    time_ms = float_field "time_ms";
    db_hits = int_field "db_hits";
    memory_bytes = int_field "memory_bytes";
    hops = int_field "hops";
    neighbor_walks = int_field "neighbor_walks";
    node_reads = int_field "node_reads";
    start;
  }

and int_field_of kvs key = match List.assoc_opt key kvs with Some (`Int n) -> Int64.of_int n | _ -> 0L

and decode_plan_node (json : Yojson.Safe.t) : plan_node =
  match json with
  | `Assoc kvs ->
    let actual =
      match List.assoc_opt "actual" kvs with
      | Some (`Assoc akvs) -> Some (decode_plan_actual akvs)
      | _ -> None
    in
    let estimated_rows =
      match List.assoc_opt "estimated_rows" kvs with
      | Some (`Int n) -> Some (Int64.of_int n)
      | _ -> None
    in
    {
      operator = optional_string kvs "operator";
      details = optional_string kvs "details";
      identifiers = string_list "plan node" "identifiers" kvs;
      estimated_rows;
      actual;
      children = child_nodes kvs;
      warnings = warnings kvs;
    }
  | other ->
    raise
      (Error.Abi
         (Printf.sprintf "plan node is not a JSON object: %s"
            (Wire.safe (Yojson.Safe.to_string other))))

and child_nodes kvs =
  match List.assoc_opt "children" kvs with
  | Some (`List items) -> List.map decode_plan_node items
  | _ -> []

and warnings kvs =
  match List.assoc_opt "warnings" kvs with
  | Some (`List items) -> List.map Notification.decode_entry items
  | _ -> []

(* decode_plan reads the structured plan document; an absent plan (a plain
   run) is legitimately None, but a payload that is not a relate.plan/v1
   document with a root operator is an ABI contract violation. *)
let decode_plan (raw : string) : plan_document option =
  let json = try Yojson.Safe.from_string raw with _ -> raise (Error.Abi (Printf.sprintf "decoding plan: %s" (Wire.safe raw))) in
  match json with
  | `Null -> raise (Error.Abi (Printf.sprintf "plan payload is JSON null, expected an object: %s" (Wire.safe raw)))
  | `Assoc kvs ->
    let schema = optional_string kvs "schema" in
    let root = decode_plan_node (match List.assoc_opt "root" kvs with Some r -> r | None -> `Assoc []) in
    if schema <> "relate.plan/v1" then
      raise (Error.Abi (Printf.sprintf "plan schema %s is not %s" (Wire.quoted schema) (Wire.quoted "relate.plan/v1")));
    if root.operator = "" then raise (Error.Abi "plan document carries no root operator");
    Some {
      schema;
      profiled = optional_bool kvs "profiled";
      statement = (match List.assoc_opt "statement" kvs with Some (`String s) -> Some s | _ -> None);
      root;
    }
  | other ->
    raise
      (Error.Abi
         (Printf.sprintf "plan payload is not a JSON object: %s"
            (Wire.safe (Yojson.Safe.to_string other))))

let guarded t call =
  Mutex.lock t.mutex;
  let outcome =
    if t.destroyed then `Closed
    else (try `Ok (call ()) with e -> `Exn e)
  in
  Mutex.unlock t.mutex;
  match outcome with
  | `Ok x -> x
  | `Closed -> raise Error.Closed
  | `Exn e -> raise e

let destroy t =
  Mutex.lock t.mutex;
  let pending = not t.destroyed in
  t.destroyed <- true;
  Mutex.unlock t.mutex;
  if pending then Abi.relate_destroy_result t.handle

(* create reads one query result's whole metadata envelope; a statement
   failure rides the result and raises Error.E, leaving the handle for the
   caller to destroy. *)
let create (handle : unit Ctypes.ptr) : t =
  if Abi.relate_result_is_error handle <> 0 then begin
    match Abi.relate_result_error_json handle with
    | None -> raise (Error.Abi "error result carries no error detail")
    | Some raw ->
      let e = Error.decode raw in
      raise (Error.E e)
  end;
  let require what = function
    | Some v -> v
    | None -> raise (Error.Abi (Printf.sprintf "result carries no %s" what))
  in
  let columns = Array.init (Int64.to_int (Abi.relate_column_count handle)) (fun i ->
      Abi.relate_column_name handle (Int64.of_int i)) in
  let t =
    {
      handle;
      columns;
      row_count = Int64.to_int (Abi.relate_row_count handle);
      query_type = decode_query_type (require "query type" (Abi.relate_result_query_type handle));
      namespace = decode_namespace (require "namespace" (Abi.relate_result_namespace handle));
      bookmark = (match Abi.relate_result_bookmark handle with Some b -> b | None -> "");
      stats = decode_stats (require "stats" (Abi.relate_result_stats handle));
      notifications = Notification.decode (require "notifications" (Abi.relate_result_notifications handle));
      plan = (match Abi.relate_result_plan_json handle with Some raw -> decode_plan raw | None -> None);
      destroyed = false;
      mutex = Mutex.create ();
    }
  in
  Gc.finalise (fun t -> destroy t) t;
  t

let row_count t = t.row_count

let columns t = Array.to_list t.columns

let query_type t = t.query_type

let namespace t = t.namespace

let bookmark t = t.bookmark

let stats t = t.stats

let notifications t = t.notifications

let plan t = t.plan

let cell t ~row ~col =
  guarded t (fun () ->
      if row < 0 || row >= t.row_count || col < 0 || col >= Array.length t.columns then
        raise (Error.Abi (Printf.sprintf "no handle for cell (%d,%d)" row col));
      match Abi.relate_value_at t.handle (Int64.of_int row) (Int64.of_int col) with
      | None -> raise (Error.Abi (Printf.sprintf "no handle for cell (%d,%d)" row col))
      | Some v -> Value.of_handle v)

let row t i = List.init (Array.length t.columns) (fun col -> cell t ~row:i ~col)

let rows t = List.init t.row_count (row t)

let iter_rows t ~f =
  for i = 0 to t.row_count - 1 do
    f (row t i)
  done

let elapsed_ms t = guarded t (fun () -> Abi.relate_result_elapsed_ms t.handle)

let parse_ms t = guarded t (fun () -> Abi.relate_result_parse_ms t.handle)

let plan_ms t = guarded t (fun () -> Abi.relate_result_plan_ms t.handle)

let execute_ms t = guarded t (fun () -> Abi.relate_result_execute_ms t.handle)
