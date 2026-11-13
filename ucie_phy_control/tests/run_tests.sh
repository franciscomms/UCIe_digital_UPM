#!/usr/bin/env bash
# Verilator 5.x regression for the PHY TX pattern control.
#   tests/run_tests.sh [build_dir]
# Overrides: SEEDS="1 2 3 4 5" (tb_phy_tx_sequencer seeds), PYTHON=python3.
set -euo pipefail
package_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ctrl800_src="$package_root/../systemVerilog/src/LtsmPhyPatternCtrl800.sv"
test_build_root="${1:-$package_root/build}"
seeds=${SEEDS:-"1 2 3 4 5 6 7 8"}
mkdir -p "$test_build_root"
if command -v verilator >/dev/null 2>&1; then
  test_simulator=(verilator)
else
  test_simulator=("${PYTHON:-python3}" -m verilator)
fi
lint() {  # lint <top> <files...>; warnings are fatal
  local top=$1; shift
  if ! "${test_simulator[@]}" --lint-only --assert --timescale-override 1ps/1ps \
      --top-module "$top" "$@" > "$test_build_root/$top.lint.log" 2>&1; then
    cat "$test_build_root/$top.lint.log"
    exit 1
  fi
  echo "LINT PASS $top"
}
phy_sources=(
  "$package_root/PhyTxSequencer.sv"
  "$package_root/PhyPatternTx500.sv"
  "$package_root/PhyPatternData2g.sv"
  "$package_root/PhyPatternValid2g.sv"
  "$package_root/PhyPatternClock2g.sv"
)
# Every production file elaborates on its own; the wrapper needs its parts.
lint LtsmPhyPatternCtrl800 "$ctrl800_src"
for rtl_file in "${phy_sources[@]}"; do
  lint "$(basename "$rtl_file" .sv)" "$rtl_file"
done
lint PhyTxControlTop "${phy_sources[@]}" "$package_root/PhyTxControlTop.sv"

rtl_sources=("$ctrl800_src" "${phy_sources[@]}" "$package_root/PhyTxControlTop.sv")
build() {  # build <tb_top>
  local test_top=$1
  if ! "${test_simulator[@]}" --binary --timing --assert --output-split 0 \
      --timescale-override 1ps/1ps -j 2 --top-module "$test_top" \
      --Mdir "$test_build_root/$test_top" \
      "${rtl_sources[@]}" "$package_root/tests/$test_top.sv" \
      > "$test_build_root/$test_top.build.log" 2>&1; then
    cat "$test_build_root/$test_top.build.log"
    exit 1
  fi
}
build tb_phy_tx_sequencer
for seed in $seeds; do
  "$test_build_root/tb_phy_tx_sequencer/Vtb_phy_tx_sequencer" "+SEED=$seed" \
    | tee "$test_build_root/tb_phy_tx_sequencer.seed$seed.run.log"
  grep -q TB_PHY_TX_SEQUENCER_PASS "$test_build_root/tb_phy_tx_sequencer.seed$seed.run.log"
done
build tb_ltsm_specialized
"$test_build_root/tb_ltsm_specialized/Vtb_ltsm_specialized" \
  | tee "$test_build_root/tb_ltsm_specialized.run.log"
grep -q LTSM_SPECIALIZED_REGRESSION_PASS "$test_build_root/tb_ltsm_specialized.run.log"
echo "ALL PHY TX CONTROL TESTS PASSED"
