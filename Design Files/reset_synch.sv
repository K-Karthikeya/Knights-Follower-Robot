module reset_synch(
    input RST_n,         // Asynchronous reset signal (active low)
    input clk,           // System clock signal
    output reg rst_n     // Synchronized reset signal
);

reg FF1; // Intermediate flop 

// Flip-flop logic to synchronize reset signal to the clock domain
always_ff @(negedge clk or negedge RST_n) begin
    if(!RST_n) begin
        FF1 <= 1'b0;
        rst_n <= 1'b0;
    end
    else begin
        FF1 <= 1'b1;
        rst_n <= FF1;
    end
end

endmodule