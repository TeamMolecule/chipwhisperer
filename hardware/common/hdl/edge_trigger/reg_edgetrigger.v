`include "includes.v"

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
module reg_edgetrigger(
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
	
	input	[15:0] sources_i,
	output reg		trig_out									              
   );
	 
	 wire	  reset;
	 assign reset = reset_i;
	 assign reg_stream = 1'b0;

`define EDGETRIGGERCFG_ADDR 50 // Collide with SAKURA_STATUS_ADDR but we're out of addresses and these two shouldn't be used at the same time...
  // 31-26: Reserved
  // 25-20: threshold (trigger after every X edges)
  // 19-18: 0 = rising edge, 1 = falling edge, 2 = both edges, 3 = reserved
  // 17-16: 0 = OR, 1 = AND, 2 = NAND, 3 = reserved
  // 15-0: source select

	 reg [15:0] reg_hyplen_reg;
	 assign reg_hyplen = reg_hyplen_reg;
	 
	 always @(reg_hypaddress) begin
		case (reg_hypaddress)
				`EDGETRIGGERCFG_ADDR: reg_hyplen_reg <= 4;
				default: reg_hyplen_reg <= 0;
		endcase
	 end    
	
	 reg [7:0] reg_datao_reg;
	 assign reg_datao = reg_datao_reg;

	 reg [31:0]	edgetriggercfg_reg;
	  	 
	 always @(posedge clk) begin
		if (reg_read) begin
			case (reg_address)		
				`EDGETRIGGERCFG_ADDR: begin reg_datao_reg <= edgetriggercfg_reg[reg_bytecnt*8 +: 8]; end
				default: begin reg_datao_reg <= 0; end
			endcase
		end
	 end
	 
	 always @(posedge clk) begin
		if (reset) begin
			edgetriggercfg_reg <= 32'h100000;
		end else if (reg_write) begin
			case (reg_address)
				`EDGETRIGGERCFG_ADDR: edgetriggercfg_reg[reg_bytecnt*8 +: 8] <= reg_datai;	
				default: ;
			endcase
		end
	 end

	 reg [5:0] counter;
	 wire [5:0] threshold;
	 wire [1:0] style;
	 `define ET_STYLE_RISING 2'b00
	 `define ET_STYLE_FALLING 2'b01
	 `define ET_STLYE_BOTH 2'b10
	 wire [1:0] op;
	 `define ET_OP_OR 2'b00
	 `define ET_OP_AND 2'b01
	 `define ET_OP_XOR 2'b10
	 wire [15:0] select;
	 wire composed;
	 reg composed_sync, composed_sync_2;
	 wire rising_edge, falling_edge;
	 wire seen;

	 assign threshold = edgetriggercfg_reg[25:20];
	 assign style = edgetriggercfg_reg[19:18];
	 assign op = edgetriggercfg_reg[17:16];
	 assign select = edgetriggercfg_reg[15:0];

	 // edge detector
	 assign composed = (op == `ET_OP_OR) ? |(sources_i & select) : ((op == `ET_OP_AND) ? &(sources_i | ~select) : &(~sources_i | ~select));

	 always @(posedge clk) begin
	 	if (reset) begin
	 		composed_sync <= 0;
	 		composed_sync_2 <= 0;
	 	end else begin
	 		composed_sync <= composed;
	 		composed_sync_2 <= composed_sync;
	 	end
	 end

	 assign rising_edge = composed_sync & ~composed_sync_2;
	 assign falling_edge = ~composed_sync & composed_sync_2;

	 assign seen = (style == `ET_STYLE_RISING) ? rising_edge : ((style == `ET_STYLE_FALLING) ? falling_edge : (rising_edge | falling_edge));

	 // event counter and trigger
	 reg trig;
	 always @(posedge clk) begin
	 	if (reset) begin
	 		counter <= 0;
	 		trig <= 0;
	 	end else begin
	 		if (seen) begin
	 			if (counter >= threshold) begin
	 				counter <= 1'd1;
	 				trig <= 1;
	 			end else begin
	 				counter <= counter + 1'd1;
	 				trig <= 0;
	 			end
	 		end else begin
 				trig <= 0;
	 		end
	 	end
	 end

	//Stretch trig_out for slower ADC clocks if needed (stretches for 127 cycles)
	reg [6:0] trig_cnt;
	always @(posedge clk) begin
		if (trig) begin
			trig_cnt <= 7'd1;
			trig_out <= 1;
		end else
			if (trig_cnt != 7'd0) begin
				trig_cnt <= trig_cnt + 7'd1;			
				trig_out <= 1'b1;
			end else
				trig_out <= 1'b0;
	end
 
endmodule
