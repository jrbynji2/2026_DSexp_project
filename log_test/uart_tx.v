`timescale 1ns / 1ps
// UART 송신기 (8N1). ready = 1일 때 start를 1클럭 주면 data 1바이트를 보냄
module uart_tx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx    = 1'b1,     // idle = High
    output wire       ready
);
    localparam DIV = CLK_HZ / BAUD;     // 50MHz / 115200 = 434

    reg        busy    = 1'b0;
    reg [15:0] cnt     = 16'd0;
    reg [3:0]  bit_idx = 4'd0;
    reg [9:0]  frame   = 10'h3FF;       // {stop, data[7:0], start}

    assign ready = ~busy;

    always @(posedge clk) begin
        if (!busy) begin
            if (start) begin
                frame   <= {1'b1, data, 1'b0};
                tx      <= 1'b0;        // start 비트
                busy    <= 1'b1;
                cnt     <= DIV - 1;
                bit_idx <= 4'd0;
            end
        end else if (cnt == 0) begin
            if (bit_idx == 4'd9) begin  // stop 비트까지 끝
                busy <= 1'b0;
                tx   <= 1'b1;
            end else begin
                bit_idx <= bit_idx + 1'b1;
                tx      <= frame[bit_idx + 1'b1];
                cnt     <= DIV - 1;
            end
        end else
            cnt <= cnt - 1'b1;
    end
endmodule
