`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/17 18:12:46
// Design Name: 
// Module Name: ComputingPool
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


module ComputingGroup#(
parameter THREADS_PER_WARP = 8,
parameter DATA_BITS = 8,
parameter WARP_NUM=8)(
input wire clk,
input wire reset,
input wire [$clog2(WARP_NUM)-1:0]warp_id,

input reg [THREADS_PER_WARP-1:0] mask,

input reg decoded_mem_read_enable,
input reg decoded_mem_write_enable,//这两个信号是所有lsu公共的

input reg [1:0] decoded_alu_arithmetic_mux,
input reg decoded_alu_output_mux,
input reg [THREADS_PER_WARP-1:0] mem_read_ready,
input reg [THREADS_PER_WARP-1:0][DATA_BITS-1:0] mem_read_data,

output reg [THREADS_PER_WARP-1:0]mem_write_valid,
output reg [THREADS_PER_WARP-1:0][7:0] mem_write_address,
output reg [THREADS_PER_WARP-1:0][7:0] mem_write_data,
input reg mem_write_ready,

output reg [THREADS_PER_WARP-1:0]mem_read_valid,
output reg [THREADS_PER_WARP-1:0][DATA_BITS-1:0] mem_read_address,

input reg [3:0] decoded_rd_address,
input reg [3:0] decoded_rs_address,
input reg [3:0] decoded_rt_address,

input reg decoded_reg_write_enable,
input reg [1:0] decoded_reg_input_mux,
input reg [DATA_BITS-1:0] decoded_immediate,

output reg [THREADS_PER_WARP - 1:0][1:0] lsu_state,
output reg [THREADS_PER_WARP - 1:0][7:0] lsu_out,
output reg [THREADS_PER_WARP - 1:0][DATA_BITS-1:0] alu_out_reg,

output reg idle,
input reg decoded_valid
    );
genvar i;
reg[THREADS_PER_WARP - 1:0][DATA_BITS-1:0] rs; // rs rt 是数据，有时候这个数据是另一个数据的地址
reg[THREADS_PER_WARP - 1:0][DATA_BITS-1:0] rt;

localparam IDLE=2'b00, LOAD=2'b01, EXECUTE = 2'b10, DONE = 2'b11;
reg [1:0] group_state = 0;

for (i = 0; i < THREADS_PER_WARP; i++)begin
    alu alu_1(.enable(~mask[i]), .rs(rs[i]), .rt(rt[i]), .clk(clk), .reset(reset), .group_state(group_state), .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux), .decoded_alu_output_mux(decoded_alu_output_mux), .alu_out(alu_out_reg[i]));
    lsu lsu_1(.clk(clk),
    .reset(reset), .rs(rs[i]), .rt(rt[i]), 
    .decoded_mem_read_enable(decoded_mem_read_enable), .decoded_mem_write_enable(decoded_mem_write_enable),
    .group_state(group_state), .enable(~mask[i]), .mem_read_valid(mem_read_valid[i]), .mem_read_address(mem_read_address[i]), .mem_read_ready(mem_read_ready[i]),
    .mem_read_data(mem_read_data[i]), .mem_write_valid(mem_write_valid[i]), .mem_write_address(mem_write_address[i]), .mem_write_ready(mem_write_ready),
    .mem_write_data(mem_write_data[i]), .lsu_state(lsu_state[i]), .lsu_out(lsu_out[i]));
    genvar k;
    for (k = 0; k < WARP_NUM; k = k + 1) begin
   registers #(.THREAD_ID(i), .THREADS_PER_WARP(THREADS_PER_WARP), .WARP_ID(k)) regi(.enable(~mask[i]), .rs(rs[i]), .rt(rt[i]), .clk(clk), .reset(reset), .group_state(group_state), .decoded_rd_address(decoded_rd_address),
   .decoded_rs_address(decoded_rs_address), .decoded_rt_address(decoded_rt_address), 
   .decoded_reg_write_enable(decoded_reg_write_enable),
   .decoded_reg_input_mux(decoded_reg_input_mux),
   .decoded_immediate(decoded_immediate), .lsu_out(lsu_out[i]), .alu_out(alu_out_reg[i]), .warp_id(warp_id));
    end
end
    always@(posedge clk)begin
        if (reset)begin
            idle <= 1;
            mem_read_valid <= 0;
            mem_write_valid <= 0;
            lsu_state <= 0;
            rs <= 0;
            rt <= 0;
            lsu_out <= 0;
            group_state <= 0;
            alu_out_reg <= 0;
        end
        case(group_state)
            IDLE: begin
                idle <= 1;
                if (decoded_valid)begin 
                    group_state <= 1;
                    idle <= 0;
                end
            end
            LOAD: begin
                group_state <= 2;
            end
            EXECUTE: begin
                group_state <= 3;
            end
            DONE: begin
                group_state <= 0;
            end
        endcase   
    end
endmodule
