package edu.berkeley.cs.ucie.digital

import chisel3._

// Encapsulates MBINIT.PARAM configuration knobs.
case class DesignParams(

  // MBINIT.PARAM (table 7.11 in UCIe_v2 spec)
  sbFeatureExtension: Bool = false.B,
  ucieA: Bool = false.B,
  moduleID: UInt = 0.U,
  clkPhase: Bool = false.B, //0b: Differential clock, 1b: Quadrature phase
  clkMode: Bool = false.B, //Clock Mode - 0b: Strobe mode; 1b: Continuous mode
  voltageSwing: UInt = 7.U(5.W), //07h: 0.7 V <------- TBC
  maxLinkSpeed: UInt = 3.U(4.W) //3h: 16 GT/s <------- TBC
)