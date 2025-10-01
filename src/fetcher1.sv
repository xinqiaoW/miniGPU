`default_nettype none
`timescale 1ns/1ns

// 指令获取器（Fetcher）
// 由WarpScheduler提供指令地址，Fetcher从程序存储器读取指令，输出给Decode阶段
module fetcher #(
    parameter PROGRAM_MEM_ADDR_BITS = 32,   // 地址宽度与WarpScheduler一致
    parameter PROGRAM_MEM_DATA_BITS = 32    // 指令宽度
) (
    input  wire clk,
    input  wire reset,

    // WarpScheduler接口
    input  wire        inst_fetch_valid,         // WarpScheduler请求取指
    input  wire [PROGRAM_MEM_ADDR_BITS-1:0] inst_fetch_pc, // WarpScheduler给出的指令地址
    output reg         inst_fetch_ready,         // Fetcher准备好接收新请求

    // 程序存储器接口
    output reg         mem_read_valid,           // 读请求有效
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] mem_read_address, // 读请求地址
    input  wire        mem_read_ready,           // 存储器响应
    input  wire [PROGRAM_MEM_DATA_BITS-1:0] mem_read_data,   // 读回的指令

    // 输出到Decode阶段
    output reg         fetcher_valid,            // 取指完成信号
    output reg [PROGRAM_MEM_DATA_BITS-1:0] instruction // 取出的指令
);

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        FETCH_REQ = 2'b01,
        FETCH_WAIT = 2'b10,
        FETCH_DONE = 2'b11
    } fetcher_state_t;

    fetcher_state_t state, next_state;

    // 状态机时序逻辑
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            mem_read_valid <= 0;
            mem_read_address <= 0;
            instruction <= 0;
            fetcher_valid <= 0;
            inst_fetch_ready <= 1;
        end else begin
            state <= next_state;
            // 输出信号在状态机中赋值
        end
    end

    // 状态机组合逻辑
    always @(*) begin
        // 默认值
        mem_read_valid = 0;
        mem_read_address = 0;
        fetcher_valid = 0;
        inst_fetch_ready = 0;

        case (state)
            IDLE: begin
                inst_fetch_ready = 1; // 可以接收WarpScheduler请求
                if (inst_fetch_valid) begin
                    mem_read_valid = 1;
                    mem_read_address = inst_fetch_pc;
                    next_state = FETCH_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            FETCH_WAIT: begin
                if (mem_read_ready) begin
                    fetcher_valid = 1;
                    next_state = FETCH_DONE;
                end else begin
                    next_state = FETCH_WAIT;
                end
            end
            FETCH_DONE: begin
                // 等待Decode阶段拉走数据（可根据decode_ready信号优化）
                fetcher_valid = 1;
                inst_fetch_ready = 1; // 可以接收下一个请求
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // 指令寄存
    always @(posedge clk) begin
        if (reset) begin
            instruction <= 0;
        end else if (state == FETCH_WAIT && mem_read_ready) begin
            instruction <= mem_read_data;
        end
    end

endmodule