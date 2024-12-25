//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// initiate claibration of yaw readings
  input moving;					// Only integrate yaw when going
  input lftIR,rghtIR;			// gaurdrail sensors
  
  output logic cal_done;				// pulses high for 1 clock when calibration done
  output logic signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs

	//////////////////////////////////////////////////////////
	// Registers to hold the YAW data ////////////////////////
	//////////////////////////////////////////////////////////
	reg [7:0] yaw_low; // Register that holds lower byte of YAW
	reg [7:0] yaw_high; // Register that holds upper byte of YAW

	logic C_Y_L; // Control signal to hold YAW low
	logic C_Y_H; // Control signal to hold YAW high

	logic [15:0] yaw_rt;

  	//////////////////////////////////
  	// Declare any internal signal //
 	////////////////////////////////
  	logic vld;		// vld yaw_rt provided to inertial_integrator
	logic [15:0] cmd; // Command to be sent to the monarch module
	logic done;	// Asserted by monarch when 1 SPI transmission is complete
	logic snd; // Control signal to indicate SPI monarch to start transmission
	logic [7:0] resp; // Data read by SPI monarch from MEMs gyro

	// Registers to double flop asychronous 
	reg INT_FF1, INT_FF2;

	// // Timer to wait for the internal setup of MEMs gyro
	logic [15:0] timer;
	logic timer_done;

	// STATES for FSM	
	typedef enum logic [2:0] { INT_ENABLE, GYRO_CONFIG, GYRO_ROUNDING_SETUP, READ_DATA_LOW, READ_DATA_HIGH, WAIT, ASSERT_VLD } STATES;
	STATES crt_state, nxt_state;

	// STATE Transition logic
	always_ff@(posedge clk, negedge rst_n) 
		if(!rst_n) crt_state <= INT_ENABLE;
		else crt_state <= nxt_state;
	
	// Timer for INT_ENABLE
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n) timer <= 16'h0000;
		else timer <= timer + 1'b1;

	// Double flop logic for INT
	always_ff@(posedge clk, negedge rst_n) 
		if(!rst_n) begin
			INT_FF1 <= 1'b0;
			INT_FF2 <= 1'b0;
		end
		else begin
			INT_FF1 <= INT;
			INT_FF2 <= INT_FF1;
		end

	// Loading the value of resp into YAW_LOW reg when C_Y_L is asserted
	always_ff@(posedge  clk, negedge rst_n) 
		if(!rst_n) yaw_low <= 8'h00;
		else if(C_Y_L) yaw_low <= resp;

	// Loading the value of resp into YAW_HIGH reg when C_Y_H is asserted
	always_ff@(posedge  clk, negedge rst_n) 
		if(!rst_n) yaw_high <= 8'h00;
		else if(C_Y_H) yaw_high <= resp;

	// State machice logic
	always_comb begin
		nxt_state  = crt_state;
		snd = 1'b0;
		C_Y_H = 1'b0;
		C_Y_L = 1'b0;
		vld = 1'b0;
		cmd = 16'hxxxx;
		
		case(crt_state)
			// Command to configure INT pin on the inertial sensor
			INT_ENABLE: begin
				cmd = 16'h0D02;
				if(timer_done) begin
					snd = 1'b1;
					nxt_state = GYRO_CONFIG;
				end
			end
			// Configuring the gyroscope for a specific resolution
			GYRO_CONFIG: begin
				cmd = 16'h1160;
				if(done) begin
					snd = 1'b1;
					nxt_state = GYRO_ROUNDING_SETUP;
				end
			end
			//Configuring the value rounding in gyro scope
			GYRO_ROUNDING_SETUP: begin
				cmd = 16'h1440;
				if(done) begin
					snd = 1'b1;
					nxt_state = READ_DATA_LOW;
				end
			end
			// Reading the lower byte data when the INT pin is high
			READ_DATA_LOW: begin
				if(INT_FF2 == 1'b1) begin
					cmd = 16'hA6xx;
					snd = 1'b1;
					nxt_state = READ_DATA_HIGH;
				end
			end
			// Reading the upper byte once lower byte is read
			READ_DATA_HIGH: begin
				if(done) begin
					C_Y_L = 1'b1;
					cmd = 16'hA7xx;
					snd = 1'b1;
					nxt_state = WAIT;
				end
			end
			// Waiting to finish reading upper byte of data
			WAIT: begin
				if(done) begin
					C_Y_H = 1'b1;
					nxt_state = ASSERT_VLD;
				end
			end
			// Once reading is complete, assert valid signal
			ASSERT_VLD: begin	
				vld = 1'b1;
				nxt_state = READ_DATA_LOW;
			end

			default: nxt_state = INT_ENABLE;
		endcase	
	end

	// Checking when timer is 16'hFFFF. Then changing state from INT_ENABLE to GYRO_CONFIG
	assign timer_done = &timer;

	// Sending the yaw readings to the intertial integrator
	assign yaw_rt = {yaw_high, yaw_low};
	 
	////////////////////////////////////////////////////////////////////
	// Instantiate Angle Engine that takes in angular rate readings  //
	// and acceleration info and produces a heading reading         //
	/////////////////////////////////////////////////////////////////
  	inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading));

	////////////////////////////////////////////////////////////////////
	// Instance of SPI monarch module to read data from the MEMs gyro //
	////////////////////////////////////////////////////////////////////
	SPI_mnrch iMNRCH(.clk(clk), .rst_n(rst_n), .snd(snd), .cmd(cmd), .done(done), .resp(resp), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));

endmodule
	  
