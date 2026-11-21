`timescale 1ns / 1ps
// 심박센서 디지털 출력 -> 박동 펄스 + 박동 간격(ms)
//  - 2FF 동기화 후 상승 엣지를 박동으로 본다
//    (출력 극성이 반대여도 엣지 사이 간격은 같으므로 BPM에는 영향 없음)
//  - 직전 박동 후 REFRACT_MS 안의 엣지는 잡음으로 보고 무시 (300ms = 최대 200BPM)
//  - IDLE_MS 동안 박동이 없으면 idle = 1 (센서 미착용/신호 없음)
module pulse_in #(
    parameter REFRACT_MS = 300,
    parameter IDLE_MS    = 3000
)(
    input  wire        clk,
    input  wire        tick_ms,
    input  wire        sig,
    output wire        level,                  // 동기화된 센서 출력 (LED 확인용)
    output reg         beat        = 1'b0,     // 박동마다 1클럭 펄스
    output reg  [11:0] interval_ms = 12'd0,    // 직전 박동과의 간격
    output wire        idle
);
    reg [2:0]  s   = 3'b000;                   // s[1]: 동기화된 값, s[2]: 1클럭 전 값
    reg [11:0] cnt = 12'hFFF;                  // 직전 박동 후 경과 ms (4095에서 멈춤)

    assign level = s[1];
    assign idle  = (cnt >= IDLE_MS);
    wire   rise  = s[1] & ~s[2];

    always @(posedge clk) begin
        s    <= {s[1:0], sig};
        beat <= 1'b0;
        if (rise && cnt >= REFRACT_MS) begin
            beat        <= 1'b1;
            interval_ms <= cnt;
            cnt         <= 12'd0;
        end else if (tick_ms && cnt != 12'hFFF)
            cnt <= cnt + 1'b1;
    end
endmodule
