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
    input  wire [ThreadNum-1:0] inst_fetch_mask, // 线程掩码
    input  wire [$clog2(WarpNum)-1:0] warp_wid,  // Warp ID
    output reg         inst_fetch_ready,         // Fetcher准备好接收新请求

    // 程序存储器接口
    output reg         mem_read_valid,           // 读请求有效
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] mem_read_address, // 读请求地址
    input  wire        mem_read_ready,           // 存储器响应
    input  wire [PROGRAM_MEM_DATA_BITS-1:0] mem_read_data,   // 读回的指令

    // 输出
    output reg [2:0] fetcher_state,//改成内部信号
    output reg [PROGRAM_MEM_DATA_BITS-1:0] instruction // 取出的指令
    output wire [ThreadNum-1:0] mask,// 线程掩码
    output wire [$clog2(WarpNum)-1:0] warp_wid,  // Warp ID

    //输出握手信号
    output reg fc_out_valid,
    input  wire fc_out_ready

);
    
    localparam 
        IDLE = 2'b00, 
        FETCHING = 2'b01, 
        FETCHED = 2'b10;


    // 状态机组合逻辑
    always @(posedge clk) begin
        if (reset) begin
            fetcher_state <= IDLE;
            mem_read_valid <= 0;
            mem_read_address <= 0;
            instruction <= {PROGRAM_MEM_DATA_BITS{1'b0}};
            inst_fetch_ready <= 1;
        end else begin
            case (fetcher_state)
                IDLE: begin
                    inst_fetch_ready = 1; // 可以接收WarpScheduler请求
                    fc_out_valid <= 0;
                    if (inst_fetch_valid && inst_fetch_ready) begin
                        fetcher_state <= FETCHING;
                        mem_read_valid <= 1;
                        mem_read_address <= inst_fetch_pc;
                    end
                end
                FETCHING: begin
                    if (mem_read_ready) begin
                        instruction <= mem_read_data; // Store the instruction when received
                        mem_read_valid <= 0;
                        fc_out_valid <= 1;
                    end

                end
                FETCHED: begin
                    if(fc_out_ready && fc_out_valid) begin
                        fetcher_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule