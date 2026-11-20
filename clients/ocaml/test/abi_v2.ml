let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let with_conn f =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn -> f conn))

let () =
  check (Relate.abi_version () = 2) "abi version is 2";
  with_conn (fun conn ->
      Relate.query conn "RETURN 1 AS n" (fun res ->
          check (Relate.Result.row_count res = 1) "one row";
          check
            (match Relate.Result.cell res ~row:0 ~col:0 with
            | Relate.Value.Int n -> n = 1L
            | _ -> false)
            "RETURN 1 is Int 1"))

let () = print_endline "abi_v2 ok"
