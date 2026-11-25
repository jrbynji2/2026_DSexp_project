`timescale 1ns / 1ps
// 단계별 Full Color LED 색 (TFT 단계 색 막대에도 같은 값 사용)
//  기준 측정 파랑, 판별 측정 노랑, 결과 빨강(거짓)/초록(진실)/흰색(데이터 없음), 나머지 꺼짐
module rgb_led (
    input  wire [2:0] state,
    input  wire       valid,
    input  wire       lie,
    output reg  [2:0] rgb              // {R,G,B}, 1 = 켜짐
);
    always @* case (state)
        3'd2:    rgb = 3'b001;
        3'd4:    rgb = 3'b110;
        3'd5:    rgb = !valid ? 3'b111 : lie ? 3'b100 : 3'b010;
        default: rgb = 3'b000;
    endcase
endmodule
