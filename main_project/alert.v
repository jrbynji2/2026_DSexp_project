`timescale 1ns / 1ps
// 결과 알림: 피에조 소리 + 진동모터
//  거짓 : 낮은 부저음 3번 + 진동 MOTOR_MS
//  진실 : 도-미-솔 상승음
module alert #(
    parameter CLK_HZ   = 50_000_000,
    parameter MOTOR_MS = 1500
)(
    input  wire clk,
    input  wire tick_ms,
    input  wire go,                // 1클럭: 알림 시작
    input  wire lie,
    output reg  piezo = 1'b0,
    output wire motor
);
    // 반주기 클럭 수 = CLK_HZ / (2 * 주파수)
    localparam [16:0] BUZZ = CLK_HZ / 440,     // 220Hz
                      C5   = CLK_HZ / 1046,    // 523Hz
                      E5   = CLK_HZ / 1318,    // 659Hz
                      G5   = CLK_HZ / 1568;    // 784Hz

    // 악보: {반주기(0 = 쉼), 길이 ms(0 = 끝)}
    function [26:0] note(input t, input [2:0] step);
        if (t) case (step)
            3'd0: note = {BUZZ, 10'd250};  3'd1: note = {17'd0, 10'd100};
            3'd2: note = {BUZZ, 10'd250};  3'd3: note = {17'd0, 10'd100};
            3'd4: note = {BUZZ, 10'd250};  default: note = 27'd0;
        endcase else case (step)
            3'd0: note = {C5, 10'd150};    3'd1: note = {E5, 10'd150};
            3'd2: note = {G5, 10'd300};    default: note = 27'd0;
        endcase
    endfunction

    reg        playing = 1'b0, mode = 1'b0;
    reg [2:0]  step = 3'd0;
    reg [9:0]  ms   = 10'd0;
    reg [16:0] pc   = 17'd0;
    wire [26:0] n    = note(mode, step);
    wire [16:0] half = n[26:10];
    wire [9:0]  dur  = n[9:0];

    always @(posedge clk) begin
        if (go) begin
            playing <= 1'b1; mode <= lie; step <= 3'd0; ms <= 10'd0;
        end else if (playing) begin
            if (dur == 10'd0) playing <= 1'b0;
            else if (tick_ms) begin
                if (ms == dur - 1'b1) begin ms <= 10'd0; step <= step + 1'b1; end
                else ms <= ms + 1'b1;
            end
        end

        if (playing && half != 17'd0) begin
            if (pc >= half - 1'b1) begin pc <= 17'd0; piezo <= ~piezo; end
            else pc <= pc + 1'b1;
        end else begin
            pc <= 17'd0; piezo <= 1'b0;
        end
    end

    reg [11:0] mcnt = 12'd0;
    always @(posedge clk)
        if (go) mcnt <= lie ? MOTOR_MS : 12'd0;
        else if (tick_ms && mcnt != 12'd0) mcnt <= mcnt - 1'b1;
    assign motor = (mcnt != 12'd0);
endmodule
