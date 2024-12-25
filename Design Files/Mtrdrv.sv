module MtrDrv(
	input clk,	
	input rst_n,
	input signed [10:0] lft_spd,      //left speed of  motor
	input signed [10:0] rght_spd,		//right speed of  motor
	output lftPWM1, lftPWM2,		//left PWM signals
	output rghtPWM1, rghtPWM2    //right PWM signals
);

wire signed [10:0] lft_PWM_input;       //input to left PWM
wire signed [10:0] rght_PWM_input;		//input to right PWM

// Based on the input speed, PWM signals of that specific duty cycles are generated
PWM11 ilft_PWM(.clk(clk), .rst_n(rst_n), .duty(lft_PWM_input), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));
PWM11 irght_PWM(.clk(clk), .rst_n(rst_n), .duty(rght_PWM_input), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));

// Adding a midrail value of 50% duty cycle to both lft_spd and rght_spd
assign lft_PWM_input = lft_spd + 11'h400;		
assign rght_PWM_input = rght_spd + 11'h400;

endmodule