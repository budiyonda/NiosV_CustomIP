module seven_seg_controller #(
    parameter LSB_FIRST = 1'b0,       // if 1, shift LSB first; if 0, shift MSB first
    parameter SEG_FIRST  = 1'b1,      // if 1, send segment byte first then digit byte
    parameter BIT_REVERSE = 1'b0,     // if 1, reverse segment bit order before shifting
    parameter LATCH_DELAY = 4'd4      // number of shift ticks to hold latch low
) (
    input clk,
    input reset,
    input avs_address,
    input avs_write,
    input [15:0] avs_writedata,
    output avs_waitrequest,
    output reg sr_data,   // serial data to 74HC595
    output reg sr_clk,
    output reg sr_latch
);

    // Avalon-MM slave logic
    assign avs_waitrequest = 0;  // always ready

    reg [15:0] display_data;  // stored data for display (4 digits, 4 bits each)

    // 7-segment patterns for 0-9 (common anode, active low)
    reg [7:0] seg_patterns [0:15];
    initial begin
        seg_patterns[0] = 8'b11000000;  // 0
        seg_patterns[1] = 8'b11111001;  // 1
        seg_patterns[2] = 8'b10100100;  // 2
        seg_patterns[3] = 8'b10110000;  // 3
        seg_patterns[4] = 8'b10011001;  // 4
        seg_patterns[5] = 8'b10010010;  // 5
        seg_patterns[6] = 8'b10000010;  // 6
        seg_patterns[7] = 8'b11111000;  // 7
        seg_patterns[8] = 8'b10000000;  // 8
        seg_patterns[9] = 8'b10010000;  // 9
        seg_patterns[10] = 8'b11111111; // blank (all OFF)
        seg_patterns[11] = 8'b11111111; // blank
        seg_patterns[12] = 8'b11111111; // blank
        seg_patterns[13] = 8'b11111111; // blank
        seg_patterns[14] = 8'b11111111; // blank
        seg_patterns[15] = 8'b11111111; // blank (0xF = OFF)
    end

    // Digit select bytes (8-bit values used by shield shifting)
    // Reversed order: digit_select[0] = rightmost (ones), digit_select[3] = leftmost (thousands)
    reg [7:0] digit_select [0:3];
    initial begin
        digit_select[0] = 8'h08;  // rightmost digit (satuan)
        digit_select[1] = 8'h04;  // tens
        digit_select[2] = 8'h02;  // hundreds
        digit_select[3] = 8'h01;  // leftmost digit (ribuan)
    end

    // Multiplexing state
    reg [1:0] digit_sel;
    reg [23:0] refresh_counter; // slow refresh
    reg load_req;

    // Shift state machine
    reg [15:0] shift_reg;
    reg [4:0] bit_idx; // 0..15
    reg [2:0] state;
    reg [7:0] segpat;
    reg [7:0] segpat_rev;
    reg [3:0] latch_cnt;
    reg [25:0] debug_cnt;

    localparam S_IDLE = 3'd0;
    localparam S_LOAD = 3'd1;
    localparam S_SHIFT_LOW = 3'd2;
    localparam S_SHIFT_HIGH = 3'd3;
    localparam S_LATCH_LOW = 3'd4;
    localparam S_LATCH_HIGH = 3'd5;

    // clock divider for shift timing
    reg [11:0] clk_div;
    wire shift_tick = (clk_div == 12'hFFF);

    // helper: reverse 8-bit value
    function [7:0] rev8;
        input [7:0] in;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) rev8[i] = in[7-i];
        end
    endfunction

    // selected bit from shift_reg depending on LSB/MSB ordering
    wire selected_bit = (LSB_FIRST) ? shift_reg[bit_idx] : shift_reg[15-bit_idx];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div <= 0;
            refresh_counter <= 0;
            digit_sel <= 0;
            load_req <= 1'b0;
            sr_data <= 1'b0;
            sr_clk <= 1'b0;
            sr_latch <= 1'b0;
            shift_reg <= 16'h0000;
            bit_idx <= 0;
            state <= S_IDLE;
            display_data <= 16'h0000;
            debug_cnt <= 0;
        end else begin
            // Always run debug counter
            debug_cnt <= debug_cnt + 1'b1;
            // Clock divider runs always
            clk_div <= clk_div + 1;
            
            // handle CPU write to display register
            if (avs_write && avs_address == 0) begin
                display_data <= avs_writedata;
                load_req <= 1'b1;
            end
            
            // If debug mode requested (write 0xFFFF), force a slow blink on sr_latch
            if (display_data == 16'hFFFF) begin
                // drive data/clk low to avoid accidental shifting; blink latch slowly
                sr_data <= 1'b0;
                sr_clk <= 1'b0;
                sr_latch <= debug_cnt[23];
                state <= S_IDLE;
                // do not run normal refresh/shift logic
            end else begin
                // refresh digit every some ticks (reduced threshold for visible multiplexing)
                refresh_counter <= refresh_counter + 1;
                if (refresh_counter == 24'h03FFFF || load_req) begin
                    refresh_counter <= 0;
                    digit_sel <= digit_sel + 1;
                    // start shifting for new digit
                    state <= S_LOAD;
                    load_req <= 1'b0;  // clear load_req
                end

                if (shift_tick) begin
                case (state)
                    S_IDLE: begin
                        // keep outputs idle
                        sr_clk <= 1'b0;
                        sr_data <= 1'b0;
                        sr_latch <= 1'b0;
                    end
                    S_LOAD: begin
                        // prepare 16-bit for shifting according to parameters
                        segpat = seg_patterns[ display_data[ (digit_sel*4) +: 4 ] ];
                        // optionally reverse bit order
                        segpat_rev = (BIT_REVERSE) ? rev8(segpat) : segpat;
                        if (SEG_FIRST)
                            shift_reg <= { segpat_rev, digit_select[digit_sel] };
                        else
                            shift_reg <= { digit_select[digit_sel], segpat_rev };
                        bit_idx <= 5'd0;
                        sr_clk <= 1'b0;
                        sr_latch <= 1'b0;
                        latch_cnt <= LATCH_DELAY;
                        state <= S_SHIFT_LOW;
                    end
                    S_SHIFT_LOW: begin
                            sr_clk <= 1'b0;
                            sr_data <= selected_bit;
                            state <= S_SHIFT_HIGH;
                    end
                    S_SHIFT_HIGH: begin
                        sr_clk <= 1'b1;
                        if (bit_idx == 5'd15) begin
                            state <= S_LATCH_LOW;
                        end else begin
                            bit_idx <= bit_idx + 1;
                            state <= S_SHIFT_LOW;
                        end
                    end
                    S_LATCH_LOW: begin
                            sr_clk <= 1'b0;
                            sr_latch <= 1'b1;  // pulse HIGH to latch
                            // hold latch high for a few ticks to ensure stable latch
                            if (latch_cnt == 0) begin
                                state <= S_LATCH_HIGH;
                            end else begin
                                latch_cnt <= latch_cnt - 1'b1;
                                state <= S_LATCH_LOW;
                            end
                    end
                        S_LATCH_HIGH: begin
                            sr_latch <= 1'b0;  // return to LOW idle
                            state <= S_IDLE;
                    end
                    default: state <= S_IDLE;
                endcase
                end // end if (shift_tick)
            end // end else (display_data != 0xFFFF)
        end // end else (not reset)
    end // end always

endmodule