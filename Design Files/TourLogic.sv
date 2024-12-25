module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  input clk,rst_n;				// 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	// starting position on 5x5 board
  input go;						// initiate calculation of solution
  input [4:0] indx;				// used to specify index of move to read out
  output logic done;			// pulses high for 1 clock when solution complete
  output [7:0] move;			// the move addressed by indx (1 of 24 moves)
  
  // STATES of the state machine
  typedef enum logic [2:0] { IDLE, START, POSSIBLE, MAKE_MOVE, BACKUP } STATES;
  STATES cnt_state, nxt_state;

  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  logic zero;
  logic init;
  logic update_position;
  logic update_coords;
  logic backup;
  logic update_poss_moves;
  logic set_move_try;
  logic save_last_move;
  logic inc_move_num;
  logic dec_move_num;
  logic update_move_try;
  logic [2:0] nxt_xx;
  logic [2:0] nxt_yy;
  logic retrieve_last_move_try;

  // << some internal registers to consider: >>
  // << These match the variables used in knightsTourSM.pl >>
  reg board[0:4][0:4];				// keeps track if position visited
  reg [7:0] last_move[0:23];		// last move tried from this spot
  reg [7:0] poss_moves[0:23];		// stores possible moves from this position as 8-bit one hot
  reg [7:0] move_try;				// one hot encoding of move we will try next
  reg [4:0] move_num;				// keeps track of move we are on
  reg [2:0] xx,yy;					// current x & y position  
 
  // << 2-D array of 5-bit vectors that keep track of where on the board the knight
  //    has visited.  Will be reduced to 1-bit boolean after debug phase >>
  // << 1-D array (of size 24) to keep track of last move taken from each move index >>
  // << 1-D array (of size 24) to keep track of possible moves from each move index >>
  // << move_try ... not sure you need this.  I had this to hold move I would try next >>
  // << move number...when you have moved 24 times you are done.  Decrement when backing up >>
  // << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  
  // << below I am giving you an implementation of the one of the register structures you have >>
  // << to infer (board[][]).  You need to implement the rest, and the controlling SM >>
  ///////////////////////////////////////////////////
  // The board memory structure keeps track of where 
  // the knight has already visited.  Initially this 
  // should be a 5x5 array of 5-bit numbers to store
  // the move number (helpful for debug).  Later it 
  // can be reduced to a single bit (visited or not)
  ////////////////////////////////////////////////

  // State Registers
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) cnt_state <= IDLE;
    else cnt_state <= nxt_state;
  end

  // Memory keeping track of all visited blocks
  always_ff @(posedge clk)
    if (zero)
	  board <= '{'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0}};
	else if (init)
	  board[x_start][y_start] <= 1'h1;	// mark starting position
	else if (update_position)
	  board[nxt_xx][nxt_yy] <= 1'b1;	// mark as visited
	else if (backup)
	  board[xx][yy] <= 1'b0;			// mark as unvisited

  // Register to keep track of number of moves
  always_ff@(posedge clk) begin
    if(go) move_num <= 5'h00;
    else if(inc_move_num) move_num <= move_num + 1'b1;
    else if(dec_move_num) move_num <= move_num - 1'b1;
  end

  // Register holds the current X and Y position of the knight
  always_ff@(posedge clk)
    if(init) begin
      xx <= x_start;
      yy <= y_start;
    end
    else if(update_coords) begin
      xx <= nxt_xx;
      yy <= nxt_yy;
    end 

  // Array of registers that holds all possible values at any given move
  always_ff@(posedge clk)
    if(update_poss_moves) poss_moves[move_num] <= calc_poss(xx, yy);

  // Register which holds the current move being tried out
  always_ff@(posedge clk)
    if(set_move_try) move_try <= 8'h01;
    else if(update_move_try) move_try <= move_try << 1'b1;
    else if(retrieve_last_move_try) move_try <= last_move[move_num - 1'b1] << 1'b1;

  // Saving the last made move to back track later
  always_ff@(posedge clk)
    if(save_last_move) last_move[move_num] <= move_try;

  // State Transition logic
  always_comb begin
    // Defaulting all the values
    nxt_state = cnt_state;
    zero = 1'b0;
    init = 1'b0;
    update_poss_moves = 1'b0;
    set_move_try = 1'b0;
    update_position = 1'b0;
    save_last_move = 1'b0;
    inc_move_num = 1'b0;
    dec_move_num = 1'b0;
    update_move_try = 1'b0;
    update_coords = 1'b0;
    nxt_xx = xx;
    nxt_yy = yy;
    backup = 1'b0;
    retrieve_last_move_try = 1'b0;
    done = 1'b0;

    case(cnt_state)
      // Wait for tour_go signal from cmd_proc to start solving the Tour
      IDLE: begin
        if(go) begin
          zero = 1'b1;
          nxt_state = START;
        end          
      end
      // Load the initial xx and yy positions into the registers
      START: begin
        init = 1'b1;
        nxt_state = POSSIBLE;
      end
      // Calculate all possible moves from the given square
      POSSIBLE: begin
        update_poss_moves = 1'b1;
        set_move_try = 1'b1;
        nxt_state = MAKE_MOVE;
      end
      // From all possible move, select one  move and proceed. If at some point
      // a move fails, backtrack and try with a different move again
      MAKE_MOVE: begin
        // Checking whether the next block was visited before, if not proceed to move to that block
        if((poss_moves[move_num] & move_try) &&
           (board[xx + off_x(move_try)][yy + off_y(move_try)] == 1'b0)) begin
            nxt_xx = xx + off_x(move_try);
            nxt_yy = yy + off_y(move_try);
            update_coords = 1'b1;;
            update_position = 1'b1;
            save_last_move = 1'b1;
            // If current move is the last move, go back to IDLE state and assert DONE signal
            if(move_num == 5'h17) begin
              done = 1'b1;
              nxt_state = IDLE;
            end
            // Else compute the possible moves for the next sqaure and repeat.
            else
              nxt_state = POSSIBLE;
            inc_move_num = 1'b1;
        end
        else if(move_try != 8'h80)
          update_move_try = 1'b1;
        else
          nxt_state = BACKUP;
      end

      // When a particular move completely fails, we move back 1 step in time and try with an alternate 
      // possible move.
      BACKUP: begin
        backup = 1'b1;
        nxt_xx = xx - off_x(last_move[move_num - 1'b1]);
        nxt_yy = yy - off_y(last_move[move_num - 1'b1]);
        update_coords = 1'b1;
        retrieve_last_move_try = 1'b1;
        if(last_move[move_num - 1'b1] != 8'h80)
          nxt_state = MAKE_MOVE;
        // set_move_try = 1'b1;
        dec_move_num = 1'b1;
      end
    endcase
    
  end

  assign move = last_move[indx]; // When TourCmd is trying to read the moves
  
  function automatic [7:0] calc_poss(input [2:0] xpos,ypos);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a packed byte of
	// all the possible moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
    automatic logic [7:0] poss = 8'h00;
    automatic logic [7:0] try = 8'h01;
    automatic logic [3:0] itr;
    automatic logic signed [2:0] xpos_i;
    automatic logic signed [2:0] ypos_i;

    // $display("Before loop, poss: %h; try = %h", poss, try);
    // Iterating over all 8 possible moves from the current location 
    // and checking if these boxes are within the boundary. If yes, 
    // we update the try register.

    for(itr = 0; itr < 8; itr++) begin
      xpos_i = (xpos + off_x(try));
      ypos_i = (ypos + off_y(try));
      if( (xpos_i >= 4'd0) && (xpos_i < 4'd5) && 
          (ypos_i >= 4'd0) && (ypos_i < 4'd5) ) begin
        poss |= try;
      end
      try = try << 1'b1;
    end
    // Assigning the final output to calc_poss
    calc_poss = poss;
  endfunction
  
  function signed [2:0] off_x(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the x-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from xx
	/////////////////////////////////////////////////////
    case(try)
      8'h01: off_x = 1;
      8'h02: off_x = -1;
      8'h04: off_x = -2;
      8'h08: off_x = -2;
      8'h10: off_x = -1;
      8'h20: off_x = 1;
      8'h40: off_x = 2;
      8'h80: off_x = 2;
    endcase

  endfunction
  
  function signed [2:0] off_y(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the y-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from yy
	/////////////////////////////////////////////////////
    case(try)
      8'h01: off_y = 2;
      8'h02: off_y = 2;
      8'h04: off_y = 1;
      8'h08: off_y = -1;
      8'h10: off_y = -2;
      8'h20: off_y = -2;
      8'h40: off_y = -1;
      8'h80: off_y = 1;
    endcase

  endfunction
  
endmodule
	  
      
  