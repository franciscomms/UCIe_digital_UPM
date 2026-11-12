#!/usr/bin/env bash
set -euo pipefail
package_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_build_root="${1:-$package_root/build}"
mkdir -p "$test_build_root"
if command -v verilator >/dev/null 2>&1; then
  test_simulator=(verilator)
else
  test_simulator=("${PYTHON:-python3}" -m verilator)
fi
rtl_sources=()
for rtl_top in LtsmPhyPatternCtrl800 PhyPatternTx500 PhyPatternData2g PhyPatternValid2g PhyPatternClock2g; do
  rtl_sources+=("$package_root/$rtl_top.sv")
  if ! "${test_simulator[@]}" --lint-only --assert --timescale-override 1ps/1ps \
      --top-module "$rtl_top" "$package_root/$rtl_top.sv" \
      > "$test_build_root/$rtl_top.lint.log" 2>&1; then
    cat "$test_build_root/$rtl_top.lint.log"
    exit 1
  fi
done
for test_top in tb_data_lfsr tb_valid_clock2g tb_clock2g tb_ltsm_specialized; do
  test_obj_dir="$test_build_root/$test_top"
  if ! "${test_simulator[@]}" --binary --timing --assert --output-split 0 --timescale-override 1ps/1ps \
      -j 2 --top-module "$test_top" --Mdir "$test_obj_dir" \
      "${rtl_sources[@]}" "$package_root/tests/$test_top.sv" \
      > "$test_build_root/$test_top.build.log" 2>&1; then
    cat "$test_build_root/$test_top.build.log"
    exit 1
  fi
  "$test_obj_dir/V$test_top" | tee "$test_build_root/$test_top.run.log"
done
