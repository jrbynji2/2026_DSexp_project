`timescale 1ns / 1ps
// uart_rx + tgam_parser 검증: 실제 TGAM 패킷 형태를 57600 baud로 흘려 보냄
module tb_tgam;
    reg clk = 0;  always #10 clk = ~clk;   // 50MHz
    reg rx = 1;
    wire [7:0] rx_data, poor, att, med;
    wire rx_valid, pkt_ok, pkt_err, new_esense;
    integer n_ok = 0, n_err = 0, n_es = 0, fails = 0;

    uart_rx #(.CLK_HZ(50_000_000), .BAUD(57600)) U_RX (.clk(clk), .rx(rx), .data(rx_data), .valid(rx_valid));
    tgam_parser U_P (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid), .poor_signal(poor),
                     .attention(att), .meditation(med), .new_esense(new_esense), .pkt_ok(pkt_ok), .pkt_err(pkt_err));
    always @(posedge clk) begin n_ok <= n_ok + pkt_ok; n_err <= n_err + pkt_err; n_es <= n_es + new_esense; end

    localparam real BIT_NS = 1.0e9 / 57600.0;
    task send_byte(input [7:0] b); integer i; begin
        rx = 0; #(BIT_NS);
        for (i = 0; i < 8; i = i + 1) begin rx = b[i]; #(BIT_NS); end
        rx = 1; #(BIT_NS);
    end endtask

    reg [7:0] pl [0:63]; reg [7:0] s; integer k;
    task send_packet(input integer len, input corrupt); begin
        s = 0; for (k = 0; k < len; k = k + 1) s = s + pl[k];
        send_byte(8'hAA); send_byte(8'hAA); send_byte(len[7:0]);
        for (k = 0; k < len; k = k + 1) send_byte(pl[k]);
        send_byte(corrupt ? ~s ^ 8'h01 : ~s);
    end endtask
    // Raw 패킷: AA AA 04 80 02 HH LL CHK
    task raw_packet(input [15:0] v); begin
        pl[0]=8'h80; pl[1]=8'h02; pl[2]=v[15:8]; pl[3]=v[7:0]; send_packet(4, 0);
    end endtask
    // 1초 요약 패킷: AA AA 20 | 02 pp | 83 18 (24B) | 04 aa | 05 mm | CHK
    task big_packet(input [7:0] p, input [7:0] a, input [7:0] m, input corrupt); begin
        pl[0]=8'h02; pl[1]=p; pl[2]=8'h83; pl[3]=8'h18;
        for (k = 0; k < 24; k = k + 1) pl[4+k] = 8'hAA ^ k;   // 대역 파워 (0xAA 포함해도 sync로 오인하지 않아야 함)
        pl[28]=8'h04; pl[29]=a; pl[30]=8'h05; pl[31]=m; send_packet(32, corrupt);
    end endtask
    task check(input [7:0] ep, input [7:0] ea, input [7:0] em, input [8*24-1:0] msg); begin
        #(5*BIT_NS);
        if (poor !== ep || att !== ea || med !== em) begin
            fails = fails + 1; $display("FAIL %0s: poor=%0d att=%0d med=%0d (expected %0d/%0d/%0d)", msg, poor, att, med, ep, ea, em);
        end else $display("PASS %0s: poor=%0d att=%0d med=%0d", msg, poor, att, med);
    end endtask

    initial begin
        #(20*BIT_NS);
        check(200, 0, 0, "initial");
        send_byte(8'h12); send_byte(8'hAA);              // 쓰레기 바이트 (중간부터 듣기 시작한 상황)
        raw_packet(16'hFF38); raw_packet(16'h0123);
        check(200, 0, 0, "raw only");
        big_packet(8'd0, 8'd57, 8'd43, 0);
        check(0, 57, 43, "good summary");
        raw_packet(16'h0042);
        big_packet(8'd0, 8'd99, 8'd99, 1);               // 체크섬 오류 -> 반영되면 안 됨
        check(0, 57, 43, "bad checksum ignored");
        big_packet(8'd200, 8'd0, 8'd0, 0);               // 전극 떨어짐
        check(200, 0, 0, "no contact");
        big_packet(8'd0, 8'd100, 8'd1, 0);
        check(0, 100, 1, "range edge");
        $display("pkt_ok=%0d (expect 6)  pkt_err=%0d (expect 1)  new_esense=%0d (expect 3)", n_ok, n_err, n_es);
        if (n_ok != 6 || n_err != 1 || n_es != 3) fails = fails + 1;
        if (fails == 0) $display("ALL TESTS PASSED"); else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule
