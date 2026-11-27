(** Sanitization of untrusted wire text echoed into error messages. *)

val value_max : int
(** The bound, in bytes, on a quoted value (a closed-vocabulary string). *)

val payload_max : int
(** The bound, in bytes, on an echoed payload (a whole JSON document). *)

val quoted : string -> string
(** The display form of an offending value: escaped, bounded, in quotes. *)

val safe : string -> string
(** The display form of an echoed payload: escaped and bounded. *)
