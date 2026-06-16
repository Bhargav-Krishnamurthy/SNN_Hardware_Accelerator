`timescale 1ns/1ns

module hdc_encoder_tb;

    parameter D = 16;
    parameter N = 4;

    reg [D-1:0] vector1, vector2, vector3, vector4;
    reg [$clog2(D)-1:0] shift_amt1, shift_amt2, shift_amt3, shift_amt4;
    wire [D-1:0] shifted;

    hdc_encoder #(D) uut (
        .vector1(vector1),
        .vector2(vector2),
        .vector3(vector3),
        .vector4(vector4),
        .shift_amt1(shift_amt1),
        .shift_amt2(shift_amt2),
        .shift_amt3(shift_amt3),
        .shift_amt4(shift_amt4),
        .shifted(shifted)
    );

    initial begin
        // Test case 1
        vector1 = 16'b0000000000000001; // 1
        vector2 = 16'b0000000000000010; // 2
        vector3 = 16'b0000000000000100; // 4
        vector4 = 16'b0000000000001000; // 8
        shift_amt1 = 1;
        shift_amt2 = 2;
        shift_amt3 = 3;
        shift_amt4 = 4;
        
        #10; 
        $display("Shifted Output: %b", shifted);

        // Test case 2
        vector1 = 16'b1011000011110000;
        vector2 = 16'b1100110010101010;
        vector3 = 16'b0011110000111100;
        vector4 = 16'b1111000010101010;

        shift_amt1 = 1;
        shift_amt2 = 3;
        shift_amt3 = 2;
        shift_amt4 = 5;

        #10;
        $display("Shifted Output: %b", shifted);
        $finish;
    end
endmodule