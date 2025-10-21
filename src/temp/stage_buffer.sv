`default_nettype none
`timescale 1ns/1ns

// 通用的阶段间缓冲寄存器
module stage_buffer #(
    parameter DATA_WIDTH = 64,      // 数据宽度
    parameter STAGE_NAME = "UNKNOWN" // 阶段名称，用于调试
) (
    input  wire clk,
    input  wire reset,
    input  wire enable,           // 流水线推进使能
    input  wire flush,            // 流水线刷新（如分支预测失败）
    input  wire [DATA_WIDTH-1:0] data_in,      // 输入数据
    output reg  [DATA_WIDTH-1:0] data_out,     // 输出数据
    output reg  valid_out         // 输出数据有效标志
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // 复位时清空缓冲区
            data_out <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (flush) begin
            // 刷新时清空缓冲（如分支预测失败时）
            data_out <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (enable) begin
            // 正常推进流水线时锁存数据
            data_out <= data_in;
            valid_out <= 1'b1;
        end
        // 否则保持当前值（当流水线暂停时）
    end

endmodule