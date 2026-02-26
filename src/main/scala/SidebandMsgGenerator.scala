package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

object SidebandMsgGenerator {

  /*
  USAGE:

  // PHY → PHY: SBINIT out of Reset
  val hdr = SidebandMsgGenerator.msgWithoutData("SBINIT_out_of_Reset", "phy", "phy")

  */

  /** 64-bit sideband "Message without data" header.
    *
    * Return layout (MSB→LSB):
    *   '0' + cp + '000' + dstid(2:0) + msgInfo(15:0) + msgSub(7:0) +
    *   srcid(2:0) + '00' + '00000' + msgCode(7:0) + '000000000' + opcode(4:0)
    *
    * DP (MSB) is forced to 0. CP is even parity over all remaining 63 bits.
    */
  def msgWithoutData(msg: String, src: String, dst: String): UInt = {
    // opcode for "Message without Data"
    val opcode = "b10010".U(5.W)

    // ---- message dictionary: msg -> (msgInfo, msgCode, msgSub) ----
    val (msgInfo, msgCode, msgSub) = msg match {
      // SBINIT
      case "SBINIT_out_of_Reset_success"    => ("b0000000000000001".U(16.W), "h91".U(8.W), "h00".U(8.W))
      case "SBINIT_out_of_Reset_failure"    => ("b0000000000000000".U(16.W), "h91".U(8.W), "h00".U(8.W))
      case "SBINIT_done_req"    => (0.U(16.W), "h95".U(8.W), "h01".U(8.W))
      case "SBINIT_done_resp"   => (0.U(16.W), "h9A".U(8.W), "h01".U(8.W))

      // MBINIT.CAL
      case "MBINIT_CAL_Done_req"  => (0.U(16.W), "hA5".U(8.W), "h02".U(8.W))
      case "MBINIT_CAL_Done_resp" => (0.U(16.W), "hAA".U(8.W), "h02".U(8.W))

      // MBINIT.REPAIRCLK
      case "MBINIT_REPAIRCLK_init_req"           => (0.U(16.W), "hA5".U(8.W), "h03".U(8.W))
      case "MBINIT_REPAIRCLK_init_resp"          => (0.U(16.W), "hAA".U(8.W), "h03".U(8.W))
      case "MBINIT_REPAIRCLK_result_req"         => (0.U(16.W), "hA5".U(8.W), "h04".U(8.W))
      //Add all msgInfo cases --- case "MBINIT_REPAIRCLK_result_resp"        => (0.U(16.W), "hAA".U(8.W), "h04".U(8.W))
      case "MBINIT_REPAIRCLK_apply_repair_req"   => (0.U(16.W), "hA5".U(8.W), "h05".U(8.W))
      case "MBINIT_REPAIRCLK_apply_repair_resp"  => (0.U(16.W), "hAA".U(8.W), "h05".U(8.W))
      case "MBINIT_REPAIRCLK_check_repair_init_req"  => (0.U(16.W), "hA5".U(8.W), "h06".U(8.W))
      case "MBINIT_REPAIRCLK_check_repair_init_resp" => (0.U(16.W), "hAA".U(8.W), "h06".U(8.W))
      case "MBINIT_REPAIRCLK_check_results_req"      => (0.U(16.W), "hA5".U(8.W), "h07".U(8.W))
      case "MBINIT_REPAIRCLK_check_results_resp"     => (0.U(16.W), "hAA".U(8.W), "h07".U(8.W))
      case "MBINIT_REPAIRCLK_done_req"           => (0.U(16.W), "hA5".U(8.W), "h08".U(8.W))
      case "MBINIT_REPAIRCLK_done_resp"          => (0.U(16.W), "hAA".U(8.W), "h08".U(8.W))

      // MBINIT.REPAIRVAL
      case "MBINIT_REPAIRVAL_init_req"   => (0.U(16.W), "hA5".U(8.W), "h09".U(8.W))
      case "MBINIT_REPAIRVAL_init_resp"  => (0.U(16.W), "hAA".U(8.W), "h09".U(8.W))
      case "MBINIT_REPAIRVAL_result_req" => (0.U(16.W), "hA5".U(8.W), "h0A".U(8.W))
      case "MBINIT_REPAIRVAL_result_resp"=> (0.U(16.W), "hAA".U(8.W), "h0A".U(8.W))
      case "MBINIT_REPAIRVAL_done_req"   => (0.U(16.W), "hA5".U(8.W), "h0C".U(8.W))
      case "MBINIT_REPAIRVAL_done_resp"  => (0.U(16.W), "hAA".U(8.W), "h0C".U(8.W))

      // Fallback
      case _ => (0.U(16.W), 0.U(8.W), 0.U(8.W))
    }

    // ---- src/dst 3-bit IDs ----
    val srcid = src match {
      case "phy" => "b010".U(3.W)
      case "d2d" => "b001".U(3.W)
      case "mpg" => "b011".U(3.W)
      case _     => "b000".U(3.W)
    }
    val dstid = dst match {
      case "phy" => "b010".U(3.W)
      case "d2d" => "b001".U(3.W)
      case "mpg" => "b011".U(3.W)
      case _     => "b000".U(3.W)
    }

    // ---- build 63-bit tail in requested order (everything except DP and CP) ----
    val tail = Cat(
      "b000".U(3.W),       // '000'
      dstid,               // 3
      msgInfo,             // 16
      msgSub,              // 8
      srcid,               // 3
      "b00".U(2.W),        // '00'
      "b00000".U(5.W),     // '00000'
      msgCode,             // 8
      "b000000000".U(9.W), // '000000000'
      opcode               // 5
    ) // = 63 bits

    // ---- even control parity over tail (excludes DP) ----
    val cp = tail.xorR

    // ---- DP (MSB) = 0 ----
    Cat(0.U(1.W), cp, tail) // 64-bit header
  }

  /**
   * Return the fixed SBINIT clock pattern (0xAAAAAAAAAAAAAAAA) as a 64-bit UInt.
   */
  def msgSbinitClkPattern(): UInt = "hAAAAAAAAAAAAAAAA".U(64.W)
}