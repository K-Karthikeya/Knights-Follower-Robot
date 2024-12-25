`timescale 1ns/1ps
module KnightsTour_tb();

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

    // Resetting the circuit
    @(negedge clk) RST_n = 1'b0;
    #43 RST_n = 1'b1; // Modelling an async reset

    initialize(); // Calibrating the Robot
    ChkResp(8'hA5);

    // SendCmd(16'h6022);
    // repeat(80000000) @(posedge clk);

    SendCmd(16'h4001);
    ChkResp(8'hA5);

    SendCmd(16'h43F1);
    ChkResp(8'hA5);

    SendCmd(16'h47F1);
    ChkResp(8'hA5);

    SendCmd(16'h4BF1);
    ChkResp(8'hA5);

    $stop;
  end
  
  always
    #5 clk = ~clk;

  /////////////////////////////////////////////////////////////////////////////////////////////
  // TASKS ////////////////////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////////////////////

  // Initialize the Robot /////////////////////////////////////////////////////////////////////
  task initialize();
    // Calibrating the circuit
    @(negedge clk);
    cmd = 16'h2000;
    send_cmd = 1'b1;
    @(negedge clk) send_cmd = 1'b0;
    wait(cmd_sent);
  endtask

  task ChkResp(input [7:0] resp_val);
    // Waiting for Response Ready on RemoteComm for 1000000 clk cycles
      fork
          begin
              wait(resp_rdy);
              if(resp == resp_val) $display("Success");
              else $display("Failed");
          end

          begin : wait_resp_rdy
              repeat(80000000) @(posedge clk);
              $display("ERR: Timeout waiting for Response on RemoteComm!!");
              $stop;
          end
      join_any
      disable fork;
  endtask

  task SendCmd(input [15:0] cmd_val);
    @(negedge clk);
    cmd = cmd_val;
    send_cmd = 1'b1;
    @(negedge clk) send_cmd = 1'b0;
    wait(cmd_sent);
  endtask
  
endmodule


