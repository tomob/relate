# OCaml client: Relate

## Install

Source integration under `clients/ocaml`; OCaml 5.0+ (developed on 5.4),
dune 3, ctypes. Build `cargo build -p relate-ffi`, then
`make install-ocaml` (deps into the active opam switch). The gate is
`make test-ocaml`; standalone use pins the directory with
`opam pin add relate clients/ocaml`. No registry publication is configured
yet.

## Minimal usage

```ocaml
Relate.with_database ":memory:" (fun db ->
    Relate.with_connection db (fun conn ->
        Relate.query_values ~params:[ ("x", Relate.Params.Int 41L) ]
          conn "RETURN $x + 1 AS n" (fun res ->
            Relate.Result.iter_rows res ~f:(function
              | [ Relate.Value.Int n ] -> Printf.printf "%Ld\n" n
              | _ -> ()))))
```

## Gotchas

- Build the native library from the same checkout. Override its directory
  with `RELATE_FFI_LIB_DIR` (default `target/debug`, searched first) and the
  link with `RELATE_FFI_LINK` (`-l:librelate_ffi.a` for static). C ABI major
  2 is checked at open.
- Prefer the `with_*` scopes (finalizers are a safety net). Uncommitted
  transactions roll back. A connection serializes calls; use one per domain.
- Results stream inside `Relate.query`'s consumer; read cells there or
  materialize explicitly with `Result.rows`. `bookmark` is `""` for a read
  or inside a transaction.
- Bind values as parameters. Interior NUL is rejected in C-string inputs
  (statement text, names, zones) but preserved in string values.
- Every failure is an exception: `Relate.Error.E` (engine shape with `stage`
  and `retryable`), `Abi`, `Closed`, `Nul`.

## Spec

`docs/api/ocaml/spec.md`; runnable examples in `docs/api/ocaml/examples`.
