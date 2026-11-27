let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let with_db f = Relate.with_database ":memory:" f

let () =
  with_db (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.begin_transaction conn;
          ignore (Relate.query conn "CREATE (:Note {n: 0})" (fun _ -> ()));
          let bookmark = Relate.commit conn in
          check (bookmark <> "") "a committing transaction returns a bookmark";
          Relate.with_connection db (fun r ->
              Relate.query r "MATCH (n:Note) RETURN count(n) AS n" (fun res ->
                  check
                    (match Relate.Result.cell res ~row:0 ~col:0 with
                    | Relate.Value.Int n -> n = 1L
                    | _ -> false)
                    "the committed write is visible"))))

let () =
  with_db (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.begin_transaction conn;
          ignore (Relate.query conn "CREATE (:Note {n: 1})" (fun _ -> ()));
          Relate.rollback conn;
          Relate.with_connection db (fun r ->
              Relate.query r "MATCH (n:Note) RETURN count(n) AS n" (fun res ->
                  check
                    (match Relate.Result.cell res ~row:0 ~col:0 with
                    | Relate.Value.Int n -> n = 0L
                    | _ -> false)
                    "a rolled-back write is not visible"))))

let () =
  with_db (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.begin_transaction conn;
          ignore (Relate.query conn "RETURN 1 AS n" (fun _ -> ()));
          check (Relate.commit conn = "") "a transaction that wrote nothing commits no bookmark";
          Relate.begin_transaction conn;
          (try
             ignore (Relate.set_namespace conn "system");
             check false "set_namespace inside a transaction fails"
           with Relate.Error.E _ -> ());
          Relate.rollback conn))

let () =
  with_db (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.begin_transaction conn;
          Relate.rollback conn;
          Relate.begin_transaction conn;
          Relate.commit conn |> ignore))

let () = print_endline "transaction ok"
