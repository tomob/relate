let rec show_value indent = function
  | Relate.Value.Null -> Printf.printf "%snull\n" indent
  | Relate.Value.Bool b -> Printf.printf "%s%s\n" indent (string_of_bool b)
  | Relate.Value.Int n -> Printf.printf "%s%Ld\n" indent n
  | Relate.Value.Float f -> Printf.printf "%s%g\n" indent f
  | Relate.Value.String s -> Printf.printf "%s\"%s\"\n" indent s
  | Relate.Value.Node n ->
    Printf.printf "%s(%s %s)\n" indent (String.concat ":" ("" :: n.Relate.Value.labels))
      n.Relate.Value.element_id
  | Relate.Value.Relationship r ->
    Printf.printf "%s[:%s %s]\n" indent r.Relate.Value.typ r.Relate.Value.element_id
  | Relate.Value.Path items ->
    List.iter (show_value (indent ^ "  ")) items
  | Relate.Value.List items ->
    Printf.printf "%s[\n" indent;
    List.iter (show_value (indent ^ "  ")) items;
    Printf.printf "%s]\n" indent
  | Relate.Value.Map entries ->
    Printf.printf "%s{\n" indent;
    List.iter
      (fun (k, v) ->
        Printf.printf "%s  %s: " indent k;
        show_value "" v)
      entries;
    Printf.printf "%s}\n" indent
  | Relate.Value.Point p -> Printf.printf "%s point sr %d\n" indent p.Relate.Value.srid
  | Relate.Value.Date d -> Printf.printf "%s%04d-%02d-%02d\n" indent d.year d.month d.day
  | Relate.Value.Vector v -> Printf.printf "%svector(%s)\n" indent v.Relate.Value.dtype
  | v -> Printf.printf "%s%s\n" indent (Relate.Value.describe v)

let () =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn ->
          ignore
            (Relate.query conn
               "CREATE (:Person {name: 'Ada'})-[:KNOWS {since: 2020}]->(:Person {name: 'Bob'})"
               (fun _ -> ()));
          Relate.query conn
            "MATCH p = (a:Person)-[r:KNOWS]->(b:Person) RETURN a, r, b, p, date('2026-02-14') AS when"
            (fun res ->
              Relate.Result.iter_rows res ~f:(fun row ->
                  List.iter (fun v -> show_value "" v) row))));
  print_endline "example_values ok"
