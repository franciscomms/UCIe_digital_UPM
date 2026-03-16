package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

object SidebandMsgGenerator {

  // Opcodes — fill from spec if they differ
  private val OPCODE_MSG_WITHOUT_DATA = "b10010".U(5.W)
  private val OPCODE_MSG_WITH_DATA    = "b11011".U(5.W) // TODO: set from spec for messages with payload

  // ----------------------------------------------------------
  // Base builder: 64-bit sideband "Message without data" header
  // ----------------------------------------------------------
  /**
    * Build the common 64-bit sideband header.
    * Layout (MSB→LSB):
    *   dp + cp + '000' + dstid(2:0) + msgInfo(15:0) + msgSub(7:0) +
    *   srcid(2:0) + '00' + '00000' + msgCode(7:0) + '000000000' + opcode(4:0)
    * CP is even parity over the 63-bit tail; DP comes from payload parity (or 0 when no payload).
    */
  private def buildHeader(msgInfo: UInt, msgCode: UInt, msgSub: UInt, src: String, dst: String, opcode: UInt, dp: UInt): UInt = {
    def endpointId(name: String): UInt = name match {
      case "phy" => "b010".U(3.W)
      case "d2d" => "b001".U(3.W)
      case "mpg" => "b011".U(3.W)
      case _     => "b000".U(3.W)
    }

    val srcid = endpointId(src)
    val dstid = endpointId(dst)

    // build 63-bit tail (everything except DP and CP)
    val tail = Cat(
      "b000".U(3.W),       // '000'
      dstid,                // 3
      msgInfo,              // 16
      msgSub,               // 8
      srcid,                // 3
      "b00".U(2.W),        // '00'
      "b00000".U(5.W),     // '00000'
      msgCode,              // 8
      "b000000000".U(9.W), // '000000000'
      opcode                // 5
    ) // = 63 bits

    val cp = tail.xorR // even control parity over tail
    Cat(dp(0), cp, tail) // 64-bit header
  }

  private def msgWithoutDataBase(msgInfo: UInt, msgCode: UInt, msgSub: UInt, src: String, dst: String): UInt =
    buildHeader(msgInfo, msgCode, msgSub, src, dst, OPCODE_MSG_WITHOUT_DATA, 0.U(1.W))

  private def msgWithPayloadBase(msgInfo: UInt, msgCode: UInt, msgSub: UInt, payload: UInt, src: String, dst: String): UInt = {
    val dp = payload.xorR // data parity over 64-bit payload
    val header = buildHeader(msgInfo, msgCode, msgSub, src, dst, OPCODE_MSG_WITH_DATA, dp)
    Cat(payload, header) // 128-bit message - header LSB
  }










  // --------------------------------------------------------------------------------------------------------
  // Message wrappers (explicit src/dst)
  // --------------------------------------------------------------------------------------------------------
  // SBINIT
  def msgSbinitOutOfResetSuccess(src: String, dst: String): UInt =
    msgWithoutDataBase("b0000000000000001".U(16.W), "h91".U(8.W), "h00".U(8.W), src, dst)
  def msgSbinitOutOfResetFailure(src: String, dst: String): UInt =
    msgWithoutDataBase("b0000000000000000".U(16.W), "h91".U(8.W), "h00".U(8.W), src, dst)
  def msgSbinitDoneReq(src: String, dst: String): UInt =
    msgWithoutDataBase(0.U(16.W), "h95".U(8.W), "h01".U(8.W), src, dst)
  def msgSbinitDoneResp(src: String, dst: String): UInt =
    msgWithoutDataBase(0.U(16.W), "h9A".U(8.W), "h01".U(8.W), src, dst)

  // MBINIT.PARAM configuration req (64-bit header + 64-bit payload)
  def msgMbinitParamConfigReq(
    src: String,
    dst: String,
    sbFeatureExtension: Bool,
    ucieA: Bool,
    moduleID: UInt,
    clkPhase: Bool,
    clkMode: Bool,
    voltageSwing: UInt,
    maxLinkSpeed: UInt
  ): UInt = {
    val payload = Cat(
      0.U(49.W),                         // [63:15] reserved
      sbFeatureExtension.asUInt,         // [14]
      ucieA.asUInt,                      // [13]
      moduleID(1, 0),                    // [12:11]
      clkPhase.asUInt,                   // [10]
      clkMode.asUInt,                    // [9]
      voltageSwing(4, 0),                // [8:4]
      maxLinkSpeed(3, 0)                 // [3:0]
    )

    msgWithPayloadBase(
      "b0000000000000000".U(16.W), // msgInfo TODO: fill from spec
      "hA5".U(8.W),  // msgCode TODO: fill from spec
      "h00".U(8.W),  // msgSub  TODO: fill from spec
      payload,
      src,
      dst
    )
  }

  
// MBINIT.PARAM configuration resp (64-bit header + 64-bit payload)
def msgMbinitParamConfigResp(
  src: String,
  dst: String,
  clkPhase: Bool,
  clkMode: Bool,
  maxLinkSpeed: UInt
): UInt = {

  val payload = Cat(
    0.U(53.W),             // [63:11] reserved
    clkPhase.asUInt,       // [10]
    clkMode.asUInt,        // [9]
    0.U(5.W),              // [8:4] reserved
    maxLinkSpeed(3, 0)     // [3:0]
  )

  msgWithPayloadBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h 
    "hAA".U(8.W),                // MsgCode = AAh  
    "h00".U(8.W),                // MsgSub  = 00h  
    payload,
    src,
    dst
  )
}

// MBINIT.CAL Done req (64-bit header only)
def msgMbinitCalDoneReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hA5".U(8.W),                // MsgCode = A5h
    "h02".U(8.W),                // MsgSub  = 02h
    src,
    dst
  )

// MBINIT.CAL Done resp (64-bit header only)
def msgMbinitCalDoneResp(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hAA".U(8.W),                // MsgCode = AAh
    "h02".U(8.W),                // MsgSub  = 02h
    src,
    dst
  )

// MBINIT.REPAIRCLK init req (64-bit header only)
def msgMbinitRepairClkInitReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hA5".U(8.W),                // MsgCode = A5h
    "h03".U(8.W),                // MsgSub  = 03h
    src,
    dst
  )

// MBINIT.REPAIRCLK init resp (64-bit header only)
def msgMbinitRepairClkInitResp(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hAA".U(8.W),                // MsgCode = AAh
    "h03".U(8.W),                // MsgSub  = 03h
    src,
    dst
  )

// MBINIT.REPAIRCLK result req (64-bit header only)
def msgMbinitRepairClkResultReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hA5".U(8.W),                // MsgCode = A5h
    "h04".U(8.W),                // MsgSub  = 04h
    src,
    dst
  )

// MBINIT.REPAIRCLK result resp (64-bit header only)
def msgMbinitRepairClkResultResp(
  src: String,
  dst: String,
  RTRK_L: UInt,
  RCKN_L: UInt,
  RCKP_L: UInt
): UInt =
  msgWithoutDataBase(
    Cat(0.U(13.W), RTRK_L(0), RCKN_L(0), RCKP_L(0)), // MsgInfo[2:0] = {RTRK_L,RCKN_L,RCKP_L}
    "hAA".U(8.W),                // MsgCode = AAh
    "h04".U(8.W),                // MsgSub  = 04h
    src,
    dst
  )

// MBINIT.REPAIRCLK done req (64-bit header only)
def msgMbinitRepairClkDoneReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hA5".U(8.W),                // MsgCode = A5h
    "h08".U(8.W),                // MsgSub  = 08h
    src,
    dst
  )

// MBINIT.REPAIRCLK done resp (64-bit header only)
def msgMbinitRepairClkDoneResp(
  src: String,
  dst: String
): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W), // MsgInfo = 0000h
    "hAA".U(8.W),                // MsgCode = AAh
    "h08".U(8.W),                // MsgSub  = 08h
    src,
    dst
  )

// MBINIT.REPAIRVAL init req (64-bit header only)
def msgMbinitRepairValInitReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W),
    "hA5".U(8.W),
    "h05".U(8.W),
    src,
    dst
  )

// MBINIT.REPAIRVAL init resp (64-bit header only)
def msgMbinitRepairValInitResp(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W),
    "hAA".U(8.W),
    "h05".U(8.W),
    src,
    dst
  )

// MBINIT.REPAIRVAL result req (64-bit header only)
def msgMbinitRepairValResultReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W),
    "hA5".U(8.W),
    "h06".U(8.W),
    src,
    dst
  )

// MBINIT.REPAIRVAL result resp (64-bit header only, msgInfo[0] carries RVLD_L detection)
def msgMbinitRepairValResultResp(
  src: String,
  dst: String,
  RVLD_L: UInt
): UInt =
  msgWithoutDataBase(
    Cat(0.U(15.W), RVLD_L(0)),
    "hAA".U(8.W),
    "h06".U(8.W),
    src,
    dst
  )

// MBINIT.REPAIRVAL done req (64-bit header only)
def msgMbinitRepairValDoneReq(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W),
    "hA5".U(8.W),
    "h09".U(8.W),
    src,
    dst
  )

// MBINIT.REPAIRVAL done resp (64-bit header only)
def msgMbinitRepairValDoneResp(src: String, dst: String): UInt =
  msgWithoutDataBase(
    "b0000000000000000".U(16.W),
    "hAA".U(8.W),
    "h09".U(8.W),
    src,
    dst
  )


  /**
   * Return the fixed SBINIT clock pattern (0xAAAAAAAAAAAAAAAA) as a 64-bit UInt.
   */
  def msgSbinitClkPattern(): UInt = "hAAAAAAAAAAAAAAAA".U(64.W)
}