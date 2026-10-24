`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2026 06:49:40 PM
// Design Name: 
// Module Name: FIR_SERIAL
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

//y[n] = sat16 (floor ( sum_{k=0}^{NTAPS-1} n[k] * x[n-k] / 2^15) )

//Each output is the 63 most recent input samples and each are multiplied by its own coefficient and all added up
//The coefficients are Q1.15. The products are 32 bits, the accumulator is 40 bits
// (32 + ceil(log2(63)) = 38. The >>> 15 is a shift which rounds towards -infinity (floor)

//After each in_valid pulse, the filter takes NTAPS clock to step through the taps plus 4 clocks of pipeline
//Meaning we will ned 63 + 4 = 67 ticks per output. If a new sample arrives sooner than that
//the filter will be bsy and will drop it. 

//S0 Address: k counts 0 to NTAPS-1, read address = newest sample - k
//S1 Read: x_r = sbuf[], c_r = coef[k]
//S2 Multiply: p_r = x_r * c_r (DSP48 multiplier + register)
//S3 Accumulate: acc = first ? p_r : acc + p_r
//S4 Output: y_out = sat(acc >>> 15), out_valid pulses

//S0 counts k, S1 reads, S2 multiplies, S3 adds, S4 scales and outputs, DSP48 is the dedicated multipler blocks

module FIR_SERIAL #(
    parameter int NTAPS = 63,
    parameter string COEF_FILE = "fir_coefs.mem"
) (
    input logic clk,
    input logic rst,
    input logic in_valid,
    input logic signed [15:0] x_in,
    output logic out_valid,
    output logic signed [15:0] y_out 
);
    
    localparam int AW = $clog2(NTAPS);  //6 bits means 64 entry circular buffer    
    
    logic signed [15:0] coef [0:NTAPS-1];
    logic signed [15:0] sbuf [0:(1<<AW)-1];
    
    initial begin
        $readmemh(COEF_FILE, coef);
        for (int i = 0; i < (1<<AW); i++) begin //start at 0
            sbuf[i] = '0;
        end
    end
    
    //S0 to S4 are split because all the math cant happen at 100 MHz in 1 tick
    
    //S0 control and sample buffer write
    logic[AW-1:0] wptr, newest, k;
    logic busy;
    
    always_ff @(posedge clk) begin
        if (rst) begin      //reset everything
            wptr <= '0;     //where next sample will be written
            busy <= 1'b0;   //currently running the loop
            k <= '0;        //loop counter
        end else if (in_valid && !busy) begin
            newest <= wptr; //save current wptr and move one slot
            wptr <= wptr + 1'b1;   
            busy <= 1'b1;   //loop running so set to busy
            k <='0;         //start loop at 0
        end else if (busy) begin    //Loop not ready net
            if (k == AW'(NTAPS-1)) busy <= 1'b0;
            k <= k + 1'b1;
        end
    end
    
    //sample buffer write kept in its own memory block    
    always_ff @(posedge clk) begin
        if (in_valid && !busy && !rst) begin
            sbuf[wptr] <= x_in;
        end
    end
    
    //S1 read sample and coefficient
    logic signed [15:0] x_r, c_r;
    logic v1, first1, last1;    //v1/v2 are valid signals, first1/first2 points to tap 0, last1/last2 point to tap 62 which sets done3
    
    always_ff @(posedge clk) begin  //fetch sample newest - k and coefficient k
        x_r <= sbuf[AW'(newest-k)];
        c_r <= coef[k];
        v1 <= busy;
        first1 <= busy && (k == '0);
        last1 <= busy && (k == AW'(NTAPS-1));
    end
    
    //S2 multiply
    logic signed [31:0] p_r;
    logic v2, first2, last2;
    
    always_ff @(posedge clk) begin
        p_r <= x_r * c_r;
        v2 <= v1;
        first2 <= first1;
        last2 <= last1;
    end
    
    //S3 accumulate
    logic signed [39:0] acc;
    logic done3;
    
    always_ff @(posedge clk)begin   //Add the product into the running total
        if (rst) begin
            done3 <= 1'b0;
        end else begin
            if (v2) begin
                acc <= first2 ? 40'(p_r) : acc + 40'(p_r);
            end
            done3 <= v2 && last2;
        end
    end
    
    //S4 output
    logic signed [24:0] scaled; //acc >>> 15 fits into 25 bits
    assign scaled = 25'(acc >>> 15);
    
    always_ff @(posedge clk) begin  //scale, clamp, and send out
        if (rst) begin
            out_valid <= 1'b0;
        end else begin
            out_valid <= done3;
            if (done3) begin
                if (scaled > 25'sd32767) begin
                    y_out <= 16'd32767;
                end else if (scaled < -25'sd32768) begin
                    y_out <= -16'sd32768;
                end else begin
                    y_out <= 16'(scaled);
                end
            end
        end
    end
endmodule
