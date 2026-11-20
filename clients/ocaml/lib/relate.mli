(** Embedded client for the Relate engine over the typed C ABI v2. *)

module Error = Error
(** Classified failures, raised as exceptions. *)

module Notification = Notification
(** Engine-native query notifications. *)

module Params = Params
(** The typed parameter builder and its value tree. *)

module Result = Result
(** A streaming query result and its metadata envelope. *)

module Value = Value
(** Typed result values. *)

module Wire = Wire
(** Sanitized wire text for error messages. *)

type database
(** An open database handle. *)

type connection
(** A connected session; its calls are serialized. *)

val abi_version : unit -> int
(** The ABI version the native library reports; this client speaks 2. *)

val open_database : ?read_only:bool -> string -> database
(** Open (or create) the database at [uri]; read-only refuses writes and a
    missing store. *)

val open_database_read_only : string -> database
(** [open_database ~read_only:true]. *)

val close_database : database -> unit
(** Close the database; idempotent. *)

val with_database : ?read_only:bool -> string -> (database -> 'a) -> 'a
(** Scope an open database, closing it on every path. *)

val connect : ?namespace:string -> database -> connection
(** Connect a session; [None] is the default namespace. *)

val disconnect : connection -> unit
(** Disconnect the session; idempotent. *)

val with_connection : ?namespace:string -> database -> (connection -> 'a) -> 'a
(** Scope a connection, disconnecting it on every path. *)

val checkpoint : database -> unit
(** Force a WAL checkpoint. *)

val set_namespace : connection -> string -> unit
(** Switch the session's namespace; fails inside a transaction. *)

val begin_transaction : connection -> unit
(** Begin an explicit transaction. *)

val commit : connection -> string
(** Commit; the transaction's bookmark, "" when it wrote nothing. *)

val rollback : connection -> unit
(** Roll the transaction back. *)

val query : ?params:Params.t -> connection -> string -> (Result.t -> 'a) -> 'a
(** Run a statement and hand the live result to [consume], destroying it on
    every path. *)

val query_values :
  ?params:(string * Params.value) list ->
  connection ->
  string ->
  (Result.t -> 'a) ->
  'a
(** [query] with the entries bound through a fresh builder. *)
