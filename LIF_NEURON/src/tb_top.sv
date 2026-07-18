`timescale 1ns / 1ps


module tb_top;
    // parameters
    localparam INPUT_SIZE = 784;
    localparam NUM_STEPS  = 25;
    localparam CLK_PERIOD = 10;

    reg clk, rst, start;
    reg [INPUT_SIZE-1:0] spike_in;
    wire [3:0] predicted_class;
    wire done;

    // DUT
    top_level dut (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .spike_in       (spike_in),
        .predicted_class(predicted_class),
        .done           (done)
    );

    // clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // spike memory — 25 timesteps, each 25 words of 32 bits
    reg [31:0] spike_mem [0:24][0:24];  // [timestep][word]

    // load all 25 spike files
    initial begin
        $readmemh("spike_t00.mem", spike_mem[0]);
        $readmemh("spike_t01.mem", spike_mem[1]);
        $readmemh("spike_t02.mem", spike_mem[2]);
        // ... repeat for all 25
        $readmemh("spike_t24.mem", spike_mem[24]);
    end

    // task to pack one timestep into spike_in bus
    integer t, w;
    task load_spike_timestep(input integer step);
        for (w = 0; w < 25; w = w + 1) begin
            // pack 32-bit words into spike_in
            if (w < 24)
                spike_in[w*32 +: 32] = spike_mem[step][w];
            else
                spike_in[768 +: 16]  = spike_mem[step][w][15:0]; // last 16 bits
        end
    endtask

    // main stimulus
    initial begin
        clk   = 0; rst = 1; start = 0;
        spike_in = 0;
        #20 rst = 0;
        #10 start = 1;
        #10 start = 0;

        // feed one spike timestep per clock cycle
        for (t = 0; t < NUM_STEPS; t = t + 1) begin
            load_spike_timestep(t);
            @(posedge clk);
        end

        // wait for done
        wait(done == 1);
        $display("Predicted class: %0d", predicted_class);
        $display("Expected:        0");   // change to your true label
        #20 $finish;
    end

endmodule