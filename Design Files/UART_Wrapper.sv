module UART_Wrapper(
    input clk, rst_n,                      
    input send_resp,                       // Signal to send rresponse
    input [7:0] resp,                     // 8-bit response 
    input clr_cmd_rdy,                    // Signal to clear the command ready state
    input RX,                               // UART receiver input
    output TX,                              // UART transmitter output
    output tx_done,                        // Signal indicating transmit is done
    output [15:0] cmd,                     // 16-bit command data output
    output reg cmd_rdy                     // Command ready flag
);


typedef enum reg {IDLE, WRAP} STATES;
STATES cnt_state, nxt_state; 


wire rx_rdy;                  // Signal indicating RX is ready
reg read_data;                // Signal to indicate read data
reg clr_rdy;                  // Clear ready flag
reg set_cmd_rdy;              // Set the command ready flag
reg [7:0] rx_data_reg;       // Register to hold received UART data
reg [7:0] upper_byte_data;   // Holds upper byte of command data


UART TxRxMod(
    .clk(clk),                       
    .rst_n(rst_n),                   
    .RX(RX),                          
    .TX(TX),                          
    .rx_rdy(rx_rdy),                 
    .clr_rx_rdy(clr_rdy),             
    .rx_data(rx_data_reg),            
    .trmt(send_resp),                
    .tx_data(resp),                   
    .tx_done(tx_done)                 
);

/*bit8_UART_Transmitter TxMod(.clk(clk),
							.rst_n(rst_n),
							.send_resp(send_resp),
							.Tx_data(resp),
							.TX(TX),
							.Tx_done(tx_done));

bit8_UART_Receiver RxMod(.clk(clk),
						.rst_n(rst_n),
						.RX(TX),
						.clr_rdy(clr_rdy),
						.Rx_data(Rx_data_reg),
						.rdy(rx_rdy));*/

// State update logic
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        cnt_state <= IDLE; // Reset state to IDLE on reset
    else 
        cnt_state <= nxt_state; // Update current state to next state
end

// Logic to handle upper byte data update
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        upper_byte_data <= 8'h00; // Reset upper byte to 0 on reset
    else 
        upper_byte_data <= read_data ? rx_data_reg : upper_byte_data; // Update only when reading data
end

//  logic for command ready flag
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) 
        cmd_rdy <= 1'b0; // Reset command ready on reset
    else if (read_data || clr_cmd_rdy) 
        cmd_rdy <= 1'b0; // Clear command ready on read or clear command request
    else if (set_cmd_rdy) 
        cmd_rdy <= 1'b1; // Set command ready when appropriate
end


always_comb begin
    nxt_state = cnt_state; 
    read_data = 1'b0;      
    clr_rdy = 1'b0;
    set_cmd_rdy = 1'b0;

    case (cnt_state)
    // Since this module is only meant to receive two byte of data and wrap them together,
	// in the IDLE state, we are waiting to receive the upper byte of the 2 byte data.
	// Once we receive 1 byte (via rx_rdy signal), we store the data and start to receive the 
	// 2nd byte of the data
        IDLE: begin
            if (rx_rdy) begin
                nxt_state = WRAP; // Transition to WRAP state if rx is ready
                read_data = 1'b1; 
                clr_rdy = 1'b1;   // Clear the ready signal
            end
        end

        WRAP: begin
        // Receiving the 2nd byte of data. Once received we assert the cmd_rdy signal and start waiting
	    // to receive the next 2 bytes. This process continues.    
            if (rx_rdy) begin
                nxt_state = IDLE; // Transition back to IDLE after handling data
                clr_rdy = 1'b1;   // Clear the ready signal
                set_cmd_rdy = 1'b1; // Indicate command is ready
            end
        end
    endcase
end

// Combine the received data (upper byte and current data) into the full command
assign cmd = {upper_byte_data[7:0], rx_data_reg[7:0]};

endmodule
