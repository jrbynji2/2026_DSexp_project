`timescale 1ns / 1ps
// 16x2 Text LCD (HD44780 호환, 8비트 쓰기 전용)
//  전원 후 50ms 대기 -> 초기화 명령 6개(각 5ms 대기) -> 두 줄 32글자를 계속 다시 씀
//  글자 하나 = RS/DATA 세팅 1us -> E High 1us -> E Low 후 100us 대기 (명령 처리 시간 37us보다 넉넉히)
//  화면을 지우지 않고 덮어쓰므로 깜빡임 없음. 한 번 다 쓰는 데 약 3.5ms
module text_lcd_ctrl #(
    parameter CLK_PER_US = 50              // 50MHz. 시뮬레이션에서 줄여 씀
)(
    input  wire         clk,
    input  wire [127:0] line1,             // ASCII 16글자, [127:120]이 맨 왼쪽
    input  wire [127:0] line2,
    output reg          lcd_e    = 1'b0,
    output reg          lcd_rs   = 1'b0,
    output wire         lcd_rw,
    output reg  [7:0]   lcd_data = 8'h00
);
    assign lcd_rw = 1'b0;                  // 쓰기만 함

    localparam T_PWR  = 50_000 * CLK_PER_US,   // 50ms
               T_INIT = 5_000  * CLK_PER_US,   // 5ms (clear 1.52ms 포함 여유)
               T_CHAR = 100    * CLK_PER_US,   // 100us
               T_1US  = CLK_PER_US;
    localparam P_SETUP = 2'd0, P_HIGH = 2'd1, P_WAIT = 2'd2;

    // 순서: 0~5 초기화, 6 = 1줄 주소, 7~22 = 1줄 글자, 23 = 2줄 주소, 24~39 = 2줄 글자, 다시 6으로
    reg [5:0]  idx = 6'd0;
    reg [1:0]  ph  = P_WAIT;
    reg [21:0] cnt = T_PWR;

    // idx번째 쓰기: {RS, DATA}
    function [8:0] op(input [5:0] i);
        case (i)
            6'd0, 6'd1, 6'd2: op = {1'b0, 8'h38};   // 8비트, 2줄, 5x8
            6'd3:             op = {1'b0, 8'h0C};   // 화면 켬, 커서 끔
            6'd4:             op = {1'b0, 8'h06};   // 쓰면 오른쪽으로
            6'd5:             op = {1'b0, 8'h01};   // 화면 지움
            6'd6:             op = {1'b0, 8'h80};   // 1줄 맨 앞
            6'd23:            op = {1'b0, 8'hC0};   // 2줄 맨 앞
            default:          op = (i < 6'd23) ? {1'b1, line1[(22 - i) * 8 +: 8]}
                                               : {1'b1, line2[(39 - i) * 8 +: 8]};
        endcase
    endfunction

    always @(posedge clk) begin
        if (cnt != 0) cnt <= cnt - 1'b1;
        else case (ph)
            P_WAIT:  begin {lcd_rs, lcd_data} <= op(idx); ph <= P_SETUP; cnt <= T_1US; end
            P_SETUP: begin lcd_e <= 1'b1; ph <= P_HIGH; cnt <= T_1US; end
            P_HIGH:  begin
                lcd_e <= 1'b0;                   // 떨어지는 엣지에서 LCD가 읽음
                ph    <= P_WAIT;
                cnt   <= (idx < 6'd6) ? T_INIT : T_CHAR;
                idx   <= (idx == 6'd39) ? 6'd6 : idx + 1'b1;
            end
            default: ph <= P_WAIT;
        endcase
    end
endmodule
