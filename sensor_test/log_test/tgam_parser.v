`timescale 1ns / 1ps
// ThinkGear 패킷 파서
// 패킷: [AA][AA][PLENGTH][PAYLOAD...][CHKSUM],  CHKSUM = ~(payload 바이트 합의 하위 8비트)
// payload = DataRow 반복: [EXCODE(0x55)*][CODE][VLENGTH(CODE>=0x80일 때만)][VALUE]
// 체크섬이 맞는 패킷의 값만 출력에 반영한다.
module tgam_parser (
    input  wire       clk,
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output reg  [7:0] poor_signal = 8'd200,  // 0x02: 0=양호, 200=전극 미접촉
    output reg  [7:0] attention   = 8'd0,    // 0x04: 0~100 (0=계산 불가)
    output reg  [7:0] meditation  = 8'd0,    // 0x05: 0~100 (0=계산 불가)
    output reg        new_esense  = 1'b0,    // attention/meditation 갱신 시 1클럭 펄스 (약 1초마다)
    output reg        pkt_ok      = 1'b0,    // 체크섬 통과 패킷마다 1클럭 펄스
    output reg        pkt_err     = 1'b0,    // 체크섬 오류 패킷마다 1클럭 펄스
    output reg [191:0] eeg_power  = 192'd0   // 0x83: 3바이트 x 8대역, [191:168]=delta ... [23:0]=mid gamma
);
    localparam S_SYNC1 = 3'd0, S_SYNC2 = 3'd1, S_LEN = 3'd2, S_PAYLOAD = 3'd3, S_CHK = 3'd4;
    localparam R_CODE = 2'd0, R_VLEN = 2'd1, R_VAL = 2'd2;

    reg [2:0] state = S_SYNC1;
    reg [1:0] row   = R_CODE;
    reg [7:0] remain = 8'd0;   // 남은 payload 바이트 수
    reg [7:0] sum    = 8'd0;
    reg [7:0] code   = 8'd0;
    reg [7:0] vlen   = 8'd0;
    reg       excode = 1'b0;   // EXCODE가 붙은 행은 무시 (TGAM1 기본 출력에는 없음)

    // 이번 패킷에서 받은 값 (체크섬 확인 전 임시 저장)
    reg [7:0] t_poor = 8'd0, t_att = 8'd0, t_med = 8'd0;
    reg       f_poor = 1'b0, f_att = 1'b0, f_med = 1'b0;
    reg [191:0] t_pow = 192'd0;
    reg       f_pow  = 1'b0;
    reg       pow_ok = 1'b0;   // 0x83의 길이가 24바이트일 때만 받음

    always @(posedge clk) begin
        new_esense <= 1'b0;
        pkt_ok     <= 1'b0;
        pkt_err    <= 1'b0;
        if (rx_valid) begin
            case (state)
                S_SYNC1: if (rx_data == 8'hAA) state <= S_SYNC2;
                S_SYNC2: state <= (rx_data == 8'hAA) ? S_LEN : S_SYNC1;
                S_LEN: begin
                    if (rx_data == 8'hAA) state <= S_LEN;        // 추가 sync 바이트
                    else if (rx_data > 8'd169) state <= S_SYNC1; // 잘못된 길이
                    else begin
                        remain <= rx_data;
                        sum    <= 8'd0;
                        row    <= R_CODE;
                        excode <= 1'b0;
                        {f_poor, f_att, f_med, f_pow} <= 4'b0000;
                        state  <= (rx_data == 8'd0) ? S_CHK : S_PAYLOAD;
                    end
                end
                S_PAYLOAD: begin
                    sum    <= sum + rx_data;
                    remain <= remain - 1'b1;
                    if (remain == 8'd1) state <= S_CHK;
                    case (row)
                        R_CODE: begin
                            if (rx_data == 8'h55) excode <= 1'b1;
                            else begin
                                code <= rx_data;
                                if (rx_data[7]) row <= R_VLEN;          // 다중 바이트 값
                                else begin vlen <= 8'd1; row <= R_VAL; end
                            end
                        end
                        R_VLEN: begin
                            vlen   <= rx_data;
                            pow_ok <= (code == 8'h83) && (rx_data == 8'd24);
                            row    <= (rx_data == 8'd0) ? R_CODE : R_VAL;
                        end
                        R_VAL: begin
                            if (!excode) case (code)
                                8'h02: begin t_poor <= rx_data; f_poor <= 1'b1; end
                                8'h04: begin t_att  <= rx_data; f_att  <= 1'b1; end
                                8'h05: begin t_med  <= rx_data; f_med  <= 1'b1; end
                                8'h83: if (pow_ok) begin
                                           t_pow <= {t_pow[183:0], rx_data};   // 먼저 온 바이트가 위쪽
                                           if (vlen == 8'd1) f_pow <= 1'b1;
                                       end
                                default: ;  // 0x80 Raw 등은 건너뜀
                            endcase
                            vlen <= vlen - 1'b1;
                            if (vlen == 8'd1) begin row <= R_CODE; excode <= 1'b0; end
                        end
                    endcase
                end
                S_CHK: begin
                    if (rx_data == ~sum) begin
                        pkt_ok <= 1'b1;
                        if (f_poor) poor_signal <= t_poor;
                        if (f_att)  attention   <= t_att;
                        if (f_med)  meditation  <= t_med;
                        if (f_pow)  eeg_power   <= t_pow;
                        if (f_att | f_med) new_esense <= 1'b1;
                    end else pkt_err <= 1'b1;
                    state <= S_SYNC1;
                end
            endcase
        end
    end
endmodule
