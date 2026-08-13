`timescale 1ns/1ps
// SNN Layer: instantiates NUM_NEURONS LIF neurons sharing a weight BRAM.
// Weight file format: one 4-digit hex value (signed int16) per line, row-major.
// Row n contains weights for neuron n: entries n*NUM_INPUTS to n*NUM_INPUTS+NUM_INPUTS-1

module snn_layer #(
    parameter NUM_NEURONS = 128,
    parameter NUM_INPUTS  = 784,
    parameter BITWIDTH    = 16,
    parameter THRESHOLD   = 17774,
    parameter MEM_FILE    = "W1.mem"
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire [NUM_INPUTS-1:0]       spike_in,
    output wire [NUM_NEURONS-1:0]      spike_out
);
    // Weight storage: flat 1D array loaded from .mem file
    reg signed [BITWIDTH-1:0] w_mem [0:NUM_NEURONS*NUM_INPUTS-1];

    initial begin
        $readmemh(MEM_FILE, w_mem);
        $display("[SNN_LAYER] Loaded %s (%0d x %0d weights)", MEM_FILE, NUM_NEURONS, NUM_INPUTS);
    end

    // Pack weights into flat buses, one per neuron
    wire [NUM_INPUTS*BITWIDTH-1:0] neuron_weights [0:NUM_NEURONS-1];

    genvar n, i;
    generate
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin : weight_pack
            for (i = 0; i < NUM_INPUTS; i = i + 1) begin : input_pack
                assign neuron_weights[n][i*BITWIDTH +: BITWIDTH] = w_mem[n*NUM_INPUTS + i];
            end
        end
    endgenerate

    // Instantiate LIF neurons
    generate
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin : neuron_array
            lif #(
                .BITWIDTH  (BITWIDTH),
                .N_INPUTS  (NUM_INPUTS),
                .THRESHOLD (THRESHOLD)
            ) lif_inst (
                .clk      (clk),
                .rst      (rst),
                .spike_in (spike_in),
                .weights  (neuron_weights[n]),
                .spike_out(spike_out[n])
            );
        end
    endgenerate

endmodule