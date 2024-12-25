module UART_rx(
    input clk, rst_n,                       
    input RX,                               // UART receive signal
    input clr_rdy,                          // Signal to clear ready
    output [7:0] rx_data,                  // Received 8-bit data
    output reg rdy                           // Signal indicating data is ready
);

// Internal signals and registers
reg start;                                  
reg shift;                                  
reg receiving;                               // Indicates active reception
reg RX_FF1, RX_FF2;                          // Double flip-flops for metastability protection
reg set_rdy;                                  // Sets the ready signal when data reception is complete
reg [8:0] shift_reg;                        // 9-bit shift register for serial data
reg [11:0] baud_cnt;                        // Counter for baud rate timing
reg [3:0] bit_cnt;                          // Counter for bits received

// State machine states
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

// State machine state register
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        cnt_state <= IDLE; 
    else 
        cnt_state <= nxt_state; 
end

// Shift register logic for data reception
// Pushing the incoming bits into the shift register
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        shift_reg <= '1; 
    else if (shift) 
        shift_reg <= {RX_FF2, shift_reg[8:1]}; 
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

// Logic to manage the ready signal
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) rdy <= 1'b0;
	else if(start || clr_rdy) rdy <= 1'b0;
	else if(set_rdy) rdy <= 1'b1;
end


always_comb begin
	nxt_state = cnt_state;
	start = 1'b0;
	receiving = 1'b0;
	set_rdy = 1'b0;
	shift = 1'b0;
	case(cnt_state)
		// Waiting in IDLE state till the double flopped RX line goes low, indicating the start of transmission
		IDLE: begin
			if(RX_FF2 == 1'b0) begin
				start = 1'b1;
				nxt_state = RECEIVE;
			end // IF BLOCK
		end // IDLE BLOCK

		// Continue to recieve 10 bits, and once received move back to IDLE again.
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

assign rx_data = shift_reg[7:0]; // Final RX data is held in the shift_reg

endmodule
