`timescale 1ns/1ps
module remoteComm(
	input clk,
	input rst_n,
	input send_cmd,
	input [15:0] cmd,
	input RX,
	output TX,
	output [7:0] resp,
	output resp_rdy,
	output reg cmd_sent
);

reg [7:0] lower_byte_data;
reg [7:0] rx_data_reg;
reg clr_rdy;

wire [7:0] tx_data;
wire tx_done;

reg trmt;
reg byte_sel;
reg set_cmd_snt;

typedef enum reg[1:0] {IDLE, TRANSMIT, RESPONSE} STATES;
STATES cnt_state, nxt_state;

UART TxRxMod(.clk(clk),
						 .rst_n(rst_n),
						 .RX(RX),
						 .TX(TX),
						 .rx_rdy(resp_rdy),
						 .clr_rx_rdy(clr_rdy),
						 .rx_data(rx_data_reg),
						 .trmt(trmt),
						 .tx_data(tx_data),
						 .tx_done(tx_done));

always_ff@(posedge clk, negedge rst_n)
	if(!rst_n) cnt_state <= IDLE;
	else cnt_state <= nxt_state;

always_ff@(posedge clk)
	if(send_cmd) lower_byte_data <= cmd[7:0];

always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) cmd_sent <= 1'b0;
	else if(send_cmd) cmd_sent <= 1'b0;
	else if(set_cmd_snt) cmd_sent <= 1'b1;
end

always_comb begin
	nxt_state = cnt_state;
	trmt = 1'b0;
	set_cmd_snt = 1'b0;
	byte_sel = 1'b0;
	clr_rdy = 1'b0;
	
	case(cnt_state)
		IDLE: begin
			if(send_cmd) begin
				byte_sel = 1'b1;
				trmt = 1'b1;
				clr_rdy = 1'b1;
				nxt_state = TRANSMIT;
			end // IF BLOCK
		end // IDLE STATE
		
		TRANSMIT: begin
			if(tx_done) begin
				trmt = 1'b1;
				nxt_state = RESPONSE;
			end // IF BLOCK
		end // TRANSMIT STATE

		RESPONSE: begin
			if(tx_done) begin
				set_cmd_snt = 1'b1;
				nxt_state = IDLE;
			end // IF BLOCK
		end // RESPONSE BLOCK
	endcase
end

assign tx_data = byte_sel ? cmd[15:8] : lower_byte_data;
assign resp = rx_data_reg;

endmodule

