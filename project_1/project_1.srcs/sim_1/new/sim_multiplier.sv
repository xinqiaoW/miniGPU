`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/08 21:13:29
// Design Name: 
// Module Name: sim_multiplier
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


module sim_multiplier#(DataWidth=32)(
    );
    reg[31:0] a, b, o;
    shortreal g, h;
    multiplier multi(
              .a(a),
              .b(b),
              .o(o));
    initial begin
        a = $shortrealtobits(328.2);
        
        $display("%f", $bitstoshortreal(a));
        b = $shortrealtobits(198.13);
        
        $display("%f", $bitstoshortreal(b));
        $display("%f", $bitstoshortreal(b) * $bitstoshortreal(a));
    end
    initial begin
    # 5 $display("%f", $bitstoshortreal(o));
    end
endmodule
