`timescale 1ns/1ps

module snn_layer #(
    parameter NUM_NEURONS = 128,
    parameter NUM_INPUTS  = 784,
    parameter BITWIDTH    = 16,
    parameter THRESHOLD   = 17774,
    parameter MEM_FILE    = "W1.mem"
)(
    input  wire clk,
    input  wire rst,
    input  wire [NUM_INPUTS-1:0]   spike_in,
    output wire [NUM_NEURONS-1:0]  spike_out
);
    // one weight array loaded once — flat [neuron*NUM_INPUTS + input]
    reg signed [BITWIDTH-1:0] w_mem [0:NUM_NEURONS*NUM_INPUTS-1];

    initial begin
        $readmemh(MEM_FILE, w_mem);
        $display("[SNN_LAYER] Loaded %s", MEM_FILE);
    end

    // wire weights per neuron
    wire signed [BITWIDTH-1:0] weights [0:NUM_NEURONS-1][0:NUM_INPUTS-1];

    genvar n, i;
    generate
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin : weight_wire
            for (i = 0; i < NUM_INPUTS; i = i + 1) begin : input_wire
                assign weights[n][i] = w_mem[n * NUM_INPUTS + i];
            end
        end
    endgenerate

    // instantiate LIF neurons
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
                .weights  (weights[n]),
                .spike_out(spike_out[n])
            );
        end
    endgenerate

endmodule