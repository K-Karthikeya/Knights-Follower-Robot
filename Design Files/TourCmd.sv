module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
			   clr_cmd_rdy,send_resp,resp);

  input clk,rst_n;			// 50MHz clock and asynch active low reset
  input start_tour;			// comes from TourLogic
  input [7:0] move;			// from tourlogic, 1 hot encoding, tells dirxn knight needs to move
  output reg [4:0] mv_indx;	// "address" to access next move
  input [15:0] cmd_UART;	// cmd from UART_wrapper
  input cmd_rdy_UART;		// cmd_rdy from UART_wrapper
  output logic [15:0] cmd;		// multiplexed cmd to cmd_proc
  output cmd_rdy;			// cmd_rdy signal to cmd_proc
  input clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
  input send_resp;			// lets us know cmd_proc is done with command
  output logic [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)

	//cmd signals from tour_cmd module to cmd_proc module
	logic [15:0] y_cmd, x_cmd, cmd_TOUR;
	
	//movement directions commands
	localparam	NORTH = 8'h00,
				EAST  = 8'hBF,
				SOUTH = 8'h7F,
				WEST  = 8'h3F;
	
	localparam last_move_indx = 5'h17;	//Decimal -> 23

	//One hot encoded movement command from TourLogic
	typedef enum logic [7:0] {	N2E1 = 8'b0000_0001,
								N2W1 = 8'b0000_0010,
								W2N1 = 8'b0000_0100,
								W2S1 = 8'b0000_1000,
								S2W1 = 8'b0001_0000,
								S2E1 = 8'b0010_0000,
								E2S1 = 8'b0100_0000,
								E2N1 = 8'b1000_0000 } encoded_move_t;
	encoded_move_t encoded_move;
	
	assign encoded_move = encoded_move_t'(move);
	localparam	MOVE 	 = 4'b0100,	//Opcode to move knight 
				MOVE_FAN = 4'b0101; //Opcode to move knight with fan fare
				
	//opcode for number of squares to move
	localparam	two_sqr = 4'b0010, 
				one_sqr = 4'b0001; 
				
	//Defining internal signals
	logic 	usurp, cmd_rdy_TOUR,
			move_y_or_x,		// move y(Vertical) =>0 and move x(Horizontal) => 1
			inc_mv, clr_mv_indx;
	
	//Generating the move index counter
	always_ff @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			mv_indx = 5'b0;
		else if (clr_mv_indx)
			mv_indx = 5'b0;
		else if (inc_mv)
			mv_indx = mv_indx + 1'b1;
	end
	
	//Generating the resp to UART logic
	
	always_comb begin : resp_gen
		if(~usurp) 
			resp = 8'hA5;
		else begin
			if(mv_indx == last_move_indx)
				resp = 8'hA5;
			else
				resp = 8'h5A;
		end
	end
	
	
	//Generating the Y axis and X axis command as per the move recieved from tourlogic
	always_comb begin
		case(encoded_move)
			N2W1 : begin
				y_cmd = {MOVE	  , NORTH , two_sqr};	
				x_cmd = {MOVE_FAN , WEST  , one_sqr};
			end
			
			N2E1 : begin
				y_cmd = {MOVE	  , NORTH , two_sqr};
				x_cmd = {MOVE_FAN , EAST  , one_sqr};
			end
			
			W2N1 : begin
				y_cmd = {MOVE	  , NORTH , one_sqr};
				x_cmd = {MOVE_FAN , WEST  , two_sqr};
			end
			
			W2S1 : begin
				y_cmd = {MOVE	  , SOUTH , one_sqr};
				x_cmd = {MOVE_FAN , WEST  , two_sqr};
			end
			
			S2W1 : begin
				y_cmd = {MOVE	  , SOUTH , two_sqr};
				x_cmd = {MOVE_FAN , WEST  , one_sqr};
			end
			
			S2E1 : begin
				y_cmd = {MOVE	  , SOUTH , two_sqr};
				x_cmd = {MOVE_FAN , EAST  , one_sqr};
			end
			
			E2S1 : begin
				y_cmd = {MOVE	  , SOUTH , one_sqr};
				x_cmd = {MOVE_FAN , EAST  , two_sqr};
			end
			
			E2N1 : begin
				y_cmd = {MOVE	  , NORTH , one_sqr};
				x_cmd = {MOVE_FAN , EAST  , two_sqr};
			end

			default : begin
				y_cmd = 16'h0000;
				x_cmd = 16'h0000;
			end
		endcase
	end 

	//Select between the generated vertical or horizontal move 
	assign cmd_TOUR = move_y_or_x ? x_cmd : y_cmd;
	//If usurp is high send out tour commands
	assign cmd = usurp ? cmd_TOUR : cmd_UART;
	//If usurp is high cmd_rdy is set by TourCmd
	assign cmd_rdy = usurp ? cmd_rdy_TOUR : cmd_rdy_UART;
	
	//Defining States
	typedef enum logic [2:0] {IDLE, Y_MOVE, Y_HOLD, X_MOVE, X_HOLD} t_state;
	t_state state, nxt_state;
	
	//State register
	always_ff @ (posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	
	//Next state and output logic
	always_comb begin
		//Defaulting outputs
		nxt_state = state;
		usurp = 1'b0;
		clr_mv_indx = 1'b0;
		inc_mv = 1'b0;
		cmd_rdy_TOUR = 1'b0;
		move_y_or_x = 1'b0;
		
		case(state)
			///DEFAULT CASE => IDLE///
			default: begin
				if (start_tour) begin	//start_tour observed, start moving in Y axis
					usurp = 1'b1;
					nxt_state = Y_MOVE;
					clr_mv_indx = 1'b1;
				end
			end
			
			Y_MOVE : begin		//Generate the Y axis command
				usurp = 1'b1;
				cmd_rdy_TOUR = 1'b1;
				if(clr_cmd_rdy) begin
					nxt_state = Y_HOLD;
				end
			end
			
			Y_HOLD : begin		//Hold the Y axis command until movement is done
				usurp = 1'b1;
				if(send_resp) begin
					nxt_state = X_MOVE;
					move_y_or_x = 1'b1;
				end
			end
			
			X_MOVE : begin		//Generate the X axis command
				usurp = 1'b1;
				move_y_or_x = 1'b1;
				cmd_rdy_TOUR = 1'b1;
				if(clr_cmd_rdy) begin
					nxt_state = X_HOLD;
				end
			end
			
			X_HOLD : begin		//Hold the X axis command when movement is done
				usurp = 1'b1;
				move_y_or_x = 1'b1;
				if(send_resp & (mv_indx == last_move_indx)) //If that was the last move
					nxt_state = IDLE;							//go back to IDLE
				else if(send_resp & (mv_indx < last_move_indx)) begin
					inc_mv = 1'b1;							//Else, move again from Y_axis
					nxt_state = Y_MOVE;
				end
			end
		endcase
	end
endmodule