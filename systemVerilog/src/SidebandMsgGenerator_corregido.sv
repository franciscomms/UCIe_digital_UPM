// Hand-translated synthesizable SystemVerilog.
// Source: SidebandMsgGenerator(4).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package SidebandMsgGenerator_pkg;
  parameter int unsigned MESSAGE_WIDTH = 128;
  parameter int unsigned HEADER_WIDTH  = 64;
  parameter int unsigned PAYLOAD_WIDTH = 64;

  // UCIe 2.0 packet opcodes used by the source.
  localparam logic [4:0] OPCODE_MSG_WITHOUT_DATA = 5'b10010;
  localparam logic [4:0] OPCODE_MSG_WITH_DATA    = 5'b11011;

  // Synthesizable replacements for the Scala string-to-endpoint mapping.
  localparam logic [2:0] ENDPOINT_STACK0     = 3'b000;
  localparam logic [2:0] ENDPOINT_D2D        = 3'b001;
  localparam logic [2:0] ENDPOINT_PHY        = 3'b010;
  localparam logic [2:0] ENDPOINT_MPG        = 3'b011;
  localparam logic [2:0] ENDPOINT_STACK1     = 3'b100;
  localparam logic [2:0] ENDPOINT_REMOTE_D2D = 3'b101;
  localparam logic [2:0] ENDPOINT_REMOTE_PHY = 3'b110;
  localparam logic [2:0] ENDPOINT_REMOTE_MPG = 3'b111;

  // Build the common 64-bit sideband header.
  function automatic logic [63:0] buildHeader(
    input logic [15:0] msgInfo,
    input logic [7:0]  msgCode,
    input logic [7:0]  msgSub,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id,
    input logic [4:0]  opcode,
    input logic        dp
  );
    logic [61:0] tail;
    logic        cp;
    tail = {
      3'b000,
      dst_id,
      msgInfo,
      msgSub,
      src_id,
      2'b00,
      5'b00000,
      msgCode,
      9'b000000000,
      opcode
    };
    cp = ^tail;
    buildHeader = {dp, cp, tail};
  endfunction

  function automatic logic [127:0] msgWithoutPayloadBase(
    input logic [15:0] msgInfo,
    input logic [7:0]  msgCode,
    input logic [7:0]  msgSub,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id
  );
    logic [63:0] header;
    header = buildHeader(msgInfo, msgCode, msgSub, src_id, dst_id,
                         OPCODE_MSG_WITHOUT_DATA, 1'b0);
    msgWithoutPayloadBase = {64'b0, header};
  endfunction

  function automatic logic [127:0] msgWithPayloadBase(
    input logic [15:0] msgInfo,
    input logic [7:0]  msgCode,
    input logic [7:0]  msgSub,
    input logic [63:0] payload,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id
  );
    logic        dp;
    logic [63:0] header;
    dp = ^payload;
    header = buildHeader(msgInfo, msgCode, msgSub, src_id, dst_id,
                         OPCODE_MSG_WITH_DATA, dp);
    msgWithPayloadBase = {payload, header};
  endfunction

  function automatic logic [63:0] headerOf(input logic [127:0] message);
    headerOf = message[63:0];
  endfunction

  function automatic logic [63:0] payloadOf(input logic [127:0] message);
    payloadOf = message[127:64];
  endfunction

  function automatic logic hasPayload(input logic [127:0] message);
    hasPayload = (message[4:0] == OPCODE_MSG_WITH_DATA);
  endfunction

  // Message wrappers translated from the Scala object. String src/dst arguments
  // are represented by the 3-bit endpoint IDs above so every function remains RTL-synthesizable.
  // -------------------------------------------------------------------------------------------------------
  // SBINIT messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgSbinitOutOfResetSuccess(//mirar, pasar bit de success como parametro
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitOutOfResetSuccess = msgWithoutPayloadBase(16'b0000000000000001, 8'h91, 8'h00, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitOutOfResetFailure(//mirar, pasar bit de success como parametro
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitOutOfResetFailure = msgWithoutPayloadBase(16'b0000000000000000, 8'h91, 8'h00, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitDoneReq = msgWithoutPayloadBase(16'd0, 8'h95, 8'h01, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitDoneResp = msgWithoutPayloadBase(16'd0, 8'h9A, 8'h01, src_id, dst_id);
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.PARAM and MBINIT.CAL messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitParamConfigReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic sbFeatureExtension,
    input logic ucieA,
    input logic [1:0] moduleID,
    input logic clkPhase,
    input logic clkMode,
    input logic [4:0] voltageSwing,
    input logic [3:0] maxLinkSpeed
  );
    logic [63:0] payload;
    payload = {49'd0, sbFeatureExtension, ucieA, moduleID[1:0], clkPhase, clkMode, voltageSwing[4:0], maxLinkSpeed[3:0]};
    msgMbinitParamConfigReq = msgWithPayloadBase( 16'b0000000000000000, 8'hA5, 8'h00, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitParamConfigResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic clkPhase,
    input logic clkMode,
    input logic [3:0] maxLinkSpeed
  );
    logic [63:0] payload;
    payload = {53'd0, clkPhase, clkMode, 5'd0, maxLinkSpeed[3:0]};
    msgMbinitParamConfigResp = msgWithPayloadBase( 16'b0000000000000000, 8'hAA, 8'h00, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitCalDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitCalDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitCalDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitCalDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h02, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REPAIRCLK messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitRepairClkInitReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkInitReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkInitResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkInitResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkResultReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkResultReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkResultResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [0:0] RTRK_L,
    input logic [0:0] RCKN_L,
    input logic [0:0] RCKP_L
  );
    msgMbinitRepairClkResultResp = msgWithoutPayloadBase( {13'd0, RTRK_L[0], RCKN_L[0], RCKP_L[0]}, 8'hAA, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h08, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h08, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REPAIRVAL messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitRepairValInitReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValInitReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValInitResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValInitResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValResultReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValResultReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0A, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValResultResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [0:0] RVLD_L
  );
    msgMbinitRepairValResultResp = msgWithoutPayloadBase( {15'd0, RVLD_L[0]}, 8'hAA, 8'h0A, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0C, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0C, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REVERSALMB messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitReversalMbInitReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbInitReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0D, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbInitResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbInitResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0D, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbClearErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbClearErrorReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0E, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbClearErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbClearErrorResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0E, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbResultReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbResultReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0F, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbResultResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] RD_L_15to0
  );
    msgMbinitReversalMbResultResp = msgWithPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0F, {48'd0, RD_L_15to0[15:0]}, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h10, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h10, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REPAIRMB messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitRepairMbStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbStartTxInitD2CPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    logic [63:0] payload;
    payload = {4'd0, comparisonMode[0], iterationCountSettings[15:0], idleCountSettings[15:0], burstCountSettings[15:0], patternMode[0], clockPhaseControl[3:0], validPattern[2:0], dataPattern[2:0]};
    msgMbinitRepairMbStartTxInitD2CPointTestReq = msgWithPayloadBase( msgInfo[15:0], 8'h85, 8'h01, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbStartTxInitD2CPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbStartTxInitD2CPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h01, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbLfsrClearErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbLfsrClearErrorReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbLfsrClearErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbLfsrClearErrorResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbTxInitD2CResultsReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbTxInitD2CResultsReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbTxInitD2CResultsResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [63:0] payload
  );
    msgMbinitRepairMbTxInitD2CResultsResp = msgWithPayloadBase( msgInfo[15:0], 8'h8A, 8'h03, payload[63:0], src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndTxInitD2CPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndTxInitD2CPointTestReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndTxInitD2CPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndTxInitD2CPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbApplyDegradeReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [2:0] laneMap
  );
    msgMbinitRepairMbApplyDegradeReq = msgWithoutPayloadBase( {13'd0, laneMap[2:0]}, 8'hA5, 8'h14, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbApplyDegradeResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbApplyDegradeResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h14, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h13, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h13, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBTRAIN messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbtrainValVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h00, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h00, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefEndReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h01, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefEndResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h01, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefStartRxInitD2CPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    logic [63:0] payload;
    payload = {4'd0, comparisonMode[0], iterationCountSettings[15:0], idleCountSettings[15:0], burstCountSettings[15:0], patternMode[0], clockPhaseControl[3:0], validPattern[2:0], dataPattern[2:0]};
    msgMbtrainValVrefStartRxInitD2CPointTestReq = msgWithPayloadBase( msgInfo[15:0], 8'h85, 8'h07, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefStartRxInitD2CPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefStartRxInitD2CPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h07, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainLfsrClearErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLfsrClearErrorReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainLfsrClearErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLfsrClearErrorResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CTxCountDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CTxCountDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h08, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CTxCountDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CTxCountDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h08, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CEndPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CEndPointTestReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CEndPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CEndPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartRxInitD2CPointTestReq(//Mirar, es el mismo codigo del msgMbtrainValVrefStartRxInitD2CPointTestReq, se puede usar el mismo mensaje
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    msgMbtrainDataVrefStartRxInitD2CPointTestReq = msgMbtrainValVrefStartRxInitD2CPointTestReq( src_id, dst_id, msgInfo, comparisonMode, iterationCountSettings, idleCountSettings, burstCountSettings, patternMode, clockPhaseControl, validPattern, dataPattern );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartRxInitD2CPointTestResp(//Mirar, es el mismo codigo del msgMbtrainValVrefStartRxInitD2CPointTestResp, se puede usar el mismo mensaje
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefStartRxInitD2CPointTestResp = msgMbtrainValVrefStartRxInitD2CPointTestResp(src_id, dst_id);
  endfunction


  function automatic logic [127:0] msgMbtrainDataVrefEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefEndReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefEndResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h03, src_id, dst_id );
  endfunction

  
  function automatic logic [127:0] msgMbtrainSpeedIdleDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainSpeedIdleDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainSpeedIdleDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainSpeedIdleDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainTxSelfCalDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainTxSelfCalDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h05, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainTxSelfCalDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainTxSelfCalDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h05, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h06, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h06, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h07, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h07, src_id, dst_id );
  endfunction

    function automatic logic [127:0] msgMbtrainValTrainCenterStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h08, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainCenterStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h08, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainCenterDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterDoneReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h09, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainCenterDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterDoneResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h09, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h0A, src_id, dst_id);
  endfunction
  
  function automatic logic [127:0] msgMbtrainValTrainVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h0A, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainVrefDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefDoneReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h0B, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainVrefDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefDoneResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h0B, src_id, dst_id);
  endfunction


  function automatic logic [127:0] msgMbtrainDataTrainCenter1StartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1StartReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h0C, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter1StartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1StartResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h0C, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter1EndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1EndReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h0D, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter1EndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1EndResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h0D, src_id, dst_id );
  endfunction
  
  function automatic logic [127:0] msgMbtrainDataTrainVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h0E, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h0E, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainVrefEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefEndReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h10, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainVrefEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefEndResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h10, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewStartReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewStartResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewEndReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h12, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewEndResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h12, src_id, dst_id );
  endfunction


  function automatic logic [127:0] msgMbtrainDataTrainCenter2StartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2StartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h13, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter2StartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2StartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h13, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter2EndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2EndReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h14, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter2EndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2EndResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h14, src_id, dst_id);
  endfunction



  function automatic logic [127:0] msgMbtrainStartTxInitD2CPointTestReq(
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    logic [63:0] payload;
    payload = {4'd0, comparisonMode[0], iterationCountSettings[15:0], idleCountSettings[15:0], burstCountSettings[15:0], patternMode[0], clockPhaseControl[3:0], validPattern[2:0], dataPattern[2:0]};
    msgMbtrainStartTxInitD2CPointTestReq = msgWithPayloadBase(msgInfo[15:0], 8'h85, 8'h01, payload, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainStartTxInitD2CPointTestResp(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainStartTxInitD2CPointTestResp = msgWithoutPayloadBase(16'd0, 8'h8A, 8'h01, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainTxInitD2CResultsReq(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainTxInitD2CResultsReq = msgWithoutPayloadBase(16'd0, 8'h85, 8'h03, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainTxInitD2CResultsResp(
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [63:0] payload
  );
    msgMbtrainTxInitD2CResultsResp = msgWithPayloadBase(msgInfo[15:0], 8'h8A, 8'h03, payload[63:0], src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainEndTxInitD2CPointTestReq(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainEndTxInitD2CPointTestReq = msgWithoutPayloadBase(16'd0, 8'h85, 8'h04, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainEndTxInitD2CPointTestResp(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainEndTxInitD2CPointTestResp = msgWithoutPayloadBase(16'd0, 8'h8A, 8'h04, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitClkPattern();
    msgSbinitClkPattern = {64'd0, 64'h5555555555555555};
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h15, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h15, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedErrorReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h16, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedErrorResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h16, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedDoneReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h19, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedDoneResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h19, src_id, dst_id);
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // UCIe2 constants and helpers (flat SystemVerilog names mirror the Scala object hierarchy).
  // -------------------------------------------------------------------------------------------------------
  localparam logic [4:0] UCIe2_PacketOpcode_MSG_WITHOUT_DATA = OPCODE_MSG_WITHOUT_DATA;
  localparam logic [4:0] UCIe2_PacketOpcode_MSG_WITH_64B_DATA = OPCODE_MSG_WITH_DATA;

  localparam logic [15:0] UCIe2_MsgInfo_REGULAR                    = 16'h0000;
  localparam logic [15:0] UCIe2_MsgInfo_STALL                      = 16'hFFFF;
  localparam logic [15:0] UCIe2_MsgInfo_STACK0_OR_POST_NEGOTIATION = 16'h0000;
  localparam logic [15:0] UCIe2_MsgInfo_STACK1_POST_NEGOTIATION    = 16'h0001;

  function automatic logic UCIe2_MsgInfo_isStall(input logic [15:0] info);
    UCIe2_MsgInfo_isStall = (info == UCIe2_MsgInfo_STALL);
  endfunction

  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_RDI_REQ       = 8'h01;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_RDI_RSP       = 8'h02;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ  = 8'h03;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP  = 8'h04;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER1_REQ  = 8'h05;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER1_RSP  = 8'h06;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ     = 8'h07;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK = 8'h08;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ERR_MSG                = 8'h09;

  localparam logic [7:0] UCIe2_LinkMgmtSubCode_ACTIVE    = 8'h01;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_PMNAK     = 8'h02;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_L1        = 8'h04;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_L2        = 8'h08;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_LINKRESET = 8'h09;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_LINKERROR = 8'h0A;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_RETRAIN   = 8'h0B;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_DISABLE   = 8'h0C;

  localparam logic [7:0] UCIe2_ParamExch_ADV_CAP_MSGCODE = 8'h01;
  localparam logic [7:0] UCIe2_ParamExch_FIN_CAP_MSGCODE = 8'h02;
  localparam logic [7:0] UCIe2_ParamExch_SUB_ADAPTER     = 8'h00;
  localparam logic [7:0] UCIe2_ParamExch_SUB_CXL         = 8'h01;
  localparam logic [7:0] UCIe2_ParamExch_SUB_MULTIPROT   = 8'h02;

  localparam logic [7:0] UCIe2_ParityFeature_SUB_REQ_ACK = 8'h00;
  localparam logic [7:0] UCIe2_ParityFeature_SUB_NAK     = 8'h01;

  localparam logic [7:0] UCIe2_ErrMsg_CORRECTABLE = 8'h00;
  localparam logic [7:0] UCIe2_ErrMsg_NON_FATAL   = 8'h01;
  localparam logic [7:0] UCIe2_ErrMsg_FATAL       = 8'h02;

  localparam logic [7:0] UCIe2_LtsmMsgCode_SBINIT_OUT_OF_RESET = 8'h91;
  localparam logic [7:0] UCIe2_LtsmMsgCode_SBINIT_DONE_REQ     = 8'h95;
  localparam logic [7:0] UCIe2_LtsmMsgCode_SBINIT_DONE_RSP     = 8'h9A;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBINIT_REQ           = 8'hA5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBINIT_RSP           = 8'hAA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBTRAIN_REQ          = 8'hB5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBTRAIN_RSP          = 8'hBA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINING_DATA_REQ    = 8'h85;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINING_DATA_RSP    = 8'h8A;
  localparam logic [7:0] UCIe2_LtsmMsgCode_PHYRETRAIN_REQ       = 8'hC5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_PHYRETRAIN_RSP       = 8'hCA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_RECAL_REQ            = 8'hD5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_RECAL_RSP            = 8'hDA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINERROR_REQ       = 8'hE5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINERROR_RSP       = 8'hEA;

  function automatic logic [63:0] UCIe2_Field_header(input logic [127:0] message);
    UCIe2_Field_header = message[63:0];
  endfunction
  function automatic logic [63:0] UCIe2_Field_payload(input logic [127:0] message);
    UCIe2_Field_payload = message[127:64];
  endfunction
  function automatic logic [4:0] UCIe2_Field_opcode(input logic [127:0] message);
    UCIe2_Field_opcode = message[4:0];
  endfunction
  function automatic logic [7:0] UCIe2_Field_msgCode(input logic [127:0] message);
    UCIe2_Field_msgCode = message[21:14];
  endfunction
  function automatic logic [2:0] UCIe2_Field_srcId(input logic [127:0] message);
    UCIe2_Field_srcId = message[31:29];
  endfunction
  function automatic logic [7:0] UCIe2_Field_msgSub(input logic [127:0] message);
    UCIe2_Field_msgSub = message[39:32];
  endfunction
  function automatic logic [15:0] UCIe2_Field_msgInfo(input logic [127:0] message);
    UCIe2_Field_msgInfo = message[55:40];
  endfunction
  function automatic logic [2:0] UCIe2_Field_dstId(input logic [127:0] message);
    UCIe2_Field_dstId = message[58:56];
  endfunction
  function automatic logic UCIe2_Field_controlParity(input logic [127:0] message);
    UCIe2_Field_controlParity = message[62];
  endfunction
  function automatic logic UCIe2_Field_dataParity(input logic [127:0] message);
    UCIe2_Field_dataParity = message[63];
  endfunction

  typedef enum logic [3:0] {
    UCIe2_Route_NONE       = 4'd0,
    UCIe2_Route_LTSM       = 4'd1,
    UCIe2_Route_RDI        = 4'd2,
    UCIe2_Route_ADAPTER0   = 4'd3,
    UCIe2_Route_ADAPTER1   = 4'd4,
    UCIe2_Route_D2D_COMMON = 4'd5,
    UCIe2_Route_MPG        = 4'd6,
    UCIe2_Route_VENDOR     = 4'd7,
    UCIe2_Route_UNKNOWN    = 4'd8
  } UCIe2_Route_t;

  function automatic logic [127:0] UCIe2_RDI_req(
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_RDI_req = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_RDI_REQ,
                                          sub, src_id, dst_id);
  endfunction

  function automatic logic [127:0] UCIe2_RDI_rsp(
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_RDI_rsp = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_RDI_RSP,
                                          sub, src_id, dst_id);
  endfunction

  function automatic logic [127:0] UCIe2_RDI_reqActive(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqActive = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspActive(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspActive = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspPMNAK(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_rspPMNAK = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_PMNAK, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqL1(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqL1 = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspL1(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_rspL1 = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqL2(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqL2 = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspL2(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_rspL2 = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqLinkReset(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqLinkReset = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspLinkReset(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspLinkReset = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqLinkError(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqLinkError = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_LINKERROR, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspLinkError(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspLinkError = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_LINKERROR, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqRetrain(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqRetrain = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_RETRAIN, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspRetrain(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspRetrain = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_RETRAIN, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqDisable(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqDisable = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspDisable(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspDisable = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, info);
  endfunction

  function automatic logic [7:0] UCIe2_Adapter_reqMsgCode(input int unsigned stack);
    UCIe2_Adapter_reqMsgCode = (stack == 0) ? UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ
                                            : UCIe2_LinkMgmtMsgCode_ADAPTER1_REQ;
  endfunction
  function automatic logic [7:0] UCIe2_Adapter_rspMsgCode(input int unsigned stack);
    UCIe2_Adapter_rspMsgCode = (stack == 0) ? UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP
                                            : UCIe2_LinkMgmtMsgCode_ADAPTER1_RSP;
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_req(
    input int unsigned stack,
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_Adapter_req = msgWithoutPayloadBase(info, UCIe2_Adapter_reqMsgCode(stack), sub, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rsp(
    input int unsigned stack,
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_Adapter_rsp = msgWithoutPayloadBase(info, UCIe2_Adapter_rspMsgCode(stack), sub, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqActive(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_reqActive = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspActive(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_rspActive = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspPMNAK(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_rspPMNAK = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_PMNAK, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqL1(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqL1 = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspL1(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_rspL1 = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqL2(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqL2 = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspL2(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_rspL2 = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqLinkReset(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqLinkReset = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspLinkReset(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_rspLinkReset = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqDisable(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqDisable = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspDisable(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_rspDisable = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, info);
  endfunction

  function automatic logic [127:0] UCIe2_Common_parityFeatureReq(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_parityFeatureReq = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ, UCIe2_ParityFeature_SUB_REQ_ACK, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_parityFeatureAck(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Common_parityFeatureAck = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK, UCIe2_ParityFeature_SUB_REQ_ACK, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_parityFeatureNak(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Common_parityFeatureNak = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK, UCIe2_ParityFeature_SUB_NAK, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_errCorrectable(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_errCorrectable = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_ERR_MSG, UCIe2_ErrMsg_CORRECTABLE, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_errNonFatal(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_errNonFatal = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_ERR_MSG, UCIe2_ErrMsg_NON_FATAL, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_errFatal(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_errFatal = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_ERR_MSG, UCIe2_ErrMsg_FATAL, src_id, dst_id);
  endfunction

  function automatic logic [127:0] UCIe2_ParamExchange_advCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_advCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_ADV_CAP_MSGCODE, UCIe2_ParamExch_SUB_ADAPTER, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_finCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_finCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_FIN_CAP_MSGCODE, UCIe2_ParamExch_SUB_ADAPTER, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_advCapCxl(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_advCapCxl = msgWithPayloadBase(info, UCIe2_ParamExch_ADV_CAP_MSGCODE, UCIe2_ParamExch_SUB_CXL, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_finCapCxl(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_finCapCxl = msgWithPayloadBase(info, UCIe2_ParamExch_FIN_CAP_MSGCODE, UCIe2_ParamExch_SUB_CXL, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_multiProtAdvCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_multiProtAdvCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_ADV_CAP_MSGCODE, UCIe2_ParamExch_SUB_MULTIPROT, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_multiProtFinCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_multiProtFinCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_FIN_CAP_MSGCODE, UCIe2_ParamExch_SUB_MULTIPROT, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_advCapAdapterStall(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_ParamExchange_advCapAdapterStall = UCIe2_ParamExchange_advCapAdapter(payload, src_id, dst_id, UCIe2_MsgInfo_STALL);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_finCapAdapterStall(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_ParamExchange_finCapAdapterStall = UCIe2_ParamExchange_finCapAdapter(payload, src_id, dst_id, UCIe2_MsgInfo_STALL);
  endfunction

  function automatic logic UCIe2_isMsgWithoutData(input logic [127:0] message);
    UCIe2_isMsgWithoutData = (UCIe2_Field_opcode(message) == UCIe2_PacketOpcode_MSG_WITHOUT_DATA);
  endfunction
  function automatic logic UCIe2_isMsgWith64bData(input logic [127:0] message);
    UCIe2_isMsgWith64bData = (UCIe2_Field_opcode(message) == UCIe2_PacketOpcode_MSG_WITH_64B_DATA);
  endfunction
  function automatic logic UCIe2_hasPayload(input logic [127:0] message);
    UCIe2_hasPayload = UCIe2_isMsgWith64bData(message);
  endfunction
  function automatic logic UCIe2_controlParityOk(input logic [127:0] message);
    logic [63:0] header;
    header = UCIe2_Field_header(message);
    UCIe2_controlParityOk = (UCIe2_Field_controlParity(message) == (^header[61:0]));
  endfunction
  function automatic logic UCIe2_dataParityOk(input logic [127:0] message);
    UCIe2_dataParityOk = UCIe2_hasPayload(message)
      ? (UCIe2_Field_dataParity(message) == (^UCIe2_Field_payload(message)))
      : (UCIe2_Field_dataParity(message) == 1'b0);
  endfunction
  function automatic logic UCIe2_isRdiLinkMgmtReq(input logic [127:0] message);
    UCIe2_isRdiLinkMgmtReq = UCIe2_isMsgWithoutData(message) &&
      (UCIe2_Field_msgCode(message) == UCIe2_LinkMgmtMsgCode_RDI_REQ);
  endfunction
  function automatic logic UCIe2_isRdiLinkMgmtRsp(input logic [127:0] message);
    UCIe2_isRdiLinkMgmtRsp = UCIe2_isMsgWithoutData(message) &&
      (UCIe2_Field_msgCode(message) == UCIe2_LinkMgmtMsgCode_RDI_RSP);
  endfunction
  function automatic logic UCIe2_isRdiLinkMgmt(input logic [127:0] message);
    UCIe2_isRdiLinkMgmt = UCIe2_isRdiLinkMgmtReq(message) || UCIe2_isRdiLinkMgmtRsp(message);
  endfunction
  function automatic logic UCIe2_isAdapterLinkMgmtReq(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_isAdapterLinkMgmtReq = UCIe2_isMsgWithoutData(message) &&
      ((code == UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ) ||
       (code == UCIe2_LinkMgmtMsgCode_ADAPTER1_REQ));
  endfunction
  function automatic logic UCIe2_isAdapterLinkMgmtRsp(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_isAdapterLinkMgmtRsp = UCIe2_isMsgWithoutData(message) &&
      ((code == UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP) ||
       (code == UCIe2_LinkMgmtMsgCode_ADAPTER1_RSP));
  endfunction
  function automatic logic UCIe2_isAdapterLinkMgmt(input logic [127:0] message);
    UCIe2_isAdapterLinkMgmt = UCIe2_isAdapterLinkMgmtReq(message) || UCIe2_isAdapterLinkMgmtRsp(message);
  endfunction
  function automatic logic UCIe2_isD2DCommonNoData(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_isD2DCommonNoData = UCIe2_isMsgWithoutData(message) &&
      ((code == UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ) ||
       (code == UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK) ||
       (code == UCIe2_LinkMgmtMsgCode_ERR_MSG));
  endfunction
  function automatic logic UCIe2_isParamExchange(input logic [127:0] message);
    logic [7:0] code;
    logic [7:0] sub;
    code = UCIe2_Field_msgCode(message);
    sub  = UCIe2_Field_msgSub(message);
    UCIe2_isParamExchange = UCIe2_isMsgWith64bData(message) &&
      ((code == UCIe2_ParamExch_ADV_CAP_MSGCODE) ||
       (code == UCIe2_ParamExch_FIN_CAP_MSGCODE)) &&
      ((sub == UCIe2_ParamExch_SUB_ADAPTER) ||
       (sub == UCIe2_ParamExch_SUB_CXL) ||
       (sub == UCIe2_ParamExch_SUB_MULTIPROT));
  endfunction
  function automatic logic UCIe2_isParamExchangeStall(input logic [127:0] message);
    UCIe2_isParamExchangeStall = UCIe2_isParamExchange(message) &&
      (UCIe2_Field_msgInfo(message) == UCIe2_MsgInfo_STALL);
  endfunction
  function automatic logic UCIe2_isSbinitClockPattern(input logic [127:0] message);
    UCIe2_isSbinitClockPattern = (UCIe2_Field_payload(message) == 64'b0) &&
                                 (UCIe2_Field_header(message) == 64'h5555555555555555);
  endfunction
  function automatic logic UCIe2_isLtsmMessage(input logic [127:0] message);
    logic [7:0] code;
    logic codeMatch;
    code = UCIe2_Field_msgCode(message);
    codeMatch =
      (code == UCIe2_LtsmMsgCode_SBINIT_OUT_OF_RESET) ||
      (code == UCIe2_LtsmMsgCode_SBINIT_DONE_REQ) ||
      (code == UCIe2_LtsmMsgCode_SBINIT_DONE_RSP) ||
      (code == UCIe2_LtsmMsgCode_MBINIT_REQ) ||
      (code == UCIe2_LtsmMsgCode_MBINIT_RSP) ||
      (code == UCIe2_LtsmMsgCode_MBTRAIN_REQ) ||
      (code == UCIe2_LtsmMsgCode_MBTRAIN_RSP) ||
      (code == UCIe2_LtsmMsgCode_TRAINING_DATA_REQ) ||
      (code == UCIe2_LtsmMsgCode_TRAINING_DATA_RSP) ||
      (code == UCIe2_LtsmMsgCode_PHYRETRAIN_REQ) ||
      (code == UCIe2_LtsmMsgCode_PHYRETRAIN_RSP) ||
      (code == UCIe2_LtsmMsgCode_RECAL_REQ) ||
      (code == UCIe2_LtsmMsgCode_RECAL_RSP) ||
      (code == UCIe2_LtsmMsgCode_TRAINERROR_REQ) ||
      (code == UCIe2_LtsmMsgCode_TRAINERROR_RSP);
    UCIe2_isLtsmMessage = UCIe2_isSbinitClockPattern(message) ||
      ((UCIe2_isMsgWithoutData(message) || UCIe2_isMsgWith64bData(message)) && codeMatch);
  endfunction
  function automatic UCIe2_Route_t UCIe2_route(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_route = UCIe2_Route_UNKNOWN;
    if (UCIe2_isLtsmMessage(message)) begin
      UCIe2_route = UCIe2_Route_LTSM;
    end else if (UCIe2_isRdiLinkMgmt(message)) begin
      UCIe2_route = UCIe2_Route_RDI;
    end else if (UCIe2_isAdapterLinkMgmt(message)) begin
      if ((code == UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ) ||
          (code == UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP))
        UCIe2_route = UCIe2_Route_ADAPTER0;
      else
        UCIe2_route = UCIe2_Route_ADAPTER1;
    end else if (UCIe2_isD2DCommonNoData(message) || UCIe2_isParamExchange(message)) begin
      UCIe2_route = UCIe2_Route_D2D_COMMON;
    end
  endfunction
  function automatic logic UCIe2_expectsResponse(input logic [127:0] message);
    UCIe2_expectsResponse = UCIe2_isRdiLinkMgmtReq(message) ||
                            UCIe2_isAdapterLinkMgmtReq(message) ||
                            (UCIe2_isMsgWithoutData(message) &&
                             (UCIe2_Field_msgCode(message) == UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ));
  endfunction

  localparam int unsigned UCIe2_Legacy6_WIDTH = 6;
  localparam logic [5:0] UCIe2_Legacy6_NOP           = 6'h00;
  localparam logic [5:0] UCIe2_Legacy6_REQ_ACTIVE    = 6'h01;
  localparam logic [5:0] UCIe2_Legacy6_REQ_L1        = 6'h04;
  localparam logic [5:0] UCIe2_Legacy6_REQ_L2        = 6'h08;
  localparam logic [5:0] UCIe2_Legacy6_REQ_LINKRESET = 6'h09;
  localparam logic [5:0] UCIe2_Legacy6_REQ_LINKERROR = 6'h0A;
  localparam logic [5:0] UCIe2_Legacy6_REQ_RETRAIN   = 6'h0B;
  localparam logic [5:0] UCIe2_Legacy6_REQ_DISABLE   = 6'h0C;
  localparam logic [5:0] UCIe2_Legacy6_RSP_ACTIVE    = 6'h11;
  localparam logic [5:0] UCIe2_Legacy6_RSP_PMNAK     = 6'h12;
  localparam logic [5:0] UCIe2_Legacy6_RSP_L1        = 6'h14;
  localparam logic [5:0] UCIe2_Legacy6_RSP_L2        = 6'h18;
  localparam logic [5:0] UCIe2_Legacy6_RSP_LINKRESET = 6'h19;
  localparam logic [5:0] UCIe2_Legacy6_RSP_LINKERROR = 6'h1A;
  localparam logic [5:0] UCIe2_Legacy6_RSP_RETRAIN   = 6'h1B;
  localparam logic [5:0] UCIe2_Legacy6_RSP_DISABLE   = 6'h1C;

endpackage

`default_nettype wire
