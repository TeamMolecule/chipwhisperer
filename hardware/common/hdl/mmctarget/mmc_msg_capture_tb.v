`timescale 1ns/1ps
module mmc_msg_capture_tb();

parameter CLK_PERIOD = 10;
parameter CLK_HALF = 5;
parameter MMC_CLK_PERIOD = 20;
parameter MMC_CLK_HALF = 10;

reg clk;
reg reset_i;
reg mmc_clk;
reg mmc_cmd;
wire [47:0] msg_packet;
wire msg_valid;
wire [2:0] debug_state;
wire [8:0] debug_cnt;

mmc_msg_capture dut(
  .clk(clk),
  .reset_i(reset_i),
  .mmc_clk(mmc_clk),
  .mmc_cmd(mmc_cmd),
  .msg_packet(msg_packet),
  .msg_valid(msg_valid),
  .debug_state(debug_state),
  .debug_cnt(debug_cnt)
);

initial clk = 0;
always #CLK_HALF clk = ~clk;

initial begin
  reset_i = 1;
  #(3 * CLK_PERIOD);
  reset_i = 0;

  $display("started!\n");
  //$monitor("[%d] clk:%b, cmd:%b",$time,mmc_clk,mmc_cmd);
  $monitor("[%d] state:%b, cnt:%d, msg_valid:%b, msg_packet:%b", $time, debug_state, debug_cnt, msg_valid, msg_packet);

  $display("testing standard packet");

  #($urandom % CLK_PERIOD);
  mmc_clk = 1;
  $display("6 cycles before starting\n");
  mmc_cmd = 1;
  repeat (6) begin
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end
  $display("send start bit\n");
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send transmission bit\n");
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send data\n");
  repeat (45) begin
    mmc_cmd = 0;
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end
  $display("send end bit\n");
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("6 cycles after ending\n");
  repeat (6) begin
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end

  $display("testing CMD2 packet");

  #($urandom % CLK_PERIOD);
  mmc_clk = 1;
  $display("6 cycles before starting\n");
  mmc_cmd = 1;
  repeat (6) begin
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end
  $display("send start bit\n");
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send transmission bit\n");
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send cmd\n");
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send data\n");
  repeat (39) begin
    mmc_cmd = $urandom % 2;
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end
  $display("send end bit\n");
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("6 cycles after ending\n");
  repeat (6) begin
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end

  $display("testing R2 response packet");

  #($urandom % CLK_PERIOD);
  mmc_clk = 1;
  $display("6 cycles before starting\n");
  mmc_cmd = 1;
  repeat (6) begin
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end
  $display("send start bit\n");
  mmc_cmd = 0;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send transmission bit\n");
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("send data\n");
  repeat (133) begin
    mmc_cmd = $urandom % 2;
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end
  $display("send end bit\n");
  mmc_cmd = 1;
  #MMC_CLK_HALF mmc_clk = 0;
  #MMC_CLK_HALF mmc_clk = 1;
  $display("6 cycles after ending\n");
  repeat (6) begin
    #MMC_CLK_HALF mmc_clk = 0;
    #MMC_CLK_HALF mmc_clk = 1;
  end

  $finish;
end

endmodule