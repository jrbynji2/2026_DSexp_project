`timescale 1ns / 1ps
// pulse_in + bpm_calc 검증. 시뮬레이션 속도를 위해 1ms = 10클럭(200ns)으로 줄임
module tb_hr;
    reg clk = 0;  always #10 clk = ~clk;
    reg sig = 0;
    wire tick_ms, level, beat, idle;
    wire [11:0] interval_ms;
    wire [7:0]  bpm;
    integer n_beat = 0, fails = 0;

    tick_gen #(.CLK_PER_MS(10)) U_TICK (.clk(clk), .tick(tick_ms));
    pulse_in U_PULSE (.clk(clk), .tick_ms(tick_ms), .sig(sig), .level(level),
                      .beat(beat), .interval_ms(interval_ms), .idle(idle));
    bpm_calc U_BPM (.clk(clk), .beat(beat), .interval_ms(interval_ms), .idle(idle), .bpm(bpm));
    always @(posedge clk) n_beat <= n_beat + beat;

    localparam MS = 200;   // 1ms = 200ns
    // period(ms) 간격으로 펄스 n개 (High 50ms)
    task beats(input integer n, input integer period); integer i; begin
        for (i = 0; i < n; i = i + 1) begin sig = 1; #(50 * MS); sig = 0; #((period - 50) * MS); end
    end endtask
    task check(input [7:0] e_bpm, input e_idle, input integer e_n, input [8*28-1:0] msg); begin
        if (bpm !== e_bpm || idle !== e_idle || n_beat !== e_n) begin
            fails = fails + 1;
            $display("FAIL %0s: bpm=%0d idle=%0d beats=%0d (expected %0d/%0d/%0d)", msg, bpm, idle, n_beat, e_bpm, e_idle, e_n);
        end else $display("PASS %0s: bpm=%0d idle=%0d beats=%0d interval=%0dms", msg, bpm, idle, n_beat, interval_ms);
    end endtask

    initial begin
        #(100 * MS);
        check(0, 1, 0, "no signal");
        beats(5, 750);                                   // 80 BPM
        check(80, 0, 5, "750ms -> 80");
        sig = 1; #(50 * MS); sig = 0; #(50 * MS);        // 박동 직후 100ms에 잡음 펄스
        sig = 1; #(20 * MS); sig = 0; #(630 * MS);
        check(80, 0, 6, "noise edge ignored");
        beats(3, 1000);                                  // 60 BPM
        check(60, 0, 9, "1000ms -> 60");
        beats(3, 857);                                   // 60000/857 = 70.01
        check(70, 0, 12, "857ms -> 70");
        #(3500 * MS);                                    // 박동 끊김
        check(0, 1, 12, "3.5s no beat -> idle");
        beats(1, 750);                                   // 다시 시작: 첫 박동은 간격 모름
        check(0, 0, 13, "first beat after idle");
        beats(1, 750);
        check(80, 0, 14, "second beat -> 80");
        if (fails == 0) $display("ALL TESTS PASSED"); else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule
