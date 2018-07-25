`include "includes.v"
//`define CHIPSCOPE

/***********************************************************************
This file is part of the ChipWhisperer Project. See www.newae.com for more
details, or the codebase at http://www.chipwhisperer.com

Copyright (c) 2013-2014, NewAE Technology Inc. All rights reserved.
Author: Colin O'Flynn <coflynn@newae.com>

  chipwhisperer is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  chipwhisperer is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with chipwhisperer.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************/
module reg_mmctrigger(
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
	output [15:0]  reg_hyplen,
	
	input				target_mmc_clk,
	input				target_mmc_cmd,
	output reg		trig_out									              
   );
	 
	 assign reg_stream = 1'b0;
        	  
	 `define IOTRIGMMC_CFG_ADDR	63

	 /* CFG register (addr 63) format:
	  *   [63:32] (4 bytes) compare data
	  *   [31] reserved
	  *   [30] compare transmission bit
	  *   [29:24] compare cmd
	  *   [23:6] reserved
	  *   [5:4] compare operation for data (see defines below)
	  *   [3] trigger on NEXT packet (delay trigger output by one packet)
	  *   [2] enable data compare
	  *   [1] enable cmd compare
	  *   [0] enable transmission compare
	  */

	 `define CMP_OP_EQ 2'b00
	 `define CMP_OP_NE 2'b01
	 `define CMP_OP_LT 2'b10
	 `define CMP_OP_GT 2'b11
  
   /* Get length */
	 reg [15:0] reg_hyplen_reg;
	 assign reg_hyplen = reg_hyplen_reg;
	 
	 always @(reg_hypaddress) begin
		case (reg_hypaddress)
				`IOTRIGMMC_CFG_ADDR: reg_hyplen_reg <= 8;
				default: reg_hyplen_reg<= 0;
		endcase
	 end    
	
	 reg [7:0] reg_datao_reg;
	 assign reg_datao = reg_datao_reg;
	 
	 reg [63:0] cnf_reg;

	 wire [31:0] cmp_data;
	 wire [5:0] cmp_cmd;
	 wire cmp_transmission;
	 wire [1:0] cmp_data_op;
	 wire cmp_delay_next;
	 wire cmp_data_en;
	 wire cmp_cmd_en;
	 wire cmp_transmission_en;

	 wire [47:0] msg_packet;
	 wire msg_valid;
	 
	 assign cmp_data = cnf_reg[63:32];
	 assign cmp_transmission = cnf_reg[30];
	 assign cmp_cmd = cnf_reg[29:24];
	 assign cmp_data_op = cnf_reg[5:4];
	 assign cmp_delay_next = cnf_reg[3];
	 assign cmp_data_en = cnf_reg[2];
	 assign cmp_cmd_en = cnf_reg[1];
	 assign cmp_transmission_en = cnf_reg[0];
	 
	 /* Read/write register */
	  	 
	 always @(posedge clk) begin
		if (reg_read) begin
			case (reg_address)		
				`IOTRIGMMC_CFG_ADDR: begin reg_datao_reg <= cnf_reg[reg_bytecnt*8 +: 8]; end
				default: begin reg_datao_reg <= 0; end
			endcase
		end
	 end
	 
	 always @(posedge clk) begin
		if (reset_i) begin
			cnf_reg <= 0;
		end else if (reg_write) begin
			case (reg_address)
				`IOTRIGMMC_CFG_ADDR: cnf_reg[reg_bytecnt*8 +: 8] <= reg_datai;	
				default: ;
			endcase
		end
	 end	 	 
	
	/* Trigger logic */
	 
	mmc_msg_capture #(.DATA_RELATED_ONLY(0)) msg_capture (
		.clk(clk),
		.reset_i(reset_i),
		.mmc_clk(target_mmc_clk),
		.mmc_cmd(target_mmc_cmd),
		.msg_packet(msg_packet),
		.msg_valid(msg_valid)
	);

	reg cmp_data_res;
	wire data_matches;
	wire cmd_matches;
	wire transmission_matches;
	wire all_matches;
	reg last_all_matches;
	wire is_cmd_packet;

	always @* begin
		case (cmp_data_op)
			`CMP_OP_EQ: cmp_data_res <= msg_packet[39:8] == cmp_data;
			`CMP_OP_NE: cmp_data_res <= msg_packet[39:8] != cmp_data;
			`CMP_OP_LT: cmp_data_res <= msg_packet[39:8] < cmp_data;
			`CMP_OP_GT: cmp_data_res <= msg_packet[39:8] > cmp_data;
		endcase
	end

	assign data_matches = cmp_data_res || !cmp_data_en;
	assign cmd_matches = (msg_packet[45:40] == cmp_cmd) || !cmp_cmd_en;
	assign transmission_matches = (msg_packet[46] == cmp_transmission) || !cmp_transmission_en;
	assign all_matches = data_matches && cmd_matches && transmission_matches;
	assign is_cmd_packet = (msg_packet[46] == 1'b1);

	always @(posedge target_mmc_clk or posedge reset_i) begin
		if (reset_i) begin
			last_all_matches <= 0;
		end else if (msg_valid) begin
			last_all_matches <= all_matches;
		end
	end

	/* Trigger output */
	reg trig;
	reg trig_s1, trig_sync;
	reg trig_ack_s1, trig_ack_sync;
	reg [6:0] trig_cnt;
	reg delay_trig;

	always @(posedge target_mmc_clk or posedge reset_i) begin
		if (reset_i || trig_ack_sync) begin
			trig <= 0;
			delay_trig <= 0;
		end else if (msg_valid && all_matches) begin
			if (!cmp_delay_next) begin
				trig <= 1; // trigger immediately
			end else begin
				delay_trig <= 1; // delay until next trigger
			end
		end else if (msg_valid && is_cmd_packet && delay_trig) begin
			if (!all_matches) begin // otherwise this one matches as well
				delay_trig <= 0;
			end
			trig <= 1;
		end
	end

	//Stretch trig_out for slower ADC clocks if needed (stretches for 127 cycles)
	always @(posedge clk) begin
		if (reset_i) begin
			trig_cnt <= 0;
			trig_out <= 0;
		end else if (trig_sync) begin
			trig_cnt <= 7'd1;
			trig_out <= 1;
		end else begin
			if (trig_cnt != 7'd0) begin
				trig_cnt <= trig_cnt + 7'd1;			
				trig_out <= 1'b1;
			end else begin
				trig_out <= 1'b0;
			end
		end
	end

	/* Synchronizer with ack since MMC clk can be slower OR faster than system clk */
	always @(posedge clk) begin
		if (reset_i) begin
			trig_s1 <= 0;
			trig_sync <= 0;
		end else begin
			trig_s1 <= trig;
			trig_sync <= trig_s1;
		end
	end

	always @(posedge target_mmc_clk or posedge reset_i) begin
		if (reset_i) begin
			trig_ack_s1 <= 0;
			trig_ack_sync <= 0;
		end else begin
			trig_ack_s1 <= trig_sync;
			trig_ack_sync <= trig_ack_s1;
		end
	end
 
endmodule
