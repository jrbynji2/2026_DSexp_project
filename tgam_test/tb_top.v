`timescale 1ns / 1ps
// top의 BCD 변환 확인: 0~255 전부
module tb_top;
    integer i, bad = 0;
    tgam_test_top U(.clk(1'b0), .tgam_tx(1'b1), .seg_com(), .seg_data(), .led());
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            force U.att = i; #1;
            if (U.att_bcd[11:8]*100 + U.att_bcd[7:4]*10 + U.att_bcd[3:0] != i) bad = bad + 1;
        end
        if (bad == 0) $display("BCD OK (0..255)"); else $display("BCD FAIL %0d", bad);
        $finish;
    end
endmodule
