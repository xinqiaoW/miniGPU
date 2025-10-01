`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/29 13:52:54
// Design Name: 
// Module Name: sim_tensorcore
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


`timescale 1ns/1ps

module sim_tensorcore();
  typedef logic [3:0][3:0][31:0] operand_t;
  typedef logic [3:0][3:0][31:0] input_t;
  typedef logic [15:0] vinstr_t;
  localparam INTeger = 0;
  localparam fp_32 = 2;
  localparam mix_precision = 1;
 
  logic clk;
  logic reset;
  vinstr_t vecop;
  input_t matrix_a;
  input_t matrix_b;
  input_t matrix_c;
  operand_t out;
  
  // 时钟生成（周期10ns）
  always #5 clk = ~clk;
  
  // 实例化被测模块
  tensorcore u_tensorcore (
    .clk(clk),
    .reset(reset),
    .vecop(vecop),
    .matrix_a(matrix_a),
    .matrix_b(matrix_b),
    .matrix_c(matrix_c),
    .out(out)
  );
  
  // 主测试逻辑
  initial begin
    // 初始化信号
    clk = 0;
    reset = 1;
    vecop = 0;
    matrix_a = 0;
    matrix_b = 0;
    matrix_c = 0;
    
    // 测试1: 复位功能
    $display("[%0t] mode1: reset", $time);
    # 20;
    if (out !== 0) $error("reset fail");
    else $display("reset success");
    
    // 释放复位
    reset = 0;
    # 20;
    
    // 测试2: 整数模式计算 (A=单位矩阵, B=单位矩阵, C=零矩阵)
//    $display("\n[%0t] mode2: integer", $time);
//    vecop = INTeger;  // 设置整数模式
    
//    // 创建单位矩阵A
//    for (int i = 0; i < 4; i++) begin
//      for (int j = 0; j < 4; j++) begin
//        matrix_a[i][j] = (i == j) ? 32'd1 : 32'd0;
//      end
//    end
    
//    // 创建单位矩阵B
//    for (int i = 0; i < 4; i++) begin
//      for (int j = 0; j < 4; j++) begin
//        matrix_b[i][j] = (i == j) ? 32'd1 : 32'd0;
//      end
//    end
    
//    // 矩阵C设为0
//    matrix_c = 0;
    
//    // 等待计算完成
//    #20;
    
//    // 验证结果应为单位矩阵
//    for (int i = 0; i < 4; i++) begin
//      for (int j = 0; j < 4; j++) begin
//        logic [31:0] expected = (i == j) ? 32'd1 : 32'd0;
//        if (out[i][j] !== expected) begin
//          $error("错误! out[%0d][%0d]=%0d, 期望值=%0d", 
//                 i, j, out[i][j], expected);
//        end
//      end
//    end
//    $display("Success!");
    
     // 随机矩阵
    $display("\n[%0t] mode3: random matrix integer", $time);
    vecop = INTeger;  // 设置整数模式
    
    // 创建矩阵A
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        matrix_a[i][j] = i;
      end
    end
    // 创建矩阵B
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        matrix_b[i][j] = j;
      end
    end
    // 创建矩阵C
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        matrix_c[i][j] = (i > j)? 1 : 0;
      end
    end
    
     # 6;
    for (int i = 0; i < 4; i++) begin
        $display("%d %d %d %d", out[i][0], out[i][1], out[i][2], out[i][3]);
    end
    # 4;
    
     // 随机矩阵
    $display("\n[%0t] mode4: random matrix fp_32", $time);
    vecop = fp_32;  // 设置fp_32数模式
    
    // 创建矩阵A
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        matrix_a[i][j] = $shortrealtobits(shortreal(i));
//         $display("%f", $bitstoshortreal(matrix_a[i][j]) * $bitstoshortreal(matrix_a[i][j]));
      end
    end
    // 创建矩阵B
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        matrix_b[i][j] = $shortrealtobits(shortreal(j));
      end
    end
    // 创建矩阵C
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        matrix_c[i][j] = (i > j)? $shortrealtobits(0.1) : $shortrealtobits(0.0);
      end
    end
    # 10;
    for (int i = 0; i < 4; i++) begin
        $display("%f %f %f %f", $bitstoshortreal(out[i][0]), $bitstoshortreal(out[i][1]), $bitstoshortreal(out[i][2]), $bitstoshortreal(out[i][3]));
    end
    
    // 随机矩阵
    $display("\n[%0t] mode4: random matrix fp_mix", $time);
    vecop = mix_precision;  // 设置fp_32数模式
    
    // 创建矩阵A
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        reg [31:0] x = $shortrealtobits(shortreal(i));
        if (x!=0) begin
            matrix_a[i][j][15] = x[31];
            matrix_a[i][j][14:10] = x[30:23] - 112;
            matrix_a[i][j][9:0] = (x[22:0] >> 13); 
        end
        else begin
            matrix_a[i][j]  = 0;
        end
//         $display("%f", $bitstoshortreal(matrix_a[i][j]) * $bitstoshortreal(matrix_a[i][j]));
      end
    end
    // 创建矩阵B
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        reg [31:0] x = $shortrealtobits(shortreal(j));
        if (x!=0) begin
            matrix_b[i][j][15] = x[31];
            matrix_b[i][j][14:10] = x[30:23] - 112;
            matrix_b[i][j][9:0] = (x[22:0] >> 13); 
        end
        else begin
            matrix_b[i][j]  = 0;
        end
      end
    end
    // 创建矩阵C
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        reg [31:0]x = (i > j)? $shortrealtobits(0.1) : $shortrealtobits(0.0);
        if (x!=0) begin
            matrix_c[i][j][15] = x[31];
            matrix_c[i][j][14:10] = x[30:23] - 112;
            matrix_c[i][j][9:0] = (x[22:0] >> 13); 
        end
        else begin
            matrix_c[i][j]  = 0;
        end
      end
    end
    # 10;
    for (int i = 0; i < 4; i++) begin
        $display("%f %f %f %f", $bitstoshortreal(out[i][0]), $bitstoshortreal(out[i][1]), $bitstoshortreal(out[i][2]), $bitstoshortreal(out[i][3]));
    end
    end
endmodule
