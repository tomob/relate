let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let read_copy () =
  List.find_map
    (fun path -> try Some (read_file path) with _ -> None)
    [ "../include/relate.h"; "include/relate.h" ]

(* The client's header copy must stay byte-equal to the FFI crate's; the
   comparison needs the repository checkout, so a package-mode run (no
   upstream header reachable) skips with this line instead of passing
   silently. *)
let () =
  match Sys.getenv_opt "RELATE_UPSTREAM_HEADER" with
  | None ->
    print_endline "skipping header equality: no upstream header (package mode)"
  | Some path ->
    (match
       let upstream = read_file path in
       match read_copy () with
       | Some copy -> Some (upstream, copy)
       | None -> None
     with
    | exception _ ->
      print_endline "skipping header equality: upstream header unreadable"
    | None ->
      print_endline "skipping header equality: client header copy unreadable"
    | Some (upstream, copy) ->
      check (String.length upstream = String.length copy) "header lengths equal";
      check (String.equal upstream copy) "header copy is byte-equal";
      print_endline "header_test ok")
