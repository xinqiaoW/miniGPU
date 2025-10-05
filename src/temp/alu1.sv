`default_nettype none
`timescale 1ns/1ns

// 算术逻辑单元（ALU）
module alu (
    input wire clk,
    input wire reset,
    input wire enable,

    input reg [2:0] core_state,

    input wire [1:0] alu_op,         // 00:ADD, 01:SUB, 10:MUL, 11:DIV
    input wire alu_cmp_mode,         // 1:比较模式，0:普通运算
    input wire [7:0] rs,
    input wire [7:0] rt,
    output reg [7:0] alu_out
);

    localparam ADD = 2'b00,
        SUB = 2'b01,
        MUL = 2'b10,
        DIV = 2'b11;

    always @(posedge clk) begin 
        if (reset) begin 
            alu_out <= 8'b0;
        end else if (enable) begin
            if(core_state == 3'b101) begin
                if (alu_cmp_mode) begin
                    // 比较模式，输出NZP
                    alu_out <= {5'b0, (rs - rt > 0), (rs - rt == 0), (rs - rt < 0)};
                end else begin
                case (alu_op)
                    ADD: begin 
                            alu_out <= rs + rt;
                        end
                    SUB: begin 
                            alu_out <= rs - rt;
                        end
                    MUL: begin 
                            alu_out <= rs * rt;
                        end
                    DIV: begin 
                            alu_out <= rs / rt;
                        end
                endcase
            end
        end
    end
endmodule