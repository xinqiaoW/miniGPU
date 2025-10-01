`default_nettype none
`timescale 1ns/1ns

// 程序计数器（PC）
module pc #(
    parameter PROGRAM_MEM_ADDR_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire enable,

    input wire [2:0] nzp,
    input wire [7:0] immediate,
    input wire nzp_write_enable,
    input wire pc_mux, 

    input wire [7:0] alu_out,

    input wire [PROGRAM_MEM_ADDR_BITS-1:0] current_pc,
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] next_pc
);
    reg [2:0] nzp_reg;

    always @(posedge clk) begin
        if (reset) begin
            nzp_reg <= 3'b0;
            next_pc <= 0;
        end else if (enable) begin
            //加个判断gpu要执行指令？？？
            if (pc_mux == 1) begin 
                if (((nzp_reg & nzp) != 3'b0)) begin 
                    next_pc <= immediate;
                end else begin 
                    next_pc <= current_pc + 4;
                end
            end else begin 
                next_pc <= current_pc + 4;
            end
            //加个判断gpu要更新nzp数据？？？
            if (nzp_write_enable) begin
                nzp_reg <= alu_out[2:0];
            end
        end
    end
endmodule