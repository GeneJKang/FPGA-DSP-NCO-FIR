`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2026 06:20:59 PM
// Design Name: 
// Module Name: DSP_TOP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//sw 0 to 6 tone 1 frequency ( 1 kHz)
//sw 7 to 13 tone 2 frequency (8 kHz)
//sw 14 unused
//sw 15 1 = FIR on, 0 = bypass FIR (raw signal)
//JA1 = PWM Output
//JA5 = GND

module DSP_TOP #(
    parameter int CE_DIV = 2048    //fs = 100MHz / CE_DIV = 48.828 kHz
) (
    input logic clk,    //100 Mhz
    input logic btnC,
    input logic [15:0] sw,
    output logic [15:0] led,
    output logic pwm_out
    );
    assign led = sw;    //set switches to use leds
    
    //reset synchronizer
    //prevent metastability when flip flop is sampling
    logic [1:0] rst_sync;
    logic rst;
    always_ff @(posedge clk) begin
        rst_sync <= {rst_sync[0], btnC};
    end
    assign rst = rst_sync[1];    
    
    //switch synchronizer
    //same idea as above but with switches
    logic [15:0] sw_s1, sw_s;
    always @(posedge clk) begin
        sw_s1 <= sw;
        sw_s <= sw_s1;
    end
    
    //sample rate clock enable
    logic [$clog2(CE_DIV)-1 /*get bits needed*/ : 0] ce_cnt;
    logic ce;
    always_ff @(posedge clk) begin
        if (rst) begin //reset
            ce_cnt <= '0;
            ce <= 1'b0;
        end else begin
            ce_cnt <= ce_cnt + 1'b1;    //increment
            ce <= (ce_cnt == '1);    //flips 44,828 times a second
        end
    end
    
    //tuning words
    //FTW per 100 Hz
    // 100 * 2^32 / 48828.12 = 8796093
    localparam logic [31:0] FTW_100HZ = 32'd8796093;
    logic [31:0] ftw1,ftw2;
    always_ff @(posedge clk) begin      //turn the NCO into step sizes
        ftw1 <= sw_s[6:0] * FTW_100HZ;
        ftw2 <= sw_s[13:7] * FTW_100HZ;
    end
        
    //two NOCs
    logic signed [15:0] tone1, tone2;
    logic v1, v2;
    NCO u_nco1 (.clk, .rst, .ce, .ftw(ftw1), .sine(tone1), .valid(v1));
    NCO u_nco2 (.clk, .rst, .ce, .ftw(ftw2), .sine(tone2), .valid(v2));
    
    //Add two tones together
    logic signed [16:0] sum;
    logic signed [15:0] mix;
    logic mix_valid;
    assign sum = tone1 + tone2;     //operands sign-extend to 17 bits
    
    always_ff @(posedge clk) begin
        if (rst) begin
            mix_valid <= 1'b0;  
        end else begin
            mix_valid <= v1;    //set if new sample ready, both NCOs are valid if one is valid
            if (v1) begin
                mix <= 16'(sum >>> 1);  //shift right to 16 bits
            end
        end
    end
    
    //FIR low-pass filter
    logic signed [15:0] fir_y;
    logic fir_valid;
    FIR_SERIAL u_fir (.clk, .rst, .in_valid(mix_valid), .x_in(mix), .out_valid(fir_valid), .y_out(fir_y));
    
    //output select and PWM
    logic signed [15:0] dac_sample;
    always_ff @(posedge clk) begin  //Check switch 15 and decide what goes to PWM
        if (rst) begin
            dac_sample <= '0;
        end else if (sw_s[15] && fir_valid) begin   //UP
            dac_sample <= fir_y;
        end else if (!sw_s[15] && mix_valid) begin  //DOWN
            dac_sample <= mix;
        end
    end
    
    PWM_DAC u_pwm(.clk, .rst, .sample(dac_sample), .pwm_out);
endmodule
