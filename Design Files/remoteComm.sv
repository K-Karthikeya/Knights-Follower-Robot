module remoteComm(
    input clk,             // System clock input
    input rst_n,          // Active low asynchronous reset
    input send_cmd,       // Signal to send command
    input [15:0] cmd,    // 16-bit command 
    input RX,             // UART receive line
    output TX,            // UART transmit line
    output [7:0] resp,   // 8-bit response data received
    output resp_rdy,      // Response ready signal
    output reg cmd_sent   // Signal indicating command has been sent
);

// Internal signal declarations
reg [7:0] lower_byte_data;   // Register to hold the lower byte of the command
reg [7:0] rx_data_reg;       // Register to store received UART data
reg clr_rdy;                  // Signal to clear response ready

wire [7:0] tx_data;          // Data to transmit over UART
wire tx_done;                 // Signal indicating transmit is done

reg trmt;                     // Signal to control transmission
reg byte_sel;                 // Control signal to select byte for transmission
reg set_cmd_snt;              // Signal to set the command_sent flag

// State machine definition
typedef enum reg[1:0] {IDLE, TRANSMIT, RESPONSE} STATES; // State encoding
STATES cnt_state, nxt_state; // Current state and next state signals


UART TxRxMod(
    .clk(clk),
    .rst_n(rst_n),
    .RX(RX),
    .TX(TX),
    .rx_rdy(resp_rdy),
    .clr_rx_rdy(clr_rdy),
    .rx_data(rx_data_reg),
    .trmt(trmt),
    .tx_data(tx_data),
    .tx_done(tx_done)
);

// State register to hold the current state
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) cnt_state <= IDLE; // Reset state on asynchronous reset
    else cnt_state <= nxt_state;  // Update state on every clock cycle

// Update the lower byte of the command on every clock edge if send_cmd is asserted
always_ff @(posedge clk)
    if (send_cmd) lower_byte_data <= cmd[7:0];


always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) cmd_sent <= 1'b0; // Reset the command_sent flag on reset
    else if (send_cmd) cmd_sent <= 1'b0; // Clear when a command is sent
    else if (set_cmd_snt) cmd_sent <= 1'b1; // Set the flag when command transmission is complete
end


always_comb begin
    nxt_state = cnt_state; 
    trmt = 1'b0;           //initialize all signals to zero
    set_cmd_snt = 1'b0;    
    byte_sel = 1'b0;       
    clr_rdy = 1'b0;        

    case (cnt_state) 
        // Wait in the IDLE state till send_cmd is received 
        IDLE: begin
            if (send_cmd) begin
                byte_sel = 1'b1; 
                trmt = 1'b1;    
                clr_rdy = 1'b1;  
                nxt_state = TRANSMIT; 
            end
        end
        // Wait for transmission to be complete
        TRANSMIT: begin
            if (tx_done) begin
                trmt = 1'b1;    
                nxt_state = RESPONSE; // Move to the response state when transmission is done
            end
        end
        // Send a response back
        RESPONSE: begin
            if (tx_done) begin
                set_cmd_snt = 1'b1; // Set the command_sent flag to indicate completion
                nxt_state = IDLE;  
            end
        end
    endcase
end

// Assign transmit data based on whether we are selecting a byte for transmission
assign tx_data = byte_sel ? cmd[15:8] : lower_byte_data;

// Assign received UART response data
assign resp = rx_data_reg;

endmodule

