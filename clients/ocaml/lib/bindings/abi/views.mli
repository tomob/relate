(** Sanitized pointers and views shared by the description and the layers above. *)

open Ctypes

val uint8 : int typ
(** The ABI's uint8_t flags as OCaml ints (0/1). *)

val size_t : int typ
(** The ABI's size_t lengths as OCaml ints, far inside int range. *)

val null_char : char ptr
(** A NULL char* for initializing out-param slots. *)
