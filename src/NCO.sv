`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2026 05:49:24 PM
// Design Name: 
// Module Name: NCO
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


module NCO #(
    parameter string LUT_FILE = "sine_lut.mem"
) (
    input logic clk,
    input logic rst,
    input logic ce, //Sample rate chip enable
    input logic [31:0] ftw,    //Frequency tuning 32 bits
    output logic signed [15:0] sine,
    output logic valid
);
    logic [31:0] phase;
    logic signed[15:0] lut [0:1023];
    
    initial $readmemh(LUT_FILE, lut); //Read mem file and put into look up table
    
    always_ff @(posedge clk) begin
        if (rst) begin  //reset parameters
            phase <='0;
            valid <= 1 'b0;
        end else begin
            valid <= ce;
            if (ce) phase <= phase + ftw;   //this wraps around naturally
        end
    end
    
    //Table look up (phase -> sine value)
    //Making Vivado put the values into block RAM
    always_ff @(posedge clk) begin
        if (ce && !rst) sine <= lut[phase[31:22]];  //get top t0 bits (0 t0 1023) and store it in sine
    end
endmodule
