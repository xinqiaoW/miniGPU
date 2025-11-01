`default_nettype none
`timescale 1ns/1ns

// 支持乱序执行的阶段间缓冲寄存器
module stage_buffer #(
    parameter DATA_WIDTH = 64,      // 数据宽度
    parameter DEPTH = 4,           // 缓冲深度
    parameter STAGE_NAME = "UNKNOWN" // 阶段名称，用于调试
) (
    input  wire clk,
    input  wire reset,

    // 上游接口
    input  wire valid_in,
    output wire ready_in,
    input  wire [DATA_WIDTH-1:0] data_in,
    
    // 下游接口  
    output wire valid_out,
    input  wire ready_out,
    output wire [DATA_WIDTH-1:0] data_out,

    // 新增：依赖检测接口（向后兼容，可选连接）
    input  wire [3:0] reg_rd_addr_in = 4'b0,     // 目标寄存器地址
    input  wire [3:0] reg_rs_addr_in = 4'b0,     // 源寄存器1地址  
    input  wire [3:0] reg_rt_addr_in = 4'b0,     // 源寄存器2地址
    input  wire reg_write_enable_in = 1'b0,      // 写使能

    // // 新增：写回反馈（向后兼容，可选连接）
    // input  wire [3:0] wb_reg_rd_addr = 4'b0,     // 写回的目标寄存器
    // input  wire wb_reg_write_enable = 1'b0,      // 写回使能
    // input  wire wb_valid = 1'b0,                 // 写回有效
    // input  wire [DATA_WIDTH-1:0] wb_data = '0    // 写回数据
);

    // 简单乱序执行支持：基于寄存器依赖性的指令选择
    reg [DATA_WIDTH-1:0] buffer [0:DEPTH-1];
    reg [DEPTH-1:0] valid_bits;


    reg [3:0] buffer_rd_addr [0:DEPTH-1];  // 存储每条指令的目标寄存器
    reg [3:0] buffer_rs_addr [0:DEPTH-1];  // 存储每条指令的源寄存器1
    reg [3:0] buffer_rt_addr [0:DEPTH-1];  // 存储每条指令的源寄存器2
    reg [DEPTH-1:0] buffer_write_en;       // 存储每条指令的写使能
    
    wire fifo_full = &valid_bits;
    wire fifo_empty = ~|valid_bits;
    
    // 乱序发射逻辑：选择没有数据依赖的指令
    wire [DEPTH-1:0] can_issue;
    wire [$clog2(DEPTH)-1:0] issue_idx;
    wire issue_found;
    
    generate
        for (genvar i = 0; i < DEPTH; i++) begin : issue_logic
            // 检查RAW数据冒险：当前指令的源寄存器是否被前面指令的目标寄存器占用
            wire rs_dep, rt_dep;
            assign rs_dep = |(valid_bits & buffer_write_en & 
                            (buffer_rd_addr[i] == buffer_rs_addr[i]) & 
                            (i != '0)); // 简化：只检查前面的指令
            
            assign rt_dep = |(valid_bits & buffer_write_en & 
                            (buffer_rd_addr[i] == buffer_rt_addr[i]) & 
                            (i != '0));
            
            // 可以发射的条件：指令有效且没有数据依赖
            assign can_issue[i] = valid_bits[i] && !rs_dep && !rt_dep;
        end
    endgenerate
    
    // 优先级编码器：选择第一个可以发射的指令
    always_comb begin
        issue_found = 1'b0;
        issue_idx = '0;
        for (int i = 0; i < DEPTH; i++) begin
            if (can_issue[i] && !issue_found) begin
                issue_found = 1'b1;
                issue_idx = i;
            end
        end
        // 如果没有可以乱序发射的指令，回退到FIFO顺序
        if (!issue_found && valid_bits[0]) begin
            issue_found = 1'b1;
            issue_idx = 0;
        end
    end
    
    assign ready_in = !fifo_full;
    assign valid_out = issue_found;
    assign data_out = buffer[issue_idx];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_bits <= {DEPTH{1'b0}};
        end else begin
            // 下游取走数据
            if (ready_out && valid_out) begin
                valid_bits[issue_idx] <= 1'b0;
            end
            
            // 上游写入数据
            if (valid_in && ready_in) begin
                // 找到第一个空位
                for (int i = 0; i < DEPTH; i++) begin
                    if (!valid_bits[i]) begin
                        buffer[i] <= data_in;
                        buffer_rd_addr[i] <= reg_rd_addr_in;
                        buffer_rs_addr[i] <= reg_rs_addr_in; 
                        buffer_rt_addr[i] <= reg_rt_addr_in;
                        buffer_write_en[i] <= reg_write_enable_in;
                        valid_bits[i] <= 1'b1;
                        break;
                    end
                end
            end
        end
    end

endmodule