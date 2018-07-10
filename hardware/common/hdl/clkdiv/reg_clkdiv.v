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
module reg_clkdiv(
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
	
	input				extclk_i,
	output		divextclk_o									              
   );
	 
	 wire	  reset;
	 assign reset = reset_i;
	 assign reg_stream = 1'b0;

`define SLOWCLOCKGEN_ADDR 49 // Collide with SAKURA_STATUS_ADDR but we're out of addresses and these two shouldn't be used at the same time...
  
	 reg [15:0] reg_hyplen_reg;
	 assign reg_hyplen = reg_hyplen_reg;
	 
	 always @(reg_hypaddress) begin
		case (reg_hypaddress)
				`SLOWCLOCKGEN_ADDR: reg_hyplen_reg <= 1;
				default: reg_hyplen_reg <= 0;
		endcase
	 end    
	
	 reg [7:0] reg_datao_reg;
	 assign reg_datao = reg_datao_reg;
	 
	 reg [7:0]	clkdiv_reg;
	  	 
	 always @(posedge clk) begin
		if (reg_read) begin
			case (reg_address)		
				`SLOWCLOCKGEN_ADDR: begin reg_datao_reg <= clkdiv_reg[reg_bytecnt*8 +: 8]; end
				default: begin reg_datao_reg <= 0; end
			endcase
		end
	 end
	 
	 always @(posedge clk) begin
		if (reset) begin
			clkdiv_reg <= 0;
		end else if (reg_write) begin
			case (reg_address)
				`SLOWCLOCKGEN_ADDR: clkdiv_reg[reg_bytecnt*8 +: 8] <= reg_datai;	
				default: ;
			endcase
		end
	 end

	 reg [7:0] cnt;
	 reg divclk;

	 assign divextclk_o = (clkdiv_reg == 8'd0) ? extclk_i : divclk;

	 always @(posedge extclk_i or posedge reset) begin
	 	if (reset) begin
	 		cnt <= 8'd0;
	 		divclk <= 1'b0;
	 	end else if (cnt == clkdiv_reg) begin
	 		divclk <= ~divclk;
	 		cnt <= 8'd0;
	 	end else begin
	 		cnt <= cnt + 8'd1;
	 	end
	 end
 
endmodule

`undef CHIPSCOPE
