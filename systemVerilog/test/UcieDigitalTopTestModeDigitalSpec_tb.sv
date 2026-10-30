// Two-die Reset-to-Active test of UcieDigitalTop in testModeDigital.
// Reuses the dual-die bring-up spec with TEST_MODE_DIGITAL = 1: each die is a
// UcieDigitalTop with testModeDigital tied to 1, and the die model drives and
// observes only its jtag_* pins (clock, reset, FDI, LTSM analog flags and the
// serial sideband pins all go through the TDR side of the muxes).
//
// The functional pins carry junk that would break the link if any of it
// leaked through the test-mode muxes: functional clock and sb_rx_clk are
// stopped, functional reset_n is held asserted, and every other functional
// input is the bit-inverse of the value on its jtag_* twin. Every functional
// output is checked to stay 0 on every clock cycle.
//
// Passing means: both dies reach LTSM/RDI/FDI Active and exchange sideband
// packets over the one-bit serial links using only the jtag_* IOs.

`timescale 1ns/1ps
`default_nettype none

module UcieDigitalTopTestModeDigitalSpec_tb;
  D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb #(
    .TEST_MODE_DIGITAL(1'b1)
  ) spec ();
endmodule

`default_nettype wire
