(** The raw typed C ABI v2, one value per [relate.h] function. Marshalling
    follows the views the description applies; policies (interior NUL,
    ownership, serialization) live in the [Relate] layer, not here. *)

open Ctypes

val relate_abi_version : unit -> int
(** The ABI version, 2. *)

val relate_free_string : char ptr -> unit
(** Free a caller-owned error string; a no-op on NULL. *)

val relate_database_open :
  string -> unit ptr ptr -> char ptr ptr -> int
(** Open or create the database at [uri]. *)

val relate_database_open_read_only :
  string -> unit ptr ptr -> char ptr ptr -> int
(** Open an existing database read-only. *)

val relate_database_close : unit ptr -> int
(** Close the database. *)

val relate_connect_namespace :
  unit ptr -> string option -> unit ptr ptr -> char ptr ptr -> int
(** Connect; [None] is the default namespace. *)

val relate_conn_set_namespace : unit ptr -> string -> char ptr ptr -> int
(** Switch the session's namespace. *)

val relate_disconnect : unit ptr -> int
(** Disconnect the session. *)

val relate_query_params :
  unit ptr -> string -> unit ptr -> unit ptr ptr -> char ptr ptr -> int
(** Run a statement; [null] params runs it bare. *)

val relate_conn_begin : unit ptr -> char ptr ptr -> int
(** Begin an explicit transaction. *)

val relate_conn_rollback : unit ptr -> char ptr ptr -> int
(** Roll the transaction back. *)

val relate_checkpoint : unit ptr -> char ptr ptr -> int
(** Force a WAL checkpoint. *)

val relate_conn_commit : unit ptr -> char ptr ptr -> char ptr ptr -> int
(** Commit; writes the bookmark, "" when nothing committed. *)

val relate_result_bookmark : unit ptr -> string option
(** The auto-commit bookmark, [None] when there is none. *)

val relate_result_is_error : unit ptr -> int
(** 1 when the result carries a statement failure. *)

val relate_result_error_json : unit ptr -> string option
(** The failure's JSON shape, [None] on a good result. *)

val relate_column_count : unit ptr -> int64
(** The number of columns. *)

val relate_row_count : unit ptr -> int64
(** The number of rows. *)

val relate_column_name : unit ptr -> int64 -> string
(** One column's name. *)

val relate_result_query_type : unit ptr -> string option
(** ["r"], ["w"], ["rw"] or ["s"]. *)

val relate_result_namespace : unit ptr -> string option
(** The resolved session namespace. *)

val relate_result_stats : unit ptr -> string option
(** The eleven counters as JSON. *)

val relate_result_notifications : unit ptr -> string option
(** The notification array as JSON. *)

val relate_result_plan_json : unit ptr -> string option
(** The plan document as JSON, [None] on a plain run. *)

val relate_result_elapsed_ms : unit ptr -> float
(** Total statement time, in milliseconds. *)

val relate_result_parse_ms : unit ptr -> float
(** Parse time, in milliseconds. *)

val relate_result_plan_ms : unit ptr -> float
(** Planning time, in milliseconds. *)

val relate_result_execute_ms : unit ptr -> float
(** Execution time, in milliseconds. *)

val relate_value_at : unit ptr -> int64 -> int64 -> unit ptr option
(** The value handle at (row, col), [None] out of range. *)

val relate_value_kind : unit ptr -> int
(** The value's kind, -1 on a NULL handle. *)

val relate_value_bool : unit ptr -> int ptr -> int
(** Read a bool into the flag slot. *)

val relate_value_int : unit ptr -> int64 ptr -> int
(** Read a 64-bit integer into the slot. *)

val relate_value_float : unit ptr -> float ptr -> int
(** Read a double into the slot. *)

val relate_value_is_nan : unit ptr -> int ptr -> int
(** 1 when the float is NaN. *)

val relate_value_is_inf : unit ptr -> int ptr -> int
(** 1 when the float is an infinity. *)

val relate_value_string : unit ptr -> int ptr -> char ptr
(** Read the string's bytes and its length. *)

val relate_value_element_id : unit ptr -> string option
(** The element id, [None] in the system namespace. *)

val relate_value_start_element_id : unit ptr -> string option
(** The start element id. *)

val relate_value_end_element_id : unit ptr -> string option
(** The end element id. *)

val relate_value_id : unit ptr -> int64 ptr -> int
(** Read the deprecated numeric id. *)

val relate_value_start_id : unit ptr -> int64 ptr -> int
(** Read the start node's numeric id. *)

val relate_value_end_id : unit ptr -> int64 ptr -> int
(** Read the end node's numeric id. *)

val relate_value_list_len : unit ptr -> int64
(** The list's length. *)

val relate_value_list_get : unit ptr -> int64 -> unit ptr option
(** One list item, [None] past the end. *)

val relate_value_map_len : unit ptr -> int64
(** The map's length. *)

val relate_value_map_key : unit ptr -> int64 -> int ptr -> char ptr
(** One map key and its length. *)

val relate_value_map_get : unit ptr -> string -> unit ptr option
(** One map entry, [None] when the key is absent. *)

val relate_value_year : unit ptr -> int64 ptr -> int
(** Read the temporal's year. *)

val relate_value_month : unit ptr -> int64 ptr -> int
(** Read the temporal's month. *)

val relate_value_day : unit ptr -> int64 ptr -> int
(** Read the temporal's day. *)

val relate_value_hour : unit ptr -> int64 ptr -> int
(** Read the temporal's hour. *)

val relate_value_minute : unit ptr -> int64 ptr -> int
(** Read the temporal's minute. *)

val relate_value_second : unit ptr -> int64 ptr -> int
(** Read the temporal's second. *)

val relate_value_nanosecond : unit ptr -> int64 ptr -> int
(** Read the temporal's nanosecond. *)

val relate_value_offset_seconds : unit ptr -> int64 ptr -> int
(** Read the temporal's UTC offset. *)

val relate_value_zone : unit ptr -> string option
(** The temporal's named zone, "" when offset-only. *)

val relate_value_duration :
  unit ptr -> int64 ptr -> int64 ptr -> int64 ptr -> int64 ptr -> int
(** Read the duration's four components. *)

val relate_value_point :
  unit ptr -> int32 ptr -> int32 ptr -> float ptr -> float ptr -> float ptr -> int
(** Read the point's srid, dimension and coordinates. *)

val relate_value_vector_dtype : unit ptr -> string option
(** The vector's dtype. *)

val relate_value_vector_dim : unit ptr -> int64
(** The vector's dimension. *)

val relate_value_vector_float : unit ptr -> int64 -> float ptr -> int
(** Read one float coordinate. *)

val relate_value_vector_int : unit ptr -> int64 -> int64 ptr -> int
(** Read one integer coordinate. *)

val relate_params_new : unit -> unit ptr
(** Allocate a root builder. *)

val relate_params_free : unit ptr -> unit
(** Free the builder tree; a no-op on children. *)

val relate_params_put_null : unit ptr -> string option -> char ptr ptr -> int
(** Put a null; [None] appends, a name sets. *)

val relate_params_put_bool :
  unit ptr -> string option -> int -> char ptr ptr -> int
(** Put a bool flag. *)

val relate_params_put_int :
  unit ptr -> string option -> int64 -> char ptr ptr -> int
(** Put a 64-bit integer. *)

val relate_params_put_float :
  unit ptr -> string option -> float -> char ptr ptr -> int
(** Put a double. *)

val relate_params_put_string :
  unit ptr -> string option -> string -> int -> char ptr ptr -> int
(** Put a string with its length. *)

val relate_params_put_date :
  unit ptr -> string option -> int64 -> int64 -> int64 -> char ptr ptr -> int
(** Put year, month, day. *)

val relate_params_put_time :
  unit ptr ->
  string option ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  string option ->
  char ptr ptr ->
  int
(** Put a time; the zone, when given, wins over the offset. *)

val relate_params_put_local_time :
  unit ptr -> string option -> int64 -> int64 -> int64 -> int64 -> char ptr ptr -> int
(** Put a zoneless time. *)

val relate_params_put_datetime :
  unit ptr ->
  string option ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  string option ->
  char ptr ptr ->
  int
(** Put a datetime; the zone, when given, wins over the offset. *)

val relate_params_put_local_datetime :
  unit ptr ->
  string option ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  int64 ->
  char ptr ptr ->
  int
(** Put a zoneless datetime. *)

val relate_params_put_duration :
  unit ptr -> string option -> int64 -> int64 -> int64 -> int64 -> char ptr ptr -> int
(** Put a duration's four components. *)

val relate_params_put_point :
  unit ptr -> string option -> int32 -> float -> float -> float ptr option -> char ptr ptr -> int
(** Put a point; the z pointer is [None] for 2D. *)

val relate_params_put_vector_float :
  unit ptr -> string option -> string -> float ptr -> int -> char ptr ptr -> int
(** Put a float vector. *)

val relate_params_put_vector_int :
  unit ptr -> string option -> string -> int64 ptr -> int -> char ptr ptr -> int
(** Put an integer vector. *)

val relate_params_put_list :
  unit ptr -> string option -> unit ptr ptr -> char ptr ptr -> int
(** Start a list child. *)

val relate_params_put_map :
  unit ptr -> string option -> unit ptr ptr -> char ptr ptr -> int
(** Start a map child. *)

val relate_destroy_result : unit ptr -> unit
(** Destroy the result; a no-op on NULL. *)
