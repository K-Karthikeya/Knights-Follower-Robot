package KnightsTour_Pkg;

localparam O_CALIBRATE = 4'b0010; // Opcode to calibrate
localparam O_MOVE = 4'b0100; // Opcode to Move
localparam O_MOVE_F = 4'b0101; // Opcode to Move with fanfare
localparam O_TOUR_GO = 4'b0110; // Opcode for Tour Logic

localparam NOMOVE_ERR_OFFSET = 16'h0100;
localparam MOVE_ERR_OFFSET = 16'h0200;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Task to calibrate the bot. Checking if NEMO_setup is going high and 
// if PWM is of 50% duty cycle initially
  task automatic initialize(
    ref logic clk,
    ref logic [15:0] cmd,
    ref logic send_cmd,
    ref logic cmd_sent,
    ref logic NEMO_setup,
    ref logic PWM
  );
  	
  	real duty;
  	
	@(posedge NEMO_setup);
  	$display("SUCCESS:: NEMO_SETUP enabled....");
  	
    // Task to calculate duty cycle
  	Calc_DUTY(PWM, duty);
  	
  	$display("Duty Cycle of PWM at the start = %f", duty);
  	
    // Calibrating the circuit
    @(negedge clk);
    cmd = 16'h2000;
    send_cmd = 1'b1;
    @(negedge clk) send_cmd = 1'b0;
    // Waiting for command to be transmitted to the bot
    wait(cmd_sent);
  endtask
  
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Task t check if calibration is complete    
  task automatic check_calibration(
  	ref logic cal_done,
  	ref logic clk
	);

    // Waiting for 8000000 to receive cal_done signal before timing out 
 	fork
 		begin: timeout
 			repeat (80000000) @ (posedge clk);
 			$display ("ERR:: Calibration Failed!!");
 			$stop();
 		end
 		
 		begin
 			@(posedge cal_done);
 			$display("SUCCESS:: Calibration Success!!");
 			disable timeout;
 		end
 	join
  endtask
 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Task to pass various commands to the bot and check if the command is successfully being transmitted to the bot    
  task automatic SendCmd(
    ref logic clk,
    ref logic send_cmd,
    ref logic cmd_sent,
    ref logic [15:0] cmd,
    input [15:0] cmd_val);

    @(negedge clk);
    cmd = cmd_val;
    send_cmd = 1'b1;
    @(negedge clk) send_cmd = 1'b0;

    // Once command is set, waiting for 8000000 cycles for the command to be transmitted before timing out
    fork
        begin
            wait(cmd_sent);
            disable wait_cmd_sent;
        end

        begin : wait_cmd_sent
            repeat(8000000) @(posedge clk);
            $display("ERR: Command %h could not be sent!! Check RemoteComm...", cmd_val);
            $stop;
        end
    join
  endtask
  
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Task to check the various responses of the bot for the command passed. This includes checking for the difference
// in left and right PWM, if we are receiving a resp_rdy, if omega_sum is ramping up after bot reaches max speed.  
  task automatic ChkResp(
    ref logic clk,
    ref logic resp_rdy,
    ref logic [7:0] resp,
    ref reg [14:0] curr_xx,
    ref reg [14:0] curr_yy,
    ref logic signed [11:0] error,
    ref logic signed [11:0] heading,
    ref logic [11:0] desired_heading,
    ref logic lftPWM,
    ref logic rghtPWM,
    ref reg signed [16:0] omega_sum,
    ref logic [9:0] frwrd,
    input [7:0] resp_val, [15:0] cmd_val
    );

	real lftPWM_duty; // variable to store the duty cycle of left PWM
	real rghtPWM_duty; // variable to store the duty cycle of right PWM

    // Signals to decode and self check the movement based on the incoming command
    logic [3:0] opcode = cmd_val[15:12]; // Opcode field
    logic [7:0] direction = cmd_val[11:4]; // Direction the bot is supposed to move
    logic [3:0] moves = cmd_val[3:0]; // Number of squares we are supposed to move

    logic signed [11:0] diff_heading; 

    // last_xx and last_yy hold the position of the bot at the start of its movement
    logic [14:0] last_xx = curr_xx;
    logic [14:0] last_yy = curr_yy;

    // Variables to check if omega_sum is ramping up
    logic signed [16:0] omega_sum1;
    logic signed [16:0] omega_sum2;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Calculating the left and right duty cycle and checking if based on the error value, if one PWM is driving greater than the other	
	Calc_DUTY(.PWM(lftPWM), .duty(lftPWM_duty));
	Calc_DUTY(.PWM(rghtPWM), .duty(rghtPWM_duty));
    
    if(error > $signed(12'd750)) begin 
    	if(lftPWM_duty > rghtPWM_duty) $display("SUCCESS:: Error is positive. lftPWM_DUTY > rghtPWM_DUTY. Moving Right");
    	else $display("ERR:: Error is positive but lftPWM_DUTY < rghtPWM_DUTY");
    end
    
    else if(error < $signed(-12'd750)) begin
    	if(lftPWM_duty < rghtPWM_duty) $display("SUCCESS:: Error is negative. lftPWM_DUTY < rghtPWM_DUTY. Moving left");
    	else $display("ERR:: Error is negative but lftPWM_DUTY > rghtPWM_DUTY");
    end
    
    else 
    	$display("SUCCESS:: Error is within limited range...... Moving straight");

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Checking if omega_sum is ramping up before and after the speed of bot max out    
    if(opcode != O_CALIBRATE) begin
		omega_sum1 = omega_sum;
		wait(frwrd == 10'h300);
		omega_sum2 = omega_sum;
		
		if(omega_sum2 > omega_sum1) $display("SUCCESS:: Omega_sum ramping up!!");
		else $display("ERR:: Omega_sum is not ramping up!!");
	end
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Waiting for Response Ready on RemoteComm for 8000000 clk cycles
    fork
        begin
            wait(resp_rdy);
            if(resp == resp_val) $display("SUCCESS:: Received %h", resp);
            else $display("ERR:: Received %h", resp);
            disable wait_resp_rdy;
        end

        begin : wait_resp_rdy
            repeat(8000000) @(posedge clk);
            $display("ERR: Timeout waiting for Response on RemoteComm!!");
            $stop;
        end
    join
	
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//Checking if the heading and desired heading converge after the move is complete
	diff_heading = heading - desired_heading;
	if ((diff_heading >= $signed(-12'h050)) && (diff_heading <= $signed(12'h050)))
		$display("SUCCESS:: Heading and desired heading converge!!");
	else $display("ERR:: Heading and Desired Heading do not converge!!");	
	
	
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Self checking if the bot is moving to the desired square based on the command passed
    // Displaying the XX and YY location after the move is complete
    $display("CURR_XX: %h", curr_xx); 
    $display("CURR_YY: %h", curr_yy);

    if(opcode == O_CALIBRATE) ; // No check required for calibrate command


    else if(opcode == O_MOVE || opcode == O_MOVE_F) begin

        // Based on the direction we are moving, only either XX or YY coordinate will change by the number of squared to move
        case(direction)
            8'h00: begin // Moving NORTH. Only YY will increase by the number of squares supposed to move
                if((curr_xx < {last_xx[14:12], 12'h800} + NOMOVE_ERR_OFFSET) && 
                    (curr_xx > {last_xx[14:12], 12'h800} - NOMOVE_ERR_OFFSET) &&
                    (curr_yy < ({last_yy[14:12], 12'h800} + {moves, 12'h000} +  MOVE_ERR_OFFSET)) &&
                    (curr_yy > ({last_yy[14:12], 12'h800} + {moves, 12'h000} -  MOVE_ERR_OFFSET))) 

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800}, {last_yy[14:12], 12'h800} + {moves, 12'h000});
            end

            8'h3F: begin // Moving WEST. Only XX will decrease by the number of squares supposed to move
                if((curr_xx < ({last_xx[14:12], 12'h800} - {moves, 12'h000} + MOVE_ERR_OFFSET)) && 
                    (curr_xx > ({last_xx[14:12], 12'h800} - {moves, 12'h000} - MOVE_ERR_OFFSET)) &&
                    (curr_yy < {last_yy[14:12], 12'h800} + NOMOVE_ERR_OFFSET) &&
                    (curr_yy > {last_yy[14:12], 12'h800} - NOMOVE_ERR_OFFSET)) 

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800} - {moves, 12'h000}, {last_yy[14:12], 12'h800});
            end

            8'h7F: begin // Moving SOUTH. Only YY will decrease by the number of squares supposed to move
                if((curr_xx < {last_xx[14:12], 12'h800} + NOMOVE_ERR_OFFSET) && 
                    (curr_xx > {last_xx[14:12], 12'h800} - NOMOVE_ERR_OFFSET) &&
                    (curr_yy < ({last_yy[14:12], 12'h800} - {moves, 12'h000} +  MOVE_ERR_OFFSET)) &&
                    (curr_yy > ({last_yy[14:12], 12'h800} - {moves, 12'h000} -  MOVE_ERR_OFFSET)))

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800}, {last_yy[14:12], 12'h800} - {moves, 12'h000});
            end

            8'hBF: begin // Moving EAST. Only XX will increase by the number of squares supposed to move
                if((curr_xx < ({last_xx[14:12], 12'h800} + {moves, 12'h000} + MOVE_ERR_OFFSET)) && 
                    (curr_xx > ({last_xx[14:12], 12'h800} + {moves, 12'h000} - MOVE_ERR_OFFSET)) &&
                    (curr_yy < {last_yy[14:12], 12'h800} + NOMOVE_ERR_OFFSET) &&
                    (curr_yy > {last_yy[14:12], 12'h800} - NOMOVE_ERR_OFFSET))

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800} + {moves, 12'h000}, {last_yy[14:12], 12'h800});
            end
        endcase
    end
  endtask
  
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Task to check if the bot is moving to the desired square for every command from TourCmd. This is almost similar 
// to the previous task but instead of manually passing the commands, we intercept the command from TourCmd.    
task automatic TourLogicResp(
					ref logic clk,
					ref logic resp_rdy,
					ref logic [7:0] resp,
					ref reg [14:0] curr_xx,
					ref reg [14:0] curr_yy,
					ref logic [15:0] cmd_val );


    // signals to decode the command				
    logic [3:0] opcode = cmd_val[15:12];
    logic [7:0] direction = cmd_val[11:4];
    logic [3:0] moves = cmd_val[3:0];
    logic [14:0] last_xx = 15'h2800;
    logic [14:0] last_yy = 15'h2800;

    // We have a total of 24 moves from Tourlogic and each move is further decomposed into 2 moves, one along X and one along Y
    // Therefore we are looping over all 48 moves and performing the self check similar to the last task.
    // i.e., based on the command we only either move along X or Y for a particular move
    				
  	for(int i = 0; i < 48; i++) begin :for_loop
  	 
  	 	repeat(5) @(posedge clk);
  	 	
  	 	opcode = cmd_val[15:12];
  	 	direction = cmd_val[11:4];
  	 	moves = cmd_val[3:0];
  	 	
  	 	last_xx = curr_xx;
  	 	last_yy = curr_yy;
  	 	
        // Waiting for 8000000 cycles for resp_rdy for each move before timing out 
	    fork
	    	begin
	    	    @(posedge resp_rdy);
		    	if(i == 46 || i == 47) begin // For mv_indx = 23, i.e. i =46 and 47, we should get a response of 8'hA5
		    		if(resp == 8'hA5) $display("move %d  success in TourLogic", i+1);
		    		else   $display("move %d failed in TourLogic\n", i+1);
		    	end
		    	else begin
		    		if(resp == 8'h5A) $display("move %d success in TourLogic", i+1);
		    		else   $display("move %d failed in TourLogic\n", i+1);
		    	end
		    	disable wait_resp;
	    	end
	    	
	    	begin : wait_resp
	    		repeat(8000000) @(posedge clk);
	    		$display("ERR: Did not receive a response for TourLogic");
	    		$stop;
	    	end : wait_resp
	    join
	    
        // Same logic as the last task
	    $display("CURR_XX: %h LAST_XX: %h", curr_xx, last_xx);
		$display("CURR_YY: %h LAST_YY: %h", curr_yy, last_yy);
		if(opcode == O_CALIBRATE) ;
		else if(opcode == O_MOVE || opcode == O_MOVE_F) begin
		    // Based on the direction we are moving, only either XX or YY coordinate will change by the number of squared to move
        case(direction)
            8'h00: begin // Moving NORTH. Only YY will increase by the number of squares supposed to move
                if((curr_xx < {last_xx[14:12], 12'h800} + NOMOVE_ERR_OFFSET) && 
                    (curr_xx > {last_xx[14:12], 12'h800} - NOMOVE_ERR_OFFSET) &&
                    (curr_yy < ({last_yy[14:12], 12'h800} + {moves, 12'h000} +  MOVE_ERR_OFFSET)) &&
                    (curr_yy > ({last_yy[14:12], 12'h800} + {moves, 12'h000} -  MOVE_ERR_OFFSET))) 

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800}, {last_yy[14:12], 12'h800} + {moves, 12'h000});
            end

            8'h3F: begin // Moving WEST. Only XX will decrease by the number of squares supposed to move
                if((curr_xx < ({last_xx[14:12], 12'h800} - {moves, 12'h000} + MOVE_ERR_OFFSET)) && 
                    (curr_xx > ({last_xx[14:12], 12'h800} - {moves, 12'h000} - MOVE_ERR_OFFSET)) &&
                    (curr_yy < {last_yy[14:12], 12'h800} + NOMOVE_ERR_OFFSET) &&
                    (curr_yy > {last_yy[14:12], 12'h800} - NOMOVE_ERR_OFFSET)) 

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800} - {moves, 12'h000}, {last_yy[14:12], 12'h800});
            end

            8'h7F: begin // Moving SOUTH. Only YY will decrease by the number of squares supposed to move
                if((curr_xx < {last_xx[14:12], 12'h800} + NOMOVE_ERR_OFFSET) && 
                    (curr_xx > {last_xx[14:12], 12'h800} - NOMOVE_ERR_OFFSET) &&
                    (curr_yy < ({last_yy[14:12], 12'h800} - {moves, 12'h000} +  MOVE_ERR_OFFSET)) &&
                    (curr_yy > ({last_yy[14:12], 12'h800} - {moves, 12'h000} -  MOVE_ERR_OFFSET)))

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800}, {last_yy[14:12], 12'h800} - {moves, 12'h000});
            end

            8'hBF: begin // Moving EAST. Only XX will increase by the number of squares supposed to move
                if((curr_xx < ({last_xx[14:12], 12'h800} + {moves, 12'h000} + MOVE_ERR_OFFSET)) && 
                    (curr_xx > ({last_xx[14:12], 12'h800} + {moves, 12'h000} - MOVE_ERR_OFFSET)) &&
                    (curr_yy < {last_yy[14:12], 12'h800} + NOMOVE_ERR_OFFSET) &&
                    (curr_yy > {last_yy[14:12], 12'h800} - NOMOVE_ERR_OFFSET))

                    $display("SUCCESS:: XX and YY within expected range....");
                else $display("ERR:: XX and YY are not within expected range....");
                $display("Expected XX: %h YY: %h", {last_xx[14:12], 12'h800} + {moves, 12'h000}, {last_yy[14:12], 12'h800});
            end
        endcase
		end
        $display("\n");
    end : for_loop
  endtask
  
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Calculating duty cycle
  task automatic Calc_DUTY(ref logic PWM, output real duty);
  	real time1 = 0, time2 = 0, time3 = 0;
  	real on_time;
  	real off_time;
  	// Using $time system variable to keep track of time
  	@(posedge PWM); time1 = $time; // Recording the first posedge
  	@(negedge PWM); time2 = $time; // Recording the corresponding negedge
  	@(posedge PWM); time3 = $time; // Recording the next posedge
  	on_time = time2 - time1; // On time is from posedgeto negedge
  	off_time = time3 - time2; // Off time is from negedge to posedge
  	duty = on_time/(on_time + off_time); // Duty cycle is on_time / on_time + off_time
  
  endtask
  
 
endpackage : KnightsTour_Pkg
