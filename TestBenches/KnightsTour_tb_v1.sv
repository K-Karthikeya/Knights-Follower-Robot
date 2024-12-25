////////////////////////////////////////////////////////////////////////////////////
// TestBench_v1: Checking if NEMO_setup is being asserted 
// and if the bot is successully calibrating 
////////////////////////////////////////////////////////////////////////////////////

module KnightsTour_tb_v1();

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

    // Wait for NEMO_setup
    fork
      begin
        wait(iPHYS.iNEMO.NEMO_setup);
        $display("Success:: NEMO_setup asserted!!");
        disable wait_NEMO_setup;
      end

      begin : wait_NEMO_setup
        repeat(800000) @(posedge clk);
        $display("ERR:: Time-out waiting for NEMO_setup");
        $stop;
      end
    join

    // Pass calibration command
    @(negedge clk);
    cmd = 16'h2000;
    send_cmd = 1'b1;
    @(negedge clk);
    cmd = 1'b0;

    // Wait for a response for Calibration
    fork
      begin
        wait(iDUT.cal_done);
        $display("Success:: calibration success....");
        disable wait_cal_done;
      end

      begin : wait_cal_done
        repeat(8000000) @(posedge clk);
        $display("ERR:: Calibration Failed..... Never received CAL_DONE signal.");
        $stop;
      end
    join

    $stop;

  end

  always #5 clk = ~clk;


endmodule
  
   