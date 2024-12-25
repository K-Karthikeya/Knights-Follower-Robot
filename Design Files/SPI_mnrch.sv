module SPI_mnrch(
    input clk,                      // System clock input
    input rst_n,                   // Active-low reset signal
    input snd,                     // Signal to initiate SPI communication
    input [15:0] cmd,              // Command  to be sent
    output [15:0] resp,            // Response data from SPI serf
    output reg done,               // Indicates the transmission is done
    output SCLK,                   // SPI clock signal
    output reg SS_n,               // SPI slave select (active low)
    input MISO,                     // Master In Slave Out (SPI input)
    output MOSI                     // Master Out Slave In (SPI output)
);


typedef enum reg[1:0] {IDLE, TRANSMIT} STATES; 
STATES cnt_state, nxt_state; 

reg [15:0] shift_reg;         // 16-bit register to hold data for SPI transmission
reg [4:0] SCLK_cntr;          // Counter for generating SPI clock signal
reg [4:0] bit_cntr;           // Counter to track number of bits transmitted

reg ld_SCLK;                   // Load signal for SCLK counter
reg set_done;                   // Signal to mark transmission completion
reg init;                       // Indicates SPI communication initialization

wire shift;                     // Indicates when data should shift
wire full;                       // Indicates full transmission readiness
wire done16;                     // Indicates when 16 bits have been transmitted

// Updating current State to next state
always@(posedge clk, negedge rst_n) 
    if(!rst_n) cnt_state <= IDLE; // Reset to IDLE state on reset
    else cnt_state <= nxt_state; // Move to the next state

// Shifting the data transfer register and loading in the new value to the MSB
always@(posedge clk)
    if(init) shift_reg <= cmd; // Load command into the shift register at the start
    else if(shift) shift_reg <= {shift_reg[14:0], MISO}; // Shift in data serially

// Incrementing the SCLK_cntr to toggle SCLK
always@(posedge clk)
    if(ld_SCLK) SCLK_cntr <= 5'b10111; // Reset counter value when SCLK is loaded
    else SCLK_cntr <= SCLK_cntr + 1; // Increment SCLK counter

// Keeping track of total number of bits transmitted
always@(posedge clk)
    if(init) bit_cntr <= 5'b00000; 
    else if(shift) bit_cntr <= bit_cntr + 1; // Increment when bits are shifted

// SR Latch to update SS_n
always@(posedge clk, negedge rst_n)
    if(!rst_n) SS_n <= 1'b1; 
    else if(set_done) SS_n <= 1'b1; // Return to idle state after transmission
    else if(init) SS_n <= 1'b0; // Assert SS_n to start communication

// SR Latch to set the set_done bit
always@(posedge clk, negedge rst_n)
    if(!rst_n) done <= 1'b0; 
    else if(init) done <= 1'b0; // Clear during initialization
    else if(set_done) done <= 1'b1; // Assert when transmission is complete

always_comb begin
    nxt_state = cnt_state; 
    ld_SCLK = 1'b0;        
    init = 1'b0;           
    set_done = 1'b0;       

    case(cnt_state)
        //ld_SCLK is always 1 when not transmitting any data.
		// Once snd signal is asserted, we initiate the transmission.
        IDLE: begin
            ld_SCLK = 1'b1; 
            if(snd) begin
                init = 1'b1; // Set the SPI transmission
                nxt_state = TRANSMIT; // Transition to TRANSMIT state
            end
        end

		// We continue transmitting the data till all 16 bits of data is transmitted.
		// Once the transmission is complete, just before the SCLK_cntr rolls over to 0
		// causing the SCLK to toggle again, we finish the transmission and assert the done bit.
		TRANSMIT: begin
			if(done16 && full) begin
                		ld_SCLK = 1'b1; // Load SCLK when 16 bits are ready
                		set_done = 1'b1; // Signal completion
                		nxt_state = IDLE; // Return to idle state after transmission
            		end
        	end
    endcase
end

// Control signals for the SM
assign shift = (SCLK_cntr == 5'b10001); // Shift condition based on SCLK counter
assign full = (SCLK_cntr == 5'b11111); // Indicates counter is fully loaded
assign done16 = (bit_cntr == 5'b10000); // Checks if all 16 bits are transmitted
// SCLK and Data transmission control
assign resp = shift_reg[7:0]; // Send the first 8 bits as response
assign SCLK = SCLK_cntr[4]; // Assign clock signal from counter bits
assign MOSI = shift_reg[15]; // Send the MSB of shift register to SPI bus

endmodule	
