#!/usr/bin/env bash
#
# snarkOS/mayhem/build.sh — build cargo-fuzz libFuzzer targets + file-input _no_inst reproducers.
#
# Upstream staging has no fuzz/ crate; the old fork harnesses live in our additive mayhem/fuzz/
# (self-contained message deserialization / length-delimited framing fuzzers — no snarkOS deps).
# cargo-fuzz builds the libFuzzer binaries; a plain `cargo build --release` on the same crate
# produces the _no_inst file-input reproducers (libfuzzer-sys run-once driver, no libFuzzer runtime).
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
export MAYHEM_JOBS
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

cd "$SRC"

FUZZ_DIR="mayhem/fuzz"
FUZZ_TARGETS=()
for f in "$FUZZ_DIR"/fuzz_targets/*.rs; do
  FUZZ_TARGETS+=("$(basename "${f%.*}")")
done
[ "${#FUZZ_TARGETS[@]}" -gt 0 ] || { echo "ERROR: no fuzz targets under $FUZZ_DIR/fuzz_targets/" >&2; exit 1; }
TRIPLE="x86_64-unknown-linux-gnu"

export RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing -Zsanitizer=address -Cdebuginfo=1 -Cforce-frame-pointers"

echo "=== cargo +nightly-2025-09-05 fuzz build (ASan via RUSTFLAGS) ==="
echo "RUSTFLAGS=$RUSTFLAGS"
echo "targets: ${FUZZ_TARGETS[*]}"

for t in "${FUZZ_TARGETS[@]}"; do
  echo "--- building fuzz target: $t ---"
  cargo +nightly-2025-09-05 fuzz build --fuzz-dir "$FUZZ_DIR" -O --debug-assertions "$t"
  bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/$t"
  [ -x "$bin" ] || { echo "ERROR: expected fuzz binary not found at $bin" >&2; exit 1; }
  cp "$bin" "/mayhem/$t"
  echo "built /mayhem/$t"
done

echo "=== cargo build _no_inst reproducers (no libFuzzer runtime) ==="
export RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -Ccodegen-units=1"
cargo build --release --manifest-path "$FUZZ_DIR/Cargo.toml" --jobs "$MAYHEM_JOBS"
for t in "${FUZZ_TARGETS[@]}"; do
  bin="$SRC/$FUZZ_DIR/target/release/$t"
  [ -x "$bin" ] || { echo "ERROR: expected _no_inst binary not found at $bin" >&2; exit 1; }
  cp "$bin" "/mayhem/${t}_no_inst"
  echo "built /mayhem/${t}_no_inst"
done

echo "build.sh complete:"
ls -la /mayhem/network /mayhem/deserialization /mayhem/network_no_inst /mayhem/deserialization_no_inst

echo "=== precompile workspace lib tests (hermetic subset) ==="
RUSTFLAGS="" cargo test --workspace --lib --no-run --no-fail-fast \
  --exclude snarkos-cli --exclude snarkos-node-bft --exclude snarkos-node-cdn \
  --jobs "$MAYHEM_JOBS"
