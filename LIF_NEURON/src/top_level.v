`timescale 1ns / 1ps
// top_level.v
// Connects two SNN layers and a spike counter

module top_level #(
    parameter INPUT_SIZE   = 784,
    parameter HIDDEN_SIZE  = 128,
    parameter OUTPUT_SIZE  = 10,
    parameter BITWIDTH     = 16,
    parameter THRESHOLD    = 17774,
    parameter NUM_STEPS    = 25
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              start,
    input  wire [INPUT_SIZE-1:0]             spike_in,
    output reg  [$clog2(OUTPUT_SIZE)-1:0]    predicted_class,
    output reg                               done
);

    // ── internal signals ──────────────────────────────────────
    wire [HIDDEN_SIZE-1:0]  hidden_spikes;
    wire [OUTPUT_SIZE-1:0]  output_spikes;

    // ── FSM states ────────────────────────────────────────────
    localparam IDLE     = 2'd0;
    localparam RUNNING  = 2'd1;
    localparam CLASSIFY = 2'd2;
    localparam DONE_ST  = 2'd3;

    reg [1:0]                        state;
    reg [$clog2(NUM_STEPS)-1:0]      step_count;
    reg                              running;

    reg [4:0] spike_count [0:OUTPUT_SIZE-1];
    integer n;

    // ── combinational argmax (MODULE LEVEL - not inside case) ─
    reg [$clog2(OUTPUT_SIZE)-1:0] best_class;
    integer j;
    always @(*) begin
        best_class = 0;
        for (j = 1; j < OUTPUT_SIZE; j = j + 1)
            if (spike_count[j] > spike_count[best_class])
                best_class = j;
    end

    // ── SNN layer 1 ───────────────────────────────────────────
    snn_layer #(
        .NUM_NEURONS (HIDDEN_SIZE),
        .NUM_INPUTS  (INPUT_SIZE),
        .BITWIDTH    (BITWIDTH),
        .THRESHOLD   (THRESHOLD),
        .MEM_FILE    ("W1.mem")
    ) layer1 (
        .clk      (clk),
        .rst      (rst | ~running),
        .spike_in (spike_in),
        .spike_out(hidden_spikes)
    );

    // ── SNN layer 2 ───────────────────────────────────────────
    snn_layer #(
        .NUM_NEURONS (OUTPUT_SIZE),
        .NUM_INPUTS  (HIDDEN_SIZE),
        .BITWIDTH    (BITWIDTH),
        .THRESHOLD   (THRESHOLD),
        .MEM_FILE    ("W2.mem")
    ) layer2 (
        .clk      (clk),
        .rst      (rst | ~running),
        .spike_in (hidden_spikes),
        .spike_out(output_spikes)
    );

    // ── FSM ───────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            step_count      <= 0;
            running         <= 0;
            done            <= 0;
            predicted_class <= 0;
            for (n = 0; n < OUTPUT_SIZE; n = n + 1)
                spike_count[n] <= 0;
        end
        else begin
            case (state)

                IDLE: begin
                    done    <= 0;
                    running <= 0;
                    if (start) begin
                        for (n = 0; n < OUTPUT_SIZE; n = n + 1)
                            spike_count[n] <= 0;
                        step_count <= 0;
                        running    <= 1;
                        state      <= RUNNING;
                    end
                end

                RUNNING: begin
                    for (n = 0; n < OUTPUT_SIZE; n = n + 1) begin
                        if (output_spikes[n])
                            spike_count[n] <= spike_count[n] + 1;
                    end
                    if (step_count == NUM_STEPS - 1) begin
                        running    <= 0;
                        state      <= CLASSIFY;
                    end
                    else begin
                        step_count <= step_count + 1;
                    end
                end

                CLASSIFY: begin
                    predicted_class <= best_class;  // from combinational block above
                    state           <= DONE_ST;
                end

                DONE_ST: begin
                    done  <= 1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule