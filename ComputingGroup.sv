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
parameter int NumAlu = 8,
parameter DATA_BITS = 8)(
input wire clk,
input wire reset,

input reg decoded_mem_read_enable,
input reg decoded_mem_write_enable,//这两个信号是所有lsu公共的

input reg [1:0] decoded_alu_arithmetic_mux,
input reg decoded_alu_output_mux,
input reg [NumAlu-1:0] mem_read_ready,
input reg [NumAlu-1:0][DATA_BITS-1:0] mem_read_data,

output reg [NumAlu-1:0]mem_write_valid,
output reg [NumAlu-1:0][7:0] mem_write_address,
output reg [NumAlu-1:0][7:0] mem_write_data,
input reg [NumAlu-1:0]mem_write_ready,

output reg [NumAlu-1:0]mem_read_valid,
output reg [NumAlu-1:0][DATA_BITS-1:0] mem_read_address,

input reg [3:0] decoded_rd_address,
input reg [3:0] decoded_rs_address,
input reg [3:0] decoded_rt_address,

input reg decoded_reg_write_enable,
input reg [1:0] decoded_reg_input_mux,
input reg [DATA_BITS-1:0] decoded_immediate
    );
genvar i;
reg[NumAlu - 1:0] mask = 0;
reg[NumAlu - 1:0][DATA_BITS-1:0] rs; // rs rt 是数据，有时候这个数据是另一个数据的地址
reg[NumAlu - 1:0][DATA_BITS-1:0] rt;
reg [1:0] group_state = 0;
reg [NumAlu - 1:0][DATA_BITS-1:0] alu_out_reg;

reg [NumAlu - 1:0][1:0] lsu_state;
reg [NumAlu - 1:0][7:0] lsu_out;


for (i = 0; i < NumAlu; i++)begin
    alu alu_1(.enable(~mask[i]), .rs(rs[i]), .rt(rt[i]), .clk(clk), .reset(reset), .group_state(group_state), .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux), .decoded_alu_output_mux(decoded_alu_output_mux), .alu_out(alu_out_reg[i]));
    lsu lsu_1(.clk(clk),
    .reset(reset), .rs(rs[i]), .rt(rt[i]), 
    .decoded_mem_read_enable(decoded_mem_read_enable), .decoded_mem_write_enable(decoded_mem_write_enable),
    .group_state(group_state), .enable(~mask[i]), .mem_read_valid(mem_read_valid[i]), .mem_read_address(mem_read_address[i]), .mem_read_ready(mem_read_ready[i]),
    .mem_read_data(mem_read_data[i]), .mem_write_valid(mem_write_valid[i]), .mem_write_address(mem_write_address[i]), .mem_write_ready(mem_write_ready[i]),
    .mem_write_data(mem_write_data[i]), .lsu_stat(lsu_state[i]), .lsu_out(lsu_out));
    
    registers regi(.enable(~mask[i]), .rs(rs[i]), .rt(rt[i]), .clk(clk), .reset(reset), .group_state(group_state), .decoded_rd_address(decoded_rd_address),
    .decoded_rs_address(decoded_rs_address), .decoded_rt_address(decoded_rt_address), 
    .decoded_reg_write_enable(decoded_reg_write_enable),
    .decoded_reg_input_mux(decoded_reg_input_mux),
    .decoded_immediate(decoded_immediate), .lsu_out(lsu_out[i]), .alu_out(alu_out_reg[i]));
end
endmodule
