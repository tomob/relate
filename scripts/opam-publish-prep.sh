#!/usr/bin/env bash
# Generates the opam packages for an OCaml client release: the client source
# tarball plus two package files (ADR-0699) — relate-ffi, which unpacks the
# release's platform FFI archive into the switch as %{lib}%/relate/native,
# and relate, which builds against it and pins relate-ffi to the same
# version. The split is forced: opam's build sandbox keeps the switch prefix
# read-only while dune freezes the C link flags into the installed META, so
# the native must already sit in the switch before the client builds.
#
# Two modes:
#   --tag vX.Y.Z  prepare the real packages from that release's assets
#                 (prints the upload and PR steps; publication stays manual)
#   --local       rehearsal: package the working tree, build the host FFI
#                 archive from target/<profile>, and generate file:// URLs so
#                 a local opam repository exercises the exact fetch →
#                 unpack → sandboxed build → install flow before any release
#                 exists. The four non-host archives are copies of the host
#                 one — placeholders, fetched and hash-checked, never
#                 unpacked.
#
# Every platform difference lives in one os/arch case per package; the seam
# (RELATE_FFI_LIB_DIR, RELATE_FFI_RPATH) carries single tokens only, so no
# multi-word environment splitting is ever needed.
set -euo pipefail

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  echo "usage: $0 (--tag vX.Y.Z | --local) [--profile debug|release] [--out DIR]"
  exit 2
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tag=""
local_mode=false
profile="release"
out="$repo_root/target/opam-prep"

while [ $# -gt 0 ]; do
  case "$1" in
    --tag) tag="${2:-}"; shift 2 ;;
    --local) local_mode=true; shift ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    -h | --help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done

if [ "$local_mode" = true ]; then
  [ -z "$tag" ] || { echo "--local and --tag are mutually exclusive" >&2; exit 2; }
  version="local"
else
  case "$tag" in
    v[0-9]*) version="${tag#v}" ;;
    *) echo "missing or malformed --tag vX.Y.Z" >&2; exit 2 ;;
  esac
fi
case "$profile" in
  debug | release) ;;
  *) echo "--profile must be debug or release" >&2; exit 2 ;;
esac

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# The release ffi job's five targets (release.yml), with the opam os/arch
# keys that select each and the library file the build must find after
# unpacking. --tag mode downloads by these exact names and fails loudly on
# any mismatch, so this table cannot drift from the release silently.
TRIPLES="
x86_64-unknown-linux-gnu|linux-x86_64|librelate_ffi.so
aarch64-unknown-linux-gnu|linux-arm64|librelate_ffi.so
x86_64-apple-darwin|macos-x86_64|librelate_ffi.dylib
aarch64-apple-darwin|macos-arm64|librelate_ffi.dylib
x86_64-pc-windows-msvc|win32-x86_64|relate_ffi.dll
"

host_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    MINGW* | MSYS* | CYGWIN*) echo win32 ;;
    *) echo "unsupported host $(uname -s)" >&2; return 2 ;;
  esac
}

host_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    arm64 | aarch64) echo arm64 ;;
    *) echo "unsupported host arch $(uname -m)" >&2; return 2 ;;
  esac
}

host_triple() {
  local key t k _
  key="$(host_os)-$(host_arch)"
  while IFS='|' read -r t k _; do
    [ -n "$t" ] || continue
    if [ "$k" = "$key" ]; then echo "$t"; return 0; fi
  done <<EOF
$TRIPLES
EOF
  echo "no release target for $key" >&2
  return 2
}

rm -rf "$out"
mkdir -p "$out/ffi"

# ---- 1. The client source tarball: the relate package root IS the client --
if [ "$local_mode" = true ]; then
  src_name="relate-ocaml-src-$version.tar.gz"
  tar -czf "$out/$src_name" \
    --exclude=_build --exclude=_opam --exclude=native --exclude='*.install' \
    -C "$repo_root/clients/ocaml" .
else
  # The client source comes from the canonical repository's tag archive on
  # GitHub — never from the local clone, which may be a fork without the
  # release tags or with divergent state. The FFI archives below already
  # come from the official release; this keeps --tag mode independent of
  # any local git state.
  src_name="relate-ocaml-src-$tag.tar.gz"
  tmp_src="$(mktemp -d)"
  tag_archive="$out/repo-$tag.tar.gz"
  curl -fsSL -o "$tag_archive" \
    "https://github.com/relatedb/relate/archive/refs/tags/$tag.tar.gz" \
    || { echo "error: no tag $tag on relatedb/relate" >&2; exit 1; }
  tar -xzf "$tag_archive" -C "$tmp_src"
  rm -f "$tag_archive"
  wrapper="$(ls "$tmp_src")"
  [ -d "$tmp_src/$wrapper/clients/ocaml" ] || {
    echo "error: the $tag archive of relatedb/relate carries no clients/ocaml" >&2
    echo "       (releases before the OCaml client landed have none)" >&2
    exit 1
  }
  tar -czf "$out/$src_name" \
    --exclude=_build --exclude=_opam --exclude=native --exclude='*.install' \
    -C "$tmp_src/$wrapper/clients/ocaml" .
  rm -rf "$tmp_src"
fi
src_sha="$(hash_file "$out/$src_name")"

# ---- 2. The five FFI archives --------------------------------------------
base_url="https://github.com/relatedb/relate/releases/download/$tag"

if [ "$local_mode" = true ]; then
  triple="$(host_triple)"
  case "$triple" in
    *apple-darwin) cdylib=librelate_ffi.dylib ;;
    *pc-windows-msvc) cdylib=relate_ffi.dll ;;
    *) cdylib=librelate_ffi.so ;;
  esac
  libdir="$repo_root/target/$profile"
  [ -f "$libdir/$cdylib" ] || {
    echo "error: no $cdylib under $libdir" >&2
    echo "       build it first: cargo build -p relate-ffi" >&2
    exit 1
  }
  tmp_ffi="$(mktemp -d)"
  mkdir -p "$tmp_ffi/ffi-package/include"
  cp "$repo_root/surfaces/relate-ffi/include/relate.h" "$tmp_ffi/ffi-package/include/"
  cp "$libdir/$cdylib" "$tmp_ffi/ffi-package/"
  for a in "$libdir"/librelate_ffi.a "$libdir"/relate_ffi.lib; do
    [ -f "$a" ] && cp "$a" "$tmp_ffi/ffi-package/"
  done
  tar -czf "$out/ffi/relate-ffi-$triple.tar.gz" -C "$tmp_ffi/ffi-package" .
  rm -rf "$tmp_ffi"
  echo "rehearsal: the four non-host archives are copies of the host one"
  echo "           (placeholders — fetched and hash-checked, never unpacked)"
fi

while IFS='|' read -r triple _ _; do
  [ -n "$triple" ] || continue
  if [ "$local_mode" = true ]; then
    if [ "$triple" != "$(host_triple)" ]; then
      cp "$out/ffi/relate-ffi-$(host_triple).tar.gz" "$out/ffi/relate-ffi-$triple.tar.gz"
    fi
  else
    curl -fsSL -o "$out/ffi/relate-ffi-$triple.tar.gz" "$base_url/relate-ffi-$triple.tar.gz" \
      || { echo "error: release $tag has no asset relate-ffi-$triple.tar.gz" >&2; exit 1; }
    tar -tzf "$out/ffi/relate-ffi-$triple.tar.gz" >/dev/null
  fi
done <<EOF
$TRIPLES
EOF

# ---- 3. The two package files --------------------------------------------
src_url="$base_url/$src_name"
[ "$local_mode" = true ] && src_url="file://$out/$src_name"

emit_ffi_extra_sources() {
  printf '%s\n' "$TRIPLES" | while IFS='|' read -r triple _ _; do
    [ -n "$triple" ] || continue
    ffi_sha="$(hash_file "$out/ffi/relate-ffi-$triple.tar.gz")"
    if [ "$local_mode" = true ]; then
      ffi_url="file://$out/ffi/relate-ffi-$triple.tar.gz"
    else
      ffi_url="$base_url/relate-ffi-$triple.tar.gz"
    fi
    printf 'extra-source "relate-ffi-%s.tar.gz" {\n  src: "%s"\n  checksum: [ "sha256=%s" ]\n}\n' \
      "$triple" "$ffi_url" "$ffi_sha"
  done
}

generate_ffi_opam() {
  cat <<'HEAD'
opam-version: "2.0"
synopsis: "The Relate engine native library (C ABI) for the OCaml client"
description: """The platform-native librelate_ffi the OCaml client links: the typed C ABI v2 of the Relate engine, prebuilt by the release pipeline for the five supported platforms and installed into the switch as lib/relate/native. The relate package pins this one to its own version."""
maintainer: "Relate maintainers"
authors: ["Relate maintainers"]
license: "Apache-2.0"
homepage: "https://github.com/relatedb/relate"
bug-reports: "https://github.com/relatedb/relate/issues"
dev-repo: "git+https://github.com/relatedb/relate.git"
available: [
  (arch = "x86_64" | arch = "arm64") & (os = "linux" | os = "macos")
  | (os = "win32" & arch = "x86_64")
]
HEAD
  emit_ffi_extra_sources
  cat <<'FFI'
build: [
  [ "bash" "-c" "set -ex
case '%{os}%-%{arch}%' in
linux-x86_64) t=x86_64-unknown-linux-gnu; lib=librelate_ffi.so ;;
linux-arm64) t=aarch64-unknown-linux-gnu; lib=librelate_ffi.so ;;
macos-x86_64) t=x86_64-apple-darwin; lib=librelate_ffi.dylib ;;
macos-arm64) t=aarch64-apple-darwin; lib=librelate_ffi.dylib ;;
win32-x86_64) t=x86_64-pc-windows-msvc; lib=relate_ffi.dll ;;
*) echo 'unsupported %{os}%-%{arch}% for the relate native' >&2; exit 2 ;;
esac
mkdir -p native
tar -xzf relate-ffi-$t.tar.gz -C native
test -f native/$lib" ]
]
install: [
  [ "bash" "-c" "set -ex
mkdir -p '%{lib}%/relate/native'
found=0
for f in native/librelate_ffi.* native/relate_ffi.*; do
[ -f $f ] || continue
cp $f '%{lib}%/relate/native/'
found=1
done
[ $found = 1 ]" ]
]
remove: [
  [ "bash" "-c" "rm -rf '%{lib}%/relate/native'" ]
]
FFI
}

generate_client_opam() {
  cat <<HEAD
opam-version: "2.0"
synopsis: "OCaml client for Relate, the embedded property-graph engine"
description: """An embedded client binding the Relate engine through its typed C ABI v2: open a database, connect a session, run Cypher with typed parameters, and walk typed results (values, entities, temporals, points, vectors) with result metadata — query type, resolved namespace, counters, notifications, plans, timings and bookmarks."""
maintainer: "Relate maintainers"
authors: ["Relate maintainers"]
license: "Apache-2.0"
homepage: "https://github.com/relatedb/relate"
bug-reports: "https://github.com/relatedb/relate/issues"
dev-repo: "git+https://github.com/relatedb/relate.git"
depends: [
  "relate-ffi" {= "$version"}
  "ocaml" {>= "5.0.0"}
  "dune" {>= "3.0"}
  "ctypes" {>= "0.20.0"}
  "yojson" {>= "2.0.0"}
]
available: [
  (arch = "x86_64" | arch = "arm64") & (os = "linux" | os = "macos")
  | (os = "win32" & arch = "x86_64")
]
url {
  src: "$src_url"
  checksum: [ "sha256=$src_sha" ]
}
build: [
  [ "bash" "-c" "set -ex
export RELATE_FFI_LIB_DIR='%{lib}%/relate/native'
case '%{os}%' in
linux|macos)
  # The rpath lives here, not in dune's c_library_flags — Windows's
  # linker rejects -rpath, so the flag cannot ship in the frozen META.
  # OCAMLPARAM's ':' separator keeps the commas in -Wl,-rpath,<path>.
  export OCAMLPARAM=\":cclib=-Wl,-rpath,'%{lib}%/relate/native':_\"
  ;;
win32)
  # flexlink treats -l/-L as literal file paths; the import library
  # goes by full path through RELATE_FFI_LINK.
  export RELATE_FFI_LINK='%{lib}%/relate/native/relate_ffi.lib'
  if [ ! -f \"$RELATE_FFI_LINK\" ]; then
    export RELATE_FFI_LINK='%{lib}%/relate/native/relate_ffi.dll.lib'
  fi
  ;;
esac
dune build -p relate -j %{jobs}% @install" ]
]
install: [
  [ "bash" "-c" "dune install relate --prefix '%{prefix}%'" ]
]
remove: [
  [ "bash" "-c" "dune uninstall relate --prefix '%{prefix}%' || true" ]
]
HEAD
}

mkdir -p "$out/packages/relate-ffi/relate-ffi.$version" "$out/packages/relate/relate.$version"
generate_ffi_opam > "$out/packages/relate-ffi/relate-ffi.$version/opam"
generate_client_opam > "$out/packages/relate/relate.$version/opam"

if [ "$local_mode" = true ]; then
  # A local repository in the opam-repository layout, so the rehearsal runs
  # the same fetch → extract → extra-sources → sandboxed build → install
  # flow opam CI runs (a bare file pin would ignore the url field and copy
  # the directory instead).
  printf 'opam-version: "2.0"\n' > "$out/repo"
fi

echo "generated:"
echo "  $out/packages/relate-ffi/relate-ffi.$version/opam"
echo "  $out/packages/relate/relate.$version/opam"
if [ "$local_mode" = true ]; then
  echo "rehearse (a local repository, the same flow opam CI runs):"
  echo "  opam switch create relate-rehearsal ocaml-base-compiler.5.4.1"
  echo "  opam repository add relate-rehearsal $out"
  echo "  opam install --switch relate-rehearsal relate"
  echo "cleanup: opam repository remove relate-rehearsal;"
  echo "         opam switch remove relate-rehearsal"
else
  echo "next steps (manual, ADR-0699):"
  echo "  1. upload the source tarball: gh release upload $tag $out/$src_name --repo relatedb/relate"
  echo "  2. re-check the names: https://opam.ocaml.org/packages/relate/"
  echo "     https://opam.ocaml.org/packages/relate-ffi/"
  echo "  3. fork ocaml/opam-repository, copy the two package directories"
  echo "     under packages/, open the PR by hand"
fi
