`default_nettype none
`timescale 1ns/1ns

// 通用寄存器堆（每个线程独立一份）
// 支持与decoder/alu/lsu/pc等单元直接对接
module registers #(
    parameter THREADS_PER_BLOCK = 4,
    parameter THREAD_ID = 0,
    parameter DATA_BITS = 32
) (
    input  wire clk,
    input  wire reset,
    input  wire enable, // 当前线程是否有效

    // Decoder/PC接口
    input  wire [3:0] reg_rd_address,
    input  wire [3:0] reg_rs_address,
    input  wire [3:0] reg_rt_address,
    input  wire [7:0] reg_immediate,
    input  wire [2:0] reg_nzp,

    // 控制信号
    input  wire reg_write_enable,   // 写使能
    input  wire [1:0] reg_input_mux,// 写入数据选择
    input  wire mem_read_enable,
    input  wire mem_write_enable,
    input  wire nzp_write_enable,

    // ALU/LSU结果输入
    input  wire [DATA_BITS-1:0] alu_out,
    input  wire [DATA_BITS-1:0] lsu_out,

    // 读端口输出
    output reg [DATA_BITS-1:0] rs,
    output reg [DATA_BITS-1:0] rt,

);

    // 16个通用寄存器（13可写+3只读）
    reg [DATA_BITS-1:0] registers[15:0];

    always @(posedge clk) begin
        if (reset) begin
            rs <= 0;
            rt <= 0;
            nzp <= 0;
            // 初始化所有寄存器
            integer i;
            for (i = 0; i < 13; i = i + 1)
                registers[i] <= 0;
            // 只读寄存器
            registers[13] <= 0;                  // %blockIdx
            registers[14] <= THREADS_PER_BLOCK;  // %blockDim
            registers[15] <= THREAD_ID;          // %threadIdx
        end else if (enable) begin
            // 读操作???判断是哪个操作？？
            rs <= registers[reg_rs_address];
            rt <= registers[reg_rt_address];

            // 写操作（通常在执行阶段）
            if (reg_write_enable && reg_rd_address < 13) begin
                case (reg_input_mux)
                    2'b00: registers[reg_rd_address] <= alu_out;         // ALU结果
                    2'b01: registers[reg_rd_address] <= lsu_out;         // LSU结果
                    2'b10: registers[reg_rd_address] <= reg_immediate; // 立即数
                    default: ; // 保持不变
                endcase
            end
        end
    end

endmodule