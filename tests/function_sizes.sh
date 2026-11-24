#!/usr/bin/env bash
# tests/function_sizes.sh — the size of each function of the package on a
# Cortex-M4, which the README gives.
#
# It builds the probe for `nrf52-qemu` with every function of the package
# kept out of its callers: a compiler wrapper in NOVO_CC adds `noinline`
# to the IR of every `novo_user_` function before the C compiler reads it,
# so the size of a symbol is the size of the function and not of a call
# site.  The sizes come from the ELF symbol table.
#
# Run from anywhere:  bash tests/function_sizes.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
NOVO="${NOVO:-$HOME/.novo/bin/novo}"
for t in arm-none-eabi-nm clang; do
  command -v "$t" >/dev/null 2>&1 || { echo "  (skipped — $t is not installed)"; exit 0; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fpmath-sizes.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src" "$WORK/wrap"
cp "$PKG"/src/*.nv "$WORK/src/"
cp "$PKG/tests/embedded_probe.nv" "$WORK/src/probe.nv"
printf '[package]\nname = "embsizes"\nversion = "0.1.0"\nmain = "src/probe.nv"\n\n[dependencies]\n' > "$WORK/novo.toml"

cat > "$WORK/cc.sh" <<'CC'
#!/bin/bash
args=()
n=0
for a in "$@"; do
  case "$a" in
    *.ll)
      n=$((n + 1)); m="$WRAP_DIR/mod$n.ll"
      sed -E '/^define [^@]*@novo_user_/ { /noinline|alwaysinline/! s/ nounwind/ noinline nounwind/ }' "$a" > "$m"
      args+=("$m") ;;
    *) args+=("$a") ;;
  esac
done
exec clang "${args[@]}"
CC
chmod +x "$WORK/cc.sh"

( cd "$WORK" && WRAP_DIR="$WORK/wrap" NOVO_CC="$WORK/cc.sh" NOVO_LEAK_CHECK=0 \
    "$NOVO" build --target=nrf52-qemu src/probe.nv ) > "$WORK/build.log" 2>&1
if [ ! -f "$WORK/probe.elf" ]; then
  echo "  ✗ the probe does not build"; grep -vE '^novo:' "$WORK/build.log" | head -10 | sed 's/^/      /'; exit 1
fi
echo "  bytes of Thumb-2 code, nrf52-qemu, each function kept out of its callers:"
arm-none-eabi-nm --size-sort -S "$WORK/probe.elf" | grep ' novo_user_fpmath\.' \
  | awk '{ printf "    %-14s %5d\n", substr($4, 18), strtonum("0x" $2) }' | sort -k2 -n -r
