`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/26 20:42:32
// Design Name: 
// Module Name: warp_scheduler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module warp_scheduler#(
parameter int NumWarp = 8,
parameter int NumComputeCore = 4,
parameter int NumTensorCore = 2
)
(
input reg[NumComputeCore-1:0] ComputeCoreState,
input reg[NumTensorCore-1:0] TensorCoreState,
input reg[NumWarp-1:0][1:0] WarpState
// WarpState
// 1 - Active 00
// 2 - InActive 01
// 3 - IDLE 10
// 4 - Stalled 11
);

endmodule
