`default_nettype none
`timescale 1ns/1ns

// 计算核心顶层模块
// 整合WarpScheduler、fetcher、decoder、registers、ALU、LSU等组件
module core #(
    parameter WarpNum = 4,              // Warp数量
    parameter ThreadNum = 32,           // 每个Warp的线程数
    parameter AddrWidth = 32,           // 地址宽度
    parameter DataWidth = 32,           // 数据宽度
    parameter InstWidth = 32            // 指令宽度
)(
    input  wire clk,
    input  wire reset,
    
    // 核心控制接口
    input  wire start,                  // 启动信号
    output wire done,                   // 完成信号
    
    // 程序存储器接口
    output wire        prog_mem_read_valid,
    output wire [AddrWidth-1:0] prog_mem_read_addr,
    input  wire        prog_mem_read_ready,
    input  wire [InstWidth-1:0] prog_mem_read_data,
    
    // 数据存储器接口
    output wire        data_mem_read_valid,
    output wire [AddrWidth-1:0] data_mem_read_addr,
    input  wire        data_mem_read_ready,
    input  wire [DataWidth-1:0] data_mem_read_data,
    output wire        data_mem_write_valid,
    output wire [AddrWidth-1:0] data_mem_write_addr,
    output wire [DataWidth-1:0] data_mem_write_data,
    input  wire        data_mem_write_ready
);

    // ==================== 内部信号定义 ====================
    

    // FETCH -> DECODE 阶段数据
    typedef struct packed {
        logic [31:0] instruction;
        logic [31:0] thread_mask;
        logic [$clog2(WarpNum)-1:0] warp_id;
    } fetch_decode_data_t;
    

    // FETCH -> DECODE 缓冲
    fetch_decode_data_t fd_data_in, fd_data_out;
    

    stage_buffer #(
        .DATA_WIDTH($bits(fetch_decode_data_t)),
        .DEPTH(4), 
        .STAGE_NAME("FETCH_DECODE")
    ) fetch_decode_buffer (
        .clk(clk),
        .reset(reset),
        .valid_in(fc_out_valid),
        .ready_in(fc_out_ready),
        .data_in(fd_data_in),
        .ready_out(dc_in_ready),
        .valid_out(dc_in_valid),//连接decode中输入的握手信号
        .data_out(fd_data_out),
        //其他信号不需要
    );

    // DECODE -> EXECUTE 阶段数据  
    typedef struct packed {
        
        // ... 其他控制信号
    } decode_execute_data_t;


    // DECODE -> EXECUTE 缓冲 - 支持乱序执行
    decode_execute_data_t de_data_in, de_data_out;


    // 新增：解码阶段的寄存器信息（需要从decoder模块输出这些信号）
    wire [3:0] de_reg_rd_addr;    // 从decoder连接到这些信号
    wire [3:0] de_reg_rs_addr;    
    wire [3:0] de_reg_rt_addr;
    wire de_reg_write_enable;

    // // 新增：写回阶段的寄存器信息（需要从执行阶段反馈）
    // wire [3:0] wb_reg_rd_addr;
    // wire wb_reg_write_enable;
    // wire wb_valid;
    // wire [DataWidth-1:0] wb_data;

    stage_buffer #(
        .DATA_WIDTH($bits(decode_execute_data_t)),
        .DEPTH(8),
        .STAGE_NAME("DECODE_EXECUTE_OoO") 
    ) decode_execute_buffer (
        .clk(clk),
        .reset(reset),
        
        .valid_in(dc_out_ready),
        .ready_in(dc_out_valid),      // 需要连接到decoder
        .data_in(de_data_in),

        .valid_out(),
        .ready_out(),   //连接到compute
        .data_out(de_data_out),
        
        // 新增乱序执行接口
        .reg_rd_addr_in(de_reg_rd_addr),
        .reg_rs_addr_in(de_reg_rs_addr),
        .reg_rt_addr_in(de_reg_rt_addr),
        .reg_write_enable_in(de_reg_write_enable),
        
        // .wb_reg_rd_addr(wb_reg_rd_addr),
        // .wb_reg_write_enable(wb_reg_write_enable),
        // .wb_valid(wb_valid),
        // .wb_data(wb_data)
    );



    // EXECUTE -> WRITEBACK 阶段数据
    typedef struct packed {
        
    } execute_writeback_data_t;

    // EXECUTE -> WRITEBACK 缓冲
    execute_writeback_data_t ew_data_in, ew_data_out;
    wire ew_valid;
    wire ew_ready = 1'b1; // 简化实现，实际可能需要根据下游模块状态确定
    
    stage_buffer #(
        .DATA_WIDTH($bits(execute_writeback_data_t)),
        .STAGE_NAME("EXECUTE_WRITEBACK")
    ) execute_writeback_buffer (
        .clk(clk),
        .reset(reset),
        .enable(ew_enable), // 使用控制逻辑生成的使能
        .flush(1'b0),       // 执行阶段通常不需要刷新
        .data_in(ew_data_in),
        .data_out(ew_data_out),
        .valid_out(ew_valid)
    );



    // WarpScheduler接口信号
    wire warp_cmd_valid, warp_cmd_ready;
    wire [AddrWidth-1:0] warp_cmd_pc;
    wire [ThreadNum-1:0] warp_cmd_mask;
    
    wire warp_ctl_valid, warp_ctl_ready;
    wire [$clog2(WarpNum)-1:0] warp_ctl_wid;
    wire warp_ctl_active;
    
    wire branch_ctl_valid, branch_ctl_ready;
    wire [$clog2(WarpNum)-1:0] branch_ctl_wid;
    wire [AddrWidth+ThreadNum-1:0] branch_ctl_data;
    
    wire end_ctl_valid, end_ctl_ready;
    wire [$clog2(WarpNum)-1:0] end_ctl_wid;

    wire warp_pop_valid, warp_pop_ready;
    wire [$clog2(WarpNum)-1:0] warp_pop_wid;

    wire [2:0] fetcher_state;
    wire [ThreadNum-1:0] lsu_state;

    
    // Fetcher接口信号
    wire inst_fetch_valid, inst_fetch_ready;
    wire [AddrWidth-1:0] inst_fetch_pc;
    wire [ThreadNum-1:0] inst_fetch_mask;
    wire [$clog2(WarpNum)-1:0] inst_fetch_wid;
    wire [InstWidth-1:0] instruction;
    wire fd_out_valid;
    wire fd_out_ready;

    

    // ==================== WarpScheduler实例化 ====================
    WarpScheduler #(
        .WarpNum(WarpNum),
        .ThreadNum(ThreadNum),
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth)
    ) warp_scheduler (
        .clk            (clk),
        .reset          (reset),
        .warp_cmd_valid (warp_cmd_valid),
        .warp_cmd_ready (warp_cmd_ready),
        .warp_cmd_pc    (warp_cmd_pc),
        .warp_cmd_mask  (warp_cmd_mask),

        .warp_ctl_valid (warp_ctl_valid),
        .warp_ctl_ready (warp_ctl_ready),
        .warp_ctl_wid   (warp_ctl_wid),
        .warp_ctl_active(warp_ctl_active),

        .branch_ctl_valid(branch_ctl_valid),
        .branch_ctl_ready(branch_ctl_ready),
        .branch_ctl_wid (branch_ctl_wid),
        .branch_ctl_data(branch_ctl_data),

        .end_ctl_valid  (end_ctl_valid),
        .end_ctl_ready  (end_ctl_ready),
        .end_ctl_wid    (end_ctl_wid),

        .warp_pop_valid (warp_pop_valid),
        .warp_pop_ready (warp_pop_ready),
        .warp_pop_wid   (warp_pop_wid),

        .inst_fetch_valid(inst_fetch_valid),
        .inst_fetch_ready(inst_fetch_ready),
        .inst_fetch_pc  (inst_fetch_pc),
        .inst_fetch_mask(inst_fetch_mask),
        .inst_fetch_wid (inst_fetch_wid),

        .fetcher_state  (fetcher_state),
        .lsu_state      (lsu_state),
        .core_state_out (core_state),

        .idle_id_out    (), // 未使用
        .pop_data_out   (), // 未使用
        .active_id_out  () // 未使用
    );

    // ==================== Fetcher实例化 ====================
    fetcher #(
        .PROGRAM_MEM_ADDR_BITS(AddrWidth),
        .PROGRAM_MEM_DATA_BITS(InstWidth)
    ) inst_fetcher (
        .clk            (clk),
        .reset          (reset),
        .inst_fetch_valid(inst_fetch_valid),
        .inst_fetch_pc  (inst_fetch_pc),
        .inst_fetch_mask(inst_fetch_mask),
        .inst_fetch_wid (inst_fetch_wid),
        .inst_fetch_ready(inst_fetch_ready),
        .mem_read_valid (prog_mem_read_valid),
        .mem_read_address(prog_mem_read_addr),
        .mem_read_ready (prog_mem_read_ready),
        .mem_read_data  (prog_mem_read_data),

        .instruction    (fd_data_in.instruction),
        .mask           (fd_data_in.thread_mask),
        .warp_wid       (fd_data_in.warp_id)

        .fc_out_valid (fc_out_valid),
        .fc_out_ready (fc_out_ready),
        
    );



    // Decoder接口信号
    wire [31:0] branch_ctl_pc;
    wire [31:0] branch_ctl_mask;
    wire branch_ctl_diverge;

    wire alu_valid;
    wire [1:0] alu_op;
    wire alu_cmp_mode;
    wire lsu_valid;
    wire lsu_mem_read_enable;
    wire lsu_mem_write_enable;
    wire pc_valid;
    wire pc_mux;
    wire [7:0] pc_immediate;
    wire [2:0] pc_nzp;
    wire pc_nzp_write_enable;
    wire [3:0] reg_rd_addr;
    wire [3:0] reg_rs_addr;
    wire [3:0] reg_rt_addr;
    wire [7:0] reg_immediate;
    wire [1:0] reg_input_mux;
    wire reg_write_enable;

    wire dc_out_valid;
    wire dc_out_ready;

    // ==================== Decoder实例化 ====================
    decoder #(
        .INSTR_WIDTH(InstWidth)
    ) inst_decoder (
        .clk            (clk),
        .reset          (reset),
        .core_state     (core_state),
        .instruction    (instruction),
        .branch_ctl_valid(branch_ctl_valid),
        .branch_ctl_pc  (branch_ctl_pc),
        .branch_ctl_mask(branch_ctl_mask),
        .branch_ctl_diverge(branch_ctl_diverge),
        .warp_ctl_valid (warp_ctl_valid),
        .warp_ctl_wid   (warp_ctl_wid),
        .warp_ctl_active(warp_ctl_active),
        .end_ctl_valid  (end_ctl_valid),
        .end_ctl_wid    (end_ctl_wid),
        .alu_valid      (alu_valid),
        .alu_op         (alu_op),
        .alu_cmp_mode   (alu_cmp_mode),
        .lsu_valid      (lsu_valid),
        .lsu_mem_read_enable(lsu_mem_read_enable),
        .lsu_mem_write_enable(lsu_mem_write_enable),
        .pc_valid       (pc_valid),
        .pc_mux         (pc_mux),
        .pc_immediate   (pc_immediate),
        .pc_nzp        (pc_nzp),
        .pc_nzp_write_enable(pc_nzp_write_enable),
        .reg_rd_addr    (reg_rd_addr),
        .reg_rs_addr    (reg_rs_addr),
        .reg_rt_addr    (reg_rt_addr),
        .reg_immediate  (reg_immediate),
        .reg_input_mux  (reg_input_mux),
        .reg_write_enable(reg_write_enable)

        .dc_out_valid (dc_out_valid),
        .dc_out_ready (dc_out_ready),
    );

endmodule
