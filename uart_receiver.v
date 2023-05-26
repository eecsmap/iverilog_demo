// ==================================================
//  https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter
//
// ==================================================

`timescale 1ns / 1ns
`define HALF_CYCLE_LENGTH 1

module test();

    // ==================================================
    // setup clock
    // ==================================================
    reg clk = 0;
    always #`HALF_CYCLE_LENGTH clk = ~clk;

    // ==================================================
    // setup uart receiver input and output signals
    // ==================================================
    reg [0:7] data_out;
    reg signal_in = 1'b1; // idle as high level according to the spec

    // normally in PYNQ 125_000_000 / 115_200 = 1085, yet I want to test the extreme case here
    localparam cycles_per_symbol = 1;
    localparam symbol_length = cycles_per_symbol * `HALF_CYCLE_LENGTH * 2;
    localparam stop_bits = 2;

    reg data_ready = 0;
    wire data_valid;

    uart_receiver #(.CYCLES_PER_SYMBOL(cycles_per_symbol), .STOP_BITS(stop_bits)) ur(
        .clk(clk),
        .signal_in(signal_in),
        .data_ready(data_ready),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    integer error_count = 0;

    task send_byte(input [7:0] test_byte);
        signal_in <= 1'b0; // start bit
        for (int i = 0; i < 8; i++) begin
            #symbol_length signal_in <= test_byte[i];
        end
        #symbol_length signal_in <= 1'b1;
        repeat (stop_bits) #symbol_length; // stop bit(s)
        assert (data_out == test_byte) else begin
            $error("data_out: %b, while expecting: %b", data_out, test_byte);
            error_count = error_count + 1;
        end
    endtask

    initial begin
        $dumpfile("uart_receiver.fst");
        $dumpvars(0, test);
        $display("Test UART receiver");
        begin
            signal_in <= 1'b1;
            #symbol_length;
            for (int i = 0; i < 256; i++) begin
                send_byte(i);
            end
        end
        if (error_count == 0) $display("Test UART receiver passed");
        else $display("Test UART receiver failed with %d errors", error_count);
        $finish;
    end
endmodule

module uart_receiver
    #(
        parameter CYCLES_PER_SYMBOL = 125_000_000 / 115_200,
        parameter DATA_BITS = 8,
        parameter STOP_BITS = 1 // practically could be 1, 1.5, 2, here we only support 1,2,...
                                // A lenient implementation might just check the first half of the first stop bit
    )
    (
        input clk,
        input signal_in,
        input data_ready, // sink is ready to accept data
        output reg [0:7] data_out,
        output reg data_valid // data is valid from source
    );
    localparam MAX_CYCLE_COUNT = CYCLES_PER_SYMBOL;
    localparam SAMPLE_INDEX = (MAX_CYCLE_COUNT - 1) >> 1;

    integer cycle_count = 0;
    wire sample_pulse = cycle_count == SAMPLE_INDEX;

    localparam START_BITS = 1; // fixed to 1
    localparam MAX_SAMPLE_COUNT = START_BITS + DATA_BITS + STOP_BITS;
    integer sample_count = 0;
    reg scanning = 1'b0;

    // ==================================================
    // drop is needed in a corner case
    // when a bit is represented by 1 cycle
    // to get the first low bit detected correctly,
    // we need to do sample on it even if is not scanning.
    // ==================================================
    reg prev_data = 1'b1;
    wire drop = prev_data & ~signal_in;
    always @(posedge clk) begin
        prev_data <= signal_in;
    end

    assign do_sample = sample_pulse && (scanning || drop);

    always @(posedge clk) begin
        cycle_count <= (cycle_count + 1 == MAX_CYCLE_COUNT) ? 0 : cycle_count + 1;
    end

    reg [MAX_SAMPLE_COUNT-1:0] buffer;

    always @(posedge clk) begin
        if (~scanning & ~signal_in) begin
            scanning <= 1'b1;
        end
        if (data_valid & data_ready) begin
            data_valid <= 1'b0;
        end
        if (do_sample) begin
            buffer[sample_count] <= signal_in;
            if (sample_count == DATA_BITS + 1) begin // a more lenient implementation, we don't care about stop bits
            //if (sample_count == MAX_SAMPLE_COUNT - 1) begin // a more strict implementation, we can verify stop bits
                scanning <= 1'b0;
                data_out <= buffer[DATA_BITS:1];
                data_valid <= 1'b1;
                sample_count <= 0;
            end else
                sample_count <= sample_count + 1;
        end
    end

endmodule
