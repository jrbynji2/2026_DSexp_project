`timescale 1ns / 1ps
// log_test_top 전체 검증: 가짜 TGAM 패킷 + 박동 + DIP + 버튼을 넣고,
// usb_tx로 나오는 글자를 복원해서 uart_out.txt에 저장 -> eeg_logger.py --replay로 CSV 확인
// 시뮬레이션 속도를 위해 1ms = 5000클럭(100us)으로 줄임. UART 속도는 실제와 같음
module tb_log;
    reg clk = 0;  always #10 clk = ~clk;
    reg tgam = 1, hr = 0, btn = 0;
    reg [7:0] dip = 8'h00;
    wire usb_tx;

    log_test_top #(.CLK_PER_MS(5000)) U (
        .clk(clk), .tgam_tx(tgam), .hr_sig(hr), .hr_vcc(), .dip(dip), .btn_mark(btn),
        .usb_tx(usb_tx), .seg_com(), .seg_data(), .led());

    // ---- TGAM 쪽 송신 (57600 baud) ----
    localparam real BIT57 = 1.0e9 / 57600.0;
    task send_byte(input [7:0] b); integer i; begin
        tgam = 0; #(BIT57);
        for (i = 0; i < 8; i = i + 1) begin tgam = b[i]; #(BIT57); end
        tgam = 1; #(BIT57);
    end endtask
    reg [7:0] pl [0:31]; reg [7:0] s; integer k;
    // 요약 패킷: 02 pp | 83 18 (8대역 x 3바이트) | 04 aa | 05 mm
    task summary(input [7:0] p, input [7:0] a, input [7:0] m, input corrupt); begin
        pl[0] = 8'h02; pl[1] = p; pl[2] = 8'h83; pl[3] = 8'h18;
        for (k = 0; k < 8; k = k + 1) begin          // 대역 k = 0x0k1234 + a (구분 가능한 값)
            pl[4 + 3*k] = k; pl[5 + 3*k] = 8'h12; pl[6 + 3*k] = 8'h34 + a;
        end
        pl[28] = 8'h04; pl[29] = a; pl[30] = 8'h05; pl[31] = m;
        s = 0; for (k = 0; k < 32; k = k + 1) s = s + pl[k];
        send_byte(8'hAA); send_byte(8'hAA); send_byte(8'h20);
        for (k = 0; k < 32; k = k + 1) send_byte(pl[k]);
        send_byte(corrupt ? (~s ^ 8'h01) : ~s);
    end endtask

    // ---- usb_tx 복원 (115200 baud) -> 파일 ----
    localparam real BIT115 = 1.0e9 / 115200.0;
    integer fd, j; reg [7:0] c;
    initial begin
        fd = $fopen("uart_out.txt", "w");
        forever begin
            @(negedge usb_tx);
            #(BIT115 * 1.5);
            for (j = 0; j < 8; j = j + 1) begin c[j] = usb_tx; #(BIT115); end
            $fwrite(fd, "%c", c);
        end
    end

    localparam MS = 100_000;   // 축소된 1ms = 100us
    initial begin
        fork
            begin : heart                            // 750ms 간격 박동 4번 (80 BPM)
                #(5 * MS);
                repeat (4) begin hr = 1; #(50 * MS); hr = 0; #(700 * MS); end
            end
            begin : eeg
                #(10 * MS);
                summary(8'd0, 8'd57, 8'd43, 0);      // 정상 패킷
            end
        join
        dip = 8'h05;  #(30 * MS);                    // DIP1, DIP3 올림 -> F 줄
        btn = 1;      #(20 * MS); btn = 0; #(20 * MS);  // 마커 -> M 줄
        summary(8'd0, 8'd99, 8'd99, 1);              // 체크섬 오류 -> 기록 안 됨
        summary(8'd200, 8'd100, 8'd1, 0);            // 전극 떨어짐 -> E 줄 (flag 05)
        #(100 * MS);                                 // 마지막 줄(79글자 = 약 7ms)이 다 나갈 때까지
        $fclose(fd);
        $finish;
    end
endmodule
