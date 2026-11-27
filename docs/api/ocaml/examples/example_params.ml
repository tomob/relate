let () =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.query_values ~params:[ ("name", Relate.Params.String "Ada") ]
            conn "CREATE (p:Person {name: $name}) RETURN p" (fun res ->
              Printf.printf "created %Ld node(s)\n"
                (Relate.Result.stats res).Relate.Result.nodes_created);
          Relate.query_values
            ~params:[ ("who", Relate.Params.String "Ada") ]
            conn "MATCH (p:Person {name: $who}) RETURN p.name AS name, size(keys(p)) AS keys"
            (fun res ->
              Relate.Result.iter_rows res ~f:(fun row ->
                  match row with
                  | [ Relate.Value.String name; Relate.Value.Int keys ] ->
                    Printf.printf "%s carries %Ld key(s)\n" name keys
                  | _ -> print_endline "unexpected row"))));
  print_endline "example_params ok"
