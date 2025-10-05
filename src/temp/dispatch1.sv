`default_nettype none
`timescale 1ns/1ns

// BLOCK DISPATCH
// > 顶层只有一个分派单元
// > 负责管理线程的处理并标记内核执行完成
// > 将线程批量以block为单位分派给可用的计算核心执行
module dispatch #(
    parameter NUM_CORES = 2,
    parameter WARPS_PER_CORE = 4,
    parameter THREADS_PER_WARP = 32
) (
    input wire clk,
    input wire reset,
    input wire start,


    // Core States
    input reg [WARPS_PER_CORE-1:0] core_idle[NUM_CORES-1:0],
    input reg [WARPS_PER_CORE-1:0] core_done[NUM_CORES-1:0],
    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,

    // Kernel Execution
    output reg done
);
    // 根据总线程数和每个block的线程数计算总block数
    wire [7:0] total_blocks;//跟计算资源池有关
    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;//???????

    // 跟踪已分派和已完成的block数量
    //block即为分配给warp的一组连续执行的程序
    reg [7:0] blocks_dispatched; // 已分派给核心的block数量
    reg [7:0] blocks_done; // 已完成处理的block数量


    always @(posedge clk) begin
        if (reset) begin
            blocks_dispatched = 0;

            for (int i = 0; i < NUM_CORES; i++) begin
                core_start[i] <= 0;
                core_reset[i] <= 1;
            end
        end else if (start) begin    

            // 如果最后一个block已处理完成，标记该内核执行已完成
            if (blocks_done == total_blocks) begin 
                done <= 1;
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_reset[i]) begin 
                    core_reset[i] <= 0;

                end
            end

            for(int i = 0; i<NUM_CORES; i++) begin
                // 如果core空闲且还有block未分派，分派一个新block
                if (core_idle[i] != 0 && blocks_dispatched < total_blocks) begin
                    core_start[i] <= 1;
                    blocks_dispatched = blocks_dispatched + 1;
                end
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                for(int w = 0; w < WARPS_PER_CORE; w++) begin
                    if (core_start[i] && core_done[i][w]) begin
                        blocks_done = blocks_done + 1;
                    end
                end
            end
            
        end
    end
endmodule