`timescale 1ns / 1ps
// 뇌파 + 심박 데이터를 노트북으로 기록하는 테스트 top
//  USB-Serial(115200 baud)로 한 줄씩 보냄 -> 노트북에서 eeg_logger.py로 CSV 저장
//  DIP 스위치 8개 = 상황 플래그(모든 줄에 같이 기록, 바꾸면 F 줄), SW_C = 마커 버튼(M 줄)
//  7-Segment: [Attention 3자리] [빈칸 2] [BPM 3자리]
//  LED1: 뇌파 패킷 수신  LED2: 박동  LED3: 전극 접촉 양호(poor=0)  LED4: 마커 버튼 눌림
//  CLOCK SELECT 스위치를 F(50MHz)로 놓고 사용
module log_test_top #(
    parameter CLK_HZ          = 50_000_000,
    parameter CLK_PER_MS      = 50_000,
    parameter BTN_ACTIVE_HIGH = 1           // 안 눌렀는데 LED4가 켜져 있으면 0으로 바꿈
)(
    input  wire       clk,
    input  wire       tgam_tx,     // 뇌파센서 T
    input  wire       hr_sig,      // 심박센서 출력
    output wire       hr_vcc,      // 3.3V 배선일 때 심박센서 VCC (항상 1)
    input  wire [7:0] dip,         // dip[0] = DIPSW1
    input  wire       btn_mark,
    output wire       usb_tx,
    output wire [7:0] seg_com,
    output wire [7:0] seg_data,
    output wire [3:0] led
);
    assign hr_vcc = 1'b1;

    // ---- 시간 ----
    wire tick_ms;
    reg  [31:0] now_ms = 32'd0;
    tick_gen #(.CLK_PER_MS(CLK_PER_MS)) U_TICK (.clk(clk), .tick(tick_ms));
    always @(posedge clk) if (tick_ms) now_ms <= now_ms + 1'b1;

    // ---- 뇌파 ----
    wire [7:0]   rx_data, poor, att, med;
    wire         rx_valid, pkt_ok, pkt_err, new_esense;
    wire [191:0] power;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(57600)) U_RX (
        .clk(clk), .rx(tgam_tx), .data(rx_data), .valid(rx_valid));
    tgam_parser U_PARSE (
        .clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
        .poor_signal(poor), .attention(att), .meditation(med),
        .new_esense(new_esense), .pkt_ok(pkt_ok), .pkt_err(pkt_err), .eeg_power(power));

    // ---- 심박 ----
    wire        level, beat, idle;
    wire [11:0] interval_ms;
    wire [7:0]  bpm;
    pulse_in U_PULSE (.clk(clk), .tick_ms(tick_ms), .sig(hr_sig), .level(level),
                      .beat(beat), .interval_ms(interval_ms), .idle(idle));
    bpm_calc U_BPM (.clk(clk), .beat(beat), .interval_ms(interval_ms), .idle(idle), .bpm(bpm));

    // ---- DIP 플래그: 10ms마다 읽어서 바뀌었으면 F 이벤트 (스위치 떨림 걸러냄) ----
    reg [7:0] dip_m = 8'd0, dip_s = 8'd0, flag = 8'd0;
    reg [3:0] t10 = 4'd0;
    reg       ev_f = 1'b0;
    always @(posedge clk) begin
        dip_m <= dip;
        dip_s <= dip_m;
        ev_f  <= 1'b0;
        if (tick_ms) begin
            if (t10 == 4'd9) begin
                t10 <= 4'd0;
                if (dip_s != flag) begin flag <= dip_s; ev_f <= 1'b1; end
            end else t10 <= t10 + 1'b1;
        end
    end

    // ---- 마커 버튼: 눌린 순간 M 이벤트 ----
    reg [2:0] b_s = 3'b000;
    always @(posedge clk) b_s <= {b_s[1:0], btn_mark};
    wire pressed      = BTN_ACTIVE_HIGH ? b_s[1] : ~b_s[1];
    wire pressed_prev = BTN_ACTIVE_HIGH ? b_s[2] : ~b_s[2];
    wire ev_m         = pressed & ~pressed_prev;

    // ---- 노트북으로 전송 ----
    log_formatter #(.CLK_HZ(CLK_HZ), .BAUD(115200)) U_LOG (
        .clk(clk), .now_ms(now_ms), .flag(flag),
        .ev_e(new_esense), .poor(poor), .att(att), .med(med), .power(power),
        .ev_b(beat), .interval_ms(interval_ms),
        .ev_f(ev_f), .ev_m(ev_m), .tx(usb_tx));

    // ---- LED (짧은 펄스는 100ms 동안 켜 둠) ----
    reg [6:0] hold_pkt = 7'd0, hold_beat = 7'd0;
    always @(posedge clk) begin
        if (pkt_ok) hold_pkt <= 7'd100;
        else if (tick_ms && hold_pkt != 0) hold_pkt <= hold_pkt - 1'b1;
        if (beat) hold_beat <= 7'd100;
        else if (tick_ms && hold_beat != 0) hold_beat <= hold_beat - 1'b1;
    end
    assign led = {pressed, poor == 8'd0, hold_beat != 0, hold_pkt != 0};

    // ---- 7-Segment ----
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
    seg8_driver U_SEG (.clk(clk), .digits({bcd3(att), 8'hFF, bcd3(bpm)}),
                       .seg_com(seg_com), .seg_data(seg_data));
endmodule
