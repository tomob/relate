# OCaml client API specification

The OCaml client binds the typed C ABI v2 (ADR-0502) exclusively: one
description module (`clients/ocaml/lib/bindings/abi/abi.ml`) drives ctypes
stub generation at build time, and every value crosses through the documented
ABI. The client carries a byte-equal copy of `relate.h` guarded by a test.

## Handles and lifecycle

```ocaml
Relate.open_database : string -> database
Relate.open_database_read_only : string -> database
Relate.close_database : database -> unit
Relate.with_database : ?read_only:bool -> string -> (database -> 'a) -> 'a
Relate.connect : ?namespace:string -> database -> connection
Relate.disconnect : connection -> unit
Relate.with_connection : ?namespace:string -> database -> (connection -> 'a) -> 'a
Relate.checkpoint : database -> unit
Relate.set_namespace : connection -> string -> unit
```

- `open_database` creates a missing store; `open_database_read_only` loads an
  existing one and refuses writes and checkpoints (a missing store is an
  error). `:memory:` is the in-memory store.
- Close and disconnect are idempotent. A handle used after close raises
  `Relate.Error.Closed` on the client side — the call never reaches the
  engine. A dropped handle is closed by a finalizer; explicit scope
  functions (`with_*`) are the contract, the finalizer is a safety net.
- Calls on one connection are serialized (the C contract allows one call at a
  time per connection); a database serializes its calls conservatively.
  Native calls are synchronous.

## Errors

Every failure is an exception:

- `Relate.Error.E of Relate.Error.t` — the engine's classified failure:
  `code` (Neo4j status code), `gql_status` (five characters), `stage`
  (`Compile` | `Runtime` | `Internal`), `retryable`, `message`. Raised from
  a call's error out-param or a result's error channel. The decoder is
  strict: all five keys required, `retryable` must be a bool, an unknown
  stage is an ABI violation naming the offending value (sanitized, bounded —
  see Wire bounds below).
- `Relate.Error.Abi of string` — a broken ABI contract (a malformed error
  shape, a walker refusal, a missing payload). Never silent.
- `Relate.Error.Closed` — a handle used after close.
- `Relate.Error.Nul of string` — an input that would silently truncate at
  the C boundary (see the NUL policy).

## The NUL policy

The ABI takes some strings NUL-terminated without a length — the statement
text, URIs, namespace names, parameter names, map-key lookups, time zones,
vector dtypes — and others length-delimited: parameter string values, result
strings, map keys. The first group refuses an interior NUL with
`Relate.Error.Nul` (silent truncation is the hazard); the second preserves
it — `Params.String "a\000b"` and its result roundtrip whole.

OCaml strings are unvalidated bytes: the client passes them through and the
engine's UTF-8 validation applies, exactly as for the other clients.

## Statements and parameters

```ocaml
Relate.query : ?params:Params.t -> connection -> string ->
  (Result.t -> 'a) -> 'a
Relate.query_values : ?params:(string * Params.value) list -> connection ->
  string -> (Result.t -> 'a) -> 'a
```

`query` hands the live result to its consumer and destroys it on every path
(exceptions included) — rows stream out of the native result, so the consumer
must finish before the handle dies. A statement failure raises `Error.E`
inside `query`, with the handle destroyed on the way out.

`Params.t` is the typed builder (one putter per ABI putter, plus `put_list` /
`put_map` child builders owned by the root, freed by the scope or finalizer).
`Params.value` is the convenience tree:

```ocaml
type value =
  | Null | Bool of bool | Int of int64 | Float of float | String of string
  | List of value list | Map of (string * value) list
  | Date of { year : int; month : int; day : int }
  | Time of { hour; minute; second; nanosecond; offset_seconds : int }
  | Zoned_time of { hour; minute; second; nanosecond : int; zone : string }
  | Local_time of { hour; minute; second; nanosecond : int }
  | Datetime of { year; month; day; hour; minute; second; nanosecond; offset_seconds : int }
  | Zoned_datetime of { year; month; day; hour; minute; second; nanosecond : int; zone : string }
  | Local_datetime of { year; month; day; hour; minute; second; nanosecond : int }
  | Duration of { months : int64; days : int64; seconds : int64; nanos : int64 }
  | Point of { srid : int; x : float; y : float; z : float option }
  | Vector_float of { dtype : string; values : float array }
  | Vector_int of { dtype : string; values : int64 array }
```

## Transactions

```ocaml
Relate.begin_transaction : connection -> unit
Relate.commit : connection -> string        (* bookmark, "" when nothing committed *)
Relate.rollback : connection -> unit
```

`commit` returns the transaction's bookmark (`"relate:<n>"`), or `""` when
the transaction committed nothing. `set_namespace` fails inside an open
transaction.

## Results

```ocaml
Relate.Result.row_count : Result.t -> int
Relate.Result.columns : Result.t -> string list
Relate.Result.cell : Result.t -> row:int -> col:int -> Value.value
Relate.Result.row : Result.t -> int -> Value.value list
Relate.Result.rows : Result.t -> Value.value list list   (* explicit materialization *)
Relate.Result.iter_rows : Result.t -> f:(Value.value list -> unit) -> unit
```

Metadata (decoded eagerly, strictly):

- `query_type` — `Read | Write | Read_write | Schema` (the C ABI's closed
  vocabulary; an unknown value is an ABI violation)
- `namespace` — `Neo4j | System | System_ontologies` (the resolved session
  namespace)
- `bookmark` — the auto-commit bookmark, `""` for a read or inside an
  explicit transaction
- `stats` — the canonical eleven counters, zeros included; a missing or null
  counter is an ABI violation, unknown keys are ignored
- `notifications` — the engine-native array; `severity` and `category` are
  closed vocabularies, both strictly typed
- `plan` — `None` on a plain run; a payload that is not a `relate.plan/v1`
  document with a root operator is an ABI violation
- timings: `elapsed_ms`, `parse_ms`, `plan_ms`, `execute_ms`

## Values

One constructor per engine kind:

```ocaml
type value =
  | Null | Bool of bool | Int of int64 | Float of float | String of string
  | Node of node | Relationship of relationship | Path of value list
  | List of value list | Map of (string * value) list | Point of point
  | Date of {...} | Time of {...} | Local_time of {...}
  | Datetime of {...} | Local_datetime of {...}
  | Duration of { months : int64; days : int64; seconds : int64; nanos : int64 }
  | Vector of vector
```

- `Node`: `element_id`, `id` (int64, the deprecated numeric id), `labels`
  (engine order), `properties` (engine order). `element_id` is `""` in the
  `system` namespace, which has no element ids.
- `Relationship`: `element_id`, `start_element_id`, `end_element_id`, `id`,
  `start_id`, `end_id`, `typ`, `properties`.
- `Point`: `srid`, `dimension`, `x`, `y`, `z : float option` (only set for
  dimension 3).
- `Vector`: `dtype` (the engine's canonical spelling) with `ints` or
  `floats`, the other `None`.
- A walker refusal (an accessor failing on a switched kind) is
  `Error.Abi`, never a zero value.

## Wire bounds

Error text that echoes untrusted native payloads is sanitized through
`Relate.Wire` with the same two bounds the Go, Java and Swift clients use:
64 characters for a quoted value, 256 for a whole payload, non-printables
escaped as `\uXXXX`, invalid UTF-8 bytes as `\u00XX`, a truncation marker
when cut — a hostile native library cannot inject log lines through an
error message (CWE-117).

## Platform support

The five triples the release pipeline builds: linux x64/arm64, macOS
x64/arm64, windows x64. The seam is `RELATE_FFI_LIB_DIR` (a directory
holding the native) plus `RELATE_FFI_LINK` (default `-lrelate_ffi`,
`-l:librelate_ffi.a` for a static link); see the client README.
