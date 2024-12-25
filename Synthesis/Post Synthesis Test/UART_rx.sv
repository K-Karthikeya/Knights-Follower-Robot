`timescale 1ns/1ps
module UART_rx(
	input clk, rst_n,
	input RX,
	input clr_rdy,
	output [7:0] rx_data,
	output reg rdy
);

reg start;
reg shift;
reg receiving;
reg RX_FF1, RX_FF2;
reg set_rdy;
reg [8:0] shift_reg;
reg [11:0] baud_cnt;
reg [3:0] bit_cnt;

typedef enum reg {IDLE, RECEIVE} STATES;
STATES cnt_state, nxt_state;

//Double Flopping RX to prevent meta-stability
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		RX_FF1 <= 1'b1;
		RX_FF2 <= 1'b1;
	end
	else begin
		RX_FF1 <= RX;
		RX_FF2 <= RX_FF1;
	end
end

// State machine registers
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) cnt_state <= IDLE;
	else cnt_state <= nxt_state;
end

// Receiving register
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) shift_reg <= '1;
	else if(shift) shift_reg <= {RX_FF2, shift_reg[8:1]};
end

// Baud count register
always_ff@(posedge clk) begin
	if(start) baud_cnt <= 12'd1302;
	else if(shift) baud_cnt <= 12'd2604;
	else if(receiving) baud_cnt <= baud_cnt - 1;
end

// Bit count register
always_ff@(posedge clk) begin
	if(start) bit_cnt <= 4'd0;
	else if(shift) bit_cnt <= bit_cnt + 1;
end

always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) rdy <= 1'b0;
	else if(start || clr_rdy) rdy <= 1'b0;
	else if(set_rdy) rdy <= 1'b1;
end

// Combinational Logic
always_comb begin
	nxt_state = cnt_state;
	start = 1'b0;
	receiving = 1'b0;
	set_rdy = 1'b0;
	shift = 1'b0;
	case(cnt_state)
		IDLE: begin
			if(RX_FF2 == 1'b0) begin
				start = 1'b1;
				nxt_state = RECEIVE;
			end // IF BLOCK
		end // IDLE BLOCK

		RECEIVE: begin
			//start = 1'b0;
			receiving = 1'b1;
			if(baud_cnt == 12'd0) shift = 1'b1;
			if(bit_cnt == 4'd10) begin
				set_rdy = 1'b1;
				receiving = 1'b0;
				nxt_state = IDLE;
			end // IF BLOCK
		end // RECEIVE BLOCK
	endcase // CASE STATEMENT
end // ALWAYS BLOCK

assign rx_data = shift_reg[7:0];

endmodule
