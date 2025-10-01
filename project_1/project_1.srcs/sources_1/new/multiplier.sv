`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/07 13:25:49
// Design Name: 
// Module Name: multiplier
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


module multiplier#(parameter int DataWidth=32,
parameter int exp_len=8,
parameter int mid=46)(
    input[DataWidth-1:0] a,
    input[DataWidth-1:0] b,
    output reg[31:0] o
    );
    reg sign_a, sign_b, sign_o;
    reg[exp_len-1:0] exp_a, exp_b, exp_o;
    reg[DataWidth-2-exp_len:0] frac_a, frac_b;
    reg[DataWidth-1-exp_len:0] with_1_frac_a, with_1_frac_b;
    reg[2 * (DataWidth-exp_len) - 1:0] frac_o;
    reg[15:0] fp_16_o;
    int cnt;
    fp_16_to_32 convert(.fp_16(fp_16_o), .fp_32(o));
    always@(*)begin
//     Special Cases
        if((a[DataWidth-2:0]==0) || (b[DataWidth-2:0]==0))begin
            o = 0;
        end
        else begin
        {sign_a, exp_a, frac_a} = a;
        {sign_b, exp_b, frac_b} = b;
        with_1_frac_a = {1'b1, frac_a};
        with_1_frac_b = {1'b1, frac_b};
        sign_o = sign_a ^ sign_b;
        
        exp_o = exp_a + exp_b - (2 ** (exp_len - 1) - 1);
        
        frac_o = with_1_frac_a * with_1_frac_b;
        cnt = 2 * (DataWidth-exp_len) - 1;
        while(cnt >= 0)begin
            if (frac_o[cnt] == 1)begin
                if(cnt > mid)begin
                    frac_o = (frac_o >>> (cnt - mid));
                    exp_o = exp_o + (cnt - mid);
                end
                else if (cnt < mid)begin
                    frac_o = (frac_o << (mid - cnt));
                    exp_o = exp_o + (cnt - mid);
                end
                break;
            end
            cnt -= 1;
        end
        o = {sign_o, exp_o, frac_o[mid-1:mid-(DataWidth-1-exp_len)]};
    end
        if (DataWidth==16) begin
            fp_16_o = {sign_o, exp_o, frac_o[mid-1:mid-(DataWidth-1-exp_len)]};
        end
    end
endmodule
