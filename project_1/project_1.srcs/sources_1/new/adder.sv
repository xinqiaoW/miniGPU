`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/01 10:55:17
// Design Name: 
// Module Name: adder
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
module adder(
    input[31:0] a,
    input[31:0] b,
    output reg[31:0] o
    );
    reg sign_a, sign_b;
    reg[7:0] exp_a, exp_b, exp_diff, exp_o;
    reg[22:0] frac_a, frac_b;
    reg [25:0] with_double_sign_a, with_double_sign_b,with_double_sign_sum;
    reg[1:0] double_sign;
    reg[4:0] cnt;

    
    always @(*) begin
        if (a[30:0]==0)begin
            o = b;
        end
        else if (b[30:0]==0)begin
            o = a;
        end
        else begin
         {sign_a, exp_a, frac_a} = a;
         {sign_b, exp_b, frac_b} = b;
         
         // fraction addition
        with_double_sign_a = {3'b001, frac_a};
        with_double_sign_b = {3'b001, frac_b};
            
        // Align
        if(exp_a > exp_b) begin
            exp_diff = exp_a - exp_b;
            with_double_sign_b = (with_double_sign_b >> exp_diff);
            exp_o = exp_a;
        end
        else if (exp_b > exp_a)begin
            exp_diff = exp_b - exp_a;
            with_double_sign_a = (with_double_sign_a >> exp_diff);
            exp_o = exp_b;
        end
        else begin
            exp_o = exp_b;
        end
        if(sign_a) begin
            with_double_sign_a[25:24] = 2'b11;
            with_double_sign_a[23:0] = ~with_double_sign_a[23:0] + 1;
        end
        if(sign_b) begin
            with_double_sign_b[25:24] = 2'b11;
            with_double_sign_b[23:0] = ~with_double_sign_b[23:0] + 1;
        end
        with_double_sign_sum = with_double_sign_a + with_double_sign_b; 
        double_sign = with_double_sign_sum[25:24];
        if (double_sign == 2'b00) begin
            if (with_double_sign_sum[23] == 1'b1)begin
                o = {1'b0, exp_o, with_double_sign_sum[22:0]};
            end
            else if (with_double_sign_sum[22:0] == 0)
                o = 0;
            else begin
                cnt = 0;
                while (with_double_sign_sum[23] != 1 && (cnt < 23)) begin
                    with_double_sign_sum = (with_double_sign_sum << 1);
                    cnt = cnt + 1;
                end
                o = {1'b0, exp_o - cnt, with_double_sign_sum[22:0]};
            end
        end
        else if (double_sign == 2'b11) begin
            with_double_sign_sum[23:0] = ~(with_double_sign_sum[23:0] - 1);
            if (with_double_sign_sum[23] == 1'b1)begin
                o = {1'b1, exp_o, with_double_sign_sum[22:0]};
            end
            else if (with_double_sign_sum[22:0] == 0)
                o = 0;
            else begin
                cnt = 0;
                while (with_double_sign_sum[23] != 1 && (cnt < 23)) begin
                    with_double_sign_sum = (with_double_sign_sum << 1);
                    cnt = cnt + 1;
                end
                o = {1'b1, exp_o - cnt, with_double_sign_sum[22:0]};
            end
        end
        else if (double_sign == 2'b01) begin
            o = {1'b0, exp_o + 1, with_double_sign_sum[23:1]};
        end
        else if (double_sign == 2'b10) begin
            o = {1'b1, exp_o + 1, ~(with_double_sign_sum[23:1] - 1)};
        end
    end
    end
endmodule