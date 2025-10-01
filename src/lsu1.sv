`default_nettype none
`timescale 1ns/1ns

// 负载存储单元（LSU）
module lsu (
    input wire clk,
    input wire reset,
    input wire enable,

    input wire mem_read_enable,
    input wire mem_write_enable,
    input wire [7:0] rs,
    input wire [7:0] rt,

    output reg mem_read_valid,
    output reg [7:0] mem_read_address,
    input wire mem_read_ready,
    input wire [7:0] mem_read_data,
    output reg mem_write_valid,
    output reg [7:0] mem_write_address,
    output reg [7:0] mem_write_data,
    input wire mem_write_ready,

    output reg [1:0] lsu_state,
    output reg [7:0] lsu_out
);
    localparam IDLE = 2'b00, 
            REQUESTING = 2'b01,
            WAITING = 2'b10, 
            DONE = 2'b11;

    always @(posedge clk) begin
        if (reset) begin
            lsu_state <= IDLE;
            lsu_out <= 0;
            mem_read_valid <= 0;
            mem_read_address <= 0;
            mem_write_valid <= 0;
            mem_write_address <= 0;
            mem_write_data <= 0;
        end else if (enable) begin
            if (mem_read_enable) begin 
                case (lsu_state)
                    IDLE: begin
                        //当gpu要请求数据时？？？
                        lsu_state <= REQUESTING;
                    end
                    REQUESTING: begin 
                        mem_read_valid <= 1;
                        mem_read_address <= rs;
                        lsu_state <= WAITING;
                    end
                    WAITING: begin
                        if (mem_read_ready == 1) begin
                            mem_read_valid <= 0;
                            lsu_out <= mem_read_data;
                            lsu_state <= DONE;
                        end
                    end
                    DONE: begin 
                        //当gpu要求新的操作时，状态机回到IDLE？？？？
                        lsu_state <= IDLE;
                    end
                endcase
            end
            if (mem_write_enable) begin 
                case (lsu_state)
                    IDLE: begin
                        ///?????判断
                        lsu_state <= REQUESTING;
                    end
                    REQUESTING: begin 
                        mem_write_valid <= 1;
                        mem_write_address <= rs;
                        mem_write_data <= rt;
                        lsu_state <= WAITING;
                    end
                    WAITING: begin
                        if (mem_write_ready) begin
                            mem_write_valid <= 0;
                            lsu_state <= DONE;
                        end
                    end
                    DONE: begin 
                        ///??????判断
                        lsu_state <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule