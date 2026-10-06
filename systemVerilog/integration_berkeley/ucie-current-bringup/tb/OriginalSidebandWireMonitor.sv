`timescale 1ns/1ps
`default_nettype none
// Passive pin monitor. It never drives, filters, delays or repairs either wire.
module OriginalSidebandWireMonitor #(
  parameter string NAME = "direction",
  parameter realtime PERIOD = 1.25ns
) (
  input wire reset_n, serial_clock, serial_data,
  output integer errors = 0,
  output integer chunks = 0,
  output integer sampled_bits = 0
);
  integer bits_in_burst = 0;
  integer log_fd;
  realtime last_rise = 0, last_fall = 0;
  logic [63:0] word = 0;
  task automatic report(input string reason);
    errors++;
    if (errors <= 12) $display("WIRE_ERROR %s at %0.3f ns: %s",NAME,$realtime,reason);
  endtask
  initial begin
    log_fd=$fopen({NAME,"_wire.csv"},"w");
    if(!log_fd) $fatal(1,"Cannot open wire log for %s",NAME);
    $fdisplay(log_fd,"time_ns,event,bits_in_burst,word_hex,high_width_ns");
  end
  always @(negedge reset_n) begin
    errors=0; chunks=0; sampled_bits=0; bits_in_burst=0;
    last_rise=0; last_fall=0; word=0;
  end
  always @(posedge serial_clock) if(reset_n) begin
    if(last_fall!=0 && $realtime-last_fall>PERIOD) begin
      if(bits_in_burst!=64)
        report($sformatf("Previous burst contained %0d sampling edges, expected 64",bits_in_burst));
      if($realtime-last_fall < 32.49*PERIOD)
        report("Gap between bursts is shorter than 32 idle bit periods");
      bits_in_burst=0; word=0;
    end
    last_rise=$realtime;
  end
  always @(negedge serial_clock) if(reset_n) begin
    if(last_rise==0 || $realtime-last_rise<0.499*PERIOD || $realtime-last_rise>0.501*PERIOD)
      report($sformatf("Forwarded-clock high width is %0.3f ns; expected %0.3f ns",$realtime-last_rise,PERIOD/2.0));
    if($isunknown(serial_data)) report("Serial data is X or Z at sampling edge");
    if(bits_in_burst<64) word[bits_in_burst]=serial_data;
    bits_in_burst++; sampled_bits++;
    if(bits_in_burst==64) begin
      chunks++;
      $fdisplay(log_fd,"%0.3f,chunk,%0d,%016h,%0.3f",$realtime,bits_in_burst,word,$realtime-last_rise);
    end else if(bits_in_burst>64) begin
      report("More than 64 sampling edges in one burst");
      $fdisplay(log_fd,"%0.3f,extra_edge,%0d,%016h,%0.3f",$realtime,bits_in_burst,word,$realtime-last_rise);
    end
    last_fall=$realtime;
  end
endmodule
`default_nettype wire
