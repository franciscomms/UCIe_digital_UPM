#!/usr/bin/env bash
# Verilator 5.x regression runner. From any directory:
#   ./test/run_tests.sh all
#   ./test/run_tests.sh 128b +SCENARIO=retrain
# Overrides: VERILATOR=/path/to/verilator JOBS=4 BUILD_DIR=/path TRACE=1
# LINT_ONLY=1 elaborates selected tops without building or running them.
set -euo pipefail

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$test_dir"
selection=${1:-all}
if (($#)); then shift; fi
case "$selection" in
  all) tests=(bringup backpressure 128b) ;;
  bringup|backpressure|128b) tests=("$selection") ;;
  *) echo 'Usage: run_tests.sh [all|bringup|backpressure|128b] [+PLUSARGS...]' >&2; exit 2 ;;
esac
simulator=${VERILATOR:-verilator}
if ! command -v "$simulator" >/dev/null 2>&1; then
  echo "Verilator not found: $simulator. Install Verilator 5.x or set VERILATOR." >&2
  exit 2
fi
build_root=${BUILD_DIR:-"$test_dir/build"}
mkdir -p "$build_root"
build_root=$(cd "$build_root" && pwd)
common=(--timing --assert -Wno-fatal -f sources.f)
if [[ ${TRACE:-0} == 1 ]]; then common+=(--trace); fi
for name in "${tests[@]}"; do
  case "$name" in
    bringup) top=D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb ;;
    backpressure) top=D2DAdapterLinkMgmtLtsmDualDieBackpressureSpec_tb ;;
    128b) top=D2DAdapterLinkMgmtTopIntegrated128Spec_tb ;;
  esac
  output_dir="$build_root/$name"
  mkdir -p "$output_dir"
  echo "[$name] Elaborating $top"
  if [[ ${LINT_ONLY:-0} == 1 ]]; then
    if ! "$simulator" --lint-only "${common[@]}" --top-module "$top" >"$output_dir/lint.log" 2>&1; then
      tail -n 100 "$output_dir/lint.log" >&2
      exit 1
    fi
    echo "[$name] Lint passed; diagnostics: $output_dir/lint.log"
    continue
  fi
  if ! "$simulator" --binary -CFLAGS "-std=c++20" -j "${JOBS:-2}" "${common[@]}" --top-module "$top" \
      --Mdir "$output_dir/obj" -o simulation >"$output_dir/build.log" 2>&1; then
    tail -n 100 "$output_dir/build.log" >&2
    exit 1
  fi
  echo "[$name] Running; build diagnostics: $output_dir/build.log"
  # Run in the test's output directory so optional +VCD files stay with its log.
  (cd "$output_dir" && ./obj/simulation "$@") 2>&1 | tee "$output_dir/run.log"
done
