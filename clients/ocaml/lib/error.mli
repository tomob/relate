(** The classified failure shape, raised as exceptions on every refusal. *)

type stage = Compile | Runtime | Internal
(** Where the engine failed: before execution, during it, or an internal fault. *)

type t = {
  code : string;        (** The Neo4j status code. *)
  gql_status : string;  (** The five-character GraphQL status code. *)
  stage : stage;        (** Where the failure happened. *)
  retryable : bool;     (** Whether the same call may be retried as-is. *)
  message : string;     (** The human-readable description. *)
}

exception E of t
(** An engine or boundary failure carrying the classified shape. *)

exception Abi of string
(** A broken ABI contract — a refusal, never a silent zero value. *)

exception Closed
(** A handle was used after close; the call never reached the engine. *)

exception Nul of string
(** An input holds an interior NUL and cannot cross the C boundary. *)

val error_keys : string list
(** The five keys the error payload must carry, zeros never standing in. *)

val decode : string -> t
(** Strictly decode the error channel's JSON, refusing a missing key. *)
