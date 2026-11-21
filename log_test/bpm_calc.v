`timescale 1ns / 1ps
// BPM = 60000 / 박동 간격(ms)
// 반복 뺄셈 나눗셈: 몫이 최대 200이라 200클럭(4us) 안에 끝남. 박동은 1초에 3번 이하라 충분
module bpm_calc #(
    parameter IDLE_MS = 3000
)(
    input  wire        clk,
    input  wire        beat,
    input  wire [11:0] interval_ms,
    input  wire        idle,
    output reg  [7:0]  bpm = 8'd0          // 0 = 측정값 없음
);
    reg [16:0] rem  = 17'd0;
    reg [11:0] d    = 12'd0;
    reg [7:0]  q    = 8'd0;
    reg        busy = 1'b0;

    always @(posedge clk) begin
        if (idle) begin
            bpm  <= 8'd0;
            busy <= 1'b0;
        end else if (beat) begin
            if (interval_ms >= IDLE_MS) bpm <= 8'd0;   // 쉬었다가 온 첫 박동: 간격을 모름
            else begin
                rem  <= 17'd60000;
                d    <= interval_ms;
                q    <= 8'd0;
                busy <= 1'b1;
            end
        end else if (busy) begin
            if (rem >= d) begin rem <= rem - d; q <= q + 1'b1; end
            else begin bpm <= q; busy <= 1'b0; end
        end
    end
endmodule
