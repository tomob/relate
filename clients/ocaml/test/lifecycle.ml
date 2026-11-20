let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let raises_closed f =
  try
    ignore (f ());
    false
  with Relate.Error.Closed -> true

let () =
  let db = Relate.open_database ":memory:" in
  Relate.close_database db;
  Relate.close_database db;
  check (raises_closed (fun () -> Relate.connect db)) "connect after close raises Closed";
  check (raises_closed (fun () -> Relate.checkpoint db)) "checkpoint after close raises Closed";
  let conn = Relate.open_database ":memory:" |> Relate.connect in
  Relate.disconnect conn;
  Relate.disconnect conn;
  check
    (raises_closed (fun () -> Relate.query conn "RETURN 1" (fun _ -> ())))
    "query after disconnect raises Closed";
  check
    (raises_closed (fun () -> Relate.set_namespace conn "system"))
    "set_namespace after disconnect raises Closed"

let () =
  let uri =
    Filename.concat (Filename.get_temp_dir_name ())
      ("relate-ocaml-lifecycle-" ^ string_of_int (Random.int 1000000) ^ ".db")
  in
  let cleanup () = try Sys.remove uri with _ -> () in
  (try
     Relate.with_database uri (fun db ->
         Relate.with_connection db (fun conn ->
             Relate.query conn "CREATE (:Person {name: 'Ada'})" (fun _ -> ())));
     let db = Relate.open_database_read_only uri in
     Relate.with_connection db (fun conn ->
         try
           Relate.query conn "CREATE ()" (fun _ -> ());
           check false "read-only refuses writes"
         with Relate.Error.E _ -> ());
     let missing =
       Filename.concat (Filename.get_temp_dir_name ())
         ("relate-ocaml-missing-" ^ string_of_int (Random.int 1000000) ^ ".db")
     in
     (try
        ignore (Relate.open_database_read_only missing);
        Printf.eprintf "FAIL: read-only open of a missing store should fail\n";
        exit 1
      with Relate.Error.E _ -> ());
     Relate.close_database db;
     cleanup ()
   with e -> cleanup (); raise e)

let () = print_endline "lifecycle ok"
