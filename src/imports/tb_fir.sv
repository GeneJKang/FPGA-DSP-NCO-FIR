// tb_fir.sv — unit test for fir_serial
// Reads test vectors from fir_in.mem (hex), feeds one sample every
// GAP clocks, and writes every output to fir_out.txt (one decimal per line).
// fir_out.txt is then compared against the golden model (Python now, MATLAB later).
`timescale 1ns/1ps
module tb_fir;
    localparam int N   = 1024;      // number of input samples
    localparam int GAP = 80;        // clocks between samples (must be > 63 + 4)

    logic clk = 0, rst = 1;
    always #5 clk = ~clk;           // 100 MHz

    logic               in_valid = 0, out_valid;
    logic signed [15:0] x_in = 0, y_out;
    logic signed [15:0] vec [0:N-1];

    FIR_SERIAL dut (.clk, .rst, .in_valid, .x_in, .out_valid, .y_out);

    integer fd, n_out = 0;

    initial begin
        $readmemh("fir_in.mem", vec);
        fd = $fopen("fir_out.txt", "w");
        repeat (5) @(posedge clk);
        rst <= 0;
        for (int n = 0; n < N; n++) begin
            @(posedge clk);
            x_in     <= vec[n];
            in_valid <= 1;
            @(posedge clk);
            in_valid <= 0;
            repeat (GAP - 2) @(posedge clk);
        end
        repeat (GAP) @(posedge clk);
        $fclose(fd);
        $display("tb_fir: %0d inputs, %0d outputs written to fir_out.txt", N, n_out);
        $finish;
    end

    always @(posedge clk) if (out_valid) begin
        $fdisplay(fd, "%0d", y_out);
        n_out++;
    end
endmodule
