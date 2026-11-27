let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let with_conn f =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn -> f conn))

module R = Relate.Result

open R

let () =
  with_conn (fun conn ->
      Relate.query conn "CREATE (:Note {n: 0})" (fun res ->
          check (query_type res = Write) "create is a write";
          check (bookmark res <> "") "an auto-commit write carries a bookmark";
          let st = stats res in
          check (st.nodes_created = 1L) "one node created";
          check (row_count res = 0) "no rows"))

let () =
  with_conn (fun conn ->
      Relate.query conn "MATCH (n) RETURN n" (fun res ->
          check (query_type res = Read) "match is a read";
          check (bookmark res = "") "a read commits nothing";
          let st = stats res in
          check (st.nodes_created = 0L) "read stats zeros included";
          check (st.constraints_removed = 0L) "read stats zeros included (last)";
          check (notifications res = []) "a plain run has no notifications";
          check (plan res = None) "a plain run has no plan";
          check (namespace res = Neo4j) "default namespace";
          check (elapsed_ms res >= 0.0) "elapsed timing present";
          check (columns res = [ "n" ]) "columns"))

let () =
  with_conn (fun conn ->
      ignore (Relate.query conn "CREATE (:Person {name: 'A'})" (fun _ -> ()));
      Relate.query conn "CREATE (a:Person {name: 'A'})-[:KNOWS]->(b:Person {name: 'B'}) RETURN a" (fun res ->
          check (query_type res = Read_write) "write with columns is rw";
          check (row_count res = 1) "one row";
          let st = stats res in
          check (st.relationships_created = 1L) "one relationship created"))

let () =
  with_conn (fun conn ->
      Relate.query conn "EXPLAIN MATCH (a:Person), (b:City) RETURN a, b" (fun res ->
          check (plan res <> None) "explain carries a plan";
          (match plan res with
          | Some p ->
            check (p.schema = "relate.plan/v1") "plan schema";
            check (p.root.operator <> "") "plan root operator";
            check (not p.profiled) "explain is not profiled"
          | None -> check false "plan");
          let ns = notifications res in
          check (ns <> []) "explain carries notifications";
          (match ns with
          | n :: _ -> check (n.Relate.Notification.code <> "") "notification code"
          | [] -> check false "notifications");
          Relate.query conn "PROFILE MATCH (p:Person) RETURN p" (fun res2 ->
              match plan res2 with
              | Some p -> check p.profiled "profiled plan"
              | None -> check false "profiled plan")))

let () =
  with_conn (fun conn ->
      Relate.query conn "USE system SHOW DATABASES" (fun res ->
          check (namespace res = System) "system namespace resolves"))

let () =
  with_conn (fun conn ->
      Relate.Params.with_params (fun builder ->
          Relate.Params.bind_map builder
            [ ("xs", Relate.Params.List (List.init 5 (fun i -> Relate.Params.Int (Int64.of_int i)))) ];
          Relate.query ~params:builder conn "UNWIND $xs AS x RETURN x" (fun res ->
              check (row_count res = 5) "unwind streams five rows";
              let seen = ref 0 in
              iter_rows res ~f:(fun row ->
                  incr seen;
                  match row with
                  | [ Relate.Value.Int x ] -> check (Int64.to_int x = !seen - 1) "row order"
                  | _ -> check false "one column");
              check (!seen = 5) "iter walked every row")))

let () = print_endline "result_meta ok"
