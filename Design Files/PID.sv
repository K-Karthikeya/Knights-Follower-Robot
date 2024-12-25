module PID (
    input clk,
    input rst_n,
    input moving,
    input err_vld,
    input signed [11:0] error,
    input [9:0] frwrd,
    output signed [10:0] lft_spd,
    output signed [10:0] rght_spd,
	output LED
);

// logic [13:0] P_term_FF;
// logic [13:0] I_term_FF;
// logic [13:0] D_term_FF;
// logic [9:0] frwrd_FF;

logic signed [9:0] err_sat;
logic signed [9:0] err_sat_FF;
logic err_vld_FF;
logic signed [13:0]PID_term_FF;

logic signed [13:0] P_term;  //P term
logic signed [8:0] I_term;   // I term
logic signed [12:0] D_term;  //D term

logic signed [12:0] P_term_div2; // P term divided by 2 before sign extending
logic signed [13:0] P_term_SE; // Sign Extended P term
logic signed [13:0] I_term_SE; // Sign Extended I term
logic signed [13:0] D_term_SE; // Sign Extended D term
logic signed [10:0] frwrd_ZE; // Zero Extended frwrd term
logic signed [13:0] PID_term; // Final PID term

logic signed [10:0] lft_spd_i; // Intermediate value for left speed
logic signed [10:0] rght_spd_i; // Intermediate value for right speed
logic signed [10:0] lft_spd_US; // Unsaturated value for left speed
logic signed [10:0] rght_spd_US; // Unsaturated value for right speed

// always_ff @( posedge clk ) begin
// 	if(!rst_n) begin
// 		P_term_FF <= 14'h0000;
// 		I_term_FF <= 14'h0000;
// 		D_term_FF <= 14'h0000;
// 	end
// 	else
// 		P_term_FF <= P_term_SE;
// 		I_term_FF <= I_term_SE;
// 		D_term_FF <= D_term_SE;
// end

// always_ff @( posedge clk ) begin
// 	if(!rst_n) 
// 		frwrd_FF <= 10'h000;
// 	else 
// 		frwrd_FF <= frwrd_ZE;
// end

//saturated error flop
always_ff @( posedge clk or negedge rst_n ) begin
	if(!rst_n) err_sat_FF <= 10'h000;
	else err_sat_FF <= err_sat;	
end

//error valid flop
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n) err_vld_FF = 1'b0;
	else err_vld_FF = err_vld;
end

//PID term flop
always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n) PID_term_FF <= 14'h0000;
	else PID_term_FF <= PID_term; 
end

//////////////////////////////////////////////////////////////////////////////
// Error Saturation //////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
assign err_sat = error[11] ?
				 (&error[10:9] ? {1'b1, error[8:0]} : -10'd512) :
				 (|error[10:9] ? 10'd511 : {1'b0, error[8:0]}) ;

//////////////////////////////////////////////////////////////////////////////
// P-term Logic //////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
localparam P_COEFF = 6'h10;
assign P_term = err_sat_FF * $signed(P_COEFF) ;
assign P_term_div2 = P_term >>> 1;
assign P_term_SE = {P_term_div2[12], P_term_div2};  //sign extended P-term

//////////////////////////////////////////////////////////////////////////////
// I-term Logic //////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
logic signed [14:0] integrator;
logic signed [14:0] err_sat_signExt;
logic signed [14:0] integrated_err;
logic signed [14:0] valid_integrated_err;
logic signed [14:0] next_integrator;
logic overflow;

// Flopping the I-term of error
always_ff @ (posedge clk, negedge rst_n) begin
	if(!rst_n)
		integrator <= 15'h0000;
	else
		integrator <= next_integrator;
end // ALWAYS BLOCK

//sign extended error sat signal
assign err_sat_signExt = {{5{err_sat_FF[9]}}, err_sat_FF};  
// Accumlating the incoming error into the already existing I-term error
assign integrated_err = integrator + err_sat_signExt;		
 //check for overflow after addition
assign overflow = ~(integrator[14] ^ err_sat_signExt[14]) ?                   
				   (integrator[14] == integrated_err[14]) ? 0 : 1 : 0 ;   
// Checking if the incoming err is valid and flop will not overflow upon addition of the next err
assign valid_integrated_err = (~overflow & err_vld_FF) ? integrated_err : integrator ; 
// Only if the bot is moving, we flop that integrated_err
assign next_integrator = (moving) ? valid_integrated_err : 15'h0000 ; 

// Reducing the precision for easier data handling
assign I_term = integrator[14:6];
//sign extended I-term to not lose the absolute value
assign I_term_SE = { { 5{I_term[8]} }, I_term };

//////////////////////////////////////////////////////////////////////////////
// D-term Logic //////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
logic signed [9:0] err_sat_MEM1;
logic signed [9:0] err_sat_MEM2;
logic signed [9:0] err_sat_MEM3;

logic [9:0] D_diff;
logic signed [7:0] D_term_sat; //saturated D-term

localparam D_COEFF = 5'h07;

// Flopping the incoming err_sat to calculate the difference between the current and previous error
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		err_sat_MEM1 <= 0;
		err_sat_MEM2 <= 0;
		err_sat_MEM3 <= 0;
	end

	else begin
		err_sat_MEM1 <= err_vld_FF ? err_sat_FF : err_sat_MEM1;
		err_sat_MEM2 <= err_vld_FF ? err_sat_MEM1 : err_sat_MEM2;
		err_sat_MEM3 <= err_vld_FF ? err_sat_MEM2 : err_sat_MEM3;
	end
end // ALWAYS_FF BLOCK

// Calculating the difference in error
assign D_diff = err_sat_FF - err_sat_MEM3;
// Saturating the error
assign D_term_sat = D_diff[9] ?
					(&D_diff[8:7]) ? D_diff[7:0] : -8'd128 :
					(|D_diff[8:7]) ? 8'd127 : {D_diff[9], D_diff[6:0]};
// Multiplying with D_COEFF
assign D_term = D_term_sat * $signed(D_COEFF);
// Sign Extending D_term
assign D_term_SE = {D_term[12], D_term};

//////////////////////////////////////////////////////////////////////////////
// PID-term Logic ////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
// Summing the P, I and D term after sign_extending
assign PID_term = P_term_SE + I_term_SE + D_term_SE;

//////////////////////////////////////////////////////////////////////////////
// Zero Extending Frwrd //////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
assign frwrd_ZE = {1'b0, frwrd};

//////////////////////////////////////////////////////////////////////////////
// Computing lft_spd and rght_spd ////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

// Intermediate value of lft_spd and rght_spd
// Calculating the leeft and right spd
assign lft_spd_i = frwrd_ZE + PID_term_FF[13:3];
assign rght_spd_i = frwrd_ZE - PID_term_FF[13:3];

// Updating the left and right spd only if the bot is moving
assign lft_spd_US = moving ? lft_spd_i : 11'h000;
assign rght_spd_US = moving ? rght_spd_i : 11'h000;

// Checking for overflow and saturating
assign lft_spd = (~PID_term_FF[13] & lft_spd_US[10]) ? 11'h3FF : lft_spd_US;
assign rght_spd = (PID_term_FF[13] & rght_spd_US[10]) ? 11'h3FF : rght_spd_US;

endmodule
