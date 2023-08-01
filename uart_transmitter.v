// ==================================================
//  https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter
//
// ==================================================

`timescale 1ns / 1ns
`define HALF_CYCLE_LENGTH 1

module test();
    reg clk = 0;
    always #`HALF_CYCLE_LENGTH clk = ~clk;

    localparam cycles_per_symbol = 1;
    localparam stop_bits = 1;

    wire signal_out;
    reg [7:0] data_in;
    reg data_valid;
    wire data_ready;

    uart_transmitter
    #(
        .CYCLES_PER_SYMBOL(cycles_per_symbol),
        .STOP_BITS(stop_bits)
    ) ut (
        .clk(clk),
        .signal_out(signal_out),
        .data_in(data_in)
    );

    integer error_count = 0;
    initial begin
        $dumpfile("uart_transmitter.fst");
        $dumpvars(0, test);
        $display("Test UART transmitter");
        for (int i = 0; i < 256; i++) begin
        end
        if (error_count == 0) $display("Test passed");
        else $display("Test failed with %d errors", error_count);
        $finish;
    end
endmodule

module uart_transmitter
    #(
        parameter CYCLES_PER_SYMBOL = 125_000_000 / 115_200,
        parameter DATA_BITS = 8,
        parameter STOP_BITS = 1
    )
    (
        input clk,
        input [0:7] data_in,
        input data_valid,
        output reg signal_out,
        output reg data_ready
    );

endmodule
