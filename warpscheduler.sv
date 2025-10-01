`default_nettype none
`timescale 1ns/1ps

module WarpScheduler #(
    parameter WarpNum     = 8,      
    parameter ThreadNum   = 32,     
    parameter AddrWidth   = 32,    
    parameter DataWidth   = 32      
) (
    input  wire clk,                // clock
    input  wire reset,              // reset signal
    
    // Warp command
    input  wire warp_cmd_valid,     
    output wire warp_cmd_ready,     
    input  wire [AddrWidth-1:0] warp_cmd_pc,   
    input  wire [ThreadNum-1:0] warp_cmd_mask,  
    
    // warp control signal
    input  wire warp_ctl_valid,     
    output wire warp_ctl_ready,     
    input  wire [$clog2(WarpNum)-1:0] warp_ctl_wid,  // Warp ID
    input  wire warp_ctl_active,    
    //////////////////////////////////////////////////////////////////////
    input  wire branch_ctl_valid,   
    output wire branch_ctl_ready,   
    input  wire [$clog2(WarpNum)-1:0] branch_ctl_wid,  // Warp ID
    input  wire [AddrWidth + ThreadNum - 1:0] branch_ctl_data,
    
    // end control
    input  wire end_ctl_valid,     
    output wire end_ctl_ready,     
    input  wire [$clog2(WarpNum)-1:0] end_ctl_wid,  // Warp ID
    // pop control
    input  wire warp_pop_valid,                      
    input  wire [$clog2(WarpNum)-1:0] warp_pop_wid,  

    
    output wire inst_fetch_valid,   
    input  wire inst_fetch_ready,   
    output wire [AddrWidth-1:0] inst_fetch_pc,  // PC Register
    output wire [ThreadNum-1:0] inst_fetch_mask,// Thread Mask
    output wire [$clog2(WarpNum)-1:0] inst_fetch_wid,  // Warp ID
    
    //////////////////////////////////////////////////////////////
    // output for simulation
    output reg [(WarpNum)-1:0] idle_id_out,
    output reg [(WarpNum)-1:0] active_id_out,
    output wire [AddrWidth + ThreadNum - 1:0] pop_data_out
    //////////////////////////////////////////////////////////////
);

    reg [WarpNum-1:0] warp_idle;        // 1-idle
    reg [WarpNum-1:0] warp_active;     // 1-active
    reg [AddrWidth-1:0] warp_pc [0:WarpNum-1];         
    reg [ThreadNum-1:0] warp_tmask [0:WarpNum-1];      
    
    wire has_idle;                      
    wire has_active;                   
    wire [$clog2(WarpNum)-1:0] idle_id; 
    wire [$clog2(WarpNum)-1:0] active_id;
    
    
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
                // branch?
                .in_data(branch_ctl_data),
                // push
                .push(branch_ctl_valid && (branch_ctl_wid == i)),
                // pop 
                .pop(warp_pop_valid && (warp_pop_wid == i)),
                // output data
                .out_data(simt_stack_out_data[i])
            );
        end
    endgenerate
    
    //SIMTStack output
    wire [AddrWidth + ThreadNum - 1:0] simt_stack_out_data [0:WarpNum-1];
   
    PriorityEncoder #(
        .WIDTH(WarpNum)
    ) idle_encoder (
        .in(warp_idle),
        .out(idle_id),
        .valid() 
    );
    
    PriorityEncoder #(
        .WIDTH(WarpNum)
    ) active_encoder (
        .in(warp_active),
        .out(active_id),
        .valid() 
    );
    
    assign active_id_out = warp_active;
    assign idle_id_out = warp_idle;
    assign pop_data_out = simt_stack_out_data[warp_pop_wid];
    
    assign has_idle = |warp_idle;
    assign has_active = |warp_active;
    
    // signal
    assign warp_cmd_ready = has_idle;  
    assign warp_ctl_ready = 1'b1;       
    assign branch_ctl_ready = 1'b1;    
    assign end_ctl_ready = 1'b1;        

    // instruction fetched signal
    assign inst_fetch_valid = has_active;
    assign inst_fetch_pc = has_active ? warp_pc[active_id] : {AddrWidth{1'b0}};
    assign inst_fetch_mask = has_active ? warp_tmask[active_id] : {ThreadNum{1'b0}};
    assign inst_fetch_wid = has_active ? active_id : {$clog2(WarpNum){1'b0}};
    
    always @(posedge clk or posedge reset) begin
        integer w, t;
        if (reset) begin
            // 复位初始化
            warp_idle <= {WarpNum{1'b1}};      
            warp_active <= {WarpNum{1'b0}};    
            
            // initialization
            for (w = 0; w < WarpNum; w = w + 1) begin
                warp_pc[w] <= {AddrWidth{1'b0}};
                for (t = 0; t < ThreadNum; t = t + 1) begin
                    warp_tmask[w][t] <= 1'b0;
                end
            end
            
        end else begin
            
            // Assign Warp 
            if (warp_cmd_valid && warp_cmd_ready) begin
                warp_idle[idle_id] <= 1'b0;            
                warp_active[idle_id] <= 1'b1;          
                warp_pc[idle_id] <= warp_cmd_pc;       // set start pc
                warp_tmask[idle_id] <= warp_cmd_mask;  // set thread mask
            end
            
            // End
            if (end_ctl_valid && end_ctl_ready) begin
                warp_idle[end_ctl_wid] <= 1'b1;        
            end
            
            // ReActive a certain warp
            if (warp_ctl_valid && warp_ctl_ready) begin
                warp_active[warp_ctl_wid] <= warp_ctl_active;
            end
    
            
            // SIMTStack pop
            if (warp_pop_valid) begin
                warp_pc[warp_pop_wid] <= simt_stack_out_data[warp_pop_wid][AddrWidth-1:0]; 
                warp_tmask[warp_pop_wid] <= simt_stack_out_data[warp_pop_wid][AddrWidth + ThreadNum - 1:AddrWidth];
            end
            
            // instruction fetched
            if (inst_fetch_valid && inst_fetch_ready) begin
                warp_active[active_id] <= 1'b0;       
                warp_pc[active_id] <= warp_pc[active_id] + 4; // PC <- PC + 4
            end
        end
    end

endmodule

// ====================Naive Priority Encoder ====================
module PriorityEncoder #(
    parameter WIDTH = 8
) (
    input wire [WIDTH-1:0] in,          
    output reg [$clog2(WIDTH)-1:0] out, 
    output wire valid                   
);
    
    assign valid = |in;

    always @(*) begin
        out = {$clog2(WIDTH){1'b0}};   
        for (integer i = 0; i < WIDTH; i = i + 1) begin
            if (in[i]) begin
                out = i;               
            end
        end
    end
    
endmodule

// ==================== SIMTStack ====================
module SIMTStack #(
    parameter DataWidth = 32,
    parameter AddrWidth = 32,
    parameter ThreadNum = 32,
    parameter DEPTH = 8
) (
    input wire clk,
    input wire reset,
    input wire [AddrWidth + ThreadNum - 1:0] in_data,         // 压入栈的是指令地址
    input wire push,
    input wire pop,
    output wire [AddrWidth + ThreadNum - 1:0] out_data
);
    integer sp;
    
    reg [AddrWidth + ThreadNum - 1:0] stack_mem [0:DEPTH-1];
    
    assign out_data = stack_mem[(sp > 0) ? (sp - 1) : 0];
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sp <= 0;
        end else begin
            if (push) begin
                stack_mem[sp] <= in_data;
                sp <= sp + 1;
            end else if (pop && sp > 0) begin
                sp <= sp - 1;
            end
        end
    end

endmodule
