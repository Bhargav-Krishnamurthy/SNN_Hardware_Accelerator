`timescale 1ns / 1ps
// LIF (Leaky Integrate-and-Fire) Neuron
// Matches the Python snn(1).ipynb implementation:
//   - Beta = 0.5  --> leak = membrane - (membrane >>> 1)
//   - Hard reset on fire
//   - 16-bit signed fixed-point arithmetic
//   - Threshold = 17774 (= 1.0 * quantization_scale)
// Weights passed as a flat packed bus to avoid Vivado port-array issues.

module lif #(
    parameter BITWIDTH  = 16,
    parameter N_INPUTS  = 784,
    parameter THRESHOLD = 17774
)(
    input  wire                           clk,
    input  wire                           rst,
    input  wire [N_INPUTS-1:0]            spike_in,
    // Flat packed: weight[i] = weights[i*BITWIDTH +: BITWIDTH]
    input  wire [N_INPUTS*BITWIDTH-1:0]   weights,
    output reg                            spike_out
);

    // 32-bit accumulator to avoid overflow during accumulation
    reg signed [31:0] membrane;
    reg signed [31:0] after_integrate;
    wire signed [31:0] after_leak;
    integer i;

    // Beta=0.5 leak: V_leak = V - V>>1
    assign after_leak = membrane - (membrane >>> 1);

    // Combinational integrate: sum weights of active inputs
    always @(*) begin
        after_integrate = after_leak;
        for (i = 0; i < N_INPUTS; i = i + 1) begin
            if (spike_in[i])
                after_integrate = after_integrate + $signed({{16{weights[i*BITWIDTH + BITWIDTH-1]}}, weights[i*BITWIDTH +: BITWIDTH]});
        end
    end

    // Sequential fire-and-reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            membrane  <= 32'sd0;
            spike_out <= 1'b0;
        end
        else if (after_integrate >= $signed(32'd0 + THRESHOLD)) begin
            membrane  <= 32'sd0;   // hard reset
            spike_out <= 1'b1;     // fire
        end
        else begin
            membrane  <= after_integrate;
            spike_out <= 1'b0;
        end
    end

endmodule
