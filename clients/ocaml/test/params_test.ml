let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let with_conn f =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn -> f conn))

let expect_nul f =
  try
    ignore (f ());
    false
  with Relate.Error.Nul _ -> true

open Relate.Params

let () =
  with_conn (fun conn ->
      Relate.query_values ~params:[ ("n", Int 7L) ] conn "RETURN $n AS n" (fun res ->
          check
            (match Relate.Result.cell res ~row:0 ~col:0 with
            | Relate.Value.Int n -> n = 7L
            | _ -> false)
            "int param roundtrips"))

let () =
  with_conn (fun conn ->
      Relate.query_values
        ~params:[
          ("a", Null);
          ("b", Bool true);
          ("d", Float 1.5);
          ("s", String "a\000b");
          ("xs", List [ Int 1L; Null ]);
          ("m", Map [ ("k", String "v") ]);
        ]
        conn "RETURN $a AS a, $b AS b, $d AS d, $s AS s, $xs AS xs, $m AS m"
        (fun res ->
           let cell col = Relate.Result.cell res ~row:0 ~col in
           (match cell 3 with
            | Relate.Value.String s -> check (String.length s = 3 && s.[1] = '\000') "param string keeps its interior NUL"
            | _ -> check false "s");
           (match cell 4 with
            | Relate.Value.List [ Relate.Value.Int 1L; Relate.Value.Null ] -> ()
            | _ -> check false "xs");
           (match cell 5 with
            | Relate.Value.Map [ ("k", Relate.Value.String "v") ] -> ()
            | _ -> check false "m")))

let () =
  with_conn (fun conn ->
      Relate.query_values
        ~params:[
          ("d", Date { year = 2026; month = 2; day = 14 });
          ("t", Time { hour = 10; minute = 30; second = 0; nanosecond = 0; offset_seconds = 3600 });
          ("lt", Local_time { hour = 8; minute = 0; second = 0; nanosecond = 0 });
          ("dt", Datetime { year = 2026; month = 2; day = 14; hour = 10; minute = 0; second = 0; nanosecond = 0; offset_seconds = 0 });
          ("dur", Duration { months = 14L; days = 0L; seconds = 0L; nanos = 0L });
          ("pt", Point { srid = 7203; x = 1.0; y = 2.0; z = None });
          ("fv", Vector_float { dtype = "FLOAT32"; values = [| 0.5; 1.5 |] });
          ("iv", Vector_int { dtype = "INTEGER"; values = [| 1L; 2L; 3L |] });
        ]
        conn "RETURN $d AS d, $t AS t, $lt AS lt, $dt AS dt, $dur AS dur, $pt AS pt, $fv AS fv, $iv AS iv"
        (fun res ->
           let cell col = Relate.Result.cell res ~row:0 ~col in
           (match cell 0 with Relate.Value.Date { year = 2026; month = 2; day = 14 } -> () | v -> check false ("d: " ^ Relate.Value.describe v));
           (match cell 1 with Relate.Value.Time { hour = 10; minute = 30; offset_seconds = 3600; _ } -> () | v -> check false ("t: " ^ Relate.Value.describe v));
           (match cell 2 with Relate.Value.Local_time { hour = 8; _ } -> () | v -> check false ("lt: " ^ Relate.Value.describe v));
           (match cell 3 with Relate.Value.Datetime { year = 2026; hour = 10; _ } -> () | v -> check false ("dt: " ^ Relate.Value.describe v));
           (match cell 4 with Relate.Value.Duration { months = 14L; _ } -> () | v -> check false ("dur: " ^ Relate.Value.describe v));
           (match cell 5 with Relate.Value.Point p -> check (p.x = 1.0 && p.y = 2.0) "pt" | v -> check false ("pt: " ^ Relate.Value.describe v));
           (match cell 6 with Relate.Value.Vector v -> check (v.floats = Some [| 0.5; 1.5 |]) "fv" | v' -> check false ("fv: " ^ Relate.Value.describe v'));
           (match cell 7 with Relate.Value.Vector v -> check (v.ints = Some [| 1L; 2L; 3L |]) "iv" | v' -> check false ("iv: " ^ Relate.Value.describe v'))))

let () =
  with_conn (fun conn ->
      check
        (expect_nul (fun () ->
             Relate.Params.with_params (fun builder ->
                 bind_map builder [ ("na\000me", Int 1L) ];
                 Relate.query ~params:builder conn "RETURN 1" (fun _ -> ()))))
        "interior NUL in a parameter name is refused";
      check
        (expect_nul (fun () ->
             Relate.Params.with_params (fun builder ->
                 ignore
                   (put_time builder ~hour:1 ~minute:0 ~second:0 ~nanosecond:0
                      ~offset_seconds:0 ~zone:(Some "Eu\000rope/Stockholm"));
                 Relate.query ~params:builder conn "RETURN 1" (fun _ -> ()))))
        "interior NUL in a zone name is refused";
      Relate.Params.with_params (fun builder ->
          put_point builder ~name:"pt" ~srid:7203 ~x:0.0 ~y:0.0 None;
          Relate.query ~params:builder conn "RETURN 1 AS ok" (fun res ->
              check (Relate.Result.row_count res = 1) "put_point binds")))

let () =
  with_conn (fun conn ->
      Relate.query_values
        ~params:[ ("rows", List [
                    Map [ ("id", Int 1L); ("until", String "2027-01-01") ];
                    Map [ ("id", Int 2L); ("until", String "2027-06-01") ];
                  ]) ]
        conn "UNWIND $rows AS r CREATE (:Grant {id: r.id, until: date(r.until)})"
        (fun res ->
           check (Relate.Result.row_count res = 0) "create returns no rows");
      Relate.query conn "MATCH (g:Grant) RETURN g.id AS id ORDER BY id" (fun res ->
          check (Relate.Result.row_count res = 2) "two grants"))

let () = print_endline "params ok"
