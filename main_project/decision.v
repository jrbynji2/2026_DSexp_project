`timescale 1ns / 1ps
// 거짓/진실 판정: 질문에 대한 긴장 반응으로 판단 (임시 규칙: log_test 데이터를 보고 TH 값과 규칙을 정할 것)
//  판별 평균 BPM이 기준보다 TH_BPM 이상 높거나,
//  판별 평균 Meditation이 기준보다 TH_MED 이상 낮으면 lie = 1
//  평균 비교는 나눗셈 대신 교차곱:  s_t/n_t - s_b/n_b >= TH  <=>  s_t*n_b >= s_b*n_t + TH*n_b*n_t
module decision #(
    parameter TH_BPM = 5,
    parameter TH_MED = 10
)(
    input  wire        clk,
    input  wire [15:0] b_bpm_sum, input wire [7:0] b_bpm_n,   // 기준 구간
    input  wire [15:0] b_med_sum, input wire [7:0] b_med_n,
    input  wire [15:0] t_bpm_sum, input wire [7:0] t_bpm_n,   // 판별 구간
    input  wire [15:0] t_med_sum, input wire [7:0] t_med_n,
    output reg         lie   = 1'b0,
    output reg         valid = 1'b0        // 비교할 데이터가 있음
);
    wire has_bpm = (b_bpm_n != 0) && (t_bpm_n != 0);
    wire has_med = (b_med_n != 0) && (t_med_n != 0);

    // 32비트 wire에 먼저 담아야 곱셈이 16비트로 잘리지 않음
    wire [31:0] bpm_l  = t_bpm_sum * b_bpm_n;
    wire [31:0] bpm_r  = b_bpm_sum * t_bpm_n;
    wire [31:0] bpm_th = TH_BPM * b_bpm_n * t_bpm_n;
    wire [31:0] med_l  = b_med_sum * t_med_n;      // Meditation은 "떨어졌는지"를 봄
    wire [31:0] med_r  = t_med_sum * b_med_n;
    wire [31:0] med_th = TH_MED * b_med_n * t_med_n;

    always @(posedge clk) begin
        lie   <= (has_bpm && bpm_l >= bpm_r + bpm_th) || (has_med && med_l >= med_r + med_th);
        valid <= has_bpm || has_med;
    end
endmodule
