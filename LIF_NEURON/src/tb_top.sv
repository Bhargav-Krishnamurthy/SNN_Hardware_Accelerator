`timescale 1ns / 1ps
// Testbench for two-layer SNN MNIST accelerator.
// Loads pre-generated rate-coded spike files (spike_t00.mem .. spike_t24.mem).
// Each spike file contains 25 32-bit hex words (little-endian bit order)
// that pack 784 binary spike values for one timestep.
// Expected result: class 7 for the test digit loaded in spike_t*.mem.

module tb_top;
    // ── Parameters ──────────────────────────────────────────────
    localparam INPUT_SIZE = 784;
    localparam NUM_STEPS  = 25;
    localparam CLK_PERIOD = 10;     // 10 ns -> 100 MHz

    // ── DUT signals ──────────────────────────────────────────────
    reg clk, rst, start;
    reg  [INPUT_SIZE-1:0] spike_in;
    wire [3:0]             predicted_class;
    wire                   done;

    // ── DUT instantiation ─────────────────────────────────────────
    top_level #(
        .INPUT_SIZE  (784),
        .HIDDEN_SIZE (128),
        .OUTPUT_SIZE (10),
        .BITWIDTH    (16),
        .THRESHOLD   (17774),
        .NUM_STEPS   (NUM_STEPS)
    ) dut (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .spike_in       (spike_in),
        .predicted_class(predicted_class),
        .done           (done)
    );

    // ── Clock generator ───────────────────────────────────────────
    initial clk = 0;
    always  #(CLK_PERIOD/2) clk = ~clk;

    // ── Spike memory: 25 independent 1D arrays of 25 words each ──
    // (Vivado/iverilog do not support $readmemh into multi-dim arrays)
    reg [31:0] smem_00 [0:24]; reg [31:0] smem_01 [0:24];
    reg [31:0] smem_02 [0:24]; reg [31:0] smem_03 [0:24];
    reg [31:0] smem_04 [0:24]; reg [31:0] smem_05 [0:24];
    reg [31:0] smem_06 [0:24]; reg [31:0] smem_07 [0:24];
    reg [31:0] smem_08 [0:24]; reg [31:0] smem_09 [0:24];
    reg [31:0] smem_10 [0:24]; reg [31:0] smem_11 [0:24];
    reg [31:0] smem_12 [0:24]; reg [31:0] smem_13 [0:24];
    reg [31:0] smem_14 [0:24]; reg [31:0] smem_15 [0:24];
    reg [31:0] smem_16 [0:24]; reg [31:0] smem_17 [0:24];
    reg [31:0] smem_18 [0:24]; reg [31:0] smem_19 [0:24];
    reg [31:0] smem_20 [0:24]; reg [31:0] smem_21 [0:24];
    reg [31:0] smem_22 [0:24]; reg [31:0] smem_23 [0:24];
    reg [31:0] smem_24 [0:24];

    initial begin
        $readmemh("spike_t00.mem", smem_00); $readmemh("spike_t01.mem", smem_01);
        $readmemh("spike_t02.mem", smem_02); $readmemh("spike_t03.mem", smem_03);
        $readmemh("spike_t04.mem", smem_04); $readmemh("spike_t05.mem", smem_05);
        $readmemh("spike_t06.mem", smem_06); $readmemh("spike_t07.mem", smem_07);
        $readmemh("spike_t08.mem", smem_08); $readmemh("spike_t09.mem", smem_09);
        $readmemh("spike_t10.mem", smem_10); $readmemh("spike_t11.mem", smem_11);
        $readmemh("spike_t12.mem", smem_12); $readmemh("spike_t13.mem", smem_13);
        $readmemh("spike_t14.mem", smem_14); $readmemh("spike_t15.mem", smem_15);
        $readmemh("spike_t16.mem", smem_16); $readmemh("spike_t17.mem", smem_17);
        $readmemh("spike_t18.mem", smem_18); $readmemh("spike_t19.mem", smem_19);
        $readmemh("spike_t20.mem", smem_20); $readmemh("spike_t21.mem", smem_21);
        $readmemh("spike_t22.mem", smem_22); $readmemh("spike_t23.mem", smem_23);
        $readmemh("spike_t24.mem", smem_24);
    end

    // ── Task: get 32-bit word for (step, word_idx) ───────────────
    reg [31:0] word_out;
    task get_word;
        input integer step;
        input integer widx;
        begin
            case (step)
                0:  word_out = smem_00[widx]; 1:  word_out = smem_01[widx];
                2:  word_out = smem_02[widx]; 3:  word_out = smem_03[widx];
                4:  word_out = smem_04[widx]; 5:  word_out = smem_05[widx];
                6:  word_out = smem_06[widx]; 7:  word_out = smem_07[widx];
                8:  word_out = smem_08[widx]; 9:  word_out = smem_09[widx];
                10: word_out = smem_10[widx]; 11: word_out = smem_11[widx];
                12: word_out = smem_12[widx]; 13: word_out = smem_13[widx];
                14: word_out = smem_14[widx]; 15: word_out = smem_15[widx];
                16: word_out = smem_16[widx]; 17: word_out = smem_17[widx];
                18: word_out = smem_18[widx]; 19: word_out = smem_19[widx];
                20: word_out = smem_20[widx]; 21: word_out = smem_21[widx];
                22: word_out = smem_22[widx]; 23: word_out = smem_23[widx];
                24: word_out = smem_24[widx];
                default: word_out = 32'd0;
            endcase
        end
    endtask

    // ── Task: pack 25 words into the 784-bit spike_in bus ────────
    integer w;
    task set_spike_in;
        input integer step;
        begin
            for (w = 0; w < 24; w = w + 1) begin
                get_word(step, w);
                spike_in[w*32 +: 32] = word_out;
            end
            // Last word: only 784 - 24*32 = 784 - 768 = 16 bits valid
            get_word(step, 24);
            spike_in[783:768] = word_out[15:0];
        end
    endtask

    // ── Main stimulus ─────────────────────────────────────────────
    integer t;
    initial begin
        rst      = 1'b1;
        start    = 1'b0;
        spike_in = {INPUT_SIZE{1'b0}};

        // Hold reset for 3 clock cycles
        @(posedge clk); @(posedge clk); @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // Load timestep 0 before asserting start
        set_spike_in(0);
        @(posedge clk);

        // Assert start for one cycle
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Feed remaining timesteps; one timestep consumed per clock cycle
        for (t = 1; t < NUM_STEPS; t = t + 1) begin
            set_spike_in(t);
            @(posedge clk);
        end

        // Wait for the FSM to complete
        wait(done == 1'b1);
        @(posedge clk);

        $display("\n==================================================");
        $display("SNN Hardware Accelerator - Inference Result");
        $display("Predicted class : %0d", predicted_class);
        $display("(Compare with python3 generate_spikes.py output)");
        $display("==================================================\n");

        #20;
        $finish;
    end

    // ── Timeout watchdog ─────────────────────────────────────────
    initial begin
        #500000;
        $display("TIMEOUT: simulation did not complete in time.");
        $finish;
    end

endmodule