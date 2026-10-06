module SidebandRxCdc #(
  parameter int unsigned DATA_WIDTH = 128
) (
  // Source domain: same effective clock used by SidebandRx.
  input  wire logic                  src_clock,
  input  wire logic                  src_reset,
  input  wire logic [DATA_WIDTH-1:0] src_data,
  input  wire logic                  src_valid,

  // Destination domain: link-management/controller clock.
  input  wire logic                  dst_clock,
  input  wire logic                  dst_reset_n,
  output var  logic [DATA_WIDTH-1:0] dst_data,
  output var  logic                  dst_valid
);
  logic [DATA_WIDTH-1:0] src_data_hold;
  logic                  src_event_toggle;

  // The source data is held unchanged until the next received message.
  // The destination receives notification through the synchronized toggle.
  always_ff @(posedge src_clock or posedge src_reset) begin
    if (src_reset) begin
      src_data_hold    <= '0;
      src_event_toggle <= 1'b0;
    end else if (src_valid) begin
      src_data_hold    <= src_data;
      src_event_toggle <= ~src_event_toggle;
    end
  end

  // Only the single-bit event crosses through synchronizer flip-flops.
  // Do not independently synchronize every bit of src_data_hold.
  (* ASYNC_REG = "TRUE" *) logic event_sync_ff1;
  (* ASYNC_REG = "TRUE" *) logic event_sync_ff2;
  (* ASYNC_REG = "TRUE" *) logic event_sync_ff3;
  logic event_sync_ff3_q;

  always_ff @(posedge dst_clock or negedge dst_reset_n) begin
    if (!dst_reset_n) begin
      event_sync_ff1  <= 1'b0;
      event_sync_ff2  <= 1'b0;
      event_sync_ff3  <= 1'b0;
      event_sync_ff3_q <= 1'b0;
    end else begin
      event_sync_ff1   <= src_event_toggle;
      event_sync_ff2   <= event_sync_ff1;
      event_sync_ff3   <= event_sync_ff2;
      event_sync_ff3_q <= event_sync_ff3;
    end
  end

  wire logic new_message;
  assign new_message = event_sync_ff3 ^ event_sync_ff3_q;

  // Bundled-data capture. By the time the event passes through three FFs,
  // src_data_hold has been stable for several destination-clock cycles.
  always_ff @(posedge dst_clock or negedge dst_reset_n) begin
    if (!dst_reset_n) begin
      dst_data  <= '0;
      dst_valid <= 1'b0;
    end else begin
      dst_valid <= 1'b0;
      if (new_message) begin
        dst_data  <= src_data_hold;
        dst_valid <= 1'b1;
      end
    end
  end

endmodule
