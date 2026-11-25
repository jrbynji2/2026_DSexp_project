`timescale 1ns / 1ps
// 800x480 TFT LCD 화면 (프레임 버퍼 없이 현재 픽셀 좌표로 색을 바로 계산)
//  y   0~ 29 : 단계 색 막대 (RGB LED와 같은 색)
//  y  40~239 : Raw 뇌파 파형 (최근 800샘플, 2개 중 1개만 저장 -> 약 3초)
//  y 270~379 : 최근 100초 Attention(하늘색)/Meditation(초록) 막대
//  y 400~469 : 숫자 BPM(빨강) / Attention(하늘색) / Meditation(초록), 오른쪽 끝 = 박동 표시
// 픽셀 클럭 25MHz (50MHz 2분주). 타이밍은 800x480 패널 일반값: 1줄 1056, 1화면 525줄
// shortcut: 25MHz가 패널 최소값보다 낮아 화면이 안 나오면 50MHz 직접 출력으로 바꿔 볼 것
module tft_display #(
    parameter RAW_SHIFT = 3                // raw >>> RAW_SHIFT 를 화면 높이(±99px)에 맞춤
)(
    input  wire              clk,
    input  wire signed [15:0] raw,
    input  wire              new_raw,
    input  wire [7:0]        att,
    input  wire [7:0]        med,
    input  wire              new_esense,
    input  wire [7:0]        bpm,
    input  wire              beat_on,      // 박동 표시 (켜 둘 시간만큼 늘린 신호)
    input  wire [2:0]        bar_rgb,      // {R,G,B}
    output reg               dclk = 1'b0,
    output reg               den  = 1'b0,
    output reg               hsync = 1'b1,
    output reg               vsync = 1'b1,
    output wire              disp_en,
    output reg  [7:0]        R = 8'd0,
    output reg  [7:0]        G = 8'd0,
    output reg  [7:0]        B = 8'd0
);
    assign disp_en = 1'b1;

    // ---------------- Raw 파형 버퍼: 화면 y(0~199)로 바꿔 저장 ----------------
    reg  [7:0] raw_mem [0:799];
    reg  [9:0] raw_wp  = 10'd0;            // 다음에 쓸 위치 = 가장 오래된 샘플
    reg        decim   = 1'b0;
    wire signed [15:0] rs = raw >>> RAW_SHIFT;
    wire [7:0] raw_y = (rs > 16'sd99) ? 8'd1 : (rs < -16'sd99) ? 8'd199 : (8'd100 - rs[7:0]);
    integer i;
    initial for (i = 0; i < 800; i = i + 1) raw_mem[i] = 8'd100;
    always @(posedge clk)
        if (new_raw) begin
            decim <= ~decim;
            if (decim) begin
                raw_mem[raw_wp] <= raw_y;
                raw_wp <= (raw_wp == 10'd799) ? 10'd0 : raw_wp + 1'b1;
            end
        end

    // ---------------- Attention/Meditation 기록: 1초마다 1칸, 100칸 ----------------
    reg  [15:0] hist_mem [0:99];           // {att, med}
    reg  [6:0]  hist_wp = 7'd0;
    initial for (i = 0; i < 100; i = i + 1) hist_mem[i] = 16'd0;
    always @(posedge clk)
        if (new_esense) begin
            hist_mem[hist_wp] <= {att, med};
            hist_wp <= (hist_wp == 7'd99) ? 7'd0 : hist_wp + 1'b1;
        end

    // ---------------- 타이밍 (pix_en마다 1픽셀) ----------------
    // 1줄: hsync 20 -> 뒤 여백 26 -> 화면 800 -> 앞 여백 210  (hsync 시작부터 화면까지 46)
    // 1화면: vsync 10 -> 뒤 여백 13 -> 화면 480 -> 앞 여백 22  (vsync 시작부터 화면까지 23)
    reg        pix_en = 1'b0;
    reg [10:0] hc = 11'd0;
    reg [9:0]  vc = 10'd0;
    always @(posedge clk) begin
        pix_en <= ~pix_en;
        dclk   <= pix_en;                  // 출력이 바뀌는 순간 상승, 가운데에서 하강(패널이 읽는 엣지)
        if (pix_en) begin
            if (hc == 11'd1055) begin
                hc <= 11'd0;
                vc <= (vc == 10'd524) ? 10'd0 : vc + 1'b1;
            end else hc <= hc + 1'b1;
        end
    end

    // 단계 A (조합): 좌표, 메모리 읽기 주소
    wire [10:0] xa  = hc - 11'd46;
    wire [9:0]  ya  = vc - 10'd23;
    wire        dea = (hc >= 11'd46) && (hc < 11'd846) && (vc >= 10'd23) && (vc < 10'd503);
    wire [9:0]  xr  = dea ? xa[9:0] : 10'd0;                    // 화면 밖에서 주소가 범위를 넘지 않게
    wire [10:0] ra_sum = raw_wp + xr;                           // 가장 오래된 샘플이 왼쪽
    wire [9:0]  ra  = (ra_sum >= 11'd800) ? ra_sum - 11'd800 : ra_sum;
    wire [7:0]  ha_sum = hist_wp + xr[9:3];                     // 8픽셀 = 1칸
    wire [6:0]  ha  = (ha_sum >= 8'd100) ? ha_sum - 8'd100 : ha_sum;

    // 단계 B (레지스터): 좌표 지연 + 메모리 읽기
    reg [9:0]  xb = 10'd0, yb = 10'd0;
    reg        deb = 1'b0, hsb = 1'b1, vsb = 1'b1;
    reg [7:0]  raw_q = 8'd100, raw_prev = 8'd100;
    reg [15:0] hist_q = 16'd0;
    always @(posedge clk)
        if (pix_en) begin
            xb <= xa[9:0];  yb <= ya;  deb <= dea;
            hsb <= ~(hc < 11'd20);
            vsb <= ~(vc < 10'd10);
            raw_q    <= raw_mem[ra];
            raw_prev <= raw_q;                 // 바로 왼쪽 픽셀의 샘플 -> 두 점을 세로선으로 이음
            hist_q   <= hist_mem[ha];
        end

    // ---------------- 그리기 ----------------
    function [11:0] bcd3(input [7:0] v);       // double dabble
        integer k; reg [19:0] t;
        begin
            t = {12'd0, v};
            for (k = 0; k < 8; k = k + 1) begin
                if (t[11:8]  >= 4'd5) t[11:8]  = t[11:8]  + 4'd3;
                if (t[15:12] >= 4'd5) t[15:12] = t[15:12] + 4'd3;
                if (t[19:16] >= 4'd5) t[19:16] = t[19:16] + 4'd3;
                t = t << 1;
            end
            bcd3 = t[19:8];
        end
    endfunction

    // 40x70 칸 안의 7-세그먼트 숫자 한 자리, 두께 8px. d = 4'hF면 빈칸
    function seg_px(input [3:0] d, input [5:0] lx, input [6:0] ly);
        reg [6:0] s;                           // {A,B,C,D,E,F,G}
        begin
            case (d)
                4'd0: s = 7'b1111110;  4'd1: s = 7'b0110000;  4'd2: s = 7'b1101101;
                4'd3: s = 7'b1111001;  4'd4: s = 7'b0110011;  4'd5: s = 7'b1011011;
                4'd6: s = 7'b1011111;  4'd7: s = 7'b1110000;  4'd8: s = 7'b1111111;
                4'd9: s = 7'b1111011;  default: s = 7'b0000000;
            endcase
            seg_px = (s[6] && ly < 8)                 ||                    // A
                     (s[5] && lx >= 32 && ly < 35)    ||                    // B
                     (s[4] && lx >= 32 && ly >= 35)   ||                    // C
                     (s[3] && ly >= 62)               ||                    // D
                     (s[2] && lx < 8 && ly >= 35)     ||                    // E
                     (s[1] && lx < 8 && ly < 35)      ||                    // F
                     (s[0] && ly >= 31 && ly < 39);                         // G
        end
    endfunction

    // 3자리 숫자: x0부터 50px 간격, 앞자리 0은 지움
    function num_px(input [7:0] v, input [9:0] x, input [9:0] x0, input [6:0] ly);
        reg [11:0] b; reg [9:0] rel; reg [1:0] k; reg [5:0] lx; reg [3:0] d;
        begin
            b   = bcd3(v);
            rel = x - x0;
            k   = (rel >= 10'd100) ? 2'd2 : (rel >= 10'd50) ? 2'd1 : 2'd0;
            lx  = rel - k * 50;
            case (k)
                2'd0: d = (b[11:8] == 0) ? 4'hF : b[11:8];
                2'd1: d = (b[11:4] == 0) ? 4'hF : b[7:4];
                default: d = b[3:0];
            endcase
            num_px = (x >= x0) && (rel < 10'd150) && (lx < 6'd40) && seg_px(d, lx, ly);
        end
    endfunction

    wire [7:0] wy   = yb - 10'd40;             // 파형 영역 안의 y (0~199)
    wire [7:0] lo   = (raw_q < raw_prev) ? raw_q : raw_prev;
    wire [7:0] hi   = (raw_q < raw_prev) ? raw_prev : raw_q;
    wire [6:0] dy   = yb - 10'd400;            // 숫자 영역 안의 y (0~69)
    wire [9:0] ah   = 10'd379 - yb;            // 막대 바닥(379)부터의 높이
    wire       in_wave = (yb >= 10'd40)  && (yb < 10'd240);
    wire       in_bar  = (yb >= 10'd270) && (yb < 10'd380);
    wire       in_num  = (yb >= 10'd400) && (yb < 10'd470);

    reg [23:0] c;
    always @* begin
        c = 24'h000000;
        if (yb < 10'd30)
            c = {{8{bar_rgb[2]}}, {8{bar_rgb[1]}}, {8{bar_rgb[0]}}};
        else if (in_wave) begin
            if (wy >= lo && wy <= hi)       c = 24'hFFFF00;              // 파형
            else if (wy == 8'd100)          c = 24'h404040;              // 0 기준선
        end else if (in_bar) begin
            if (xb[2:0] < 3'd3 && ah < hist_q[15:8])                    c = 24'h00C0FF;  // Attention
            else if (xb[2:0] >= 3'd4 && xb[2:0] < 3'd7 && ah < hist_q[7:0]) c = 24'h00FF40;  // Meditation
        end else if (yb == 10'd380)         c = 24'h404040;              // 막대 바닥선
        else if (in_num) begin
            if      (num_px(bpm, xb, 10'd40,  dy)) c = 24'hFF3030;
            else if (num_px(att, xb, 10'd300, dy)) c = 24'h00C0FF;
            else if (num_px(med, xb, 10'd560, dy)) c = 24'h00FF40;
            else if (beat_on && xb >= 10'd750 && xb < 10'd780 && dy < 7'd30) c = 24'hFF0000;
        end
    end

    // 단계 C (레지스터): 출력
    always @(posedge clk)
        if (pix_en) begin
            den   <= deb;
            hsync <= hsb;
            vsync <= vsb;
            {R, G, B} <= deb ? c : 24'h000000;
        end
endmodule
