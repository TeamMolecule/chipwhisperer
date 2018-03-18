`include "includes.v"
//`define CHIPSCOPE

/***********************************************************************
This file is part of the ChipWhisperer Project. See www.newae.com for more details,
or the codebase at http://www.assembla.com/spaces/openadc .

This file is the OpenADC main registers. Does not include the actual data
transfer register which is in a seperate file.

Copyright (c) 2013, Colin O'Flynn <coflynn@newae.com>. All rights reserved.
This project (and file) is released under the 2-Clause BSD License:

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.


*************************************************************************/
module reg_mmctarget(
	input 			reset_i,
	input 			clk,
	input [5:0]    reg_address,  // Address of register
	input [15:0]   reg_bytecnt,  // Current byte count
	input [7:0]    reg_datai,    // Data to write
	output [7:0]   reg_datao,    // Data to read
	input [15:0]   reg_size,     // Total size being read/write
	input          reg_read,     // Read flag
	input  			reg_write,    // Write flag
	input          reg_addrvalid,// Address valid flag
	output			reg_stream,	
	
	input [5:0]    reg_hypaddress,
	output  [15:0] reg_hyplen,
	
	
	input				target_mmc_clk,
	input				target_mmc_cmd									              
);
	 
assign reg_stream = 1'b0;
        	  
/*
	 0x3b - MMC Target Status (1 byte: overflow: 1 bit, full: 1 bit, empty: 1 bit)
	 0x3c - MMC Target Data length (1 byte)
	 0x3d - MMC Target Data (8 bytes)
*/
`define TARGMMC_STATUS_ADDR 59
`define TARGMMC_LEN_ADDR 60
`define TARGMMC_DATA_ADDR 61
  
wire [7:0] targmmc_status;
wire [7:0] targmmc_len;
wire [63:0] fifo_data;
wire fifo_data_valid;

// get size
reg [15:0] reg_hyplen_reg;
assign reg_hyplen = reg_hyplen_reg;

always @(reg_hypaddress) begin
	case (reg_hypaddress)
		`TARGMMC_STATUS_ADDR: reg_hyplen_reg <= 1;
		`TARGMMC_LEN_ADDR: reg_hyplen_reg <= 1;
		`TARGMMC_DATA_ADDR: reg_hyplen_reg <= 8;
		default: reg_hyplen_reg<= 0;
	endcase
end    

// data output
reg [7:0] reg_datao_reg;	 
assign reg_datao = reg_datao_reg;
assign targmmc_status[7:3] = 5'b0;

always @(posedge clk) begin
	if (reg_read) begin
		case (reg_address)		
			`TARGMMC_STATUS_ADDR: begin reg_datao_reg <= targmmc_status; end
			`TARGMMC_LEN_ADDR: begin reg_datao_reg <= targmmc_len; end
			`TARGMMC_DATA_ADDR: begin reg_datao_reg <= fifo_data_valid ? fifo_data[reg_bytecnt*8 +: 8] : 8'b0;	end
			default: begin reg_datao_reg <= 0; end
		endcase
	end
end

// read enable (pop stack after last byte is read)
reg fifo_rd;
always @(posedge clk) begin
	if ((reg_read) && (reg_address == `TARGMMC_DATA_ADDR) && (reg_bytecnt == 7)) begin
		fifo_rd <= 1'b1;
	end else begin
		fifo_rd <= 1'b0;
	end
end

// counter for packet ordering

reg [15:0] packet_id;
always @(posedge capture_packet_valid or posedge reset_i) begin
	if (reset_i) begin
		packet_id <= 16'b0;
	end else begin
		packet_id <= packet_id + 16'b1;
	end
end

// capture
wire [47:0] capture_packet;
wire capture_packet_valid;
mmc_msg_capture #(.DATA_RELATED_ONLY(1)) msg_capture (
	.clk(clk),
	.reset_i(reset_i),
	.mmc_clk(target_mmc_clk),
	.mmc_cmd(target_mmc_cmd),
	.msg_packet(capture_packet),
	.msg_valid(capture_packet_valid)
);

// fifo
fifo_mmc_cmd tx_fifo (
	.rd_clk(clk),
	.wr_clk(target_mmc_clk),
	.rst(reset_i),
	.din({packet_id, capture_packet}),
	.wr_en(capture_packet_valid),
	.rd_en(fifo_rd),
	.dout(fifo_data),
	.full(targmmc_status[1]),
	.empty(targmmc_status[0]),
	.overflow(targmmc_status[2]),
	.valid(fifo_data_valid),
	.rd_data_count(targmmc_len)
);

/*
wire tmp_rd;
wire       tx_busy;

assign tmp_rd = fifo_data_valid && !tx_busy;

// TEMP send through UART
	targ_async_transmitter targ_tx(
	 .clk(clk),
	 .TxD_start(tmp_rd),
	 .parity_even(0),
	 .two_stopbits(0),
	 .TxD_data(fifo_data),
	 .TxD(target_tx),
	 .TxD_busy(tx_busy),
	 .TxD_BaudGeneratorInc(16'd175)
	 );
 */

endmodule

`undef CHIPSCOPE
