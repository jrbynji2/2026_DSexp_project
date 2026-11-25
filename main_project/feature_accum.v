`timescale 1ns / 1ps
// 측정 구간 동안 BPM, Meditation 값의 합과 개수를 모음 (평균 = 합/개수, 나눗셈은 decision에서 교차곱으로 피함)
// 기준 구간용, 판별 구간용으로 하나씩 둔다
module feature_accum (
    input  wire        clk,
    input  wire        clear,              // 1클럭: 모두 0으로
    input  wire        en,                 // 측정 중일 때 1
    input  wire        bpm_new,            // 새 BPM 펄스
    input  wire [7:0]  bpm,
    input  wire        med_new,            // 새 Meditation 펄스 (전극 접촉 양호일 때만)
    input  wire [7:0]  med,
    output reg  [15:0] bpm_sum = 16'd0,
    output reg  [7:0]  bpm_n   = 8'd0,
    output reg  [15:0] med_sum = 16'd0,
    output reg  [7:0]  med_n   = 8'd0
);
    always @(posedge clk) begin
        if (clear) begin
            bpm_sum <= 16'd0; bpm_n <= 8'd0;
            med_sum <= 16'd0; med_n <= 8'd0;
        end else if (en) begin
            if (bpm_new && bpm != 8'd0) begin bpm_sum <= bpm_sum + bpm; bpm_n <= bpm_n + 1'b1; end
            if (med_new && med != 8'd0) begin med_sum <= med_sum + med; med_n <= med_n + 1'b1; end  // 0 = 계산 불가
        end
    end
endmodule
