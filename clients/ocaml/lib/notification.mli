(** Engine-native query notifications with their closed vocabularies. *)

type severity = Information | Warning
(** How loud a notification is. *)

type category = Performance | Unrecognized | Deprecation | Schema | Hint
(** What a notification is about. *)

type t = {
  code : string;          (** The engine's notification code. *)
  gql_status : string;    (** The five-character GraphQL status code. *)
  severity : severity;    (** The closed severity noun. *)
  category : category;    (** The closed category noun. *)
  title : string;         (** One-line summary, "" when absent. *)
  description : string;   (** What the notification means, "" when absent. *)
  remedy : string;        (** How to address it, "" when absent. *)
  operator_id : int64 option; (** The plan node it is attached to, when statement-scoped. *)
}

val severity_vocabulary : (severity * string) list
(** The closed severity nouns as (value, wire string) pairs. *)

val category_vocabulary : (category * string) list
(** The closed category nouns as (value, wire string) pairs. *)

val decode_entry : Yojson.Safe.t -> t
(** Strictly decode one notification object, refusing a missing key. *)

val decode : string -> t list
(** Strictly decode the engine's notification array. *)
