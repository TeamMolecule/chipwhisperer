`include "includes.v"
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
module mmc_msg_capture(
	input 					clk,
	input 					reset_i,

	input 					mmc_clk,
	input 					mmc_cmd,

	output [47:0]		msg_packet,
	output 					msg_valid
);

`define GET_START 3'b000
`define GET_TRANSMITTER 3'b001
`define GET_CMD 3'b010
`define GET_CONTENT 3'b011
`define SKIP_R2_RESP 3'b101
`define GET_CRC 3'b110
`define GET_END 3'b111

`define CMD2 6'd2
`define CMD9 6'd9
`define CMD10 6'd10

reg [47:0] packet, next_packet;
reg valid, next_valid;
reg [2:0] state, next_state;
reg [8:0] cnt, next_cnt;
reg wait_for_r2, next_wait_for_r2;

assign msg_packet = packet;
assign msg_valid = valid;

always @(posedge mmc_clk or posedge reset_i) begin
	if (reset_i) begin
		state <= `GET_START;
		cnt <= 9'b0;
		wait_for_r2 <= 1'b0;
		packet <= 48'b0;
		valid <= 1'b0;
	end else begin
		state <= next_state;
		cnt <= next_cnt;
		wait_for_r2 <= next_wait_for_r2;
		packet <= next_packet;
		valid <= next_valid;
 	end
end

always @(*) begin
	next_state = state;
	next_cnt = cnt;
	next_wait_for_r2 = wait_for_r2;
	next_packet = packet;
	next_valid = valid;
	case (state)
		`GET_START: begin
			next_valid = 1'b0;
			next_packet[47] = mmc_cmd;
			if (!mmc_cmd)
				next_state = `GET_TRANSMITTER;
		end
		`GET_TRANSMITTER: begin
			next_packet[46] = mmc_cmd;
			next_state = `GET_CMD;
			next_cnt = 0;
		end
		`GET_CMD: begin
			next_packet[45-cnt] = mmc_cmd;
			next_cnt = cnt + 1'b1;
			if (cnt >= 6) begin
				next_state = `GET_CONTENT;
				next_cnt = 9'b0;
			end
		end
		`GET_CONTENT: begin
			next_packet[39-cnt] = mmc_cmd;
			next_cnt = cnt + 1'b1;
			if (cnt >= 32) begin
				if (wait_for_r2) begin
					next_state = `SKIP_R2_RESP;
				end else begin
					next_state = `GET_CRC;
					next_cnt = 9'b0;
				end
			end
		end
		`SKIP_R2_RESP: begin
			next_cnt = cnt + 1'b1;
			if (cnt >= 120) begin
				next_state = `GET_CRC;
				next_cnt = 9'b0;
			end
		end
		`GET_CRC: begin
			next_packet[7-cnt] = mmc_cmd;
			next_cnt = cnt + 1'b1;
			if (cnt >= 7) begin
				next_state = `GET_END;
				next_cnt = 9'b0;
			end
		end
		`GET_END: begin
			next_packet[0] = mmc_cmd;
			next_state = `GET_START;
			if (packet[46] && (packet[45:40] == `CMD2 || packet[45:40] == `CMD9 || packet[45:40] == `CMD10)) begin
				next_wait_for_r2 = 1'b1;
			end else begin
				next_wait_for_r2 = 1'b0;
			end
			next_valid = 1'b1;
		end
		default: next_state = `GET_START;
	endcase
end

endmodule // mmc_cmd_capture
