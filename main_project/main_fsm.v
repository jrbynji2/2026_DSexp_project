`timescale 1ns / 1ps
// 진행 단계 FSM
//  ① WAIT     : 센서 연결 대기. 센서가 정상일 때 START -> ②
//  ② BASE_RDY : 참 질문 준비. START -> ③
//  ③ BASE     : 기준 측정 MEAS_SEC초 -> ④
//  ④ TEST_RDY : 판별 질문 준비. START -> ⑤
//  ⑤ TEST     : 판별 측정 MEAS_SEC초 -> ⑥
//  ⑥ RESULT   : 결과 표시. START -> ④ (같은 기준으로 다음 질문)
//  RESET은 어느 단계에서든 ①로
module main_fsm #(
    parameter MEAS_SEC   = 10,
    parameter MS_PER_SEC = 1000            // 시뮬레이션에서 줄여 씀
)(
    input  wire       clk,
    input  wire       tick_ms,
    input  wire       start,               // 펄스
    input  wire       reset,               // 펄스
    input  wire       sensor_ok,
    output reg  [2:0] state    = 3'd0,
    output reg  [3:0] sec_left = 4'd0,     // 측정 중 남은 초
    output reg        clear    = 1'b0,     // 측정 시작 순간 1클럭 (그 구간 누적값 지움)
    output reg        done     = 1'b0      // 판별 측정이 끝난 순간 1클럭
);
    localparam S_WAIT = 3'd0, S_BASE_RDY = 3'd1, S_BASE = 3'd2,
               S_TEST_RDY = 3'd3, S_TEST = 3'd4, S_RESULT = 3'd5;

    reg [9:0] ms = 10'd0;

    always @(posedge clk) begin
        clear <= 1'b0;
        done  <= 1'b0;
        if (reset) begin
            state    <= S_WAIT;
            sec_left <= 4'd0;
        end else case (state)
            S_WAIT:     if (start && sensor_ok) state <= S_BASE_RDY;
            S_BASE_RDY: if (start) begin state <= S_BASE; clear <= 1'b1; sec_left <= MEAS_SEC; ms <= 10'd0; end
            S_TEST_RDY: if (start) begin state <= S_TEST; clear <= 1'b1; sec_left <= MEAS_SEC; ms <= 10'd0; end
            S_BASE, S_TEST:
                if (tick_ms) begin
                    if (ms == MS_PER_SEC - 1) begin
                        ms <= 10'd0;
                        sec_left <= sec_left - 1'b1;
                        if (sec_left == 4'd1) begin
                            if (state == S_BASE) state <= S_TEST_RDY;
                            else begin state <= S_RESULT; done <= 1'b1; end
                        end
                    end else ms <= ms + 1'b1;
                end
            S_RESULT:   if (start) state <= S_TEST_RDY;
            default:    state <= S_WAIT;
        endcase
    end
endmodule
