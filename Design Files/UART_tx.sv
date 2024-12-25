module UART_tx(
    input clk, rst_n,                       
    input trmt,                             // signal to start transmission
    input [7:0] tx_data,                   // 8-bit data to transmit
    output TX,                               // UART transmit line
    output reg tx_done                      // Signal indicating transmission completion
);

// Define UART state machine states
typedef enum logic [1:0] {IDLE, TRANSMIT} UART_STATES;
UART_STATES cnt_state, nxt_state; // Current and next state variables

// Internal signals
reg init;                              // Signal to initialize transmission
reg transmitting;                       // Signal indicating active transmission
reg shift;                              // Signal controlling data shifting
reg set_done;                            // Signal to set transmission done
reg [3:0] bit_cnt;                     // Counter for bits transmitted
reg [11:0] baud_cnt;                    // Baud rate counter
reg [8:0] data_shift_reg;              // Shift register to hold UART data for transmission


// STATE MACHINE REGISTER
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        cnt_state <= IDLE; // Reset to IDLE state on reset
    else 
        cnt_state <= nxt_state; // Update to the next state
end

// DATA SHIFT REGISTER
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        data_shift_reg <= '1; // Reset shift register
    else if (init) 
        data_shift_reg <= {tx_data, 1'b0}; // Load data into shift register with stop bit
    else if (shift) 
        data_shift_reg <= {1'b1, data_shift_reg[8:1]}; // Shift bits during transmission
end

// BAUD COUNT REGISTER
always_ff @(posedge clk) begin
    if (init | shift) 
        baud_cnt <= 12'h000; // Reset the baud counter on init or shift
    else if (transmitting) 
        baud_cnt <= baud_cnt + 1; // Increment baud counter during transmission
end

// BIT COUNT REGISTER
// Counting number of bits being transmitted
always_ff @(posedge clk) begin
    if (init) 
        bit_cnt <= 9'h000; // Reset bit counter on init
    else if (shift) 
        bit_cnt <= bit_cnt + 1; // Count bits during transmission
end

// SET BIT REGISTER
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        tx_done <= 1'b0; // Reset tx_done on reset
    else if (init) 
        tx_done <= 1'b0; // Clear tx_done on initialization
    else if (set_done) 
        tx_done <= 1'b1; // Set tx_done when transmission is complete
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
            init = 1'b1; // Trigger initialization
			nxt_state = TRANSMIT;
		end // IF BLOCK
	end // IDLE BLOCK
	TRANSMIT: begin
			if(bit_cnt == 4'hA) begin
				set_done = 1'b1; // Mark transmission as done
				transmitting = 1'b0;
				nxt_state = IDLE; // Return to IDLE state
			end // IF BLOCK
			transmitting = 1'b1;
			shift = (baud_cnt == 12'hA2C); // Perform shift at the correct baud rate interval
	end // TRANSMIT BLOCK
	endcase
end // ALWAYS_COMB BLOCK


// --------------------------------------------------
// Assign TX line to the least significant bit of the shift register
assign TX = data_shift_reg[0];


endmodule
