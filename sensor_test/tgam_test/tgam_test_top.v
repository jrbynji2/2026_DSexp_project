`timescale 1ns / 1ps
// TGAM1 동작 확인용 top
//  7-Segment: [Attention 3자리] [빈칸 2] [Meditation 3자리]
//  LED1: UART 바이트 수신 중   LED2: 정상 패킷 수신 중   LED3: 체크섬 오류 발생
//  LED4: 신호 양호(poor=0)     LED5: 전극 미접촉(poor=200)
//  CLOCK SELECT 스위치를 F(50MHz)로 놓고 사용
module tgam_test_top (
    input  wire       clk,       // MAIN_CLOCK (B6)
    input  wire       tgam_tx,   // TGAM T핀 -> Exp. Port
    output reg  [7:0] seg_com  = 8'hFF,
    output reg  [7:0] seg_data = 8'h00,
    output wire [4:0] led
);
    wire [7:0] rx_data, poor, att, med;
    wire       rx_valid, pkt_ok, pkt_err, new_esense;

    uart_rx #(.CLK_HZ(50_000_000), .BAUD(57600)) U_RX (
        .clk(clk), .rx(tgam_tx), .data(rx_data), .valid(rx_valid));

    tgam_parser U_PARSE (
        .clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
        .poor_signal(poor), .attention(att), .meditation(med),
        .new_esense(new_esense), .pkt_ok(pkt_ok), .pkt_err(pkt_err));

    // 짧은 펄스를 LED로 보이게 늘림 (2^22 / 50MHz = 약 84ms)
    reg [21:0] hold_rx = 0, hold_ok = 0, hold_err = 0;
    always @(posedge clk) begin
        hold_rx  <= rx_valid ? {22{1'b1}} : (hold_rx  != 0 ? hold_rx  - 1'b1 : 22'd0);
        hold_ok  <= pkt_ok   ? {22{1'b1}} : (hold_ok  != 0 ? hold_ok  - 1'b1 : 22'd0);
        hold_err <= pkt_err  ? {22{1'b1}} : (hold_err != 0 ? hold_err - 1'b1 : 22'd0);
    end
    assign led = {poor == 8'd200, poor == 8'd0, hold_err != 0, hold_ok != 0, hold_rx != 0};

    // 2진수 -> BCD 3자리 (double dabble)
    function [11:0] bcd3(input [7:0] v);
        integer i;
        reg [19:0] t;
        begin
            t = {12'd0, v};
            for (i = 0; i < 8; i = i + 1) begin
                if (t[11:8]  >= 4'd5) t[11:8]  = t[11:8]  + 4'd3;
                if (t[15:12] >= 4'd5) t[15:12] = t[15:12] + 4'd3;
                if (t[19:16] >= 4'd5) t[19:16] = t[19:16] + 4'd3;
                t = t << 1;
            end
            bcd3 = t[19:8];
        end
    endfunction
    wire [11:0] att_bcd = bcd3(att);
    wire [11:0] med_bcd = bcd3(med);

    // seg = {A,B,C,D,E,F,G,DP}, 5주차 bcd2seg와 같은 인코딩
    function [7:0] seg7(input [3:0] d);
        case (d)
            4'd0: seg7 = 8'b1111_1100;  4'd1: seg7 = 8'b0110_0000;
            4'd2: seg7 = 8'b1101_1010;  4'd3: seg7 = 8'b1111_0010;
            4'd4: seg7 = 8'b0110_0110;  4'd5: seg7 = 8'b1011_0110;
            4'd6: seg7 = 8'b1011_1110;  4'd7: seg7 = 8'b1110_0000;
            4'd8: seg7 = 8'b1111_1110;  4'd9: seg7 = 8'b1111_0110;
            default: seg7 = 8'b0000_0000;   // 빈칸
        endcase
    endfunction

    // 50MHz에서 한 자리당 2^13 클럭(약 164us) -> 8자리 한 바퀴 약 1.3ms
    reg [15:0] scan = 0;
    always @(posedge clk) begin
        scan <= scan + 1'b1;
        case (scan[15:13])
            3'd0: begin seg_com <= 8'b0111_1111; seg_data <= seg7(att_bcd[11:8]); end
            3'd1: begin seg_com <= 8'b1011_1111; seg_data <= seg7(att_bcd[7:4]);  end
            3'd2: begin seg_com <= 8'b1101_1111; seg_data <= seg7(att_bcd[3:0]);  end
            3'd3: begin seg_com <= 8'b1110_1111; seg_data <= 8'b0000_0000;        end
            3'd4: begin seg_com <= 8'b1111_0111; seg_data <= 8'b0000_0000;        end
            3'd5: begin seg_com <= 8'b1111_1011; seg_data <= seg7(med_bcd[11:8]); end
            3'd6: begin seg_com <= 8'b1111_1101; seg_data <= seg7(med_bcd[7:4]);  end
            3'd7: begin seg_com <= 8'b1111_1110; seg_data <= seg7(med_bcd[3:0]);  end
        endcase
    end
endmodule
