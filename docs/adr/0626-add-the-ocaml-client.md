# 0626. Add an OCaml client over the typed C ABI

Status: Proposed
Claim: cf1e53ab241a55f9fe149c54d621b03af04215c6

## Context

OCaml applications need an embedded client with the same engine, typed
values, errors and transaction semantics as the existing language
clients. The typed C ABI v2 (ADR-0502) is the documented surface every
client wraps; the Go client is the thin reference. The repository builds
the native `librelate_ffi` for five platform triples and attaches the
archives to every release.

## Decision

Add a first-party OCaml client under `clients/ocaml`, binding the
documented C ABI v2 exclusively through `ctypes.stubs`: one OCaml module
describes the ABI, dune generates the C stubs at build time, nothing
generated is committed. Target OCaml 5.0.0 and later (no 4.x); develop
and run CI on 5.4 with dune 3.

Local builds link the native library from the workspace build output
(`target/debug` first, then `target/release`) or an explicit path via
environment knobs; a missing library fails the build with an authored
message naming `cargo build -p relate-ffi`. No build downloads a
release. CI builds the native from the same commit and runs the client's
tests, documented examples and an install rehearsal on Linux, macOS and
Windows.

The client carries its own copy of the C header, kept byte-equal by a
test: the opam package ships the client directory alone, so the header
travels with it.

String policy follows the ABI's own split. Inputs the ABI takes
NUL-terminated without a length — Cypher text, URIs, namespace and
parameter names, time zones, vector dtypes — reject embedded NUL with a
typed error instead of silently truncating; length-delimited strings —
parameter values, result strings, map keys — preserve it.

Supported platforms are the five triples the release pipeline builds:
Linux and macOS on x64 and arm64, Windows on x64. Windows links through
flexdll, which reads the DLL export table directly; the import-library
workaround the Go client needs for mingw ld stays a fallback, not the
plan. Results stream row by row like the Go client; resolved namespace,
query type, counters, notifications, plans, timings and bookmarks are
preserved. Connection operations, including transaction validation, are
serialized; native calls are synchronous.

## Alternatives considered

- Bind through `ctypes-foreign` (dlopen at runtime): rejected — runtime
  discovery of the native library where build-time linking resolves the
  symbols up front.
- Reference the header from the FFI crate instead of copying it:
  rejected — the opam package source is the client directory alone.
- Generate a mingw import library on Windows up front: rejected —
  flexdll links against the DLL itself; the workaround is the fallback
  if CI proves otherwise.
- Vendor the five natives inside the opam archive: rejected — a large
  binary archive is atypical for the opam repository.
- Ship a `conf-relate-ffi` package probing a system library: rejected —
  presence without versioning, and nothing distributes the native as a
  system package.
- Split into two opam packages with a version pin: rejected for the
  first release — one package with extra-sources is the smaller start;
  the split stays an evolution path.

## Consequences

The repository gains an OCaml surface, documentation and native
compatibility coverage on the five platforms. The native library is
required at build and runtime; the client README documents the three
sources (workspace build, explicit path, package extra-sources). opam
publication and the version surface in the release bump are separate
work; the package will pin the release's FFI archives as extra-sources —
prebuilt binaries fetched at install time, which the opam repository may
question, with the conf-package as the fallback. Other platforms may
work with a self-built native but are unsupported.
