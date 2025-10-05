`default_nettype none
`timescale 1ns/1ns

// BLOCK DISPATCH
// > 顶层只有一个分派单元
// > 负责管理线程的处理并标记内核执行完成
// > 将线程批量以block为单位分派给可用的计算核心执行
module dispatch #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
) (
    input wire clk,
    input wire reset,
    input wire start,

    // Kernel Metadata
    input wire [7:0] thread_count,

    // Core States
    input reg [NUM_CORES-1:0] core_done,
    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,
    output reg [7:0] core_block_id [NUM_CORES-1:0],
    output reg [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    // Kernel Execution
    output reg done
);
    // 根据总线程数和每个block的线程数计算总block数
    wire [7:0] total_blocks;
    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    // 跟踪已分派和已完成的block数量
    reg [7:0] blocks_dispatched; // 已分派给核心的block数量
    reg [7:0] blocks_done; // 已完成处理的block数量
    reg start_execution; // EDA: 由于EDA工具原因的无关hack

    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            blocks_dispatched = 0;
            blocks_done = 0;
            start_execution <= 0;

            for (int i = 0; i < NUM_CORES; i++) begin
                core_start[i] <= 0;
                core_reset[i] <= 1;
                core_block_id[i] <= 0;
                core_thread_count[i] <= THREADS_PER_BLOCK;
            end
        end else if (start) begin    
            // EDA: 间接实现@(posedge start)，避免由两个不同时钟驱动
            if (!start_execution) begin 
                start_execution <= 1;
                for (int i = 0; i < NUM_CORES; i++) begin
                    core_reset[i] <= 1;
                end
            end

            // 如果最后一个block已处理完成，标记该内核执行已完成
            if (blocks_done == total_blocks) begin 
                done <= 1;
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_reset[i]) begin 
                    core_reset[i] <= 0;

                    // 如果该核心刚刚被复位，检查是否还有block需要分派
                    if (blocks_dispatched < total_blocks) begin 
                        core_start[i] <= 1;
                        core_block_id[i] <= blocks_dispatched;
                        core_thread_count[i] <= (blocks_dispatched == total_blocks - 1) 
                            ? thread_count - (blocks_dispatched * THREADS_PER_BLOCK)
                            : THREADS_PER_BLOCK;

                        blocks_dispatched = blocks_dispatched + 1;
                    end
                end
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_start[i] && core_done[i]) begin
                    // 如果某个核心刚完成当前block的执行，则复位该核心
                    core_reset[i] <= 1;
                    core_start[i] <= 0;
                    blocks_done = blocks_done + 1;
                end
            end
        end
    end
endmodule