`timescale 1ns / 1ps
// top_level.v
// Two-layer SNN accelerator for MNIST digit recognition.
// Matches snn(1).ipynb:
//   - Layer 1: 784 -> 128 LIF neurons
//   - Layer 2: 128 -> 10  LIF neurons
//   - Rate coding: N_STEPS timesteps of binary spikes
//   - Classification: argmax of output spike counts over N_STEPS
//
// FSM:
//   IDLE    -> (start) -> RUNNING
//   RUNNING -> (step_count == NUM_STEPS-1) -> CLASSIFY
//   CLASSIFY -> DONE_ST
//   DONE_ST  -> IDLE  (asserts done=1 for one cycle)

module top_level #(
    parameter INPUT_SIZE   = 784,
    parameter HIDDEN_SIZE  = 128,
    parameter OUTPUT_SIZE  = 10,
    parameter BITWIDTH     = 16,
    parameter THRESHOLD    = 17774,
    parameter NUM_STEPS    = 25
)(
    input  wire                            clk,
    input  wire                            rst,
    input  wire                            start,
    input  wire [INPUT_SIZE-1:0]           spike_in,
    output reg  [$clog2(OUTPUT_SIZE)-1:0]  predicted_class,
    output reg                             done
);

    // ── Internal signals ─────────────────────────────────────────
    wire [HIDDEN_SIZE-1:0]  hidden_spikes;
    wire [OUTPUT_SIZE-1:0]  output_spikes;

    // ── FSM states ───────────────────────────────────────────────
    localparam IDLE     = 2'd0;
    localparam RUNNING  = 2'd1;
    localparam CLASSIFY = 2'd2;
    localparam DONE_ST  = 2'd3;

    reg  [1:0]  state;
    // Need 5 bits to count up to 24 (NUM_STEPS-1)
    reg  [4:0]  step_count;

    // Output spike accumulator (max count = 25, so 5 bits each)
    reg  [4:0]  spike_count [0:OUTPUT_SIZE-1];
    integer n;

    // ── Combinational argmax ─────────────────────────────────────
    reg [$clog2(OUTPUT_SIZE)-1:0] best_class;
    integer j;
    always @(*) begin
        best_class = 0;
        for (j = 1; j < OUTPUT_SIZE; j = j + 1)
            if (spike_count[j] > spike_count[best_class])
                best_class = j[$clog2(OUTPUT_SIZE)-1:0];
    end

    // ── SNN Layer 1: 784 -> 128 ───────────────────────────────────
    snn_layer #(
        .NUM_NEURONS (HIDDEN_SIZE),
        .NUM_INPUTS  (INPUT_SIZE),
        .BITWIDTH    (BITWIDTH),
        .THRESHOLD   (THRESHOLD),
        .MEM_FILE    ("W1.mem")
    ) layer1 (
        .clk      (clk),
        .rst      (rst),
        .spike_in (spike_in),
        .spike_out(hidden_spikes)
    );

    // ── SNN Layer 2: 128 -> 10 ────────────────────────────────────
    snn_layer #(
        .NUM_NEURONS (OUTPUT_SIZE),
        .NUM_INPUTS  (HIDDEN_SIZE),
        .BITWIDTH    (BITWIDTH),
        .THRESHOLD   (THRESHOLD),
        .MEM_FILE    ("W2.mem")
    ) layer2 (
        .clk      (clk),
        .rst      (rst),
        .spike_in (hidden_spikes),
        .spike_out(output_spikes)
    );

    // ── FSM ──────────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            step_count      <= 5'd0;
            done            <= 1'b0;
            predicted_class <= {$clog2(OUTPUT_SIZE){1'b0}};
            for (n = 0; n < OUTPUT_SIZE; n = n + 1)
                spike_count[n] <= 5'd0;
        end
        else begin
            case (state)

                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (n = 0; n < OUTPUT_SIZE; n = n + 1)
                            spike_count[n] <= 5'd0;
                        step_count <= 5'd0;
                        state      <= RUNNING;
                    end
                end

                RUNNING: begin
                    // Accumulate output spikes for this cycle
                    for (n = 0; n < OUTPUT_SIZE; n = n + 1) begin
                        if (output_spikes[n])
                            spike_count[n] <= spike_count[n] + 5'd1;
                    end
                    if (step_count == NUM_STEPS - 1) begin
                        state <= CLASSIFY;
                    end
                    else begin
                        step_count <= step_count + 5'd1;
                    end
                end

                CLASSIFY: begin
                    predicted_class <= best_class;
                    state           <= DONE_ST;
                end

                DONE_ST: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule