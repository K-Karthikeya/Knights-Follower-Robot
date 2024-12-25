`timescale 1ns/1ps
module UART_tx(
	input clk, rst_n,
	input trmt,
	input [7:0] tx_data,
	output TX,
	output reg tx_done
);

typedef enum logic [1:0] {IDLE, TRANSMIT} UART_STATES;
UART_STATES cnt_state, nxt_state;

reg init;
reg transmitting;
reg shift;
reg set_done;
reg [3:0] bit_cnt;
reg [11:0] baud_cnt;
reg [8:0] data_shift_reg;


// STATE MACHINE REGISTER
always_ff@(posedge clk, negedge rst_n)
	if(!rst_n) cnt_state <= IDLE;
	else cnt_state <= nxt_state;

// DATA SHIFT REGISTER
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) data_shift_reg <= '1;
	else if(init) data_shift_reg <= {tx_data, 1'b0};
	else if(shift) data_shift_reg <= {1'b1, data_shift_reg[8:1]};
end

// BAUD COUNT REGISTER
always_ff@(posedge clk) begin
	if(init | shift) baud_cnt <= 12'h000;
	else if(transmitting) baud_cnt <= baud_cnt + 1;
end

// BIT COUNT REGISTER
// Counting number of bits being transmitted
always_ff@(posedge clk) begin
	if(init) bit_cnt <= 9'h000;
	else if(shift) bit_cnt <= bit_cnt + 1;
end

// SET BIT REGISTER
always@(posedge clk, negedge rst_n) begin
	if(!rst_n) tx_done <= 1'b0;
	else if(init) tx_done <= 1'b0;
	else if(set_done) tx_done <= 1'b1;
end

always_comb begin
	nxt_state = cnt_state;
	init = 1'b0;
	transmitting = 1'b0;
	set_done = 1'b0;
	shift = 1'b0;
	case(cnt_state)
	IDLE: begin
		if(trmt) begin
			init = 1'b1;
			nxt_state = TRANSMIT;
		end // IF BLOCK
	end // IDLE BLOCK
	TRANSMIT: begin
			if(bit_cnt == 4'hA) begin
				set_done = 1'b1;
				transmitting = 1'b0;
				nxt_state = IDLE;
			end // IF BLOCK
			transmitting = 1'b1;
			shift = (baud_cnt == 12'hA2C);
	end // TRANSMIT BLOCK
	endcase
end // ALWAYS_COMB BLOCK

assign TX = data_shift_reg[0];


endmodule
