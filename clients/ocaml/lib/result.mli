(** A streaming query result and its metadata envelope. *)

type query_type =
  | Read        (** The statement read only. *)
  | Write       (** The statement wrote only. *)
  | Read_write  (** The statement wrote and returned rows. *)
  | Schema      (** The statement changed the schema. *)

type namespace = Neo4j | System | System_ontologies
(** The session's resolved namespace. *)

type stats = {
  nodes_created : int64;           (** Nodes created by the statement. *)
  nodes_deleted : int64;           (** Nodes deleted by the statement. *)
  relationships_created : int64;   (** Relationships created by the statement. *)
  relationships_deleted : int64;   (** Relationships deleted by the statement. *)
  properties_set : int64;          (** Properties set by the statement. *)
  labels_added : int64;            (** Labels added by the statement. *)
  labels_removed : int64;          (** Labels removed by the statement. *)
  indexes_added : int64;           (** Indexes added by the statement. *)
  indexes_removed : int64;         (** Indexes removed by the statement. *)
  constraints_added : int64;       (** Constraints added by the statement. *)
  constraints_removed : int64;     (** Constraints removed by the statement. *)
}

type notification = Notification.t
(** One notification the statement carried. *)

type plan_actual = {
  rows : int64;                    (** Rows the operator produced. *)
  time_ms : float;                 (** Time the operator took, in milliseconds. *)
  db_hits : int64;                 (** Engine reads the operator made. *)
  memory_bytes : int64;            (** Memory the operator used, when profiled. *)
  hops : int64;                    (** Hops the operator walked. *)
  neighbor_walks : int64;          (** Neighbor walks the operator made. *)
  node_reads : int64;              (** Node reads the operator made. *)
  start : (int64 * bool * string) option;  (** The join-order start, when recorded: element, direction, reason. *)
}

and plan_node = {
  operator : string;               (** The operator name. *)
  details : string;                (** What the operator did. *)
  identifiers : string list;       (** The variables the operator carries. *)
  estimated_rows : int64 option;   (** The planner's estimate, when present. *)
  actual : plan_actual option;     (** The profiled numbers, when profiled. *)
  children : plan_node list;       (** The operator's children. *)
  warnings : notification list;    (** Warnings attached to this operator. *)
}

type plan_document = {
  schema : string;                 (** Always ["relate.plan/v1"]. *)
  profiled : bool;                 (** Whether the plan carries actual numbers. *)
  statement : string option;       (** The statement the plan describes. *)
  root : plan_node;                (** The plan's root operator. *)
}

type t
(** A live result handle: read it inside [Relate.query]'s consumer. *)

val create : unit Ctypes.ptr -> t
(** Read one native result's metadata envelope; a statement error raises. *)

val destroy : t -> unit
(** Destroy the native result; idempotent. *)

val row_count : t -> int
(** The number of rows in the final answer. *)

val columns : t -> string list
(** The column names, in order. *)

val query_type : t -> query_type
(** What the statement did. *)

val namespace : t -> namespace
(** The session's resolved namespace. *)

val bookmark : t -> string
(** The auto-commit bookmark, "" for a read or inside a transaction. *)

val stats : t -> stats
(** The canonical eleven counters, zeros included. *)

val notifications : t -> notification list
(** The notifications the statement carried. *)

val plan : t -> plan_document option
(** The plan, [None] on a plain run. *)

val cell : t -> row:int -> col:int -> Value.value
(** Walk one cell into a typed value. *)

val row : t -> int -> Value.value list
(** Walk one whole row. *)

val rows : t -> Value.value list list
(** Materialize the whole final answer explicitly. *)

val iter_rows : t -> f:(Value.value list -> unit) -> unit
(** Stream every row through [f], one at a time. *)

val elapsed_ms : t -> float
(** Total statement time, in milliseconds. *)

val parse_ms : t -> float
(** Parse time, in milliseconds. *)

val plan_ms : t -> float
(** Planning time, in milliseconds. *)

val execute_ms : t -> float
(** Execution time, in milliseconds. *)
