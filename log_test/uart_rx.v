`timescale 1ns / 1ps
// UART 수신기 (8N1). TGAM1 기본 설정: 57600 baud
module uart_rx #(
    parameter CLK_HZ = 50_000_000,   // CLOCK SELECT 스위치 F = 50MHz
    parameter BAUD   = 57600
)(
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] data  = 8'd0,
    output reg        valid = 1'b0   // 바이트 1개 수신 시 1클럭 펄스
);
    localparam DIV = CLK_HZ / BAUD;  // 비트당 클럭 수 (50MHz/57600 = 868)
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0]  sync  = 2'b11;        // 비동기 입력 2FF 동기화 (idle = High)
    reg [1:0]  state = IDLE;
    reg [15:0] cnt   = 16'd0;
    reg [2:0]  bit_idx = 3'd0;
    reg [7:0]  shift = 8'd0;

    always @(posedge clk) begin
        sync  <= {sync[0], rx};
        valid <= 1'b0;
        case (state)
            IDLE:  if (!sync[1]) begin cnt <= DIV/2; state <= START; end
            START: if (cnt == 0) begin                 // start 비트 가운데에서 재확인
                       if (!sync[1]) begin cnt <= DIV-1; bit_idx <= 3'd0; state <= DATA; end
                       else state <= IDLE;              // 글리치였으면 무시
                   end else cnt <= cnt - 1'b1;
            DATA:  if (cnt == 0) begin                 // 각 비트 가운데에서 샘플, LSB first
                       shift <= {sync[1], shift[7:1]};
                       cnt   <= DIV-1;
                       if (bit_idx == 3'd7) state <= STOP;
                       else bit_idx <= bit_idx + 1'b1;
                   end else cnt <= cnt - 1'b1;
            STOP:  if (cnt == 0) begin
                       if (sync[1]) begin data <= shift; valid <= 1'b1; end  // stop 비트가 1일 때만 유효
                       state <= IDLE;
                   end else cnt <= cnt - 1'b1;
        endcase
    end
endmodule
