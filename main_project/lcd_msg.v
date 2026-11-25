`timescale 1ns / 1ps
// 단계별 Text LCD 문구 (각 줄 정확히 16글자)
module lcd_msg (
    input  wire [2:0]   state,
    input  wire [3:0]   sec_left,
    input  wire         eeg_ok,
    input  wire         hr_ok,
    input  wire         valid,
    input  wire         lie,
    output reg  [127:0] line1,
    output reg  [127:0] line2
);
    wire [7:0]   tens = (sec_left >= 4'd10) ? "1" : " ";
    wire [7:0]   ones = (sec_left >= 4'd10) ? "0" : ("0" + sec_left);
    wire [127:0] time_left = {"TIME LEFT ", tens, ones, "s   "};

    always @* begin
        case (state)
            3'd0: begin
                line1 = (eeg_ok && hr_ok) ? "PRESS START     " : "CONNECT SENSORS ";
                line2 = {"EEG:", eeg_ok ? "OK" : "--", "  HR:", hr_ok ? "OK" : "--", "   "};
            end
            3'd1: begin line1 = "ASK TRUE Q.     "; line2 = "THEN PRESS START"; end
            3'd2: begin line1 = "BASELINE...     "; line2 = time_left;          end
            3'd3: begin line1 = "ASK TEST Q.     "; line2 = "THEN PRESS START"; end
            3'd4: begin line1 = "MEASURING...    "; line2 = time_left;          end
            3'd5: begin
                line1 = !valid ? "NO DATA (RETRY) " : lie ? "LIE DETECTED    " : "TRUTH           ";
                line2 = "START: NEXT Q   ";
            end
            default: begin line1 = "                "; line2 = "                "; end
        endcase
    end
endmodule
