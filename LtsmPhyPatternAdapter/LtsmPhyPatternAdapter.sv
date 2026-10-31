`default_nettype none

// ============================================================================
// LtsmPhyPatternAdapter
// Converts the LTSM pattern handshake (flagToAnalog_*Send* / flagFromAnalog_*
// Finished/Sent) into the send-bit + return-edge control used by the analog PHY.
//
// Sequence, for each pattern burst:
//   1. An LTSM send flag rises. The state decides the pattern and the count.
//   2. The matching phy_send* bit is set and stays high during the burst.
//   3. Every positive edge of phy_patternSent is counted.
//   4. On the last edge the phy_send* bit falls and the flagFromAnalog_* of the
//      requester pulses for one clock in the same cycle.
//
// Expected PHY behavior:
//   - phy_send* high: send that pattern repeatedly. Low: stop. At most one of
//     the four bits is high at a time. The bits come straight from registers.
//   - phy_patternSent: one positive edge per pattern sent. It is asynchronous
//     to clock and goes through a 2-stage synchronizer, so it must stay high
//     for at least 2 clock periods and low for at least 2 clock periods.
//   - The send bit falls about 3 clocks after the last edge. Edges received
//     after that are ignored, so patterns sent in this time are not counted.
//
// Who activates the PHY, and how many positive edges are counted:
//   LTSM state               Flag from LTSM                  PHY bit    Count
//   MBINIT.REPAIRCLK         SendClkPatterns                 ClkRepair  300 (*)
//   MBINIT.REPAIRVAL         SendValTrainPattern             ValTrain   300 (*)
//   MBINIT.REVERSALMB        ReversalMbSendLaneIDPattern     LaneId     300 (*)
//   MBINIT.REPAIRMB          RepairMbSendLaneIDPattern       LaneId     300 (*)
//   MBTRAIN.VALVREF          valVref_sendPattern             ValTrain   128
//   MBTRAIN.DATAVREF         dataVref_sendPattern            Lfsr       300 (*)
//   MBTRAIN.VALTRAINCENTER   d2cSender_sendValTrainPattern   ValTrain   128
//   MBTRAIN.VALTRAINVREF     valVref_sendPattern             ValTrain   128
//   MBTRAIN.DATATRAINCENTER1 d2cSender_sendLfsrPattern       Lfsr       300 (*)
//   MBTRAIN.DATATRAINVREF    dataVref_sendPattern            Lfsr       300 (*)
//   MBTRAIN.RXDESKEW         rxDeskew_sendLfsrPattern        Lfsr       300 (*)
//   MBTRAIN.DATATRAINCENTER2 d2cSender_sendLfsrPattern       Lfsr       300 (*)
//   MBTRAIN.LINKSPEED        d2cSender_sendLfsrPattern       Lfsr       300 (*)
//   (*) The LTSM code does not define the number of return edges, so 300 is a
//   placeholder. Each count is a parameter; see the notes at the parameters.
//
// Why the send flags are edge detected: the LTSM drives them in three ways.
//   MBINIT flags           One-clock pulse; the FSM then waits for Finished.
//   VREF / RXDESKEW flags  High until the Finished pulse is received.
//   d2cSender flags        Stay high after Finished until the next test start.
//
// A burst is aborted (send bit falls, no Finished pulse) when the LTSM state or
// substate changes during it, or when a flag of the last two kinds falls.
// ============================================================================

module LtsmPhyPatternAdapter #(
  // Count not defined in the code: MBINIT has no REPAIRCLK iteration count.
  parameter logic [15:0] COUNT_MBINIT_REPAIRCLK = 16'd300,
  // Count not defined in the code: MBINIT has no REPAIRVAL iteration count.
  parameter logic [15:0] COUNT_MBINIT_REPAIRVAL = 16'd300,
  // Count not defined in the code: MBINIT has no REVERSALMB iteration count.
  parameter logic [15:0] COUNT_MBINIT_REVERSALMB = 16'd300,
  // Count not clear in the code: the D2C request gives a burst of 2048 UI, but
  // the code does not define the length of the lane ID pattern.
  parameter logic [15:0] COUNT_MBINIT_REPAIRMB = 16'd300,
  // MBTrain_ValidVrefStateCore: 128 repetitions of 11110000 = 1024 UI.
  parameter logic [15:0] COUNT_MBTRAIN_VALVREF = 16'd128,
  // Count not clear in the code: 4096 UI burst, but the number of UI per return
  // edge is not defined. Same for all the LFSR states below.
  parameter logic [15:0] COUNT_MBTRAIN_DATAVREF = 16'd300,
  // MBTrain_ValTrainCenterFSM: 1024 UI burst of the 8 UI VALTRAIN pattern.
  parameter logic [15:0] COUNT_MBTRAIN_VALTRAINCENTER = 16'd128,
  // Same core and burst as VALVREF.
  parameter logic [15:0] COUNT_MBTRAIN_VALTRAINVREF = 16'd128,
  // Count not clear in the code: 4096 UI burst.
  parameter logic [15:0] COUNT_MBTRAIN_DATATRAINCENTER1 = 16'd300,
  // Count not clear in the code: 4096 UI burst.
  parameter logic [15:0] COUNT_MBTRAIN_DATATRAINVREF = 16'd300,
  // Count not clear in the code: 4096 UI burst.
  parameter logic [15:0] COUNT_MBTRAIN_RXDESKEW = 16'd300,
  // Count not clear in the code: 4096 UI burst.
  parameter logic [15:0] COUNT_MBTRAIN_DATATRAINCENTER2 = 16'd300,
  // Count not clear in the code: 4096 UI burst.
  parameter logic [15:0] COUNT_MBTRAIN_LINKSPEED = 16'd300,
  // Used if a shared MBTRAIN flag rises in an unexpected state (should not occur).
  parameter logic [15:0] COUNT_UNEXPECTED_STATE = 16'd300
) (
  input wire logic clock,
  input wire logic reset_n,

  // ==========================================================================
  // LTSM STATE
  // Selects the count of the shared MBTRAIN flags and detects a state change.
  // ==========================================================================
  input wire logic [3:0] ltsm_state,
  input wire logic [2:0] ltsm_dbg_mbinitSubstate,
  input wire logic [3:0] ltsm_dbg_mbtrainState,

  // ==========================================================================
  // LTSM SEND REQUESTS
  // ==========================================================================
  input wire logic ltsm_flagToAnalog_SendClkPatterns,
  input wire logic ltsm_flagToAnalog_SendValTrainPattern,
  input wire logic ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
  input wire logic ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
  input wire logic ltsm_flagToAnalog_valVref_sendPattern,
  input wire logic ltsm_flagToAnalog_dataVref_sendPattern,
  input wire logic ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
  input wire logic ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,

  // ==========================================================================
  // LTSM COMPLETION PULSES
  // One clock wide, one per send request above.
  // ==========================================================================
  output var logic ltsm_flagFromAnalog_FinishedClkPatterns,
  output var logic ltsm_flagFromAnalog_FinishedValTrainPattern,
  output var logic ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  output var logic ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
  output var logic ltsm_flagFromAnalog_valVref_finishedPattern,
  output var logic ltsm_flagFromAnalog_dataVref_finishedPattern,
  output var logic ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
  output var logic ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,

  // ==========================================================================
  // ANALOG PHY CONTROL
  // ==========================================================================
  output var logic phy_sendClkRepairPattern,
  output var logic phy_sendValTrainPattern,
  output var logic phy_sendLaneIdPattern,
  output var logic phy_sendLfsrPattern,
  input wire logic phy_patternSent
);
  // MBTrainFSM.State_t encoding, seen on ltsm_dbg_mbtrainState.
  typedef enum logic [3:0] {
    MBTrainState_VALVREF = 4'h1,
    MBTrainState_DATAVREF = 4'h2,
    MBTrainState_VALTRAINCENTER = 4'h6,
    MBTrainState_VALTRAINVREF = 4'h7,
    MBTrainState_DATATRAINCENTER1 = 4'h8,
    MBTrainState_DATATRAINVREF = 4'h9,
    MBTrainState_RXDESKEW = 4'hA,
    MBTrainState_DATATRAINCENTER2 = 4'hB,
    MBTrainState_LINKSPEED = 4'hC
  } MBTrainState_t;

  // One-hot: each bit drives one phy_send* output directly from a register.
  typedef enum logic [3:0] {
    Pattern_none = 4'b0000,
    Pattern_clkRepair = 4'b0001,
    Pattern_valTrain = 4'b0010,
    Pattern_laneId = 4'b0100,
    Pattern_lfsr = 4'b1000
  } Pattern_t;

  localparam int unsigned REQ_REPAIRCLK = 0;
  localparam int unsigned REQ_REPAIRVAL = 1;
  localparam int unsigned REQ_REVERSALMB = 2;
  localparam int unsigned REQ_REPAIRMB = 3;
  localparam int unsigned REQ_VALVREF = 4;
  localparam int unsigned REQ_DATAVREF = 5;
  localparam int unsigned REQ_D2C_VALTRAIN = 6;
  localparam int unsigned REQ_D2C_LFSR = 7;
  localparam int unsigned REQ_RXDESKEW = 8;
  localparam int unsigned REQ_COUNT = 9;

  // Requests held high during the burst: if they fall, the burst is aborted.
  // The MBINIT requests are one-clock pulses and are not part of this mask.
  localparam logic [REQ_COUNT-1:0] REQ_HELD_MASK = 9'b1_1111_0000;

  (* keep = "true" *) Pattern_t patternReg;
  (* keep = "true" *) logic [15:0] targetCountReg;
  (* keep = "true" *) logic [15:0] sentCountReg;
  (* keep = "true" *) logic [REQ_COUNT-1:0] activeRequestReg;
  (* keep = "true" *) logic [REQ_COUNT-1:0] previousRequestReg;
  (* keep = "true" *) logic [REQ_COUNT-1:0] finishedReg;
  (* keep = "true" *) logic [10:0] activeLtsmContextReg;
  (* keep = "true" *) logic previousPatternSentSync;

  logic patternSentSync;
  logic [REQ_COUNT-1:0] request;
  logic [REQ_COUNT-1:0] requestRise;
  logic [10:0] ltsmContext;
  logic busy;
  logic abortBurst;
  logic startBurst;
  logic patternSentRise;
  Pattern_t requestedPattern;
  logic [15:0] requestedCount;
  logic unexpectedMbtrainState;

  // phy_patternSent is generated by the analog PHY, asynchronous to clock.
  tc_sync #(.Stages(2)) u_pattern_sent_sync (
    .clk_i(clock), .rst_ni(reset_n),
    .serial_i(phy_patternSent),
    .serial_o(patternSentSync)
  );

  assign request[REQ_REPAIRCLK] = ltsm_flagToAnalog_SendClkPatterns;
  assign request[REQ_REPAIRVAL] = ltsm_flagToAnalog_SendValTrainPattern;
  assign request[REQ_REVERSALMB] = ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  assign request[REQ_REPAIRMB] = ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
  assign request[REQ_VALVREF] = ltsm_flagToAnalog_valVref_sendPattern;
  assign request[REQ_DATAVREF] = ltsm_flagToAnalog_dataVref_sendPattern;
  assign request[REQ_D2C_VALTRAIN] = ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
  assign request[REQ_D2C_LFSR] = ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
  assign request[REQ_RXDESKEW] = ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;

  assign ltsmContext = {ltsm_state, ltsm_dbg_mbinitSubstate, ltsm_dbg_mbtrainState};
  assign requestRise = request & ~previousRequestReg;
  assign patternSentRise = patternSentSync && !previousPatternSentSync;
  assign busy = (patternReg != Pattern_none);
  assign abortBurst = busy &&
    ((ltsmContext != activeLtsmContextReg) ||
     (|(activeRequestReg & REQ_HELD_MASK & ~request)));
  // A new state may raise its request in the same cycle that aborts the old burst.
  assign startBurst = (|requestRise) && (!busy || abortBurst);

  // State -> pattern and count. See the table in the header.
  always_comb begin
    requestedPattern = Pattern_none;
    requestedCount = COUNT_UNEXPECTED_STATE;
    unexpectedMbtrainState = 1'b0;

    if (requestRise[REQ_REPAIRCLK]) begin
      // MBINIT.REPAIRCLK
      requestedPattern = Pattern_clkRepair;
      requestedCount = COUNT_MBINIT_REPAIRCLK;
    end else if (requestRise[REQ_REPAIRVAL]) begin
      // MBINIT.REPAIRVAL
      requestedPattern = Pattern_valTrain;
      requestedCount = COUNT_MBINIT_REPAIRVAL;
    end else if (requestRise[REQ_REVERSALMB]) begin
      // MBINIT.REVERSALMB
      requestedPattern = Pattern_laneId;
      requestedCount = COUNT_MBINIT_REVERSALMB;
    end else if (requestRise[REQ_REPAIRMB]) begin
      // MBINIT.REPAIRMB
      requestedPattern = Pattern_laneId;
      requestedCount = COUNT_MBINIT_REPAIRMB;
    end else if (requestRise[REQ_VALVREF]) begin
      requestedPattern = Pattern_valTrain;
      case (ltsm_dbg_mbtrainState)
        MBTrainState_VALVREF: requestedCount = COUNT_MBTRAIN_VALVREF;
        MBTrainState_VALTRAINVREF: requestedCount = COUNT_MBTRAIN_VALTRAINVREF;
        default: unexpectedMbtrainState = 1'b1;
      endcase
    end else if (requestRise[REQ_DATAVREF]) begin
      requestedPattern = Pattern_lfsr;
      case (ltsm_dbg_mbtrainState)
        MBTrainState_DATAVREF: requestedCount = COUNT_MBTRAIN_DATAVREF;
        MBTrainState_DATATRAINVREF: requestedCount = COUNT_MBTRAIN_DATATRAINVREF;
        default: unexpectedMbtrainState = 1'b1;
      endcase
    end else if (requestRise[REQ_D2C_VALTRAIN]) begin
      // MBTRAIN.VALTRAINCENTER
      requestedPattern = Pattern_valTrain;
      requestedCount = COUNT_MBTRAIN_VALTRAINCENTER;
    end else if (requestRise[REQ_D2C_LFSR]) begin
      requestedPattern = Pattern_lfsr;
      case (ltsm_dbg_mbtrainState)
        MBTrainState_DATATRAINCENTER1: requestedCount = COUNT_MBTRAIN_DATATRAINCENTER1;
        MBTrainState_DATATRAINCENTER2: requestedCount = COUNT_MBTRAIN_DATATRAINCENTER2;
        MBTrainState_LINKSPEED: requestedCount = COUNT_MBTRAIN_LINKSPEED;
        default: unexpectedMbtrainState = 1'b1;
      endcase
    end else if (requestRise[REQ_RXDESKEW]) begin
      // MBTRAIN.RXDESKEW
      requestedPattern = Pattern_lfsr;
      requestedCount = COUNT_MBTRAIN_RXDESKEW;
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      patternReg <= Pattern_none;
      targetCountReg <= 16'd0;
      sentCountReg <= 16'd0;
      activeRequestReg <= '0;
      previousRequestReg <= '0;
      finishedReg <= '0;
      activeLtsmContextReg <= '0;
      previousPatternSentSync <= 1'b0;
    end else begin
      previousRequestReg <= request;
      previousPatternSentSync <= patternSentSync;
      finishedReg <= '0;

      if (startBurst) begin
        patternReg <= requestedPattern;
        targetCountReg <= requestedCount;
        sentCountReg <= 16'd0;
        // Lowest set bit: same priority as the if-chain above.
        activeRequestReg <= requestRise & (~requestRise + 1'b1);
        activeLtsmContextReg <= ltsmContext;
      end else if (abortBurst) begin
        patternReg <= Pattern_none;
        activeRequestReg <= '0;
      end else if (busy && patternSentRise) begin
        if (sentCountReg + 16'd1 == targetCountReg) begin
          patternReg <= Pattern_none;
          activeRequestReg <= '0;
          finishedReg <= activeRequestReg;
        end else begin
          sentCountReg <= sentCountReg + 16'd1;
        end
      end
    end
  end

  always_comb begin
    phy_sendClkRepairPattern = patternReg[0];
    phy_sendValTrainPattern = patternReg[1];
    phy_sendLaneIdPattern = patternReg[2];
    phy_sendLfsrPattern = patternReg[3];

    ltsm_flagFromAnalog_FinishedClkPatterns = finishedReg[REQ_REPAIRCLK];
    ltsm_flagFromAnalog_FinishedValTrainPattern = finishedReg[REQ_REPAIRVAL];
    ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = finishedReg[REQ_REVERSALMB];
    ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = finishedReg[REQ_REPAIRMB];
    ltsm_flagFromAnalog_valVref_finishedPattern = finishedReg[REQ_VALVREF];
    ltsm_flagFromAnalog_dataVref_finishedPattern = finishedReg[REQ_DATAVREF];
    ltsm_flagFromAnalog_d2cSender_valTrainPatternSent = finishedReg[REQ_D2C_VALTRAIN];
    ltsm_flagFromAnalog_d2cSender_lfsrPatternSent = finishedReg[REQ_D2C_LFSR];
    ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent = finishedReg[REQ_RXDESKEW];
  end

`ifndef SYNTHESIS
  // The LTSM sends one pattern at a time; a request raised during a burst would
  // never get its Finished pulse.
  always_ff @(posedge clock) begin
    if (reset_n) begin
      if (!$onehot0(requestRise))
        $error("LtsmPhyPatternAdapter: several send requests in one cycle (%b)", requestRise);
      if ((|requestRise) && !startBurst)
        $error("LtsmPhyPatternAdapter: send request %b ignored, burst in progress", requestRise);
      if (startBurst && (requestedCount == 16'd0))
        $error("LtsmPhyPatternAdapter: count of 0 for request %b", requestRise);
      if (startBurst && unexpectedMbtrainState)
        $error("LtsmPhyPatternAdapter: request %b in unexpected MBTRAIN state %h",
               requestRise, ltsm_dbg_mbtrainState);
    end
  end
`endif
endmodule

`default_nettype wire
