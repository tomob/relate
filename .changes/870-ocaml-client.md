### Added

- New OCaml client `relate` under `clients/ocaml` (ADR-0699): an embedded
  OCaml 5 API over the typed C ABI v2, with scoped databases, connections
  and transactions, typed parameters, graph, temporal and vector values,
  streaming results with full metadata, and the classified error shape.
  CI builds the native library from the same checkout and runs the
  client's tests and documented examples on Linux, macOS and Windows.

### Notes

- The OCaml client's opam publication ships as two lockstep packages (ADR-0699, amended): `relate-ffi` installs the release's platform native into the switch and `relate` builds against it with a baked runpath — a sandbox rehearsal proved the single-package variant cannot work. `scripts/opam-publish-prep.sh` generates both from a release, with a local rehearsal mode.
