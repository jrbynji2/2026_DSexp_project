`timescale 1ns / 1ps
// 생체신호 거짓말탐지기 최종 top
//  SW_A = 처음으로, SW_B = START. 단계는 main_fsm 참고
//  7-Segment: [Attention 3자리] [측정 중 남은 초 2자리] [BPM 3자리]
//  LED1 뇌파 패킷 수신 / LED2 박동 / LED3 전극 접촉 양호 / LED4 심박 측정 중 / LED5 START 버튼 눌림
//  Full Color LED: 기준 측정 파랑, 판별 측정 노랑, 결과 빨강(거짓)/초록(진실)/흰색(데이터 없음)
//  CLOCK SELECT 스위치 F(50MHz) 전제
module main_top #(
    parameter CLK_HZ          = 50_000_000,
    parameter CLK_PER_MS      = 50_000,
    parameter CLK_PER_US      = 50,
    parameter MS_PER_SEC      = 1000,
    parameter MEAS_SEC        = 10,
    parameter BTN_ACTIVE_HIGH = 1,
    parameter TH_BPM          = 5,
    parameter TH_MED          = 10
)(
    input  wire       clk,
    input  wire       tgam_tx,
    input  wire       hr_sig,
    output wire       hr_vcc,
    input  wire       btn_reset,         // SW_A
    input  wire       btn_start,         // SW_B
    output wire [4:0] led,
    output wire       rgb_r, rgb_g, rgb_b,
    output wire       motor,
    output wire       piezo,
    output wire [7:0] seg_com,
    output wire [7:0] seg_data,
    output wire       lcd_e, lcd_rs, lcd_rw,
    output wire [7:0] lcd_data,
    output wire       tft_dclk, tft_den, tft_hsync, tft_vsync, tft_disp_en,
    output wire [7:0] tft_r, tft_g, tft_b
);
    assign hr_vcc = 1'b1;

    wire tick_ms;
    tick_gen #(.CLK_PER_MS(CLK_PER_MS)) U_TICK (.clk(clk), .tick_ms(tick_ms));

    // ---- 버튼 ----
    wire start_p, reset_p, start_held, reset_held;
    btn_pulse #(.ACTIVE_HIGH(BTN_ACTIVE_HIGH)) U_BS (.clk(clk), .btn(btn_start), .pressed(start_held), .pulse(start_p));
    btn_pulse #(.ACTIVE_HIGH(BTN_ACTIVE_HIGH)) U_BR (.clk(clk), .btn(btn_reset), .pressed(reset_held), .pulse(reset_p));

    // ---- 뇌파 ----
    wire [7:0] rx_data, poor, att, med;
    wire       rx_valid, pkt_ok, pkt_err, new_esense, new_raw;
    wire signed [15:0] raw;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(57600)) U_RX (.clk(clk), .rx(tgam_tx), .data(rx_data), .valid(rx_valid));
    tgam_parser U_PARSE (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
        .poor_signal(poor), .attention(att), .meditation(med), .new_esense(new_esense),
        .pkt_ok(pkt_ok), .pkt_err(pkt_err), .raw(raw), .new_raw(new_raw));

    // ---- 심박 ----
    wire        level, beat, idle, bpm_new;
    wire [11:0] interval_ms;
    wire [7:0]  bpm;
    pulse_in U_PULSE (.clk(clk), .tick_ms(tick_ms), .sig(hr_sig), .level(level),
                      .beat(beat), .interval_ms(interval_ms), .idle(idle));
    bpm_calc U_BPM (.clk(clk), .beat(beat), .interval_ms(interval_ms), .idle(idle), .bpm(bpm), .done(bpm_new));

    wire eeg_ok = (poor == 8'd0);
    wire hr_ok  = (bpm != 8'd0);

    // ---- 단계 ----
    wire [2:0] state;
    wire [3:0] sec_left;
    wire       clear, done;
    main_fsm #(.MEAS_SEC(MEAS_SEC), .MS_PER_SEC(MS_PER_SEC)) U_FSM (
        .clk(clk), .tick_ms(tick_ms), .start(start_p), .reset(reset_p), .sensor_ok(eeg_ok && hr_ok),
        .state(state), .sec_left(sec_left), .clear(clear), .done(done));

    wire in_base = (state == 3'd2), in_test = (state == 3'd4);
    wire med_new = new_esense && eeg_ok;

    // ---- 특징값 누적 + 판정 ----
    wire [15:0] bbs, bms, tbs, tms;
    wire [7:0]  bbn, bmn, tbn, tmn;
    feature_accum U_ACC_B (.clk(clk), .clear(clear && in_base), .en(in_base),
        .bpm_new(bpm_new), .bpm(bpm), .med_new(med_new), .med(med),
        .bpm_sum(bbs), .bpm_n(bbn), .med_sum(bms), .med_n(bmn));
    feature_accum U_ACC_T (.clk(clk), .clear(clear && in_test), .en(in_test),
        .bpm_new(bpm_new), .bpm(bpm), .med_new(med_new), .med(med),
        .bpm_sum(tbs), .bpm_n(tbn), .med_sum(tms), .med_n(tmn));

    wire lie, valid;
    decision #(.TH_BPM(TH_BPM), .TH_MED(TH_MED)) U_DEC (.clk(clk),
        .b_bpm_sum(bbs), .b_bpm_n(bbn), .b_med_sum(bms), .b_med_n(bmn),
        .t_bpm_sum(tbs), .t_bpm_n(tbn), .t_med_sum(tms), .t_med_n(tmn),
        .lie(lie), .valid(valid));

    // 판정 레지스터가 마지막 샘플까지 반영한 뒤 알림 시작
    reg [1:0] done_d = 2'b00;
    always @(posedge clk) done_d <= {done_d[0], done};
    alert #(.CLK_HZ(CLK_HZ)) U_ALERT (.clk(clk), .tick_ms(tick_ms), .go(done_d[1] && valid),
        .lie(lie), .piezo(piezo), .motor(motor));

    // ---- Full Color LED ----
    wire [2:0] rgb;
    rgb_led U_RGB (.state(state), .valid(valid), .lie(lie), .rgb(rgb));
    assign {rgb_r, rgb_g, rgb_b} = rgb;

    // ---- LED (짧은 펄스는 100ms 동안 켜 둠) ----
    reg [6:0] hold_pkt = 7'd0, hold_beat = 7'd0;
    always @(posedge clk) begin
        if (pkt_ok) hold_pkt <= 7'd100;
        else if (tick_ms && hold_pkt != 0) hold_pkt <= hold_pkt - 1'b1;
        if (beat) hold_beat <= 7'd100;
        else if (tick_ms && hold_beat != 0) hold_beat <= hold_beat - 1'b1;
    end
    assign led = {start_held, hr_ok, eeg_ok, hold_beat != 0, hold_pkt != 0};

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
    wire [11:0] sec_bcd = bcd3({4'd0, sec_left});
    wire [7:0]  sec2    = (in_base || in_test) ? sec_bcd[7:0] : 8'hFF;
    seg8_driver U_SEG (.clk(clk), .digits({bcd3(att), sec2, bcd3(bpm)}), .seg_com(seg_com), .seg_data(seg_data));

    // ---- Text LCD ----
    wire [127:0] line1, line2;
    lcd_msg U_MSG (.state(state), .sec_left(sec_left), .eeg_ok(eeg_ok), .hr_ok(hr_ok),
                   .valid(valid), .lie(lie), .line1(line1), .line2(line2));
    text_lcd_ctrl #(.CLK_PER_US(CLK_PER_US)) U_LCD (.clk(clk), .line1(line1), .line2(line2),
        .lcd_e(lcd_e), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_data(lcd_data));

    // ---- TFT LCD ----
    tft_display U_TFT (.clk(clk), .raw(raw), .new_raw(new_raw), .att(att), .med(med),
        .new_esense(new_esense), .bpm(bpm), .beat_on(hold_beat != 0), .bar_rgb(rgb),
        .dclk(tft_dclk), .den(tft_den), .hsync(tft_hsync), .vsync(tft_vsync), .disp_en(tft_disp_en),
        .R(tft_r), .G(tft_g), .B(tft_b));
endmodule
