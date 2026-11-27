#!/usr/bin/env bash
# Compiles and runs every documented example under docs/api/ocaml/examples
# against the client built in this checkout, the Go client's
# check-go-examples.sh shape: the examples are tests, and this script is the
# one lane that executes them. Installing the client into the active opam
# switch is the dev workflow (see clients/ocaml/README.md); the examples
# resolve it as a normal installed package.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
client="$repo_root/clients/ocaml"
examples="$repo_root/docs/api/ocaml/examples"

if [ -z "${RELATE_FFI_LIB_DIR:-}" ]; then
  RELATE_FFI_LIB_DIR="$repo_root/target/debug"
fi
export RELATE_FFI_LIB_DIR

case "$(uname -s)" in
  Darwin) native="$RELATE_FFI_LIB_DIR/librelate_ffi.dylib" ;;
  MINGW* | MSYS* | CYGWIN*) native="$RELATE_FFI_LIB_DIR/relate_ffi.dll" ;;
  *) native="$RELATE_FFI_LIB_DIR/librelate_ffi.so" ;;
esac
if [ ! -f "$native" ]; then
  echo "error: no native library at $native" >&2
  echo "       build it first: cargo build -p relate-ffi" >&2
  echo "       or set RELATE_FFI_LIB_DIR to a directory holding it" >&2
  exit 1
fi
export LD_LIBRARY_PATH="$RELATE_FFI_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="$RELATE_FFI_LIB_DIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

cd "$client"
opam install --yes .

cd "$examples"
dune build @all

status=0
for example in example_*.ml; do
  [ -f "$example" ] || continue
  name="${example%.ml}"
  echo "running $name"
  if ! dune exec "./$name.exe"; then
    echo "FAIL: $name" >&2
    status=1
  fi
done
exit $status
