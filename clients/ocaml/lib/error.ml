type stage = Compile | Runtime | Internal

type t = {
  code : string;
  gql_status : string;
  stage : stage;
  retryable : bool;
  message : string;
}

exception E of t
exception Abi of string
exception Closed
exception Nul of string

let stage_vocabulary = [ (Compile, "compile"); (Runtime, "runtime"); (Internal, "internal") ]

let stage_of_raw raw =
  match List.assoc_opt raw (List.map (fun (v, s) -> (s, v)) stage_vocabulary) with
  | Some v -> v
  | None -> raise (Abi (Printf.sprintf "error stage %s" (Wire.quoted raw)))

let error_keys = [ "code"; "gql_status"; "stage"; "retryable"; "message" ]

let field what = function
  | `String s -> s
  | other ->
    raise
      (Abi
         (Printf.sprintf "error shape: %s is not a string: %s" what
            (Wire.quoted (Yojson.Safe.to_string other))))

let decode raw =
  let json = try Yojson.Safe.from_string raw with _ -> raise (Abi (Printf.sprintf "decoding error shape: %s" (Wire.safe raw))) in
  match json with
  | `Null -> raise (Abi (Printf.sprintf "error shape is JSON null, expected an object: %s" (Wire.safe raw)))
  | `Assoc kvs ->
    let value_of key =
      match List.assoc_opt key kvs with
      | None | Some `Null -> raise (Abi (Printf.sprintf "error shape is missing %S" key))
      | Some v -> v
    in
    let missing =
      List.find_opt (fun k -> not (List.mem_assoc k kvs)) error_keys
    in
    (match missing with
    | Some k -> raise (Abi (Printf.sprintf "error shape is missing %S" k))
    | None -> ());
    let retryable =
      match value_of "retryable" with
      | `Bool b -> b
      | other ->
        raise (Abi (Printf.sprintf "error shape: retryable is not a bool: %s" (Wire.quoted (Yojson.Safe.to_string other))))
    in
    {
      code = field "code" (value_of "code");
      gql_status = field "gql_status" (value_of "gql_status");
      stage = stage_of_raw (field "stage" (value_of "stage"));
      retryable;
      message = field "message" (value_of "message");
    }
  | other ->
    raise (Abi (Printf.sprintf "error shape is not a JSON object: %s" (Wire.safe (Yojson.Safe.to_string other))))
