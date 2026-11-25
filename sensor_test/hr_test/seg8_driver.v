`timescale 1ns / 1ps
// 7-Segment 8자리 스캔 표시
//  digits[31:28] = 가장 왼쪽 자리 ... digits[3:0] = 가장 오른쪽 자리, 4'hF = 빈칸
//  seg_com은 0인 자리가 켜짐 (5주차 코드와 같은 방식)
module seg8_driver (
    input  wire        clk,               // 50MHz
    input  wire [31:0] digits,
    output reg  [7:0]  seg_com  = 8'hFF,
    output reg  [7:0]  seg_data = 8'h00
);
    function [7:0] seg7(input [3:0] d);   // {A,B,C,D,E,F,G,DP}
        case (d)
            4'd0: seg7 = 8'b1111_1100;  4'd1: seg7 = 8'b0110_0000;
            4'd2: seg7 = 8'b1101_1010;  4'd3: seg7 = 8'b1111_0010;
            4'd4: seg7 = 8'b0110_0110;  4'd5: seg7 = 8'b1011_0110;
            4'd6: seg7 = 8'b1011_1110;  4'd7: seg7 = 8'b1110_0000;
            4'd8: seg7 = 8'b1111_1110;  4'd9: seg7 = 8'b1111_0110;
            default: seg7 = 8'b0000_0000;
        endcase
    endfunction

    reg  [15:0] scan = 16'd0;              // 한 자리당 2^13클럭(약 164us)
    wire [2:0]  idx  = scan[15:13];

    always @(posedge clk) begin
        scan     <= scan + 1'b1;
        seg_com  <= ~(8'b1000_0000 >> idx);
        seg_data <= seg7(digits[(7 - idx) * 4 +: 4]);
    end
endmodule
