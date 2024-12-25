module cmd_proc(
    input clk,
    input rst_n,

    // to/from Wrapper
    input [15:0] cmd, // Input command from Wrapper
    input cmd_rdy, // Control signal to indicate Input command is ready
    output logic clr_cmd_rdy, // Control signal to clear cmd_rdy, to receive next cmd
    output logic send_resp, // Control signal to send a response data (0xA5)

    // tour_go control signal
    output logic tour_go,

    // to/from inert_intf
    input logic signed [11:0] heading, // Actual heading of the robot from MEMs GYRO
    input heading_rdy, // Control signal asserted when heading reading is ready
    output logic strt_cal, // Control signal to start calibration
    input cal_done, // Control signal asserted when calibration is complete
    output logic moving, // Control signal to indicate when robot is moving

    // from IR sensors
    input lftIR, // left IR sensor reading
    input cntrIR, // Centre IR sensor reading
    input rghtIR, // Right IR sensor reading

    // to spongeBob
    output logic fanfare_go, // Control signal to play sound

    // to PID controller
    output logic [9:0] frwrd, // Speed control of the robot
    output logic signed[11:0] error // Error term of the robot
    // Moving signal will be used from up above
);

parameter FAST_SIM = 1;

localparam O_CALIBRATE = 4'b0010; // Opcode to calibrate
localparam O_MOVE = 4'b0100; // Opcode to Move
localparam O_MOVE_F = 4'b0101; // Opcode to Move with fanfare
localparam O_TOUR_GO = 4'b0110; // Opcode for Tour Logic

typedef enum logic [7:0] {IDLE, CALIBRATE, MOVE, RAMP_UP, RAMP_DOWN, FANFARE, TOUR_GO} STATES;
STATES cnt_state, nxt_state;

logic [11:0] desired_heading;// Desired heading value
logic [11:0] err_nudge;// Error nudge value
logic [7:0] frwrd_incr;// Forward increment
logic [7:0] frwrd_decr;// Forward decrement
logic [7:0] incr;// Increment value
logic [2:0] num_boxs;// Number of boxes to move
logic [3:0] num_box_count;// Counter for number of boxes crossed
logic frwrd_en;// Forward enable signal
logic inc_frwrd;// Increment forward signal
logic dec_frwrd;// Decrement forward signal
logic RE_cntrIR;// rising edge for center IR sensor
logic move_cmd;//command to make  move
logic move_done;// command asserted when move is complete
logic max_spd;//max speed of knight
logic zero;
logic [3:0] opcode;// from command

// Register to change the current state
always_ff@(posedge clk, negedge rst_n) 
    if(!rst_n) cnt_state <= IDLE;
    else cnt_state <= nxt_state;

// Controlling the speed of the robot
always_ff@(posedge clk, negedge rst_n)
    if(!rst_n) frwrd <= 10'h000;
    else if(frwrd_en) frwrd <= inc_frwrd ? frwrd + incr : frwrd - incr;

// cntrIR Rise edge detector
logic FF1, FF2, FF3;
always_ff @( posedge clk, negedge rst_n ) begin 
    if(!rst_n) begin
        FF1 <= 1'b0;
        FF2 <= 1'b0;
        FF3 <= 1'b0; 
    end
    else begin
        FF1 <= cntrIR;
        FF2 <= FF1;
        FF3 <= FF2; //double flopped signal FF3
    end
end

assign RE_cntrIR = (!FF3 & FF2); //rising edge detector

// Flopping number of squares to move
always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) num_boxs <= 4'h0;
    else if(move_cmd) num_boxs <= cmd[2:0]; //load number of boxes from the command
end

// Counting number of squares crossed
always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) num_box_count <= '0;
    else if(move_cmd) num_box_count <= 4'h0; //reset box count on move_cmd
    else if(RE_cntrIR) num_box_count <= num_box_count + 1'b1;// increment box count on rising edge of center IR
end
    
// Register to load the value of desired heading from the incoming command
always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) desired_heading <= '0;
    else if(move_cmd) desired_heading <= (cmd[11:4] == 8'h00) ? {cmd[11:4], 4'h0} : {cmd[11:4], 4'hF};// desired heading along which knight should make a move
end

always_comb begin : STATE_TRANSITION

    nxt_state = cnt_state;
    clr_cmd_rdy = 1'b0;// initializing signals to zero
    strt_cal = 1'b0;
    send_resp = 1'b0;
    moving = 1'b0;
    move_cmd = 1'b0;
    inc_frwrd = 1'b0;
    dec_frwrd = 1'b0;
    fanfare_go = 1'b0;
    tour_go = 1'b0;

    case(cnt_state)
        // Jumps to appropriate state based on imcoming command
        IDLE: begin
            case(opcode)
                O_CALIBRATE: begin
                    nxt_state = CALIBRATE;
                    strt_cal = 1'b1;
                    clr_cmd_rdy = 1'b1;
                end
                O_MOVE, O_MOVE_F: begin
                    nxt_state = MOVE;
                    clr_cmd_rdy = 1'b1;
                    move_cmd = 1'b1;
                end
                O_TOUR_GO: begin
                    nxt_state = TOUR_GO;
                    clr_cmd_rdy = 1'b1;
                end
                default: nxt_state = cnt_state;
            endcase
        end

        // Calibration state
        CALIBRATE: begin
            if(cal_done) begin
                nxt_state = IDLE;
                send_resp = 1'b1;
            end
        end

        // Waiting for the error to come within acceptable limit
        MOVE: begin
            moving = 1'b1;//
            if((error > $signed(-12'h02C)) && (error < $signed(12'h02C))) begin // check error value within the limits
                nxt_state = RAMP_UP;
            end
        end

        // Once error is within acceptable limit, we start moving
        RAMP_UP: begin
            moving = 1'b1;
            inc_frwrd = 1'b1; //forward speed is incremented
            if(move_done) begin
                nxt_state = RAMP_DOWN;
                fanfare_go = |cmd[13:12]; //play fanfare
            end
        end

        // Once we cross required number of boxes, we start to slow down
        RAMP_DOWN: begin
            moving = 1'b1;
            dec_frwrd = 1'b1;// decrement the forward speed
            if(frwrd == 10'h000) begin
                nxt_state = IDLE;
                send_resp = 1'b1;// send response signal high
            end
        end

        // If tour_go command, we hand over control to tour_cmd block
        TOUR_GO: begin
            tour_go = 1'b1;
            nxt_state = IDLE;
        end

        default: nxt_state = IDLE;
    endcase
end

// Generating the value of frwrd increment and err_nudge based on FAST_SIM
generate
    if(FAST_SIM)
        assign err_nudge = lftIR ? 12'h1FF : //positive offset when FAST_SIM is high
                           rghtIR ? 12'hE00 : // NEGATIVE OFFSET when FAST_SIM is high
                           12'h000;
    else
        assign err_nudge = lftIR ? 12'h05F : //positive offset without FAST_SIM
                           rghtIR ? 12'hFA1 : //negative offset without FAST_SIM
                           12'h000;
endgenerate


generate
    if(FAST_SIM) assign frwrd_incr = 8'h20;
    else assign frwrd_incr = 8'h03;
endgenerate

assign frwrd_decr = frwrd_incr << 1; // Decrement is 2 times increment
assign incr = inc_frwrd ? frwrd_incr : frwrd_decr; // Value to increment or decrement
assign zero = (!(|frwrd)); // Control signal to check if speed is 0
assign max_spd = (&frwrd[9:8]); // Control signal to check for max speed
assign frwrd_en = (heading_rdy && ((inc_frwrd & !max_spd) | (dec_frwrd & !zero ))); // Control signal to enable forward movement
assign error = heading - desired_heading + err_nudge; // Final error term after the fusion of IR sensors
assign move_done = ({num_boxs, 1'b0} == num_box_count); // Control signal to keep track of number of boxes moved
assign opcode = cmd_rdy ? cmd[15:12] : 4'h0; // Opcode segment of incoming cmd
endmodule
