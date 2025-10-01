`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/10 10:13:28
// Design Name: 
// Module Name: fp_16_to_32
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


module fp_16_to_32(
    input reg[15:0] fp_16,
    output reg[31:0] fp_32
    );
    always @(*)begin
        fp_32[31] <= fp_16[15];
        if (fp_16[14:10]==5'b11111)begin
            fp_32[30:23] <= 8'b11111111;
        end
        else if(fp_16[14:10]==5'b00000)begin
            fp_32[30:23] <= 8'b00000000;
        end
        else begin
            fp_32[30:23] <= fp_16[14:10] + 112;
        end
        fp_32[22:0] <= (fp_16[9:0] << 13); 
    end
endmodule
