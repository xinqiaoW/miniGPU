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
    // 核心状态
    reg [2:0] core_state;

    localparam IDLE = 3'b000,    // 等待开始
        FETCH = 3'b001,          // 从程序存储器获取指令
        DECODE = 3'b010,         // 将指令解码为控制信号
        REQUEST = 3'b011,        // 从寄存器或内存请求数据
        WAIT = 3'b100,           // 等待内存响应（如果需要）
        EXECUTE = 3'b101,        // 执行ALU和PC计算
        UPDATE = 3'b110,         // 更新寄存器、NZP和PC
        DONE = 3'b111;           // 执行完成
    



    // FETCH -> DECODE 阶段数据
    typedef struct packed {
        logic [31:0] instruction;
        logic [31:0] thread_mask;
        logic [$clog2(WarpNum)-1:0] warp_id;
    } fetch_decode_data_t;

    // DECODE -> EXECUTE 阶段数据  
    typedef struct packed {
        
        // ... 其他控制信号
    } decode_execute_data_t;

    // EXECUTE -> WRITEBACK 阶段数据
    typedef struct packed {
        
    } execute_writeback_data_t;

    // 在core1.sv的模块实例化部分添加：

    // FETCH -> DECODE 缓冲
    fetch_decode_data_t fd_data_in, fd_data_out;
    wire fd_valid;
    wire fd_ready = 1'b1; // 简化实现，实际可能需要根据下游模块状态确定
    
    stage_buffer #(
        .DATA_WIDTH($bits(fetch_decode_data_t)),
        .STAGE_NAME("FETCH_DECODE")
    ) fetch_decode_buffer (
        .clk(clk),
        .reset(reset),
        .enable(fd_enable),           // 使用控制逻辑生成的使能
        .flush(pipeline_flush),       // 使用控制逻辑生成的刷新
        .data_in(fd_data_in),
        .data_out(fd_data_out),
        .valid_out(fd_valid)
    );

    // DECODE -> EXECUTE 缓冲
    decode_execute_data_t de_data_in, de_data_out;
    wire de_valid;
    wire de_ready = 1'b1; // 简化实现，实际可能需要根据下游模块状态确定
    
    stage_buffer #(
        .DATA_WIDTH($bits(decode_execute_data_t)),
        .STAGE_NAME("DECODE_EXECUTE") 
    ) decode_execute_buffer (
        .clk(clk),
        .reset(reset),
        .enable(de_enable), // 使用控制逻辑生成的使能
        .flush(branch_mispredict),
        .data_in(de_data_in),
        .data_out(de_data_out),
        .valid_out(de_valid)
    );

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

    // ==================== 流水线控制逻辑 ====================

    // 1. 数据相关性检测 - 检测RAW（Read After Write）冒险
    wire data_hazard_rs = (de_data_out.reg_rs_addr == ew_data_out.reg_rd_addr) && 
                        ew_data_out.reg_write_enable && de_valid;
    wire data_hazard_rt = (de_data_out.reg_rt_addr == ew_data_out.reg_rd_addr) && 
                        ew_data_out.reg_write_enable && de_valid;
    wire data_hazard = data_hazard_rs || data_hazard_rt;

    // 2. 结构冲突检测
    // 简化实现，假设LSU始终空闲
    wire lsu_busy = 1'b0;
    wire structural_hazard = lsu_busy && de_data_out.lsu_mem_read_enable;

    // 3. 控制冒险（分支预测失败）
    // 简化实现，假设分支预测总是不发生（实际应根据分支预测逻辑确定）
    wire branch_taken = 1'b0;
    wire [AddrWidth-1:0] predicted_pc = 0;
    wire [AddrWidth-1:0] actual_branch_target = 0;
    wire branch_mispredict = branch_taken && (predicted_pc != actual_branch_target);

    // 4. 综合流水线stall信号
    wire pipeline_stall = data_hazard || structural_hazard;

    // 5. 修改缓冲寄存器使能信号
    wire fd_enable = (core_state == FETCH) && !pipeline_stall && fd_ready;
    wire de_enable = (core_state == DECODE) && !pipeline_stall && de_ready;
    wire ew_enable = (core_state == EXECUTE) && !pipeline_stall && ew_ready;

    // 6. 流水线刷新信号
    wire pipeline_flush = branch_mispredict;

    // ==================== 连接到缓冲寄存器 ====================

    // 已在实例化时设置了缓冲寄存器的使能信号和刷新信号



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
        .core_state     (core_state),
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
    );

endmodule
