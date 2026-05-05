package RdiLinkManagement

import chisel3._

/** Subestados internos del bring-up / init del RDI.
  * Esto no es la SM visible del link (esa ya la representa PhyState),
  * sino la sub-FSM de inicialización del RDI.
  */
object RDIBringUpState extends ChiselEnum {
  val IDLE          = Value(0.U(3.W))
  val ACTIVE_ENTRY_HANDSHAKE = Value(1.U(3.W))
  val BRINGUP_DONE = Value(2.U(3.W))
}

object PhyState extends ChiselEnum {
  val NOP       = Value(0x0.U(4.W))
  val RESET     = Value(0x1.U(4.W))
  val ACTIVE    = Value(0x2.U(4.W))
  val L1        = Value(0x3.U(4.W))
  val L2        = Value(0x4.U(4.W))
  val RETRAIN   = Value(0x5.U(4.W))
  val LINKERROR = Value(0x6.U(4.W))
  val LINKRESET = Value(0x7.U(4.W))
  val PMNAK     = Value(0x8.U(4.W))
  val DISABLED  = Value(0x9.U(4.W))
}

/** Mensajes SB que previsiblemente usará la RDI SM.
  * De momento dejamos la base para Active / Retrain / LinkReset / Disabled / PM.
  * Si en tu proyecto ya existe un mapping oficial común de sideband opcodes,
  * entonces convendrá unificar esto con él en vez de duplicarlo.
  */
object RdiSideBandMessage {
  val NOP: UInt = "b000000".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)

  // RDI Link Management Requests
  val REQ_ACTIVE: UInt    = "b000001".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val REQ_L1: UInt        = "b000100".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val REQ_L2: UInt        = "b001000".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val REQ_LINKRESET: UInt = "b001001".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val REQ_RETRAIN: UInt   = "b001010".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val REQ_LINKERROR: UInt = "b001011".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val REQ_DISABLED: UInt  = "b001100".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)

  // RDI Link Management Responses
  val RSP_ACTIVE: UInt    = "b010001".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_PMNAK: UInt     = "b010011".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_L1: UInt        = "b010100".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_L2: UInt        = "b011000".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_LINKRESET: UInt = "b011001".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_RETRAIN: UInt   = "b011010".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_LINKERROR: UInt = "b011011".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)
  val RSP_DISABLED: UInt  = "b011100".U(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH)

}

object D2DAdapterSignalSize{
    val SIDEBAND_MESSAGE_OP_WIDTH = 6.W
}