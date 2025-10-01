`default_nettype none
`timescale 1ns/1ps

// Warp调度器模块
// 功能：管理多个Warp(线程组)的执行状态，处理分支控制和指令获取
// 特点：支持SIMT(单指令多线程)执行模型，处理分支分歧和合并
module WarpScheduler #( 
    parameter WarpNum     = 8,      // Warp数量
    parameter ThreadNum   = 32,     // 每个Warp的线程数
    parameter AddrWidth   = 32,     // 地址宽度
    parameter DataWidth   = 32      // 数据宽度(XLen)
) (
    input  wire clk,                // 时钟信号
    input  wire reset,              // 复位信号，高有效
    
    // Warp命令接口 - 输入
    input  wire warp_cmd_valid,     // Warp命令有效信号
    output wire warp_cmd_ready,     // Warp命令就绪信号
    input  wire [AddrWidth-1:0] warp_cmd_pc,    // Warp起始程序计数器
    input  wire [ThreadNum-1:0] warp_cmd_mask,  // Warp线程掩码
    
    // Warp控制接口 - 输入

    input  wire warp_ctl_valid,     // Warp控制有效信号
    output wire warp_ctl_ready,     // Warp控制就绪信号
    input  wire [$clog2(WarpNum)-1:0] warp_ctl_wid,  // Warp ID
    input  wire warp_ctl_active,    // Warp活跃状态控制信号

    // 分支控制接口 - 输入
    input  wire branch_ctl_valid,   // 分支控制有效信号
    output wire branch_ctl_ready,   // 分支控制就绪信号
    input  wire [$clog2(WarpNum)-1:0] branch_ctl_wid,  // Warp ID
    input  wire [AddrWidth + ThreadNum - 1:0] branch_ctl_data,// 分支数据
    
    // 结束控制接口 - 输入  
    input  wire end_ctl_valid,      // 结束控制有效信号
    output wire end_ctl_ready,      // 结束控制就绪信号
    input  wire [$clog2(WarpNum)-1:0] end_ctl_wid,  // Warp ID

    // Warp栈弹出控制信号
    input  wire warp_pop_valid,                      // Warp栈弹出有效信号
    output wire warp_pop_ready,                      // Warp栈弹出就绪信号
    input  wire [$clog2(WarpNum)-1:0] warp_pop_wid,  // Warp栈弹出Warp ID

    
    // 指令获取接口 - 输出
    output wire inst_fetch_valid,   // 指令获取有效信号
    input  wire inst_fetch_ready,   // 指令获取就绪信号
    output wire [AddrWidth-1:0] inst_fetch_pc,  // 指令地址
    output wire [ThreadNum-1:0] inst_fetch_mask,// 线程掩码
    output wire [$clog2(WarpNum)-1:0] inst_fetch_wid,  // Warp ID
    
    //////////////////////////////////////////////////////////////
    output reg [(WarpNum)-1:0] idle_id_out,
    output reg [(WarpNum)-1:0] active_id_out,
    output wire [AddrWidth + ThreadNum - 1:0] pop_data_out
    //////////////////////////////////////////////////////////////
);

    // ==================== 内部寄存器定义 ====================
    reg [WarpNum-1:0] warp_idle;        // Warp空闲状态 (1=空闲, 0=已分配)
    reg [WarpNum-1:0] warp_active;      // Warp活跃状态 (1=活跃, 0=非活跃)
    reg [AddrWidth-1:0] warp_pc [0:WarpNum-1];         // 每个Warp的程序计数器
    reg [ThreadNum-1:0] warp_tmask [0:WarpNum-1];      // 每个Warp的线程掩码

    // ==================== 内部连线定义 ====================
    wire has_idle;                      // 是否存在空闲Warp
    wire has_active;                    // 是否存在活跃Warp
    wire [$clog2(WarpNum)-1:0] idle_id; // 第一个空闲Warp的ID
    wire [$clog2(WarpNum)-1:0] active_id;// 第一个活跃Warp的ID
    
    
    // ==================== SIMT栈实例化 ====================
    // 每个Warp都有�?个独立的SIMT栈，用于处理分支分歧和合�?
    genvar i;
    generate
        for (i = 0; i < WarpNum; i = i + 1) begin : simt_stacks
            SIMTStack #(
                .DataWidth(DataWidth),
                .AddrWidth(AddrWidth),
                .ThreadNum(ThreadNum)
            ) simt_stack (
                .clk(clk),
                .reset(reset),
                // 分支数据输入
                .in_data(branch_ctl_data),
                // 推入操作：当分支控制有效且Warp ID匹配时
                .push(branch_ctl_valid && (branch_ctl_wid == i)),
                // 弹出操作：当Warp控制有效且是合并操作且Warp ID匹配时
                .pop(warp_pop_valid && (warp_pop_wid == i)),
                // 输出数据
                .out_data(simt_stack_out_data[i])
            );
        end
    endgenerate
    
    // SIMT栈输出信号
    wire [AddrWidth + ThreadNum - 1:0] simt_stack_out_data [0:WarpNum-1];
    wire [$clog2(8):0] simt_stack_sp_out [0:WarpNum-1]; // 添加栈指针输出数组

   
    // ==================== 优先级编码器 ====================
    // 查找第一个空闲Warp的ID
    PriorityEncoder #(
        .WIDTH(WarpNum)
    ) idle_encoder (
        .in(warp_idle),
        .out(idle_id),
        .valid() // 未使用
    );
    
    // 查找第一个活跃Warp的ID
    PriorityEncoder #(
        .WIDTH(WarpNum)
    ) active_encoder (
        .in(warp_active),
        .out(active_id),
        .valid() // 未使用
    );
    
    // ==================== 组合逻辑 ====================
    assign active_id_out = warp_active;
    assign idle_id_out = warp_idle;
    assign pop_data_out = simt_stack_out_data[warp_pop_wid];

    // 查找是否有空闲Warp
    assign has_idle = |warp_idle;
    // 查找是否有活跃Warp
    assign has_active = |warp_active;
    
    // 接口就绪信号
    assign warp_cmd_ready = has_idle;   // 有空闲Warp时可接收新命令
    assign warp_ctl_ready = 1'b1;       // 总是准备好接收控制信号
    assign branch_ctl_ready = has_idle;     // 总是准备好接收分支控制信号
    //或者has_active;
    assign warp_pop_ready = 1'b1;       // 总是准备好接收弹出控制信号
    assign end_ctl_ready = 1'b1;        // 总是准备好接收结束控制信号


    // 指令获取输出
    assign inst_fetch_valid = has_active;
    assign inst_fetch_pc = has_active ? warp_pc[active_id] : {AddrWidth{1'b0}};
    assign inst_fetch_mask = has_active ? warp_tmask[active_id] : {ThreadNum{1'b0}};
    assign inst_fetch_wid = has_active ? active_id : {$clog2(WarpNum){1'b0}};
    
    // ==================== 时序逻辑 ====================
    always @(posedge clk or posedge reset) begin
        integer w, t;
        if (reset) begin
            // 复位初始�?
            warp_idle <= {WarpNum{1'b1}};      // �?有Warp初始为空�?
            warp_active <= {WarpNum{1'b0}};    // �?有Warp初始为非活跃
            
            // 初始化每个Warp的PC和线程掩�?
            for (w = 0; w < WarpNum; w = w + 1) begin
                warp_pc[w] <= {AddrWidth{1'b0}};
                warp_tmask[w] <= {ThreadNum{1'b0}};
            end
            
        end else begin
            
            // Warp命令处理：分配新Warp
            if (warp_cmd_valid && warp_cmd_ready) begin
                warp_idle[idle_id] <= 1'b0;            // 标记Warp为非空闲
                warp_active[idle_id] <= 1'b1;          // 标记Warp为活�?
                warp_pc[idle_id] <= warp_cmd_pc;       // 设置程序计数�?
                warp_tmask[idle_id] <= warp_cmd_mask;  // 设置线程掩码
            end
            
            // 结束控制处理：释放Warp
            if (end_ctl_valid && end_ctl_ready) begin
                warp_idle[end_ctl_wid] <= 1'b1;        // 标记Warp为空�?
                warp_active[end_ctl_wid] <= 1'b0;      // 标记Warp为非活跃
            end
            
            // Warp控制处理：更新Warp活跃状态
            if (warp_ctl_valid && warp_ctl_ready) begin
                warp_active[warp_ctl_wid] <= warp_ctl_active;
            end
    
            
            // SIMT栈弹出处理：处理合并操作
            if (warp_pop_valid&&warp_pop_ready) begin
                warp_pc[warp_pop_wid] <= simt_stack_out_data[warp_pop_wid][AddrWidth-1:0];
                warp_tmask[warp_pop_wid] <= simt_stack_out_data[warp_pop_wid][AddrWidth + ThreadNum - 1:AddrWidth];
            end


            // 指令获取处理：指令执行完成后更新状态
            if (inst_fetch_valid && inst_fetch_ready) begin
                warp_pc[active_id] <= warp_pc[active_id] + 4; // PC指向下一条指令
                warp_active[active_id] <= 1'b0;
            end
        end
    end

endmodule

// ==================== 子模块：优先级编码器 ====================
module PriorityEncoder #(
    parameter WIDTH = 8
) (
    input wire [WIDTH-1:0] in,          // 输入信号
    output reg [$clog2(WIDTH)-1:0] out, // 编码输出
    output wire valid                   // 有效信号（至少有�?位为1�?
);
    
    // �?查输入是否有效（至少有一位为1�?
    assign valid = |in;
    
    // 优先级编码�?�辑
    always @(*) begin
        out = {$clog2(WIDTH){1'b0}};    // 默认输出0
        // 遍历�?有位，找到第�?个为1的位
        for (integer i = 0; i < WIDTH; i = i + 1) begin
            if (in[i]) begin
                out = i;                // 输出第一个为1的位的索�?
            end
        end
    end
    
endmodule

// ==================== 子模块：SIMT�? ====================
// 用于处理分支分歧和合并的栈结�?
module SIMTStack #(
    parameter DataWidth = 32,
    parameter AddrWidth = 32,
    parameter ThreadNum = 32,
    parameter DEPTH = 8
) (
    input wire clk,
    input wire reset,
    input wire [AddrWidth + ThreadNum - 1:0] in_data,         // 压入栈的是指令地�?
    input wire push,
    input wire pop,
    output wire [AddrWidth + ThreadNum - 1:0] out_data
);
    reg [AddrWidth-1:0] sp; 
    reg [AddrWidth + ThreadNum - 1:0] stack_mem [0:DEPTH-1];
    
    assign out_data = stack_mem[(sp > 0) ? (sp - 1) : 0];
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sp <= 0;
        end else begin
            if (push && sp < DEPTH) begin
                stack_mem[sp] <= in_data;
                sp <= sp + 1;
            end else if (pop && sp > 0) begin
                sp <= sp - 1;
            end
        end
    end

endmodule
