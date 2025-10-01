`default_nettype none
`timescale 1ns/1ns

// 指令译码器（Decoder）
// 解析fetcher取出的指令，产生控制信号，必要时反馈给WarpScheduler和执行单元
module decoder #(
    parameter INSTR_WIDTH = 32
) (
    input  wire clk,
    input  wire reset,

    // 来自fetcher的接口
    input  wire         fetcher_valid,         // 取指完成信号
    input  wire [INSTR_WIDTH-1:0] instruction, // 取出的指令

    // 反馈给WarpScheduler的接口
    output reg          branch_ctl_valid,      // 分支控制有效
    output reg  [31:0]  branch_ctl_pc,         // 分支目标地址
    output reg  [31:0]  branch_ctl_mask,       // 分支掩码
    output reg          branch_ctl_diverge,    // 分支是否分歧

    output reg          warp_ctl_valid,        // warp控制有效
    output reg  [2:0]   warp_ctl_wid,          // warp id
    output reg          warp_ctl_active,       // warp活跃控制

    output reg          end_ctl_valid,         // 结束控制有效
    output reg  [2:0]   end_ctl_wid,           // 结束warp id

    // 交给后续执行单元的接口
    output reg          alu_valid,             // ALU操作有效
    output reg  [1:0]   alu_op,                // ALU操作类型
    output reg          alu_cmp_mode,          // ALU比较模式


    output reg          lsu_valid,             // LSU操作有效
    output reg          lsu_mem_read_enable,
    output reg          lsu_mem_write_enable,

    output reg          pc_valid,              // PC操作有效
    output reg          pc_mux,                // PC选择信号

    output reg  [7:0]   pc_immediate,
    output reg  [2:0]   pc_nzp,

    output reg          pc_nzp_write_enable,


    output reg  [3:0]   reg_rd_addr,
    output reg  [3:0]   reg_rs_addr,
    output reg  [3:0]   reg_rt_addr,
    output reg  [7:0]   reg_immediate,
    output reg  [1:0]   reg_input_mux,
    output reg          reg_write_enable
);
    

    // 指令类型定义（举例，需根据你的ISA实际扩展）
    localparam [3:0]
        NOP    = 4'b0000,
        BRnzp  = 4'b0001,
        CMP    = 4'b0010,
        ADD    = 4'b0011,
        SUB    = 4'b0100,
        MUL    = 4'b0101,
        DIV    = 4'b0110,
        LDR    = 4'b0111,
        STR    = 4'b1000,
        CONST  = 4'b1001,
        RET    = 4'b1111;

    wire [3:0] opcode = instruction[31:28]; // 假设高4位为操作码

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // WarpScheduler接口
            branch_ctl_valid  <= 0;
            branch_ctl_pc     <= 0;
            branch_ctl_mask   <= 0;
            branch_ctl_diverge<= 0;
            warp_ctl_valid    <= 0;
            warp_ctl_wid      <= 0;
            warp_ctl_active   <= 0;
            warp_ctl_join     <= 0;
            end_ctl_valid     <= 0;
            end_ctl_wid       <= 0;
            // 执行单元接口
            alu_valid         <= 0;
            reg_rd_addr       <= 0;
            reg_rs_addr       <= 0;
            reg_rt_addr       <= 0;
            alu_op            <= 0;
            alu_cmp_mode      <= 0;
            lsu_valid         <= 0;
            lsu_mem_read_enable  <= 0;
            lsu_mem_write_enable <= 0;
            pc_valid          <= 0;
            pc_mux            <= 0;
            pc_immediate      <= 0;
            pc_nzp            <= 0;
            pc_nzp_write_enable <= 0;
        end else begin
            // 默认清零
            branch_ctl_valid  <= 0;
            warp_ctl_valid    <= 0;
            end_ctl_valid     <= 0;
            alu_valid         <= 0;
            lsu_valid         <= 0;
            pc_valid          <= 0;

            if (fetcher_valid) begin

                reg_rd_addr <= instruction[11:8];
                reg_rs_addr <= instruction[7:4];
                reg_rt_addr <= instruction[3:0];
                pc_immediate <= instruction[7:0];
                pc_nzp <= instruction[11:9];
                reg_immediate <= pc_immediate;

                case (opcode)
                    NOP: begin
                        // 空操作
                    end
                    BRnzp: begin
                        // 分支指令？？如何确定掩码
                        branch_ctl_valid   <= 1;
                        branch_ctl_pc      <= instruction[27:0]; // 目标地址
                        branch_ctl_mask    <= 32'hFFFFFFFF;      // 示例
                        branch_ctl_diverge <= 1;                 // 示例
                        pc_valid           <= 1;
                        pc_mux             <= 1;
                        pc_immediate       <= instruction[7:0];
                        pc_nzp             <= instruction[11:9];
                    end
                    CMP: begin
                        alu_valid          <= 1;
                        alu_cmp_mode       <= 1;
                        alu_rs_addr        <= instruction[7:4];
                        alu_rt_addr        <= instruction[3:0];
                        pc_valid           <= 1;
                        pc_nzp_write_enable<= 1;
                    end
                    ADD, SUB, MUL, DIV: begin
                        alu_valid          <= 1;
                        alu_op             <= opcode - ADD; // 00:ADD, 01:SUB, 10:MUL, 11:DIV
                        alu_rd_addr        <= instruction[11:8];
                        alu_rs_addr        <= instruction[7:4];
                        alu_rt_addr        <= instruction[3:0];
                    end
                    LDR: begin
                        lsu_valid          <= 1;
                        lsu_mem_read_enable<= 1;
                        alu_rd_addr        <= instruction[11:8];
                    end
                    STR: begin
                        lsu_valid             <= 1;
                        lsu_mem_write_enable  <= 1;
                    end
                    CONST: begin
                        alu_valid          <= 1;
                        alu_rd_addr        <= instruction[11:8];
                    end
                    RET: begin
                        // 结束warp指令
                        end_ctl_valid      <= 1;
                        end_ctl_wid        <= instruction[7:5];
                    end
                    default: begin
                        // 其它指令可扩展
                    end
                endcase
            end
        end
    end

endmodule