// SystemVerilog translation of D2DAdapterLinkMgmtTopIntegrated128Spec(1).scala.
// Revised to run the complete UCIe 2.0 LTSM training sequence and every
// directed message through production one-bit sideband serializers.
// The 128-bit task arguments are BFM transactions, not DUT packet ports.
// Reset convention: asynchronous active-low reset_n; there is no reset signal.
// Run one scenario with +SCENARIO=<name>, or omit it to run all scenarios.

`timescale 1ns/1ps
`default_nettype none

module D2DAdapterLinkMgmtTopIntegrated128Spec_tb;
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

  localparam logic [15:0] REQUIRED_MBTRAIN_STATE_MASK = 16'h5FFE;
  localparam int unsigned MAX_LTSM_BRINGUP_CYCLES = 1_500_000;

  logic clock = 1'b0;
  logic reset_n = 1'b1;

  PhyStateReq_t fdi_lp_state_req;
  logic fdi_lp_linkerror;
  logic fdi_lp_rx_active_sts;
  logic fdi_lp_wake_req;
  logic fdi_lp_clk_ack;
  logic fdi_lp_stall_ack;
  PhyState_t fdi_pl_state_sts;
  logic fdi_pl_rx_active_req;
  logic fdi_pl_inband_pres;
  logic fdi_pl_wake_ack;
  logic fdi_pl_clk_req;
  logic fdi_pl_stall_req;

  logic ltsm_start;
  logic ltsm_stable_clk;
  logic ltsm_pll_locked;
  logic ltsm_stable_supply;
  logic manual_sideband_mode;
  logic [3:0] local_ltsm_state;
  logic [3:0] peer_ltsm_state;
  logic [2:0] local_mbinit_substate;
  logic [2:0] peer_mbinit_substate;
  logic [3:0] local_mbtrain_state;
  logic [3:0] peer_mbtrain_state;
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  logic [11:0] local_mbtrain_active_substate;
  logic [11:0] peer_mbtrain_active_substate;
  logic local_ltsm_train_error;
  logic peer_ltsm_train_error;
  logic training_complete;
  logic training_sideband_transfer;
  logic training_unknown_drop;
  logic serial_error;
  logic serial_idle;
  bit serial_failure_seen = 1'b0;

  logic sb_tx_valid;
  logic [127:0] sb_tx_msg;
  logic sb_tx_ready;
  logic sb_rx_valid;
  logic [127:0] sb_rx_msg;
  logic sb_rx_ready;
  logic [31:0] cycles_1us;

  LinkInitState_t debug_fdi_link_init_state;
  PhyState_t debug_rdi_state;
  logic debug_arb_grant_ltsm;
  logic debug_arb_grant_fdi;
  logic debug_arb_grant_rdi;
  logic debug_arb_tx_locked;
  logic debug_arb_tx_fire;
  logic debug_rx_drop_unknown;
  logic debug_rx_fire;

  always #5ns clock = ~clock;

  task automatic step(input int unsigned cycles);
    repeat (cycles) begin
      @(posedge clock);
      #1ps;
      if (serial_error === 1'b1) serial_failure_seen = 1'b1;
    end
  endtask

  function automatic logic [63:0] build_header(
    input logic [15:0] msg_info,
    input logic [7:0]  msg_code,
    input logic [7:0]  msg_sub,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id,
    input logic [4:0]  opcode,
    input logic        data_parity
  );
    logic [63:0] tail;
    logic control_parity;
    begin
      tail = 64'b0;
      tail[58:56] = dst_id;
      tail[55:40] = msg_info;
      tail[39:32] = msg_sub;
      tail[31:29] = src_id;
      tail[21:14] = msg_code;
      tail[4:0] = opcode;
      control_parity = ^tail[61:0];
      build_header = {data_parity, control_parity, tail[61:0]};
    end
  endfunction

  function automatic logic [127:0] build_message(
    input logic [63:0] header,
    input logic [63:0] payload
  );
    build_message = {payload, header};
  endfunction

  localparam logic [4:0] MSG_WITHOUT_DATA = 5'h12;
  localparam logic [4:0] MSG_WITH_64B_DATA = 5'h1b;
  localparam logic [2:0] LOCAL_D2D = 3'h1;
  localparam logic [2:0] LOCAL_PHY = 3'h2;
  localparam logic [2:0] REMOTE_D2D = 3'h5;
  localparam logic [2:0] REMOTE_PHY = 3'h6;
  localparam logic [7:0] RDI_REQ = 8'h01;
  localparam logic [7:0] RDI_RSP = 8'h02;
  localparam logic [7:0] ADAPTER0_REQ = 8'h03;
  localparam logic [7:0] ADAPTER0_RSP = 8'h04;
  localparam logic [7:0] SUB_ACTIVE = 8'h01;
  localparam logic [7:0] SUB_LINKRESET = 8'h09;
  localparam logic [7:0] SUB_LINKERROR = 8'h0a;
  localparam logic [7:0] SUB_RETRAIN = 8'h0b;
  localparam logic [7:0] SUB_DISABLE = 8'h0c;
  localparam logic [63:0] RAW_STREAMING_ADV_CAP_PAYLOAD = 64'h0000_0000_0000_0091;

  localparam logic [63:0] LOCAL_RDI_REQ_ACTIVE =
    build_header(16'h0, RDI_REQ, SUB_ACTIVE, LOCAL_PHY, REMOTE_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] LOCAL_RDI_RSP_ACTIVE =
    build_header(16'h0, RDI_RSP, SUB_ACTIVE, LOCAL_PHY, REMOTE_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_RDI_REQ_ACTIVE =
    build_header(16'h0, RDI_REQ, SUB_ACTIVE, REMOTE_PHY, LOCAL_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_RDI_RSP_ACTIVE =
    build_header(16'h0, RDI_RSP, SUB_ACTIVE, REMOTE_PHY, LOCAL_PHY, MSG_WITHOUT_DATA, 1'b0);

  localparam logic [63:0] LOCAL_ADAPTER_REQ_ACTIVE =
    build_header(16'h0, ADAPTER0_REQ, SUB_ACTIVE, LOCAL_D2D, REMOTE_D2D, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] LOCAL_ADAPTER_RSP_ACTIVE =
    build_header(16'h0, ADAPTER0_RSP, SUB_ACTIVE, LOCAL_D2D, REMOTE_D2D, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_ADAPTER_REQ_ACTIVE =
    build_header(16'h0, ADAPTER0_REQ, SUB_ACTIVE, REMOTE_D2D, LOCAL_D2D, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_ADAPTER_RSP_ACTIVE =
    build_header(16'h0, ADAPTER0_RSP, SUB_ACTIVE, REMOTE_D2D, LOCAL_D2D, MSG_WITHOUT_DATA, 1'b0);

  localparam logic [63:0] LOCAL_ADV_CAP_ADAPTER =
    build_header(16'h0, 8'h01, 8'h00, LOCAL_D2D, REMOTE_D2D,
                 MSG_WITH_64B_DATA, ^RAW_STREAMING_ADV_CAP_PAYLOAD);
  localparam logic [63:0] REMOTE_ADV_CAP_ADAPTER =
    build_header(16'h0, 8'h01, 8'h00, REMOTE_D2D, LOCAL_D2D,
                 MSG_WITH_64B_DATA, ^RAW_STREAMING_ADV_CAP_PAYLOAD);

  localparam logic [63:0] LOCAL_RDI_REQ_RETRAIN =
    build_header(16'h0, RDI_REQ, SUB_RETRAIN, LOCAL_PHY, REMOTE_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_RDI_RSP_RETRAIN =
    build_header(16'h0, RDI_RSP, SUB_RETRAIN, REMOTE_PHY, LOCAL_PHY, MSG_WITHOUT_DATA, 1'b0);

  localparam logic [63:0] LOCAL_RDI_REQ_DISABLE =
    build_header(16'h0, RDI_REQ, SUB_DISABLE, LOCAL_PHY, REMOTE_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_RDI_RSP_DISABLE =
    build_header(16'h0, RDI_RSP, SUB_DISABLE, REMOTE_PHY, LOCAL_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] LOCAL_ADAPTER_REQ_DISABLE =
    build_header(16'h0, ADAPTER0_REQ, SUB_DISABLE, LOCAL_D2D, REMOTE_D2D, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_ADAPTER_RSP_DISABLE =
    build_header(16'h0, ADAPTER0_RSP, SUB_DISABLE, REMOTE_D2D, LOCAL_D2D, MSG_WITHOUT_DATA, 1'b0);

  localparam logic [63:0] LOCAL_RDI_REQ_LINKRESET =
    build_header(16'h0, RDI_REQ, SUB_LINKRESET, LOCAL_PHY, REMOTE_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_RDI_RSP_LINKRESET =
    build_header(16'h0, RDI_RSP, SUB_LINKRESET, REMOTE_PHY, LOCAL_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] LOCAL_ADAPTER_REQ_LINKRESET =
    build_header(16'h0, ADAPTER0_REQ, SUB_LINKRESET, LOCAL_D2D, REMOTE_D2D, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_ADAPTER_RSP_LINKRESET =
    build_header(16'h0, ADAPTER0_RSP, SUB_LINKRESET, REMOTE_D2D, LOCAL_D2D, MSG_WITHOUT_DATA, 1'b0);

  localparam logic [63:0] LOCAL_RDI_REQ_LINKERROR =
    build_header(16'h0, RDI_REQ, SUB_LINKERROR, LOCAL_PHY, REMOTE_PHY, MSG_WITHOUT_DATA, 1'b0);
  localparam logic [63:0] REMOTE_RDI_RSP_LINKERROR =
    build_header(16'h0, RDI_RSP, SUB_LINKERROR, REMOTE_PHY, LOCAL_PHY, MSG_WITHOUT_DATA, 1'b0);

  D2DAdapterLinkMgmtLtsmIntegrated128Harness dut (
    .clock(clock),
    .reset_n(reset_n),
    .ltsm_start(ltsm_start),
    .ltsm_stable_clk(ltsm_stable_clk),
    .ltsm_pll_locked(ltsm_pll_locked),
    .ltsm_stable_supply(ltsm_stable_supply),
    .manual_sideband_mode(manual_sideband_mode),
    .fdi_lp_state_req(fdi_lp_state_req),
    .fdi_lp_linkerror(fdi_lp_linkerror),
    .fdi_lp_rx_active_sts(fdi_lp_rx_active_sts),
    .fdi_lp_wake_req(fdi_lp_wake_req),
    .fdi_lp_clk_ack(fdi_lp_clk_ack),
    .fdi_lp_stall_ack(fdi_lp_stall_ack),
    .fdi_pl_state_sts(fdi_pl_state_sts),
    .fdi_pl_rx_active_req(fdi_pl_rx_active_req),
    .fdi_pl_inband_pres(fdi_pl_inband_pres),
    .fdi_pl_wake_ack(fdi_pl_wake_ack),
    .fdi_pl_clk_req(fdi_pl_clk_req),
    .fdi_pl_stall_req(fdi_pl_stall_req),
    .sb_tx_valid(sb_tx_valid),
    .sb_tx_msg(sb_tx_msg),
    .sb_tx_ready(sb_tx_ready),
    .sb_rx_valid(sb_rx_valid),
    .sb_rx_msg(sb_rx_msg),
    .sb_rx_ready(sb_rx_ready),
    .cycles_1us(cycles_1us),
    .local_ltsm_state(local_ltsm_state),
    .peer_ltsm_state(peer_ltsm_state),
    .local_mbinit_substate(local_mbinit_substate),
    .peer_mbinit_substate(peer_mbinit_substate),
    .local_mbtrain_state(local_mbtrain_state),
    .peer_mbtrain_state(peer_mbtrain_state),
    .local_mbtrain_active_substate(local_mbtrain_active_substate),
    .peer_mbtrain_active_substate(peer_mbtrain_active_substate),
    .local_ltsm_train_error(local_ltsm_train_error),
    .peer_ltsm_train_error(peer_ltsm_train_error),
    .training_complete(training_complete),
    .training_sideband_transfer(training_sideband_transfer),
    .training_unknown_drop(training_unknown_drop),
    .serial_error(serial_error),
    .serial_idle(serial_idle),
    .debug_fdi_link_init_state(debug_fdi_link_init_state),
    .debug_rdi_state(debug_rdi_state),
    .debug_arb_grant_ltsm(debug_arb_grant_ltsm),
    .debug_arb_grant_fdi(debug_arb_grant_fdi),
    .debug_arb_grant_rdi(debug_arb_grant_rdi),
    .debug_arb_tx_locked(debug_arb_tx_locked),
    .debug_arb_tx_fire(debug_arb_tx_fire),
    .debug_rx_drop_unknown(debug_rx_drop_unknown),
    .debug_rx_fire(debug_rx_fire)
  );

  task automatic reset_and_initialize(input logic run_ltsm_training);
    int unsigned training_cycles;
    logic [15:0] local_ltsm_visited;
    logic [15:0] peer_ltsm_visited;
    logic [15:0] local_mbtrain_visited;
    logic [15:0] peer_mbtrain_visited;
    logic saw_training_transfer;
    logic saw_training_unknown_drop;
    begin
      // Never use reset to discard an accepted or partially serialized frame
      // from the preceding scenario (including direct Reset-exit subcases).
      if (reset_n && manual_sideband_mode)
        finish_serial_exchange(
          (fdi_pl_state_sts == PhyState_reset) &&
          (debug_rdi_state == PhyState_reset) &&
          (fdi_lp_state_req == PhyStateReq_active));
      fdi_lp_state_req = PhyStateReq_nop;
      fdi_lp_linkerror = 1'b0;
      fdi_lp_rx_active_sts = 1'b0;
      fdi_lp_wake_req = 1'b0;
      fdi_lp_clk_ack = 1'b0;
      fdi_lp_stall_ack = 1'b0;
      ltsm_start = 1'b0;
      ltsm_stable_clk = 1'b0;
      ltsm_pll_locked = 1'b0;
      ltsm_stable_supply = 1'b0;
      manual_sideband_mode = 1'b0;
      cycles_1us = run_ltsm_training ? 32'd1000 : 32'd1;
      sb_tx_ready = 1'b0;
      sb_rx_valid = 1'b0;
      sb_rx_msg = 128'b0;

      reset_n = 1'b0;
      step(3);
      @(negedge clock);
      #1ps;
      reset_n = 1'b1;
      step(1);

      if (local_ltsm_state !== 4'd0 || peer_ltsm_state !== 4'd0)
        $fatal(1, "Post-reset LTSM state mismatch: local=%0d peer=%0d",
               local_ltsm_state, peer_ltsm_state);

      if (run_ltsm_training) begin
        ltsm_start = 1'b1;
        ltsm_stable_clk = 1'b1;
        ltsm_pll_locked = 1'b1;
        ltsm_stable_supply = 1'b1;

        local_ltsm_visited = 16'h0001 << local_ltsm_state;
        peer_ltsm_visited = 16'h0001 << peer_ltsm_state;
        local_mbtrain_visited = 16'h0001 << local_mbtrain_state;
        peer_mbtrain_visited = 16'h0001 << peer_mbtrain_state;
        saw_training_transfer = 1'b0;
        saw_training_unknown_drop = 1'b0;
        training_cycles = 0;

        while (training_cycles < MAX_LTSM_BRINGUP_CYCLES &&
               (training_complete !== 1'b1)) begin
          local_ltsm_visited |= 16'h0001 << local_ltsm_state;
          peer_ltsm_visited |= 16'h0001 << peer_ltsm_state;
          local_mbtrain_visited |= 16'h0001 << local_mbtrain_state;
          peer_mbtrain_visited |= 16'h0001 << peer_mbtrain_state;
          saw_training_transfer |= training_sideband_transfer;
          saw_training_unknown_drop |= training_unknown_drop;

          if ((local_ltsm_train_error === 1'b1) ||
              (peer_ltsm_train_error === 1'b1))
            $fatal(1, "LTSM training error at cycle %0d: LTSM=(%0d,%0d) MBTRAIN=(%0h,%0h)",
                   training_cycles, local_ltsm_state, peer_ltsm_state,
                   local_mbtrain_state, peer_mbtrain_state);
          step(1);
          training_cycles++;
        end

        local_ltsm_visited |= 16'h0001 << local_ltsm_state;
        peer_ltsm_visited |= 16'h0001 << peer_ltsm_state;
        local_mbtrain_visited |= 16'h0001 << local_mbtrain_state;
        peer_mbtrain_visited |= 16'h0001 << peer_mbtrain_state;
        saw_training_transfer |= training_sideband_transfer;
        saw_training_unknown_drop |= training_unknown_drop;

        if (training_complete !== 1'b1)
          $fatal(1, "Timed out after %0d clocks waiting for LTSM training: LTSM=(%0d,%0d) MBTRAIN=(%0h,%0h)",
                 MAX_LTSM_BRINGUP_CYCLES, local_ltsm_state, peer_ltsm_state,
                 local_mbtrain_state, peer_mbtrain_state);
        if ((local_ltsm_visited & 16'h01FF) !== 16'h01FF ||
            (peer_ltsm_visited & 16'h01FF) !== 16'h01FF)
          $fatal(1, "LTSM state coverage mismatch: local=0x%04h peer=0x%04h",
                 local_ltsm_visited, peer_ltsm_visited);
        if ((local_mbtrain_visited & REQUIRED_MBTRAIN_STATE_MASK) !==
              REQUIRED_MBTRAIN_STATE_MASK ||
            (peer_mbtrain_visited & REQUIRED_MBTRAIN_STATE_MASK) !==
              REQUIRED_MBTRAIN_STATE_MASK)
          $fatal(1, "MBTRAIN state coverage mismatch: local=0x%04h peer=0x%04h required=0x%04h",
                 local_mbtrain_visited, peer_mbtrain_visited,
                 REQUIRED_MBTRAIN_STATE_MASK);
        if (saw_training_transfer !== 1'b1)
          $fatal(1, "No LTSM sideband packet traversed the integrated top during training");
        if (saw_training_unknown_drop !== 1'b0)
          $fatal(1, "An LTSM training packet was dropped as an unknown sideband message");

        $display("[ltsm] PASS: cycles=%0d LTSM masks=(0x%04h,0x%04h) MBTRAIN masks=(0x%04h,0x%04h)",
                 training_cycles, local_ltsm_visited, peer_ltsm_visited,
                 local_mbtrain_visited, peer_mbtrain_visited);

        // The harness declares completion only after serial FIFOs, complete
        // wire frames, and the training relay have drained.  Directed task
        // traffic continues through the same local serial pins after this.
        // cycles_1us returns to one for the existing 16-ms residency check;
        // the shortest adapter timer is still 4000 clocks, well above the
        // maximum 192-clock serialized frame and directed response latency.
        manual_sideband_mode = 1'b1;
        cycles_1us = 32'd1;
        step(2);
      end else begin
        // Direct Reset-exit scenarios intentionally keep the physical LTSM in
        // Reset, matching the old explicit ltsm_pl_inband_pres=0 stimulus.
        manual_sideband_mode = 1'b1;
        cycles_1us = 32'd1;
        step(2);
      end
    end
  endtask

  task automatic take_tx_message(
    output logic [63:0] header,
    output logic [63:0] payload,
    output logic has_payload,
    input int unsigned max_cycles
  );
    int unsigned wait_message;
    begin
      sb_tx_ready = 1'b0;
      wait_message = 0;
      while (!sb_tx_valid && wait_message < max_cycles) begin
        step(1);
        wait_message++;
      end
      if (wait_message >= max_cycles)
        $fatal(1, "No TX message within %0d cycles", max_cycles);

      header = sb_tx_msg[63:0];
      payload = sb_tx_msg[127:64];
      has_payload = (header[4:0] == MSG_WITH_64B_DATA);

      sb_tx_ready = 1'b1;
      step(1);
      sb_tx_ready = 1'b0;
    end
  endtask

  task automatic send_rx_message(
    input logic [63:0] header,
    input logic [63:0] payload,
    input logic has_payload,
    input int unsigned max_cycles
  );
    int unsigned wait_ready;
    begin
      sb_rx_valid = 1'b0;
      wait_ready = 0;
      while (!sb_rx_ready && wait_ready < max_cycles) begin
        step(1);
        wait_ready++;
      end
      if (wait_ready >= max_cycles)
        $fatal(1, "RX not ready for header 0x%016h", header);

      sb_rx_msg = build_message(header, has_payload ? payload : 64'b0);
      sb_rx_valid = 1'b1;
      step(1);
      sb_rx_valid = 1'b0;
      sb_rx_msg = 128'b0;
      // Input ready belongs to the BFM serializer.  Wait through the entire
      // frame and final 32-bit idle gap before declaring stimulus complete.
      wait_ready = 0;
      while (!sb_rx_ready && wait_ready < max_cycles) begin
        step(1);
        wait_ready++;
      end
      if (wait_ready >= max_cycles)
        $fatal(1, "Serial TX did not finish injected header 0x%016h", header);
      step(2);
    end
  endtask

  task automatic finish_serial_exchange(input logic allow_reset_follow_on);
    logic [63:0] header, payload;
    logic has_payload;
    int unsigned waited, quiet_cycles, follow_on_count;
    begin
      waited = 0;
      quiet_cycles = 0;
      follow_on_count = 0;
      // Checkers include accepted-but-not-yet-sent and not-yet-consumed
      // frames.  The idle condition also covers the serializer's final gap.
      while (quiet_cycles < 16 && waited < 2000) begin
        if (sb_tx_valid) begin
          take_tx_message(header, payload, has_payload, 1000);
          // Disabled/LinkReset -> Reset leaves LP Req.Active asserted.
          // An autonomous new RDI Req.Active is therefore an expected
          // follow-on transaction.  Observe it on the wire before resetting.
          if (!allow_reset_follow_on || header !== LOCAL_RDI_REQ_ACTIVE ||
              has_payload || follow_on_count != 0)
            $fatal(1, "Unexpected trailing serialized message 0x%016h", header);
          follow_on_count++;
          quiet_cycles = 0;
        end
        step(1);
        waited++;
        if (serial_idle && !sb_tx_valid) quiet_cycles++;
        else quiet_cycles = 0;
      end
      if (quiet_cycles < 16)
        $fatal(1, "Serial transport failed to drain before scenario reset/completion");
      if (serial_error || serial_failure_seen)
        $fatal(1, "Serial checker reported a failure before scenario completion");
    end
  endtask

  task automatic bring_both_controllers_to_active;
    logic [63:0] header;
    logic [63:0] payload;
    logic has_payload;
    int unsigned count;
    begin
      reset_and_initialize(1'b1);

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_RDI_REQ_ACTIVE || has_payload)
        $fatal(1, "Bring-up: expected local RDI Req.Active, got header=0x%016h payload=%0b", header, has_payload);

      send_rx_message(REMOTE_RDI_REQ_ACTIVE, 64'b0, 1'b0, 1000);
      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_RDI_RSP_ACTIVE)
        $fatal(1, "Bring-up: expected local RDI Rsp.Active, got 0x%016h", header);
      send_rx_message(REMOTE_RDI_RSP_ACTIVE, 64'b0, 1'b0, 1000);

      count = 0;
      while (debug_rdi_state != PhyState_active && count < 300) begin
        step(1);
        count++;
      end
      if (count >= 300) $fatal(1, "Bring-up: RDI did not reach Active");

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_ADV_CAP_ADAPTER || payload !== RAW_STREAMING_ADV_CAP_PAYLOAD || !has_payload)
        $fatal(1, "Bring-up: AdvCap.Adapter mismatch header=0x%016h payload=0x%016h hasPayload=%0b",
               header, payload, has_payload);
      send_rx_message(REMOTE_ADV_CAP_ADAPTER, RAW_STREAMING_ADV_CAP_PAYLOAD, 1'b1, 1000);

      count = 0;
      while (debug_fdi_link_init_state != LinkInitState_FDI_WAIT_LP_REQ_ACTIVE && count < 300) begin
        step(1);
        count++;
      end
      if (count >= 300) $fatal(1, "Bring-up: FDI did not finish Parameter Exchange");

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_active;

      count = 0;
      while (!fdi_pl_rx_active_req && count < 300) begin
        step(1);
        count++;
      end
      if (count >= 300) $fatal(1, "Bring-up: FDI did not request RX Active");
      fdi_lp_rx_active_sts = 1'b1;
      step(2);

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_ADAPTER_REQ_ACTIVE)
        $fatal(1, "Bring-up: expected local Adapter Req.Active, got 0x%016h", header);
      send_rx_message(REMOTE_ADAPTER_REQ_ACTIVE, 64'b0, 1'b0, 1000);

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_ADAPTER_RSP_ACTIVE)
        $fatal(1, "Bring-up: expected local Adapter Rsp.Active, got 0x%016h", header);
      send_rx_message(REMOTE_ADAPTER_RSP_ACTIVE, 64'b0, 1'b0, 1000);

      count = 0;
      while (fdi_pl_state_sts != PhyState_active && count < 300) begin
        step(1);
        count++;
      end
      if (count >= 300) $fatal(1, "Bring-up: FDI did not reach Active");
      if (debug_rdi_state != PhyState_active || !fdi_pl_inband_pres)
        $fatal(1, "Bring-up final state/inband mismatch");
    end
  endtask

  task automatic scenario_retrain;
    logic [63:0] header;
    logic [63:0] payload;
    logic has_payload;
    int unsigned count;
    begin
      $display("[scenario] Reset -> Active -> Retrain -> Active");
      bring_both_controllers_to_active();

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_retrain;

      count = 0;
      while (!fdi_pl_stall_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "No FDI stall before Retrain");
      fdi_lp_stall_ack = 1'b1;
      step(3);

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_RDI_REQ_RETRAIN)
        $fatal(1, "Expected local RDI Req.Retrain, got 0x%016h", header);
      send_rx_message(REMOTE_RDI_RSP_RETRAIN, 64'b0, 1'b0, 1000);

      count = 0;
      while (fdi_pl_rx_active_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "RX Active request did not fall for Retrain");
      fdi_lp_rx_active_sts = 1'b0;

      count = 0;
      while ((fdi_pl_state_sts != PhyState_retrain || debug_rdi_state != PhyState_retrain) && count < 500) begin
        step(1); count++;
      end
      if (count >= 500) $fatal(1, "FDI/RDI did not both reach Retrain");

      count = 0;
      while (fdi_pl_stall_req && count < 100) begin step(1); count++; end
      if (count >= 100) $fatal(1, "Stall request did not fall in Retrain");
      fdi_lp_stall_ack = 1'b0;
      step(2);

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_active;

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_RDI_REQ_ACTIVE)
        $fatal(1, "Retrain exit: expected RDI Req.Active, got 0x%016h", header);
      send_rx_message(REMOTE_RDI_REQ_ACTIVE, 64'b0, 1'b0, 1000);
      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_RDI_RSP_ACTIVE)
        $fatal(1, "Retrain exit: expected RDI Rsp.Active, got 0x%016h", header);
      send_rx_message(REMOTE_RDI_RSP_ACTIVE, 64'b0, 1'b0, 1000);

      count = 0;
      while (debug_rdi_state != PhyState_active && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "RDI did not return to Active");

      count = 0;
      while (!fdi_pl_rx_active_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "FDI did not request RX Active on Retrain exit");
      fdi_lp_rx_active_sts = 1'b1;
      step(2);

      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_ADAPTER_REQ_ACTIVE)
        $fatal(1, "Retrain exit: expected Adapter Req.Active, got 0x%016h", header);
      send_rx_message(REMOTE_ADAPTER_REQ_ACTIVE, 64'b0, 1'b0, 1000);
      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_ADAPTER_RSP_ACTIVE)
        $fatal(1, "Retrain exit: expected Adapter Rsp.Active, got 0x%016h", header);
      send_rx_message(REMOTE_ADAPTER_RSP_ACTIVE, 64'b0, 1'b0, 1000);

      count = 0;
      while (fdi_pl_state_sts != PhyState_active && count < 300) begin step(1); count++; end
      if (count >= 300 || debug_rdi_state != PhyState_active)
        $fatal(1, "FDI/RDI did not return to Active");
      finish_serial_exchange(1'b0);
      $display("PASS: scenario_retrain");
    end
  endtask

  task automatic scenario_disabled;
    logic [63:0] header;
    logic [63:0] payload;
    logic has_payload;
    logic saw_adapter;
    logic saw_rdi;
    int unsigned count;
    int unsigned packets;
    begin
      $display("[scenario] Active -> Disabled -> Reset");
      bring_both_controllers_to_active();

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_disabled;

      count = 0;
      while (!fdi_pl_stall_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "No FDI stall before Disabled");
      fdi_lp_stall_ack = 1'b1;
      step(3);

      saw_adapter = 1'b0;
      saw_rdi = 1'b0;
      packets = 0;
      while (!(saw_adapter && saw_rdi) && packets < 4) begin
        take_tx_message(header, payload, has_payload, 1000);
        if (header == LOCAL_ADAPTER_REQ_DISABLE) begin
          if (saw_adapter) $fatal(1, "Duplicate Adapter Req.Disable");
          saw_adapter = 1'b1;
        end else if (header == LOCAL_RDI_REQ_DISABLE) begin
          if (saw_rdi) $fatal(1, "Duplicate RDI Req.Disable");
          saw_rdi = 1'b1;
        end else begin
          $fatal(1, "Unexpected Disable message 0x%016h", header);
        end
        packets++;
      end
      if (!(saw_adapter && saw_rdi)) $fatal(1, "Did not observe both Disable requests");

      send_rx_message(REMOTE_RDI_RSP_DISABLE, 64'b0, 1'b0, 1000);
      count = 0;
      while (debug_rdi_state != PhyState_disabled && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "RDI did not reach Disabled");

      send_rx_message(REMOTE_ADAPTER_RSP_DISABLE, 64'b0, 1'b0, 1000);
      count = 0;
      while (fdi_pl_rx_active_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "RX Active request did not fall for Disabled");
      fdi_lp_rx_active_sts = 1'b0;

      count = 0;
      while ((fdi_pl_state_sts != PhyState_disabled || debug_rdi_state != PhyState_disabled) && count < 500) begin
        step(1); count++;
      end
      if (count >= 500) $fatal(1, "FDI/RDI did not both reach Disabled");

      count = 0;
      while (fdi_pl_stall_req && count < 100) begin step(1); count++; end
      fdi_lp_stall_ack = 1'b0;
      step(2);
      if (fdi_pl_state_sts != PhyState_disabled || debug_rdi_state != PhyState_disabled || fdi_pl_inband_pres)
        $fatal(1, "Disabled final state/inband mismatch");

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_active;
      count = 0;
      while ((fdi_pl_state_sts != PhyState_reset || debug_rdi_state != PhyState_reset) && count < 300) begin
        step(1); count++;
      end
      if (count >= 300) $fatal(1, "Disabled did not return through Reset");
      finish_serial_exchange(1'b1);
      $display("PASS: scenario_disabled");
    end
  endtask

  task automatic scenario_linkreset;
    logic [63:0] header;
    logic [63:0] payload;
    logic has_payload;
    logic saw_adapter;
    logic saw_rdi;
    int unsigned count;
    int unsigned packets;
    begin
      $display("[scenario] Active -> LinkReset -> Reset");
      bring_both_controllers_to_active();

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_linkReset;

      count = 0;
      while (!fdi_pl_stall_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "No FDI stall before LinkReset");
      fdi_lp_stall_ack = 1'b1;
      step(3);

      saw_adapter = 1'b0;
      saw_rdi = 1'b0;
      packets = 0;
      while (!(saw_adapter && saw_rdi) && packets < 4) begin
        take_tx_message(header, payload, has_payload, 1000);
        if (header == LOCAL_ADAPTER_REQ_LINKRESET) begin
          if (saw_adapter) $fatal(1, "Duplicate Adapter Req.LinkReset");
          saw_adapter = 1'b1;
        end else if (header == LOCAL_RDI_REQ_LINKRESET) begin
          if (saw_rdi) $fatal(1, "Duplicate RDI Req.LinkReset");
          saw_rdi = 1'b1;
        end else begin
          $fatal(1, "Unexpected LinkReset message 0x%016h", header);
        end
        packets++;
      end
      if (!(saw_adapter && saw_rdi)) $fatal(1, "Did not observe both LinkReset requests");

      send_rx_message(REMOTE_RDI_RSP_LINKRESET, 64'b0, 1'b0, 1000);
      count = 0;
      while (debug_rdi_state != PhyState_linkReset && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "RDI did not reach LinkReset");

      send_rx_message(REMOTE_ADAPTER_RSP_LINKRESET, 64'b0, 1'b0, 1000);
      count = 0;
      while (fdi_pl_rx_active_req && count < 300) begin step(1); count++; end
      if (count >= 300) $fatal(1, "RX Active request did not fall for LinkReset");
      fdi_lp_rx_active_sts = 1'b0;

      count = 0;
      while ((fdi_pl_state_sts != PhyState_linkReset || debug_rdi_state != PhyState_linkReset) && count < 500) begin
        step(1); count++;
      end
      if (count >= 500) $fatal(1, "FDI/RDI did not both reach LinkReset");

      count = 0;
      while (fdi_pl_stall_req && count < 100) begin step(1); count++; end
      fdi_lp_stall_ack = 1'b0;
      step(2);
      if (fdi_pl_state_sts != PhyState_linkReset || debug_rdi_state != PhyState_linkReset)
        $fatal(1, "LinkReset final state mismatch");

      fdi_lp_state_req = PhyStateReq_nop;
      step(2);
      fdi_lp_state_req = PhyStateReq_active;
      count = 0;
      while ((fdi_pl_state_sts != PhyState_reset || debug_rdi_state != PhyState_reset) && count < 300) begin
        step(1); count++;
      end
      if (count >= 300) $fatal(1, "LinkReset did not return through Reset");
      finish_serial_exchange(1'b1);
      $display("PASS: scenario_linkreset");
    end
  endtask

  task automatic scenario_linkerror;
    logic [63:0] header;
    logic [63:0] payload;
    logic has_payload;
    int unsigned count;
    begin
      $display("[scenario] Active -> LinkError -> Reset after 16 ms residency");
      bring_both_controllers_to_active();

      fdi_lp_linkerror = 1'b1;
      take_tx_message(header, payload, has_payload, 1000);
      if (header !== LOCAL_RDI_REQ_LINKERROR)
        $fatal(1, "Expected local RDI Req.LinkError, got 0x%016h", header);
      send_rx_message(REMOTE_RDI_RSP_LINKERROR, 64'b0, 1'b0, 1000);

      count = 0;
      while (fdi_pl_rx_active_req && count < 300) begin step(1); count++; end
      fdi_lp_rx_active_sts = 1'b0;

      count = 0;
      while ((fdi_pl_state_sts != PhyState_linkError || debug_rdi_state != PhyState_linkError) && count < 300) begin
        step(1); count++;
      end
      if (count >= 300) $fatal(1, "FDI/RDI did not both reach LinkError");
      if (fdi_pl_stall_req || fdi_pl_inband_pres)
        $fatal(1, "LinkError stall/inband outputs are incorrect");

      fdi_lp_linkerror = 1'b0;
      fdi_lp_state_req = PhyStateReq_active;

      step(15000);
      if (fdi_pl_state_sts != PhyState_linkError || debug_rdi_state != PhyState_linkError)
        $fatal(1, "LinkError exited before the configured residency");

      step(1100);
      count = 0;
      while ((fdi_pl_state_sts != PhyState_reset || debug_rdi_state != PhyState_reset) && count < 100) begin
        step(1); count++;
      end
      if (count >= 100) $fatal(1, "LinkError did not return to Reset after residency");
      finish_serial_exchange(1'b1);
      $display("PASS: scenario_linkerror");
    end
  endtask

  task automatic scenario_direct_reset_exits;
    logic [63:0] header;
    logic [63:0] payload;
    logic has_payload;
    logic saw_adapter;
    logic saw_rdi;
    int unsigned packets;
    int unsigned count;
    string direct_reset_case;
    begin
      if (!$value$plusargs("DIRECT_RESET_CASE=%s", direct_reset_case))
        direct_reset_case = "all";
      if (direct_reset_case != "all" && direct_reset_case != "disabled" &&
          direct_reset_case != "linkreset" && direct_reset_case != "linkerror")
        $fatal(1, "Unknown +DIRECT_RESET_CASE=%s", direct_reset_case);
      $display("[scenario] Direct Reset exits case=%s", direct_reset_case);

      if (direct_reset_case == "all" || direct_reset_case == "disabled") begin
        // Reset -> Disabled -> Reset.
        reset_and_initialize(1'b0);
        fdi_lp_state_req = PhyStateReq_nop;
        step(2);
        fdi_lp_state_req = PhyStateReq_disabled;

        saw_adapter = 1'b0;
        saw_rdi = 1'b0;
        packets = 0;
        while (!(saw_adapter && saw_rdi) && packets < 4) begin
          take_tx_message(header, payload, has_payload, 1000);
          if (header == LOCAL_ADAPTER_REQ_DISABLE) saw_adapter = 1'b1;
          else if (header == LOCAL_RDI_REQ_DISABLE) saw_rdi = 1'b1;
          else $fatal(1, "Unexpected Reset->Disabled message 0x%016h", header);
          packets++;
        end
        if (!(saw_adapter && saw_rdi)) $fatal(1, "Reset->Disabled requests incomplete");

        send_rx_message(REMOTE_RDI_RSP_DISABLE, 64'b0, 1'b0, 1000);
        count = 0;
        while (debug_rdi_state != PhyState_disabled && count < 300) begin step(1); count++; end
        send_rx_message(REMOTE_ADAPTER_RSP_DISABLE, 64'b0, 1'b0, 1000);
        count = 0;
        while ((fdi_pl_state_sts != PhyState_disabled || debug_rdi_state != PhyState_disabled) && count < 500) begin
          step(1); count++;
        end
        if (count >= 500) $fatal(1, "Direct Reset->Disabled did not complete");

        fdi_lp_state_req = PhyStateReq_active;
        count = 0;
        while ((fdi_pl_state_sts != PhyState_reset || debug_rdi_state != PhyState_reset) && count < 300) begin
          step(1); count++;
        end
        if (count >= 300) $fatal(1, "Disabled->Reset did not complete");
      end

      if (direct_reset_case == "all" || direct_reset_case == "linkreset") begin
        // Reset -> LinkReset -> Reset.
        reset_and_initialize(1'b0);
        fdi_lp_state_req = PhyStateReq_nop;
        step(2);
        fdi_lp_state_req = PhyStateReq_linkReset;

        saw_adapter = 1'b0;
        saw_rdi = 1'b0;
        packets = 0;
        while (!(saw_adapter && saw_rdi) && packets < 4) begin
          take_tx_message(header, payload, has_payload, 1000);
          if (header == LOCAL_ADAPTER_REQ_LINKRESET) saw_adapter = 1'b1;
          else if (header == LOCAL_RDI_REQ_LINKRESET) saw_rdi = 1'b1;
          else $fatal(1, "Unexpected Reset->LinkReset message 0x%016h", header);
          packets++;
        end
        if (!(saw_adapter && saw_rdi)) $fatal(1, "Reset->LinkReset requests incomplete");

        send_rx_message(REMOTE_RDI_RSP_LINKRESET, 64'b0, 1'b0, 1000);
        count = 0;
        while (debug_rdi_state != PhyState_linkReset && count < 300) begin step(1); count++; end
        send_rx_message(REMOTE_ADAPTER_RSP_LINKRESET, 64'b0, 1'b0, 1000);
        count = 0;
        while ((fdi_pl_state_sts != PhyState_linkReset || debug_rdi_state != PhyState_linkReset) && count < 500) begin
          step(1); count++;
        end
        if (count >= 500) $fatal(1, "Direct Reset->LinkReset did not complete");

        fdi_lp_state_req = PhyStateReq_active;
        count = 0;
        while ((fdi_pl_state_sts != PhyState_reset || debug_rdi_state != PhyState_reset) && count < 300) begin
          step(1); count++;
        end
        if (count >= 300) $fatal(1, "LinkReset->Reset did not complete");
      end

      if (direct_reset_case == "all" || direct_reset_case == "linkerror") begin
        // Reset -> LinkError.
        reset_and_initialize(1'b0);
        fdi_lp_linkerror = 1'b1;
        take_tx_message(header, payload, has_payload, 1000);
        if (header !== LOCAL_RDI_REQ_LINKERROR)
          $fatal(1, "Direct Reset->LinkError expected RDI request, got 0x%016h", header);
        send_rx_message(REMOTE_RDI_RSP_LINKERROR, 64'b0, 1'b0, 1000);

        count = 0;
        while ((fdi_pl_state_sts != PhyState_linkError || debug_rdi_state != PhyState_linkError) && count < 300) begin
          step(1); count++;
        end
        if (count >= 300) $fatal(1, "Direct Reset->LinkError did not complete");
      end
      finish_serial_exchange(direct_reset_case == "disabled" || direct_reset_case == "linkreset");
      $display("PASS: scenario_direct_reset_exits case=%s", direct_reset_case);
    end
  endtask

  initial begin : run_tests
    string scenario;
    if (!$value$plusargs("SCENARIO=%s", scenario))
      scenario = "all";

    if ($test$plusargs("VCD")) begin
      $dumpfile("D2DAdapterLinkMgmtTopIntegrated128Spec_tb.vcd");
      $dumpvars(0, D2DAdapterLinkMgmtTopIntegrated128Spec_tb);
    end

    // Give every input a defined value before the first asynchronous reset.
    fdi_lp_state_req = PhyStateReq_nop;
    fdi_lp_linkerror = 1'b0;
    fdi_lp_rx_active_sts = 1'b0;
    fdi_lp_wake_req = 1'b0;
    fdi_lp_clk_ack = 1'b0;
    fdi_lp_stall_ack = 1'b0;
    ltsm_start = 1'b0;
    ltsm_stable_clk = 1'b0;
    ltsm_pll_locked = 1'b0;
    ltsm_stable_supply = 1'b0;
    manual_sideband_mode = 1'b0;
    sb_tx_ready = 1'b0;
    sb_rx_valid = 1'b0;
    sb_rx_msg = 128'b0;
    cycles_1us = 32'd1;
    reset_n = 1'b0;

    if (scenario == "all" || scenario == "retrain") scenario_retrain();
    if (scenario == "all" || scenario == "disabled") scenario_disabled();
    if (scenario == "all" || scenario == "linkreset") scenario_linkreset();
    if (scenario == "all" || scenario == "linkerror") scenario_linkerror();
    if (scenario == "all" || scenario == "direct_reset_exits") scenario_direct_reset_exits();

    if (scenario != "all" && scenario != "retrain" && scenario != "disabled" &&
        scenario != "linkreset" && scenario != "linkerror" &&
        scenario != "direct_reset_exits")
      $fatal(1, "Unknown +SCENARIO=%s", scenario);

    if (serial_error || serial_failure_seen)
      $fatal(1, "Serial wire/receive checker failed; scenario cannot pass");
    if (dut.local_out_completed == 0 || dut.local_in_completed == 0)
      $fatal(1, "No complete serialized traffic observed in both local directions");
    $display("PASS: D2DAdapterLinkMgmtTopIntegrated128Spec serial scenario=%s", scenario);
    $finish;
  end
endmodule

`default_nettype wire
