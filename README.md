# Knights-Follower-Robot
This project involves designing, simulating and synthesizing modules for a Knights follower robot using SystemVerilog. The robot navigates the chessboard, covering each square exactly once, with the implementation of a backtracking algorithm.


# Chessboard Navigation: 
  Utilizes a backtracking algorithm to ensure the robot covers each square of the chessboard precisely once.

# User Input Handling:
  Developed a UART transceiver and wrapper to capture user inputs via a Bluetooth module.

# Gyroscope Data Handling: 
  Implemented an SPI master controller to configure, read, and write data from the gyroscope.

# Precision Movement Control: 
  Created a PID controller using fixed-point arithmetic to correct movement errors. This is achieved by fusing data from a MEMS gyroscope and IR sensor.



# Synthesis
   Also synthesized the design to ensure timing closure and performed post-synthesis verification to ensure full funcitonality.
