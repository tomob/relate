[@@@warning "-30"]

(** Typed result values: one constructor per engine kind. *)

type node = {
  element_id : string;            (** The opaque element id, "" in the system namespace. *)
  id : int64;                     (** The deprecated numeric id. *)
  labels : string list;           (** The node's labels, in engine order. *)
  properties : (string * value) list; (** The node's properties, in engine order. *)
}

and relationship = {
  element_id : string;            (** The opaque element id. *)
  start_element_id : string;      (** The start node's element id. *)
  end_element_id : string;        (** The end node's element id. *)
  id : int64;                     (** The deprecated numeric id. *)
  start_id : int64;               (** The start node's numeric id. *)
  end_id : int64;                 (** The end node's numeric id. *)
  typ : string;                   (** The relationship type. *)
  properties : (string * value) list; (** The relationship's properties, in engine order. *)
}

and point = {
  srid : int;                     (** The coordinate reference system. *)
  dimension : int;                (** 2 or 3. *)
  x : float;                      (** The first coordinate. *)
  y : float;                      (** The second coordinate. *)
  z : float option;               (** The third coordinate, present in dimension 3. *)
}

and vector = {
  dtype : string;                 (** The engine's canonical dtype spelling. *)
  ints : int64 array option;      (** Integer coordinates, [None] for float vectors. *)
  floats : float array option;    (** Float coordinates, [None] for integer vectors. *)
}

and value =
  | Null                                (** The absent value. *)
  | Bool of bool                        (** true or false. *)
  | Int of int64                        (** A 64-bit integer. *)
  | Float of float                      (** A double, NaN and infinities included. *)
  | String of string                    (** Bytes, interior NULs preserved. *)
  | Node of node                        (** A graph node. *)
  | Relationship of relationship        (** A graph relationship. *)
  | Path of value list                  (** An alternating node/relationship walk. *)
  | List of value list                  (** A list, in engine order. *)
  | Map of (string * value) list        (** A map, in engine order. *)
  | Point of point                      (** A spatial point. *)
  | Date of { year : int; month : int; day : int }
                                        (** A calendar date. *)
  | Time of {
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
    }                                  (** A wall-clock time with a UTC offset. *)
  | Local_time of { hour : int; minute : int; second : int; nanosecond : int }
                                        (** A wall-clock time with no zone. *)
  | Datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
      offset_seconds : int;
      zone : string;
    }                                  (** A date and time with a UTC offset and named zone. *)
  | Local_datetime of {
      year : int;
      month : int;
      day : int;
      hour : int;
      minute : int;
      second : int;
      nanosecond : int;
    }                                  (** A date and time with no zone. *)
  | Duration of { months : int64; days : int64; seconds : int64; nanos : int64 }
                                        (** An months/days/seconds/nanos duration. *)
  | Vector of vector                   (** A typed vector. *)

val describe : value -> string
(** The kind noun of a value, for refusal messages. *)

val of_handle : unit Ctypes.ptr -> value
(** Walk one native value handle into a typed value. *)
