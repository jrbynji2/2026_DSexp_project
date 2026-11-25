`timescale 1ns / 1ps
// 심박센서 동작 확인용 top (5V 배선, 3.3V 배선 공통)
//  7-Segment: [BPM 3자리] [빈칸] [박동 간격 ms 4자리]
//  LED1: 센서 출력 그대로   LED2: 박동으로 인정된 순간 (100ms 켜짐)   LED3: 3초 넘게 박동 없음
//  hr_vcc: 3.3V 배선일 때 센서 VCC로 쓰는 핀 (항상 1). 5V 배선이면 연결하지 않음
//  CLOCK SELECT 스위치를 F(50MHz)로 놓고 사용
module hr_test_top (
    input  wire       clk,
    input  wire       hr_sig,
    output wire       hr_vcc,
    output wire [7:0] seg_com,
    output wire [7:0] seg_data,
    output wire [2:0] led
);
    assign hr_vcc = 1'b1;

    wire        tick_ms, level, beat, idle;
    wire [11:0] interval_ms;
    wire [7:0]  bpm;

    tick_gen #(.CLK_PER_MS(50_000)) U_TICK (.clk(clk), .tick(tick_ms));
    pulse_in U_PULSE (.clk(clk), .tick_ms(tick_ms), .sig(hr_sig), .level(level),
                      .beat(beat), .interval_ms(interval_ms), .idle(idle));
    bpm_calc U_BPM (.clk(clk), .beat(beat), .interval_ms(interval_ms), .idle(idle), .bpm(bpm));

    // 박동 LED를 100ms 동안 켜 둠
    reg [6:0] hold = 7'd0;
    always @(posedge clk) begin
        if (beat) hold <= 7'd100;
        else if (tick_ms && hold != 0) hold <= hold - 1'b1;
    end
    assign led = {idle, hold != 0, level};

    // 2진수 -> BCD (double dabble)
    function [11:0] bcd3(input [7:0] v);
        integer i; reg [19:0] t;
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
    function [15:0] bcd4(input [11:0] v);
        integer i; reg [27:0] t;
        begin
            t = {16'd0, v};
            for (i = 0; i < 12; i = i + 1) begin
                if (t[15:12] >= 4'd5) t[15:12] = t[15:12] + 4'd3;
                if (t[19:16] >= 4'd5) t[19:16] = t[19:16] + 4'd3;
                if (t[23:20] >= 4'd5) t[23:20] = t[23:20] + 4'd3;
                if (t[27:24] >= 4'd5) t[27:24] = t[27:24] + 4'd3;
                t = t << 1;
            end
            bcd4 = t[27:12];
        end
    endfunction

    seg8_driver U_SEG (.clk(clk), .digits({bcd3(bpm), 4'hF, bcd4(interval_ms)}),
                       .seg_com(seg_com), .seg_data(seg_data));
endmodule
