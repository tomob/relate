open Ctypes

let uint8 : int typ =
  view ~read:Unsigned.UInt8.to_int ~write:Unsigned.UInt8.of_int uint8_t

let size_t : int typ =
  view ~read:Unsigned.UInt64.to_int ~write:Unsigned.UInt64.of_int uint64_t

let null_char : char ptr =
  coerce (ptr void) (ptr char) null
