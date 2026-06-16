module hdc_encoder #(parameter D = 16) (
    input  [D-1:0] vector1,
    input  [D-1:0] vector2,
    input  [D-1:0] vector3,
    input  [D-1:0] vector4,
    input  [$clog2(D)-1:0] shift_amt1,
    input  [$clog2(D)-1:0] shift_amt2,
    input  [$clog2(D)-1:0] shift_amt3,
    input  [$clog2(D)-1:0] shift_amt4,
    output [D-1:0] shifted
);
    wire [D-1:0] shifted1, shifted2, shifted3, shifted4;

    assign shifted1 = (vector1 << shift_amt1) | (vector1 >> (D - shift_amt1));
    assign shifted2 = (vector2 << shift_amt2) |(vector2 >> (D - shift_amt2));

    assign shifted3 = (vector3 << shift_amt3) |(vector3 >> (D - shift_amt3));

    assign shifted4 =(vector4 << shift_amt4) |(vector4 >> (D - shift_amt4));
       
    assign shifted = shifted1 ^ shifted2 ^ shifted3 ^ shifted4;


endmodule