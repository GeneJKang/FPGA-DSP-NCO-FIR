`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2026 06:08:25 PM
// Design Name: 
// Module Name: PWM_DAC
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

//This is needed because the FPGA pins can only output 0V or 3.3V
module PWM_DAC(
    input logic clk,
    input logic rst,
    input logic signed [15:0] sample,
    output logic pwm_out
    );
    
    logic [7:0]cnt, duty;   //0 to 255 and wrap around
                            //One full count is one PWM period (256 clock ticks) => 390625 periods per second
    
    always_ff @(posedge clk) begin
        if (rst) begin  //reset pin triggered
            cnt <= '0;
            duty <= 8'd128;     //middle average = 1.65V
            pwm_out <= 1'b0;    //Hold down to 0 to prevent unpredictable behavior
        end else begin
            cnt <= cnt + 1'b1;  //Increment
            if (cnt == 8'hFF) begin
                duty <= {~sample[15], sample [14:8]}; //Take top 8 bits because we only have 256 steps
            end                                       //Flip top bit so sine value goes from negative to positive, duty cant handle negative
            pwm_out <= (cnt < duty);   
        end                             
    end  
endmodule
