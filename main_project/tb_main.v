`timescale 1ns / 1ps
// main_top 시뮬레이션 (시간 축소: 1ms = 10us, 측정 4초)
//  1) 기준 60BPM -> 판별 100BPM : 거짓 판정, 진동/소리
//  2) 같은 기준으로 판별 60BPM  : 진실 판정
//  3) Text LCD에 실제로 써진 1줄 글자, TFT 한 화면의 픽셀 수 확인
module tb_main;
    reg clk = 0;
    always #10 clk = ~clk;                         // 50MHz

    reg tgam_tx = 1, hr_sig = 0, btn_reset = 0, btn_start = 0;
    wire [4:0] led; wire rgb_r, rgb_g, rgb_b, motor, piezo, hr_vcc;
    wire [7:0] seg_com, seg_data, lcd_data, tft_r, tft_g, tft_b;
    wire lcd_e, lcd_rs, lcd_rw, tft_dclk, tft_den, tft_hsync, tft_vsync, tft_disp_en;

    main_top #(.CLK_PER_MS(500), .CLK_PER_US(1), .MEAS_SEC(4)) U (
        .clk(clk), .tgam_tx(tgam_tx), .hr_sig(hr_sig), .hr_vcc(hr_vcc),
        .btn_reset(btn_reset), .btn_start(btn_start), .led(led),
        .rgb_r(rgb_r), .rgb_g(rgb_g), .rgb_b(rgb_b), .motor(motor), .piezo(piezo),
        .seg_com(seg_com), .seg_data(seg_data),
        .lcd_e(lcd_e), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_data(lcd_data),
        .tft_dclk(tft_dclk), .tft_den(tft_den), .tft_hsync(tft_hsync), .tft_vsync(tft_vsync),
        .tft_disp_en(tft_disp_en), .tft_r(tft_r), .tft_g(tft_g), .tft_b(tft_b));

    localparam MS = 10_000;                        // 축소된 1ms (ns)
    integer errors = 0;

    // ---- TGAM: 57600 baud UART ----
    task send_byte(input [7:0] b);
        integer k;
        begin
            tgam_tx = 0; #17361;
            for (k = 0; k < 8; k = k + 1) begin tgam_tx = b[k]; #17361; end
            tgam_tx = 1; #17361;
        end
    endtask
    task send_esense(input [7:0] poor, input [7:0] att, input [7:0] med);
        reg [7:0] sum;
        begin
            sum = 8'h02 + poor + 8'h04 + att + 8'h05 + med;
            send_byte(8'hAA); send_byte(8'hAA); send_byte(8'd6);
            send_byte(8'h02); send_byte(poor); send_byte(8'h04); send_byte(att);
            send_byte(8'h05); send_byte(med); send_byte(~sum);
        end
    endtask
    task send_raw(input [15:0] v);
        begin
            send_byte(8'hAA); send_byte(8'hAA); send_byte(8'd4);
            send_byte(8'h80); send_byte(8'd2); send_byte(v[15:8]); send_byte(v[7:0]);
            send_byte(~(8'h80 + 8'd2 + v[15:8] + v[7:0]));
        end
    endtask

    // 1초(축소)마다 eSense, 그 사이에 raw 몇 개
    initial begin
        forever begin
            send_esense(8'd0, 8'd50, 8'd60);
            repeat (3) send_raw(16'hFF38);         // -200
            #(1000 * MS - 3_000_000);
        end
    end

    // ---- 심박: hr_per(ms)마다 펄스 ----
    integer hr_per = 1000;
    initial forever begin
        hr_sig = 1; #(50 * MS); hr_sig = 0; #((hr_per - 50) * MS);
    end

    task press_start; begin btn_start = 1; #2000; btn_start = 0; #2000; end endtask

    // ---- Text LCD에 실제로 써진 1줄 글자 기록 ----
    reg [127:0] lcd_line1 = 0;
    integer pos = 99;
    always @(negedge lcd_e)
        if (!lcd_rs) pos = (lcd_data == 8'h80) ? 0 : 99;
        else if (pos < 16) begin lcd_line1[(15 - pos) * 8 +: 8] = lcd_data; pos = pos + 1; end

    task check(input cond, input [8*40-1:0] msg);
        if (cond) $display("PASS: %0s", msg);
        else begin $display("FAIL: %0s", msg); errors = errors + 1; end
    endtask

    integer piezo_edges = 0;
    always @(posedge piezo) piezo_edges = piezo_edges + 1;

    initial begin
        // 센서 준비 대기 (BPM이 나와야 함)
        wait (U.hr_ok && U.eeg_ok);
        $display("sensor ok, bpm=%0d med=%0d", U.bpm, U.med);
        press_start;  check(U.state == 1, "WAIT -> BASE_RDY");
        press_start;  check(U.state == 2, "BASE_RDY -> BASE");
        wait (U.state == 3);
        $display("base: bpm_sum=%0d n=%0d med_sum=%0d n=%0d", U.bbs, U.bbn, U.bms, U.bmn);

        // 판별 질문: 심박 상승
        hr_per = 600;
        #(2000 * MS);
        press_start;  check(U.state == 4, "TEST_RDY -> TEST");
        wait (U.state == 5);
        #(1 * MS);
        $display("test: bpm_sum=%0d n=%0d med_sum=%0d n=%0d", U.tbs, U.tbn, U.tms, U.tmn);
        check(U.valid && U.lie, "100BPM vs 60BPM -> lie");
        check(motor, "motor on");
        check({rgb_r, rgb_g, rgb_b} == 3'b100, "RGB red");
        #(300 * MS);
        check(piezo_edges > 0, "piezo sound");      // 음 주파수는 실제 시간 기준이라 축소된 시간 안에선 몇 번만 토글
        check(lcd_line1 == "LIE DETECTED    ", "LCD shows LIE DETECTED");

        // 다음 질문: 심박 원래대로
        press_start;  check(U.state == 3, "RESULT -> TEST_RDY");
        hr_per = 1000;
        #(3000 * MS);
        press_start;
        wait (U.state == 5);
        #(1 * MS);
        check(U.valid && !U.lie, "60BPM vs 60BPM -> truth");
        check({rgb_r, rgb_g, rgb_b} == 3'b010, "RGB green");
        #(100 * MS);
        check(lcd_line1 == "TRUTH           ", "LCD shows TRUTH");

        btn_reset = 1; #2000; btn_reset = 0; #2000;
        check(U.state == 0, "SW_A -> WAIT");

        $display("errors = %0d", errors);
        $finish;
    end

    // ---- TFT: 한 화면 동안 den인 픽셀 수 = 800x480 ----
    integer pix = 0, frames = 0;
    always @(posedge tft_dclk) if (tft_den) pix = pix + 1;
    always @(negedge tft_vsync) begin
        if (frames >= 1) begin
            if (pix == 800 * 480) $display("PASS: TFT frame %0d pixels = %0d", frames, pix);
            else begin $display("FAIL: TFT frame %0d pixels = %0d", frames, pix); errors = errors + 1; end
        end
        frames = frames + 1; pix = 0;
    end
endmodule
