let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let with_conn f =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn -> f conn))

let () =
  with_conn (fun conn ->
      Relate.query conn
        "RETURN null AS a, true AS b, 9007199254740993 AS c, 1.5 AS d, 'a\\u0000b' AS e, [1, null] AS f, {k: 'v'} AS g"
        (fun res ->
           let cell col = Relate.Result.cell res ~row:0 ~col in
           (match cell 0 with Relate.Value.Null -> () | v -> check false ("a: " ^ Relate.Value.describe v));
           (match cell 1 with Relate.Value.Bool true -> () | v -> check false ("b: " ^ Relate.Value.describe v));
           (match cell 2 with Relate.Value.Int n -> check (n = 9007199254740993L) "c = 2^53+1" | v -> check false ("c: " ^ Relate.Value.describe v));
           (match cell 3 with Relate.Value.Float f -> check (f = 1.5) "d = 1.5" | v -> check false ("d: " ^ Relate.Value.describe v));
           (match cell 4 with
            | Relate.Value.String s -> check (String.length s = 3 && s.[0] = 'a' && s.[1] = '\000' && s.[2] = 'b') "e keeps the interior NUL"
            | v -> check false ("e: " ^ Relate.Value.describe v));
           (match cell 5 with
            | Relate.Value.List [ Relate.Value.Int 1L; Relate.Value.Null ] -> ()
            | v -> check false ("f: " ^ Relate.Value.describe v));
           (match cell 6 with
            | Relate.Value.Map [ ("k", Relate.Value.String "v") ] -> ()
            | v -> check false ("g: " ^ Relate.Value.describe v))))

let () =
  with_conn (fun conn ->
      ignore (Relate.query conn "CREATE (:Person {name: 'Ada'})-[:KNOWS {since: 2020}]->(:Person {name: 'Bob'})" (fun _ -> ()));
      Relate.query conn "MATCH p = (a:Person)-[r:KNOWS]->(b) RETURN a, r, b, p" (fun res ->
          check (Relate.Result.row_count res = 1) "one path";
          let cell col = Relate.Result.cell res ~row:0 ~col in
          (match cell 0 with
          | Relate.Value.Node n ->
            check (n.element_id <> "") "node element id";
            check (n.labels = [ "Person" ]) "node labels";
            check (n.properties = [ ("name", Relate.Value.String "Ada") ]) "node properties"
          | v -> check false ("a: " ^ Relate.Value.describe v));
          (match cell 1 with
          | Relate.Value.Relationship r ->
            check (r.typ = "KNOWS") "relationship type";
            check (r.start_element_id <> "" && r.end_element_id <> "") "endpoint element ids";
            check (r.properties = [ ("since", Relate.Value.Int 2020L) ]) "relationship properties"
          | v -> check false ("r: " ^ Relate.Value.describe v));
          (match cell 2 with
          | Relate.Value.Node n -> check (n.properties = [ ("name", Relate.Value.String "Bob") ]) "bob"
          | v -> check false ("b: " ^ Relate.Value.describe v));
          (match cell 3 with
          | Relate.Value.Path [ Relate.Value.Node _; Relate.Value.Relationship _; Relate.Value.Node _ ] -> ()
          | v -> check false ("p: " ^ Relate.Value.describe v))))

let () =
  with_conn (fun conn ->
      Relate.query conn
        "RETURN date('2020-06-01') AS d, localtime('12:30:00.5') AS lt, datetime('2020-06-01T10:00:00+02:00') AS dt, duration('P1Y2M') AS dur, point({x: 1.0, y: 2.0}) AS pt"
        (fun res ->
           let cell col = Relate.Result.cell res ~row:0 ~col in
           (match cell 0 with
           | Relate.Value.Date { year = 2020; month = 6; day = 1 } -> ()
           | v -> check false ("d: " ^ Relate.Value.describe v));
           (match cell 1 with
           | Relate.Value.Local_time { hour = 12; minute = 30; second = 0; nanosecond = 500000000 } -> ()
           | v -> check false ("lt: " ^ Relate.Value.describe v));
           (match cell 2 with
           | Relate.Value.Datetime { year = 2020; month = 6; day = 1; hour = 10; minute = 0; second = 0; nanosecond = 0; offset_seconds = 7200; zone = "" } -> ()
           | v -> check false ("dt: " ^ Relate.Value.describe v));
           (match cell 3 with
           | Relate.Value.Duration { months = 14L; days = 0L; seconds = 0L; nanos = 0L } -> ()
           | v -> check false ("dur: " ^ Relate.Value.describe v));
           (match cell 4 with
           | Relate.Value.Point p ->
             check (p.dimension = 2) "point dimension";
             check (p.x = 1.0 && p.y = 2.0) "point coordinates";
             check (p.z = None) "2d point has no z"
           | v -> check false ("pt: " ^ Relate.Value.describe v))))

let () =
  with_conn (fun conn ->
      Relate.query conn "RETURN vector([1, 2, 3], 3, INTEGER) AS iv, vector([0.5, 1.5], 2, FLOAT32) AS fv" (fun res ->
          let cell col = Relate.Result.cell res ~row:0 ~col in
          (match cell 0 with
          | Relate.Value.Vector v ->
            check (v.dtype = "INTEGER") "integer dtype";
            check (v.ints = Some [| 1L; 2L; 3L |]) "integer coordinates"
          | v' -> check false ("iv: " ^ Relate.Value.describe v'));
          (match cell 1 with
          | Relate.Value.Vector v ->
            check (v.dtype = "FLOAT32") "float dtype";
            check (v.floats = Some [| 0.5; 1.5 |]) "float coordinates"
          | v' -> check false ("fv: " ^ Relate.Value.describe v'))))

let () =
  with_conn (fun conn ->
      Relate.query conn "RETURN 0.0/0.0 AS nan, 1.0/0.0 AS inf" (fun res ->
          let cell col = Relate.Result.cell res ~row:0 ~col in
          (match cell 0 with Relate.Value.Float f -> check (f <> f) "nan" | v -> check false ("nan: " ^ Relate.Value.describe v));
          (match cell 1 with Relate.Value.Float f -> check (f = infinity) "inf" | v -> check false ("inf: " ^ Relate.Value.describe v))))

let () = print_endline "values ok"
