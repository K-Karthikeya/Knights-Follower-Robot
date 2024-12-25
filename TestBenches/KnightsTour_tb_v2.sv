////////////////////////////////////////////////////////////////////////////////////
// TestBench_v2:
// With v1 it is established that calibration is working. Now,
// Passing 1 random move and observing error value.
////////////////////////////////////////////////////////////////////////////////////

module KnightsTour_tb_v2();

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
    cmd = 16'h43F2;
    send_cmd = 1'b1;
    @(negedge clk);
    send_cmd = 1'b0;

    fork
      begin
        wait(iDUT.cmd_rdy); // Waiting for the command to be transmitted to the command processor
        disable wait_cmd_rdy;
      end

      begin : wait_cmd_rdy
        repeat(8000000) @(posedge clk);
        $display("ERR:: Command not transmitted to Command Processor......");
        $stop;
      end
    join 

    repeat(50) @(posedge clk); // Waiting for a few clock cycles before monitoring error signal

    if(iDUT.error < $signed(-12'd1000)) $display("Error Value is large as expected: %d", iDUT.error);
    else $display("Error value not as expected: %d", iDUT.error);

    // Waiting for the cmd_proc to send a valid response
    fork
      begin
        wait(resp_rdy); 
        if(resp == 8'hA5)
          if(iPHYS.xx[14:12] == 3'h0 && iPHYS.yy[14:12] == 3'h2) $display("Success:: Response Received: %h. Moved to expected block X: %h, Y: %h", resp, iPHYS.xx[14:12], iPHYS.yy[14:12]);
          else $display("ERR:: Response received: %h, but moved to unexpected block X: %h, Y: %h", resp, iPHYS.xx[14:12], iPHYS.yy[14:12]);
        else
          $display("ERR:: Received wrong response: %h", resp);
        disable wait_resp_rdy;
      end

      begin : wait_resp_rdy
        repeat(8000000) @(posedge clk);
        $display("ERR:: Did not receive a response from KnightsTour......");
        $stop;
      end      
    join
  $stop;

  end

  always #5 clk = ~clk;

endmodule
  
   