module PWM11(
    input clk,                   // System clock input
    input rst_n,                // Active low reset signal
    input [10:0] duty,          // PWM duty cycle value (11 bits wide)
    output reg PWM_sig,         // PWM signal output
    output reg PWM_sig_n        // Complementary PWM signal output
);


reg [10:0] cnt;  // 11-bit counter to track the PWM signal


always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) 
        cnt <= 0; 
    else 
        cnt <= cnt + 1; // Increment counter on each clock cycle

// PWM signal generation logic
always_ff @(posedge clk, negedge rst_n) 
    if (!rst_n) begin
        PWM_sig <= 0;       
        PWM_sig_n <= 1;     
    end
    else begin
        PWM_sig <= (cnt <= duty) ? 1 : 0;      // Set PWM signal high for cnt value till duty-cycle 
        PWM_sig_n <= (cnt <= duty) ? 0 : 1;    // Set the complementary PWM signal 
    end

endmodule
