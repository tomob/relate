module Description = Relate_abi_types.Abi.Description

let () =
  match Sys.argv with
  | [| _; "c" |] ->
    Format.printf "#include \"relate.h\"@\n";
    Cstubs.write_c Format.std_formatter ~prefix:"relate_cstubs" (module Description)
  | [| _; "ml" |] ->
    Cstubs.write_ml Format.std_formatter ~prefix:"relate_cstubs" (module Description)
  | _ -> exit 2
