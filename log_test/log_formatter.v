`timescale 1ns / 1ps
// 이벤트를 받아 16진수 텍스트 한 줄로 만들어 UART로 보냄. 줄 끝은 '\n'
//  E,<ms 8>,<flag 2>,<poor 2>,<att 2>,<med 2>,<delta 6>,<theta 6>,<lowA 6>,<highA 6>,<lowB 6>,<highB 6>,<lowG 6>,<midG 6>
//  B,<ms 8>,<flag 2>,<박동 간격 ms 3>
//  F,<ms 8>,<flag 2>      DIP 스위치가 바뀐 순간
//  M,<ms 8>,<flag 2>      마커 버튼을 누른 순간
// 이벤트 순간의 값을 따로 저장해 두므로, 앞 줄을 보내는 중에 생긴 이벤트도 빠지지 않음
// (같은 종류가 보내기 전에 또 오면 최신 값으로 덮어씀. E는 1초, B는 0.3초 이상 간격이라 실제로는 생기지 않음)
module log_formatter #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115200
)(
    input  wire         clk,
    input  wire [31:0]  now_ms,
    input  wire [7:0]   flag,
    input  wire         ev_e,
    input  wire [7:0]   poor,
    input  wire [7:0]   att,
    input  wire [7:0]   med,
    input  wire [191:0] power,
    input  wire         ev_b,
    input  wire [11:0]  interval_ms,
    input  wire         ev_f,
    input  wire         ev_m,
    output wire         tx
);
    // ---- 16진수 글자 변환 ----
    function [7:0] hc(input [3:0] n);
        hc = (n < 4'd10) ? (8'h30 + n) : (8'h37 + n);   // '0'~'9', 'A'~'F'
    endfunction
    function [15:0] hex2(input [7:0] v);  hex2 = {hc(v[7:4]), hc(v[3:0])}; endfunction
    function [23:0] hex3(input [11:0] v); hex3 = {hc(v[11:8]), hex2(v[7:0])}; endfunction
    function [47:0] hex6(input [23:0] v); hex6 = {hex2(v[23:16]), hex2(v[15:8]), hex2(v[7:0])}; endfunction
    function [63:0] hex8(input [31:0] v); hex8 = {hex2(v[31:24]), hex2(v[23:16]), hex2(v[15:8]), hex2(v[7:0])}; endfunction

    localparam [7:0] C = 8'h2C, NL = 8'h0A;   // ',' '\n'

    // ---- 이벤트 순간의 값 저장 ----
    reg pe = 1'b0, pb = 1'b0, pf = 1'b0, pm = 1'b0;
    reg [31:0] e_t = 0, b_t = 0, f_t = 0, m_t = 0;
    reg [7:0]  e_f = 0, b_f = 0, f_f = 0, m_f = 0;
    reg [7:0]  e_poor = 0, e_att = 0, e_med = 0;
    reg [191:0] e_pow = 0;
    reg [11:0] b_int = 0;

    // ---- 줄 버퍼: 최대 80글자, 왼쪽(위쪽 비트)부터 한 글자씩 내보냄 ----
    reg [639:0] line = 640'd0;
    reg [6:0]   left = 7'd0;      // 남은 글자 수
    reg         tx_start = 1'b0;
    wire        tx_ready;

    always @(posedge clk) begin
        tx_start <= 1'b0;

        if (left != 0) begin
            // 송신기가 비었으면 다음 글자
            if (tx_ready && !tx_start) begin
                tx_start <= 1'b1;
                line     <= line << 8;
                left     <= left - 1'b1;
            end
        end else if (pm) begin
            line <= {"M,", hex8(m_t), C, hex2(m_f), NL, 528'd0};                     // 14글자
            left <= 7'd14;  pm <= 1'b0;
        end else if (pf) begin
            line <= {"F,", hex8(f_t), C, hex2(f_f), NL, 528'd0};
            left <= 7'd14;  pf <= 1'b0;
        end else if (pb) begin
            line <= {"B,", hex8(b_t), C, hex2(b_f), C, hex3(b_int), NL, 496'd0};    // 18글자
            left <= 7'd18;  pb <= 1'b0;
        end else if (pe) begin
            line <= {"E,", hex8(e_t), C, hex2(e_f), C, hex2(e_poor), C, hex2(e_att), C, hex2(e_med),
                     C, hex6(e_pow[191:168]), C, hex6(e_pow[167:144]), C, hex6(e_pow[143:120]), C, hex6(e_pow[119:96]),
                     C, hex6(e_pow[95:72]),   C, hex6(e_pow[71:48]),   C, hex6(e_pow[47:24]),   C, hex6(e_pow[23:0]),
                     NL, 8'd0};                                                         // 79글자
            left <= 7'd79;  pe <= 1'b0;
        end

        // 새 이벤트 저장 (위에서 지운 것보다 나중에 써서, 같은 클럭에 온 이벤트도 남음)
        if (ev_m) begin pm <= 1'b1; m_t <= now_ms; m_f <= flag; end
        if (ev_f) begin pf <= 1'b1; f_t <= now_ms; f_f <= flag; end
        if (ev_b) begin pb <= 1'b1; b_t <= now_ms; b_f <= flag; b_int <= interval_ms; end
        if (ev_e) begin pe <= 1'b1; e_t <= now_ms; e_f <= flag;
                        e_poor <= poor; e_att <= att; e_med <= med; e_pow <= power; end
    end

    // 글자 하나 보낼 때 line은 이미 8비트 밀려 있으므로, 밀기 직전 값의 맨 위 글자를 data로 잡아 둠
    reg [7:0] tx_data = 8'h00;
    always @(posedge clk)
        if (left != 0 && tx_ready && !tx_start) tx_data <= line[639:632];

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) U_TX (
        .clk(clk), .start(tx_start), .data(tx_data), .tx(tx), .ready(tx_ready));
endmodule
