`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/01 14:11:08
// Design Name: 
// Module Name: sim_adder
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


module sim_adder(
    );
   
    reg[31:0] a, b, o;
    shortreal g, h;
    adder add(
              .a(a),
              .b(b),
              .o(o));
    initial begin
        a = $shortrealtobits(0.0);
        
        $display("%f", $bitstoshortreal(a));
        b = $shortrealtobits(0.0);
        
        $display("%f", $bitstoshortreal(b));
        $display("%f", $bitstoshortreal(b) + $bitstoshortreal(a));
    end
    initial begin
    # 5 $display("%f", $bitstoshortreal(o));
    end
endmodule
