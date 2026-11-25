`timescale 1ns / 1ps
// 버튼 -> 눌린 순간 1클럭 펄스 (채터링은 보드 회로가 걸러줌)
module btn_pulse #(
    parameter ACTIVE_HIGH = 1      // 안 눌렀는데 동작하면 0으로 바꿈
)(
    input  wire clk,
    input  wire btn,
    output wire pressed,           // 누르고 있는 동안 1
    output wire pulse              // 눌린 순간 1클럭
);
    reg [2:0] s = 3'b000;          // 2FF 동기화 + 1클럭 전 값
    always @(posedge clk) s <= {s[1:0], btn};
    wire now  = ACTIVE_HIGH ? s[1] : ~s[1];
    wire prev = ACTIVE_HIGH ? s[2] : ~s[2];
    assign pressed = now;
    assign pulse   = now & ~prev;
endmodule
