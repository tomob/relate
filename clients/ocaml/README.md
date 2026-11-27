# Relate OCaml client

Thin OCaml bindings for the Relate engine over the documented typed C ABI v2
(ADR-0699). Open a database, connect a session, run Cypher with typed
parameters, and stream typed results with full metadata — query type,
resolved namespace, counters, notifications, plans, timings and bookmarks.

## Prerequisites

- OCaml 5.0.0 or later (the client is developed and CI-tested on 5.4), dune 3,
  opam; `opam install ctypes yojson` covers the dependencies
- The native library `librelate_ffi` — see the next section

## Build the native library

The client links the C ABI the engine ships; build it from this checkout
first (a debug build is what the client resolves by default):

```sh
cargo build -p relate-ffi        # produces target/debug/librelate_ffi.so
```

## Run the tests

```sh
cd clients/ocaml
export LD_LIBRARY_PATH=$PWD/../../target/debug   # macOS: DYLD_LIBRARY_PATH
dune test
```

The header guard additionally compares `include/relate.h` byte-equal against
the FFI crate's copy when `RELATE_UPSTREAM_HEADER` points at
`surfaces/relate-ffi/include/relate.h` (the test lanes set it); without the
variable the test skips with one printed line, so a package-mode run never
passes silently.

The documented examples under `docs/api/ocaml/examples` are tests too:

```sh
bash scripts/check-ocaml-examples.sh
```

The script installs the client into the active opam switch
(`opam install .`), builds every example against the installed package, and
runs each one — the same build path the published opam package uses.

## How the build finds the native

One seam, three sources, resolved in this order:

1. `RELATE_FFI_LIB_DIR` — a directory holding `librelate_ffi.so` (a staged
   release archive, or a package's `native/<platform>` directory)
2. The workspace default `<repo>/target/debug` (absolute, resolved by dune)
3. Never a download: a missing library fails the link with
   `cannot find -lrelate_ffi` — build it (see above) or point the variable

`RELATE_FFI_LINK` overrides the link name (default `-lrelate_ffi`; on
Windows flexlink treats `-l` as a literal file path — pass the full path
to the MSVC import library instead). The opam package bakes a loader
runpath into executables on Linux and macOS through `OCAMLPARAM` (the
`relate-ffi` package installs the native to `lib/relate/native`), so
consumers run with no environment at all. Without it, executables load
the shared library at runtime through `LD_LIBRARY_PATH` (macOS:
`DYLD_LIBRARY_PATH`; Windows: `PATH` or the exe's directory).

## Use the client from a standalone OCaml project

```sh
opam pin add relate <this-directory>   # or the published package
export RELATE_FFI_LIB_DIR=/opt/relate-ffi   # wherever you staged the native
ocamlfind ocamlopt -package relate -linkpkg main.ml -o main
```

```ocaml
let () =
  Relate.with_database ":memory:" (fun db ->
      Relate.with_connection db (fun conn ->
          Relate.query conn "RETURN 1 AS one" (fun res ->
              Relate.Result.iter_rows res ~f:(fun row ->
                  match row with
                  | [ Relate.Value.Int n ] -> Printf.printf "%Ld\n" n
                  | _ -> ()))))
```

## Per-OS natives

The release attaches `relate-ffi-<triple>.tar.gz` for linux x64/arm64, macOS
x64/arm64 and windows x64; unpack one and point `RELATE_FFI_LIB_DIR` at it.
These five platforms are the supported set — others may work with a
self-built native but are unsupported. On Windows, flexdll links the DLL
directly; no mingw import-library step is needed.

## Gotchas

- **A stale `target/debug` shadows everything**: the seam resolves the debug
  directory; rebuild it (`cargo build -p relate-ffi`) after pulling, or an
  ABI-v1 library fails at open with a version error.
- **An interior NUL in an input is refused**: the ABI takes the statement
  text, URIs, namespace, parameter names, time zones and vector dtypes
  NUL-terminated, so the client raises `Relate.Error.Nul` instead of
  silently truncating. Parameter *values* cross length-delimited —
  `Params.String "a\000b"` roundtrips whole.
- **Calls on one connection are serialized**: the C ABI allows one call at a
  time per connection; the client enforces it with a mutex, so sharing a
  connection across domains is safe but gains no parallelism — use one
  connection per domain.
- **Results stream**: `Relate.query` hands the live result to its consumer
  and destroys it on every path; read cells and rows inside the consumer,
  materialize explicitly with `Result.rows` when the whole answer must be
  held.
- **opam publication and the lockstep version surface are separate work**
  (ADR-0699): this directory carries no release version yet.
