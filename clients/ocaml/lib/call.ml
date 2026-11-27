module Abi = Relate_abi.Bindings
module Views = Relate_abi_types.Views

let rec private_strlen p n =
  if Ctypes.(!@) (Ctypes.(+@) p n) = '\000' then n
  else private_strlen p (n + 1)

let read_cstr (p : char Ctypes.ptr) : string =
  Ctypes.string_from_ptr p ~length:(private_strlen p 0)

(* take_error reads, frees and decodes a caller-owned error_json out-param;
   a NULL one after a failed status is a broken ABI contract. *)
let take_error (slot : char Ctypes.ptr Ctypes.ptr) : 'a =
  let p = Ctypes.(!@) slot in
  if Ctypes.ptr_compare p Views.null_char = 0 then
    raise (Error.Abi "call failed without an error detail");
  let raw = read_cstr p in
  Abi.relate_free_string p;
  raise (Error.E (Error.decode raw))

(* check is the error of a fallible status call: nothing on RELATE_OK,
   otherwise the error shape the call wrote to its out-param. *)
let check st slot = if st <> 0 then take_error slot
