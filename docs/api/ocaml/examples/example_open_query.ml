let () =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.query conn "RETURN 1 AS one" (fun res ->
              Relate.Result.iter_rows res ~f:(fun row ->
                  match row with
                  | [ Relate.Value.Int n ] -> Printf.printf "one: %Ld\n" n
                  | _ -> print_endline "unexpected row"))));
  print_endline "example_open_query ok"
