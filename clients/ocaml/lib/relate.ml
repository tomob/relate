module Abi = Relate_abi.Bindings
module Views = Relate_abi_types.Views

module Error = Error
module Notification = Notification
module Params = Params
module Result = Result
module Value = Value
module Wire = Wire

type database = { mutable ptr : unit Ctypes.ptr option; mutex : Mutex.t }

type connection = { mutable ptr : unit Ctypes.ptr option; mutex : Mutex.t }

(* c_string is the one home of the interior-NUL policy: every port that
   takes an OCaml string NUL-terminated (statement text, parameter and entry
   names, map-key lookups, the uri, namespace and zone names) would
   silently truncate an interior NUL, so what names the string and the NUL
   is refused here. Value bytes that cross with an explicit length
   (Params.put_string) do not come through here: their NULs are data. *)
let c_string what s =
  if String.contains s '\000' then
    raise
      (Error.Nul
         (Printf.sprintf "%s holds an interior NUL and cannot cross the C boundary" what));
  s

let err_slot () = Ctypes.allocate (Ctypes.ptr Ctypes.char) Views.null_char

let abi_version () = Abi.relate_abi_version ()

let check_abi () =
  let v = Abi.relate_abi_version () in
  if v <> 2 then
    raise
      (Error.Abi
         (Printf.sprintf "relate native library reports ABI version %d; this client speaks v2" v))

let close_database (db : database) =
  Mutex.lock db.mutex;
  let pending = db.ptr in
  db.ptr <- None;
  Mutex.unlock db.mutex;
  (match pending with Some p -> ignore (Abi.relate_database_close p) | None -> ())

let open_database ?(read_only = false) uri =
  check_abi ();
  let uri = c_string "database uri" uri in
  let out = Ctypes.allocate (Ctypes.ptr Ctypes.void) Ctypes.null in
  let err = err_slot () in
  let st =
    if read_only then Abi.relate_database_open_read_only uri out err
    else Abi.relate_database_open uri out err
  in
  Call.check st err;
  let p = Ctypes.(!@) out in
  if Ctypes.ptr_compare p Ctypes.null = 0 then
    raise (Error.Abi "open returned no database handle");
  let db : database = { ptr = Some p; mutex = Mutex.create () } in
  Gc.finalise (fun db -> close_database db) db;
  db

let open_database_read_only uri = open_database ~read_only:true uri

let with_database ?read_only uri f =
  let db = open_database ?read_only uri in
  match f db with
  | x -> close_database db; x
  | exception e -> close_database db; raise e

let guarded_database (db : database) call =
  Mutex.lock db.mutex;
  let outcome =
    match db.ptr with
    | None -> `Closed
    | Some p -> (try `Ok (call p) with e -> `Exn e)
  in
  Mutex.unlock db.mutex;
  match outcome with
  | `Ok x -> x
  | `Closed -> raise Error.Closed
  | `Exn e -> raise e

let disconnect (conn : connection) =
  Mutex.lock conn.mutex;
  let pending = conn.ptr in
  conn.ptr <- None;
  Mutex.unlock conn.mutex;
  (match pending with Some p -> ignore (Abi.relate_disconnect p) | None -> ())

let guarded_connection (conn : connection) call =
  Mutex.lock conn.mutex;
  let outcome =
    match conn.ptr with
    | None -> `Closed
    | Some p -> (try `Ok (call p) with e -> `Exn e)
  in
  Mutex.unlock conn.mutex;
  match outcome with
  | `Ok x -> x
  | `Closed -> raise Error.Closed
  | `Exn e -> raise e

let connect ?namespace (db : database) =
  let namespace =
    match namespace with
    | None -> None
    | Some n -> Some (c_string "namespace name" n)
  in
  guarded_database db (fun dp ->
      let out = Ctypes.allocate (Ctypes.ptr Ctypes.void) Ctypes.null in
      let err = err_slot () in
      Call.check (Abi.relate_connect_namespace dp namespace out err) err;
      let p = Ctypes.(!@) out in
      if Ctypes.ptr_compare p Ctypes.null = 0 then
        raise (Error.Abi "connect returned no connection handle");
      let conn : connection = { ptr = Some p; mutex = Mutex.create () } in
      Gc.finalise (fun conn -> disconnect conn) conn;
      conn)

let with_connection ?namespace db f =
  let conn = connect ?namespace db in
  match f conn with
  | x -> disconnect conn; x
  | exception e -> disconnect conn; raise e

let checkpoint (db : database) =
  guarded_database db (fun dp ->
      let err = err_slot () in
      Call.check (Abi.relate_checkpoint dp err) err)

let set_namespace (conn : connection) name =
  let name = c_string "namespace name" name in
  guarded_connection conn (fun cp ->
      let err = err_slot () in
      Call.check (Abi.relate_conn_set_namespace cp name err) err)

let begin_transaction (conn : connection) =
  guarded_connection conn (fun cp ->
      let err = err_slot () in
      Call.check (Abi.relate_conn_begin cp err) err)

let rollback (conn : connection) =
  guarded_connection conn (fun cp ->
      let err = err_slot () in
      Call.check (Abi.relate_conn_rollback cp err) err)

(* commit commits the explicit transaction and returns its bookmark
   ("relate:<n>"), or "" when the transaction committed nothing: no bookmark
   is fabricated for a commit that crossed no WAL boundary. *)
let commit (conn : connection) =
  guarded_connection conn (fun cp ->
      let bookmark = Ctypes.allocate (Ctypes.ptr Ctypes.char) Views.null_char in
      let err = err_slot () in
      Call.check (Abi.relate_conn_commit cp bookmark err) err;
      let p = Ctypes.(!@) bookmark in
      if Ctypes.ptr_compare p Views.null_char = 0 then ""
      else begin
        let raw = Call.read_cstr p in
        Abi.relate_free_string p;
        raw
      end)

(* query_raw runs a statement and returns the live result handle's Result.t
   without destroying it; the caller owns destruction. A statement failure
   raises Error.E from Result.create (the handle is destroyed by query's
   scope below); a connection-level failure raises from the call's own
   out-param. *)
let query_raw ?params (conn : connection) cypher =
  let cypher = c_string "statement" cypher in
  let root =
    match params with
    | None -> Ctypes.null
    | Some p -> (match Params.handle p with Some r -> r | None -> raise Error.Closed)
  in
  guarded_connection conn (fun cp ->
      let out = Ctypes.allocate (Ctypes.ptr Ctypes.void) Ctypes.null in
      let err = err_slot () in
      Call.check (Abi.relate_query_params cp cypher root out err) err;
      let p = Ctypes.(!@) out in
      if Ctypes.ptr_compare p Ctypes.null = 0 then
        raise (Error.Abi "query returned no result handle");
      Result.create p)

(* query runs a statement and hands the live result to consume, destroying
   it on every path: rows stream out of the native result, so the consumer
   must finish before the handle dies. *)
let query ?params (conn : connection) cypher consume =
  let result = query_raw ?params conn cypher in
  match consume result with
  | x -> Result.destroy result; x
  | exception e -> Result.destroy result; raise e

(* query_values is the convenience port: the entries bind through a fresh
   builder (see Params.bind), freed when the statement has been read. *)
let query_values ?(params = []) (conn : connection) cypher consume =
  Params.with_params (fun builder ->
      Params.bind_map builder params;
      query ~params:builder conn cypher consume)
