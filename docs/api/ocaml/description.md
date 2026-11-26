# OCaml client

An embedded, in-process client for OCaml applications: open a database
straight from the process, run Cypher with statically-typed parameters, and
walk statically-typed results — entities, temporals, points and vectors
included — with the full result metadata (query type, resolved namespace,
counters, notifications, plans, timings, bookmarks).

The client binds the documented typed C ABI v2 exclusively through
`ctypes.stubs` (ADR-0699): the stubs are generated from one ABI description
at build time, nothing generated is committed, and the library links the
same native `librelate_ffi` every other client wraps. It is the surface of
choice when the graph engine should live inside an OCaml program —
compilers, static analyzers, tooling — with the same engine, semantics and
error classification as every other embedding.

Results stream row by row out of the native result (memory proportional to
what the consumer holds, not to the whole answer), and one connection drives
one statement at a time, matching the C ABI's threading contract.
