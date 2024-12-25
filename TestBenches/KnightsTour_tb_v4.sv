////////////////////////////////////////////////////////////////////////////////////
// TestBench_v4:
// With v3 we checked if the heading and desired heading converge at the end of the move
// Now,
// CChecking the working of tourLogic
////////////////////////////////////////////////////////////////////////////////////

module KnightsTour_tb_v4();

  localparam FAST_SIM = 1;
  
  
  /////////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, RST_n;
  reg [15:0] cmd;
  reg send_cmd;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire SS_n,SCLK,MOSI,MISO,INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire TX_RX, RX_TX;
  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  wire IR_en;
  wire lftIR_n,rghtIR_n,cntrIR_n;

  ///////////////////////////////////////////
  // Variables for calculating duty cycle  //
  ///////////////////////////////////////////

  real time1 = 0;
  real time2 = 0;
  real time3 = 0;
  real duty_cycle;  

  // Variable to store the difference between heading and desired heading
  logic signed [11:0] diff_heading;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));
				  
  /////////////////////////////////////////////////////
  // Instantiate RemoteComm to send commands to DUT //
  ///////////////////////////////////////////////////
  remoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
				   
  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 


  // Defaulting all signals to 0
	initial begin
    clk = 1'b0;
    cmd = '0;
    send_cmd = 1'b0;

    // Modelling physical button type RST_n
    RST_n = 1'b0;
    #57 RST_n = 1'b1;
  end   

  initial begin

    // Wait for sync rst to be deasserted
    wait(iDUT.rst_n);

    // Pass calibration command
    @(negedge clk);
    cmd = 16'h2000;
    send_cmd = 1'b1;
    @(negedge clk);
    send_cmd = 1'b0;

    // Wait for calibration to complete
    fork
      begin
        wait(resp_rdy);
        if(resp == 8'hA5) $display("Success:: Calibration Complete. Response received: %h", resp);
        else $display("ERR:: Calibration complete but response received: %h", resp);
        disable wait_cal_done;
      end

      begin : wait_cal_done
        repeat(800000) @(posedge clk);
        $display("ERR:: Time-out waiting for NEMO_setup");
        $stop;
      end
    join

    // Moving the bot WEST by 2 blocks
    @(negedge clk);
    cmd = 16'h6022;
    send_cmd = 1'b1;
    @(negedge clk);
    send_cmd = 1'b0;
    wait(iDUT.cmd_rdy); // Waiting for the command to be transmitted to the command processor
    // Not verifying cmd_rdy because with v2 we are sure that command is being transmitted to cmd_proc
    
    // Waiting for the cmd_proc to send a valid responses for all 48 moves (Each move is decoded into 2 further moves)

    for(int i = 0; i < 48; i++) begin :for_loop
  	 
  	 	repeat(5) @(posedge clk);
  	 	
  	 	// Checking for fanfare being played
  	 	if(i%2) begin
	  	 	fork
	  	 		begin
	  	 			wait(iDUT.fanfare_go);
	  	 			$display("Fanfare being played.....");
	  	 			disable wait_fanfare_go;
	  	 		end
	  	 		
	  	 		begin : wait_fanfare_go
	  	 			repeat(8000000) @(posedge clk);
	  	 			$display("Fanfare should have been played by now");
	  	 			$stop;
	  	 		end
	  	 	join
	  	 end
  	 	
  	 	
  	 	// Waiting for 8000000 cycles to recieve resp_rdy before timing out
	    fork
	    	begin
	    	@(posedge resp_rdy);
		    	if(i == 46 || i == 47) begin
		    		if(resp == 8'hA5) $display("%d move success in TourLogic\n", i+1);
		    		else   $display("%d move failed in TourLogic\n", i+1);
		    	end
		    	else begin
		    		if(resp == 8'h5A) $display("%d move success in TourLogic\n", i+1);
		    		else   $display("%d move failed in TourLogic\n", i+1);
		    	end
		    	disable wait_resp;
	    	end
	    	
	    	begin : wait_resp
	    		repeat(8000000) @(posedge clk);
	    		$display("ERR: Did not receive a response for TourLogic\n");
	    		$stop;
	    	end : wait_resp
	    join
    end

    $stop;
  end
  

  always #5 clk = ~clk;

endmodule
  
   
