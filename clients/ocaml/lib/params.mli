(** The typed parameter builder and its value tree. *)

type t
(** A builder handle: the root owns every child put into it. *)

val create : unit -> t
(** Allocate an empty root builder. *)

val free : t -> unit
(** Free the builder tree; idempotent, a no-op on children. *)

val with_params : (t -> 'a) -> 'a
(** Scope a fresh root builder, freeing it on every path. *)

val handle : t -> unit Ctypes.ptr option
(** The root's native handle for [Relate.query]; [None] once freed. *)

val put_null : ?name:string -> t -> unit
(** Put a null. [None] appends (list child); a name sets (map child). *)

val put_bool : ?name:string -> t -> bool -> unit
(** Put a bool. *)

val put_int : ?name:string -> t -> int64 -> unit
(** Put a 64-bit integer. *)

val put_float : ?name:string -> t -> float -> unit
(** Put a double. *)

val put_string : ?name:string -> t -> string -> unit
(** Put a string with its length, interior NULs preserved as data. *)

val put_date : ?name:string -> t -> year:int -> month:int -> day:int -> unit
(** Put a calendar date. *)

val put_time :
  ?name:string ->
  t ->
  hour:int ->
  minute:int ->
  second:int ->
  nanosecond:int ->
  offset_seconds:int ->
  zone:string option ->
  unit
(** Put a time; a zone makes it zoned and the offset is then ignored. *)

val put_local_time :
  ?name:string -> t -> hour:int -> minute:int -> second:int -> nanosecond:int -> unit
(** Put a zoneless time. *)

val put_datetime :
  ?name:string ->
  t ->
  year:int ->
  month:int ->
  day:int ->
  hour:int ->
  minute:int ->
  second:int ->
  nanosecond:int ->
  offset_seconds:int ->
  zone:string option ->
  unit
(** Put a datetime; a zone makes it zoned and the offset is then ignored. *)

val put_local_datetime :
  ?name:string ->
  t ->
  year:int ->
  month:int ->
  day:int ->
  hour:int ->
  minute:int ->
  second:int ->
  nanosecond:int ->
  unit
(** Put a zoneless datetime. *)

val put_duration :
  ?name:string -> t -> months:int64 -> days:int64 -> seconds:int64 -> nanos:int64 -> unit
(** Put a duration in its four components. *)

val put_point : ?name:string -> t -> srid:int -> x:float -> y:float -> float option -> unit
(** Put a point; the trailing argument is the z coordinate, [None] for 2D. *)

val put_vector_float : ?name:string -> t -> dtype:string -> float array -> unit
(** Put a float vector. *)

val put_vector_int : ?name:string -> t -> dtype:string -> int64 array -> unit
(** Put an integer vector. *)

val put_list : ?name:string -> t -> t
(** Start a list child; appended entries take no names. *)

val put_map : ?name:string -> t -> t
(** Start a map child; its entries take names. *)

type value =
  | Null                                    (** The absent value. *)
  | Bool of bool                            (** true or false. *)
  | Int of int64                            (** A 64-bit integer. *)
  | Float of float                          (** A double. *)
  | String of string                        (** Bytes, interior NULs preserved. *)
  | List of value list                      (** A list. *)
  | Map of (string * value) list            (** A map, order preserved. *)
  | Date of { year : int; month : int; day : int }
                                            (** A calendar date. *)
  | Time of {
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
    }                                      (** A time with a UTC offset. *)
  | Zoned_time of { hour : int; minute : int; second : int; nanosecond : int; zone : string }
                                            (** A time with a named zone. *)
  | Local_time of { hour : int; minute : int; second : int; nanosecond : int }
                                            (** A zoneless time. *)
  | Datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
    }                                      (** A datetime with a UTC offset. *)
  | Zoned_datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      zone : string;
    }                                      (** A datetime with a named zone. *)
  | Local_datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
    }                                      (** A zoneless datetime. *)
  | Duration of { months : int64; days : int64; seconds : int64; nanos : int64 }
                                            (** A duration. *)
  | Point of { srid : int; x : float; y : float; z : float option }
                                            (** A point, [z] present in dimension 3. *)
  | Vector_float of { dtype : string; values : float array }
                                            (** A float vector. *)
  | Vector_int of { dtype : string; values : int64 array }
                                            (** An integer vector. *)

val bind : t -> string option -> value -> unit
(** Bind one tree entry: [None] appends, a name sets. *)

val bind_map : t -> (string * value) list -> unit
(** Bind every entry of an association list. *)

val bind_list : t -> value list -> unit
(** Bind every entry of a list, appended in order. *)
