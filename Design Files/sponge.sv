module sponge (
    input wire clk,              // 50 MHz clock
    input wire rst_n,            // Active-low reset
    input wire go,               // Start signal
    output logic piezo,          // Output for piezo bender
    output logic piezo_n         // Complementary output for piezo bender
);

    // Internal signal declarations
    logic [23:0] dur_cnt;
    logic clr_dur_cnt;
    logic [14:0] note_freq;
    logic clr_note_freq;
    logic [14:0] note_freq_value;
    logic [4:0] cnt;

    parameter FAST_SIM = 1;  // Set to 1 by default for fast simulation

    // State machine states declaration
    typedef enum logic [3:0] {IDLE, D7, E7, F7, E7_again, F7_again, D7_again, A6, D7_again_again} state_t;
    state_t state, next_state;

    // Frequency constants
    localparam D7_FREQ = 15'd21285;
    localparam E7_FREQ = 15'd18960;
    localparam F7_FREQ = 15'd17895;
    localparam A6_FREQ = 15'd28409;

    // Duration constants (for hardware and fast simulation)
    localparam DURATION_DEFAULT = 24'h800000;
    localparam DUR_1 = 24'h400000; // 2^22 clocks
    localparam DUR_2 = 24'hC00000; //2^23 +2^22 clocks
    
    // Set cnt value based on FAST_SIM parameter
    generate
        if (FAST_SIM)
            assign cnt = 5'b10000; //if FAST_SIM,count increments by 16
        else
            assign cnt = 1'b1;   //without FAST_SIM,count increments by 1
    endgenerate

    // Note frequency counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            note_freq <= '0;
        else if (clr_note_freq | (note_freq==note_freq_value))
            note_freq <= '0;
        else
            note_freq <= note_freq + 1;
    end

    // Duration counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dur_cnt <= '0;
        else if (clr_dur_cnt)
            dur_cnt <= '0;
        else
            dur_cnt <= dur_cnt + cnt;
    end

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        clr_dur_cnt = 1'b0;
        clr_note_freq = 1'b0;
        note_freq_value = '0;
        
        case (state)
            IDLE: begin
                if (go) begin
                    next_state = D7;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            D7: begin
                note_freq_value = D7_FREQ;
                if (dur_cnt == DURATION_DEFAULT) begin
                    next_state = E7;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            E7: begin
                note_freq_value = E7_FREQ;
                if (dur_cnt == DURATION_DEFAULT) begin
                    next_state = F7;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            F7: begin
                note_freq_value = F7_FREQ;
                if (dur_cnt == DURATION_DEFAULT) begin
                    next_state = E7_again;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            E7_again: begin
                note_freq_value = E7_FREQ;
                if (dur_cnt == DUR_2) begin
                    next_state = F7_again;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            F7_again: begin
                note_freq_value = F7_FREQ;
                if (dur_cnt == DUR_1) begin
                    next_state = D7_again;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            D7_again: begin
                note_freq_value = D7_FREQ;
                if (dur_cnt == DUR_2) begin
                    next_state = A6;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end

            A6: begin
                note_freq_value = A6_FREQ;
                if (dur_cnt == DUR_1) begin
                    next_state = D7_again_again;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end
				
				D7_again_again: begin
                note_freq_value = D7_FREQ;
                if (dur_cnt == DUR_2) begin
                    next_state = IDLE;
                    clr_dur_cnt = 1'b1;
                    clr_note_freq = 1'b1;
                end
            end
        endcase
    end

    // Output assignment for piezo
    assign piezo = (note_freq < (note_freq_value >> 1)) ? 1'b0 : 1'b1;
    assign piezo_n = ~piezo;

endmodule
