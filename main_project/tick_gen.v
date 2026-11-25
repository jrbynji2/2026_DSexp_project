`timescale 1ns / 1ps
// 1ms마다 1클럭 펄스 (50MHz 기준 50,000클럭)
module tick_gen #(
    parameter CLK_PER_MS = 50_000
)(
    input  wire clk,
    output reg  tick_ms = 1'b0
);
    reg [15:0] cnt = 16'd0;
    always @(posedge clk) begin
        tick_ms <= 1'b0;
        if (cnt == CLK_PER_MS - 1) begin cnt <= 16'd0; tick_ms <= 1'b1; end
        else cnt <= cnt + 1'b1;
    end
endmodule
