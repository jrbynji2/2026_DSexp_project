`timescale 1ns / 1ps
// 진동모터 동작 확인용 top: 버튼을 누르는 동안 진동, LED1도 같이 켜짐
// 보드 버튼은 채터링 방지 회로가 내장되어 있어 그대로 연결
// 누르지 않았는데 진동하면 버튼이 눌렀을 때 Low인 것이므로 ~btn으로 바꾼다
module motor_test_top (
    input  wire btn,
    output wire motor,
    output wire led
);
    assign motor = btn;
    assign led   = btn;
endmodule
