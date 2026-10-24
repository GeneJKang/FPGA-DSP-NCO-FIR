// tb_top.sv — full-chain test: NCO x2 -> mix -> FIR -> PWM
// Uses CE_DIV = 128 instead of 2048 so the simulation runs 16x faster;
// the datapath is identical, only the time between samples changes.
// Switches: tone 1 = 10 (1 kHz at the real fs), tone 2 = 80 (8 kHz), filter on.
// Writes mix_out.txt and fir_out_top.txt (decimal, one sample per line).
`timescale 1ns/1ps
module tb_top;
    localparam int CE_DIV = 128;
    localparam int N      = 2048;   // samples to capture

    logic        clk = 0, btnC = 1;
    logic [15:0] sw, led;
    logic        pwm_out;
    always #5 clk = ~clk;

    DSP_TOP #(.CE_DIV(CE_DIV)) dut (.clk, .btnC, .sw, .led, .pwm_out);

    integer fd_mix, fd_fir, n_mix = 0, n_fir = 0;

    initial begin
        sw = {1'b1, 1'b0, 7'd80, 7'd10};
        fd_mix = $fopen("mix_out.txt", "w");
        fd_fir = $fopen("fir_out_top.txt", "w");
        repeat (10) @(posedge clk);
        btnC = 0;
        wait (n_fir == N);
        $fclose(fd_mix);
        $fclose(fd_fir);
        $display("tb_top: captured %0d mix and %0d FIR samples", n_mix, n_fir);
        $finish;
    end

    // hierarchical taps into the design (no debug ports needed on the top level)
    always @(posedge clk) begin
        if (dut.mix_valid && n_mix < N) begin $fdisplay(fd_mix, "%0d", dut.mix);   n_mix++; end
        if (dut.fir_valid && n_fir < N) begin $fdisplay(fd_fir, "%0d", dut.fir_y); n_fir++; end
    end
endmodule
