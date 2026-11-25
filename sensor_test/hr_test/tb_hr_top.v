`timescale 1ns / 1ps
// hr_test_top의 7-Segment 숫자 변환 확인: BPM 0~255, 간격 0~4095 전부
module tb_hr_top;
    integer i, bad = 0;
    hr_test_top U (.clk(1'b0), .hr_sig(1'b0), .hr_vcc(), .seg_com(), .seg_data(), .led());
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            force U.bpm = i % 256;
            force U.interval_ms = i;
            #1;
            if (U.U_SEG.digits[31:28] * 100 + U.U_SEG.digits[27:24] * 10 + U.U_SEG.digits[23:20] != i % 256) bad = bad + 1;
            if (U.U_SEG.digits[19:16] != 4'hF) bad = bad + 1;
            if (U.U_SEG.digits[15:12] * 1000 + U.U_SEG.digits[11:8] * 100 + U.U_SEG.digits[7:4] * 10 + U.U_SEG.digits[3:0] != i) bad = bad + 1;
        end
        if (bad == 0) $display("BCD OK (BPM 0..255, interval 0..4095)"); else $display("BCD FAIL %0d", bad);
        $finish;
    end
endmodule
