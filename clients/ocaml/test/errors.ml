let check cond msg = if not cond then (Printf.eprintf "FAIL: %s\n" msg; exit 1)

let with_conn f =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn -> f conn))

let () =
  with_conn (fun conn ->
      try
        Relate.query conn "RETURN 1/0 AS x" (fun _ -> ());
        check false "division by zero raises"
      with Relate.Error.E e ->
        check (e.Relate.Error.stage = Relate.Error.Runtime) "1/0 is a runtime failure";
        check (e.Relate.Error.message <> "") "engine message present";
        check (e.Relate.Error.code <> "") "status code present";
        check (not e.Relate.Error.retryable) "1/0 is not retryable";
        check (String.length e.Relate.Error.gql_status = 5) "gql status is the five-character code")

let () =
  with_conn (fun conn ->
      try
        Relate.query conn "RETURN (" (fun _ -> ());
        check false "a parse failure raises"
      with Relate.Error.E e ->
        check (e.Relate.Error.stage = Relate.Error.Compile) "a parse failure is a compile failure")

let raw_shape =
  {|{"code":"Neo.ClientError.Statement.SyntaxError","gql_status":"22001","stage":"runtime",|}
  ^ {|"retryable":false,"message":"boom"}|}

let () =
  let e = Relate.Error.decode raw_shape in
  check (e.Relate.Error.code = "Neo.ClientError.Statement.SyntaxError") "code decodes";
  check (e.Relate.Error.gql_status = "22001") "gql status decodes";
  check (e.Relate.Error.stage = Relate.Error.Runtime) "stage decodes";
  check (not e.Relate.Error.retryable) "retryable decodes";
  check (e.Relate.Error.message = "boom") "message decodes"

let expect_abi f =
  try
    ignore (f ());
    false
  with Relate.Error.Abi _ -> true

let () =
  check
    (expect_abi (fun () -> ignore (Relate.Error.decode {|{"code":"x","gql_status":"y","stage":"runtime","retryable":false}|})))
    "a missing message key is a violation";
  check
    (expect_abi (fun () -> ignore (Relate.Error.decode {|{"code":"x","gql_status":"y","stage":"sideways","retryable":false,"message":"m"}|})))
    "an unknown stage is a violation";
  check
    (expect_abi (fun () -> ignore (Relate.Error.decode {|{"code":"x","gql_status":"y","stage":"runtime","retryable":null,"message":"m"}|})))
    "a null retryable is a violation"

let () =
  let long = String.make 500 'x' in
  let quoted = Relate.Wire.quoted long in
  check (String.length quoted <= 2 + 64 + String.length "...(truncated)") "quoted is bounded to the value budget";
  check (String.contains quoted '"') "quoted wraps in quotes";
  let control = Relate.Wire.quoted "a\nb\tc\rd" in
  check (not (String.contains control '\n')) "newlines are escaped";
  check (not (String.contains control '\t')) "tabs are escaped";
  check (not (String.contains control '\r')) "carriage returns are escaped";
  let payload = String.make 900 'y' in
  check (String.length (Relate.Wire.safe payload) <= 256 + String.length "...(truncated)") "safe is bounded to the payload budget"

let expect_nul f =
  try
    ignore (f ());
    false
  with Relate.Error.Nul _ -> true

let () =
  with_conn (fun conn ->
      check
        (expect_nul (fun () -> Relate.query conn "RETURN 1 AS \000n" (fun _ -> ())))
        "an interior NUL in the statement is refused before the call";
      check
        (expect_nul (fun () -> ignore (Relate.open_database ":memo\000ry:")))
        "an interior NUL in the uri is refused";
      ignore conn;
      let db = Relate.open_database ":memory:" in
      check
        (expect_nul (fun () -> ignore (Relate.connect ~namespace:"sys\000tem" db)))
        "an interior NUL in the namespace is refused";
      Relate.close_database db)

let () = print_endline "errors ok"
