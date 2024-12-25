// Importing all the tasks as a package.
import KnightsTour_Pkg::*;

module KnightsTour_tb_v6();

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
  
    // Setting the Clock
    clk = 1'b0;
    cmd = '0;

    // Resetting the circuit
    @(negedge clk) RST_n = 1'b0;
    #43 @(negedge clk) RST_n = 1'b1; // Modelling an async reset

    // Calibrating the bot and checking if it is cal_done is asserted
    initialize(.clk(clk), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .NEMO_setup(iPHYS.iNEMO.NEMO_setup), .PWM(iDUT.lftPWM1)); // Calibrating the Robot
    check_calibration(.clk(clk), .cal_done(iDUT.iNEMO.cal_done));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading),
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h2000));
    $display("\n");
	
    // Moving NORTH by 1 block and checking the response of the bot    
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h4001));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading),
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h4001));
    $display("\n");
    
    // Moving EAST by 1 block and checking the response of the bot
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h4BF1));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading), 
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h4BF1));
    $display("\n");
    
    // Moving SOUTH by 1 block and checking the response of the bot
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h47F1));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading), 
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h47F1));
    $display("\n");

    // Moving WEST by 1 block and checking the response of the bot          
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h43F1));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading), 
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h43F1));
    $display("\n");
    
    // Starting TourLogic and checking all the moves
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h6022));
    TourLogicResp(.clk(clk), .resp(resp), .resp_rdy(resp_rdy), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .cmd_val(iDUT.iTC.cmd)); 
    $display("\n");

    // Moving SOUTH by 1 block and checking the response of the bot  
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h47F1));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading), 
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h47F1));
    $display("\n");
    
    // Moving SOUTH by 1 block again and checking the response of the bot
    SendCmd(.clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent), .cmd(cmd), .cmd_val(16'h47F1));
    ChkResp(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .curr_xx(iPHYS.xx), .curr_yy(iPHYS.yy), .error(iDUT.iCMD.error), .heading(iDUT.iNEMO.heading), 
            .desired_heading(iDUT.iCMD.desired_heading), .lftPWM(iDUT.lftPWM1), .rghtPWM(iDUT.rghtPWM1), .frwrd(iDUT.iCMD.frwrd), .omega_sum(iPHYS.omega_sum), .resp_val(8'hA5), .cmd_val(16'h47F1));
    
	
    

    $stop;
  end
  
  // Generating a clock
  always
    #5 clk = ~clk;
  
  
endmodule
