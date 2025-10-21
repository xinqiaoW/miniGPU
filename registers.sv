`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/17 19:05:57
// Design Name: 
// Module Name: registers
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

`default_nettype none
`timescale 1ns/1ns

// REGISTER FILE
// > Each thread within each core has it's own register file with 13 free registers and 3 read-only registers
// > Read-only registers hold the familiar %blockIdx, %blockDim, and %threadIdx values critical to SIMD
module registers #(
    parameter THREADS_PER_WARP = 4,
    parameter WARP_NUM = 8,
    parameter WARP_ID = 0,
    parameter THREAD_ID = 0,
    parameter DATA_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire enable, // If current block has less threads then block size, some registers will be inactive

    input wire [$clog2(WARP_NUM)- 1:0] warp_id,
    // State
    input reg [2:0] group_state,

    // Instruction Signals
    input reg [3:0] decoded_rd_address,
    input reg [3:0] decoded_rs_address,
    input reg [3:0] decoded_rt_address,

    // Control Signals
    input reg decoded_reg_write_enable,
    input reg [1:0] decoded_reg_input_mux,
    input reg [DATA_BITS-1:0] decoded_immediate,

    // Thread Unit Outputs
    input reg [DATA_BITS-1:0] alu_out,
    input reg [DATA_BITS-1:0] lsu_out,

    // Registers
    output reg [7:0] rs,
    output reg [7:0] rt
);
    localparam ARITHMETIC = 2'b00,
        MEMORY = 2'b01,
        CONSTANT = 2'b10;

    // 16 registers per thread (13 free registers and 3 read-only registers)
    reg [7:0] registers[15:0];

    always @(posedge clk) begin
        if (reset) begin
            // Empty rs, rt
            rs <= 0;
            rt <= 0;
            // Initialize all free registers
            for(integer i = 0 ; i < WARP_NUM; i = i + 1)begin
                registers[0] <= 8'b0;
                registers[1] <= 8'b0;
                registers[2] <= 8'b0;
                registers[3] <= 8'b0;
                registers[4] <= 8'b0;
                registers[5] <= 8'b0;
                registers[6] <= 8'b0;
                registers[7] <= 8'b0;
                registers[8] <= 8'b0;
                registers[9] <= 8'b0;
                registers[10] <= 8'b0;
                registers[11] <= 8'b0;
                registers[12] <= 8'b0;
                // Initialize read-only registers
                registers[13] <= 8'b0;              // %WarpID
                registers[14] <= THREADS_PER_WARP; // %blockDim
                registers[15] <= THREAD_ID;         // %threadIdx
            end
        end else if (enable & (warp_id === WARP_ID)) begin 
            
            // Fill rs/rt when group_state = LOAD
            if (group_state == 2'b01) begin 
                rs <= registers[decoded_rs_address];
                rt <= registers[decoded_rt_address];
            end

            // Store rd when group_state = DONE
            if (group_state == 2'b11) begin 
                // Only allow writing to R0 - R12
                if (decoded_reg_write_enable && decoded_rd_address < 13) begin
                    case (decoded_reg_input_mux)
                        ARITHMETIC: begin 
                            // ADD, SUB, MUL, DIV
                            registers[decoded_rd_address] <= alu_out;
                        end
                        MEMORY: begin 
                            // LDR
                            registers[decoded_rd_address] <= lsu_out;
                        end
                        CONSTANT: begin 
                            // CONST
                            registers[decoded_rd_address] <= decoded_immediate;
                        end
                        default: begin
                            // default
                            // do nothing
                        end
                    endcase
                end
            end
        end
    end
endmodule
