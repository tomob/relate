type severity = Information | Warning

type category = Performance | Unrecognized | Deprecation | Schema | Hint

type t = {
  code : string;
  gql_status : string;
  severity : severity;
  category : category;
  title : string;
  description : string;
  remedy : string;
  operator_id : int64 option;
}

let severity_vocabulary = [ (Information, "INFORMATION"); (Warning, "WARNING") ]

let category_vocabulary =
  [
    (Performance, "PERFORMANCE");
    (Unrecognized, "UNRECOGNIZED");
    (Deprecation, "DEPRECATION");
    (Schema, "SCHEMA");
    (Hint, "HINT");
  ]

let decode_closed what vocabulary raw =
  match List.assoc_opt raw (List.map (fun (v, s) -> (s, v)) vocabulary) with
  | Some v -> v
  | None ->
    raise (Error.Abi (Printf.sprintf "notification entry carries an unknown %s %s" what (Wire.quoted raw)))

let string_field key = function
  | `String s -> s
  | other ->
    raise
      (Error.Abi
         (Printf.sprintf "notification entry: %s is not a string: %s" key
            (Wire.quoted (Yojson.Safe.to_string other))))

let required key kvs =
  match List.assoc_opt key kvs with
  | None | Some `Null ->
    raise (Error.Abi (Printf.sprintf "notification entry is missing %S" key))
  | Some v -> v

let optional_string kvs key = match List.assoc_opt key kvs with Some (`String s) -> s | _ -> ""

let decode_entry (json : Yojson.Safe.t) =
  match json with
  | `Assoc kvs ->
    let severity =
      match required "severity" kvs with
      | `String s -> decode_closed "severity" severity_vocabulary s
      | other ->
        raise
          (Error.Abi
             (Printf.sprintf "notification entry: severity is not a string: %s"
                (Wire.quoted (Yojson.Safe.to_string other))))
    in
    let category =
      match required "category" kvs with
      | `String s -> decode_closed "category" category_vocabulary s
      | other ->
        raise
          (Error.Abi
             (Printf.sprintf "notification entry: category is not a string: %s"
                (Wire.quoted (Yojson.Safe.to_string other))))
    in
    let operator_id =
      match List.assoc_opt "operator_id" kvs with
      | Some (`Int n) -> Some (Int64.of_int n)
      | _ -> None
    in
    {
      code = string_field "code" (required "code" kvs);
      gql_status = string_field "gql_status" (required "gql_status" kvs);
      severity;
      category;
      title = optional_string kvs "title";
      description = optional_string kvs "description";
      remedy = optional_string kvs "remedy";
      operator_id;
    }
  | other ->
    raise
      (Error.Abi
         (Printf.sprintf "notification entry is not a JSON object: %s"
            (Wire.safe (Yojson.Safe.to_string other))))

(* decode reads the engine-native notification array: the payload is always
   a JSON array on a good result, so a null or non-array payload is an ABI
   contract violation, never an empty list in its place. *)
let decode (raw : string) =
  let json = try Yojson.Safe.from_string raw with _ -> raise (Error.Abi (Printf.sprintf "decoding notifications: %s" (Wire.safe raw))) in
  match json with
  | `List entries -> List.map decode_entry entries
  | _ ->
    raise
      (Error.Abi
         (Printf.sprintf "notifications is not a JSON array: %s" (Wire.safe raw)))
