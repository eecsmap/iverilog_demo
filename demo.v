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
    localparam CYCLES_PER_SYMBOL = 1;
    localparam SYMBOL_LENGTH = CYCLES_PER_SYMBOL * `HALF_CYCLE_LENGTH * 2;

    reg data_ready = 0;

    uart_receiver #(.CYCLES_PER_SYMBOL(CYCLES_PER_SYMBOL)) ur(
	    .clk(clk),
        .data_ready(data_ready),
        .signal_in(signal_in),
	    .data_out(data_out)
	);

    integer test_byte;

    integer error_count = 0;

    task send_byte(input [7:0] test_byte);
        signal_in <= 1'b0; // start bit
        for (int i = 0; i < 8; i++) begin
            #SYMBOL_LENGTH signal_in <= test_byte[i];
        end
        #SYMBOL_LENGTH signal_in <= 1'b1;
		#SYMBOL_LENGTH; // stop bit
        assert (data_out == test_byte) else begin
            $error("data_out: %b, while expecting: %b", data_out, test_byte);
            error_count = error_count + 1;
        end
    endtask

	initial begin
		$dumpfile("demo.fst");
		$dumpvars(0, test);
		$display("Test UART receiver");
        fork
            begin
                signal_in <= 1'b1;
                #SYMBOL_LENGTH;
                for (int i = 0; i < 256; i++) begin
                    send_byte(i);
                end
            end
            begin
                // test data consecutively read
                // check manually on gtkwave
                #39
                data_ready <= 1'b1;
                $display("data_ready <= 1 : %t", $time);
                #4
                data_ready <= 1'b0;
                $display("data_ready <= 0 : %t", $time);
            end
        join
        if (error_count == 0) $display("Test UART receiver passed");
        else $display("Test UART receiver failed with %d errors", error_count);
		$finish;
	end
endmodule

// baud rate: BAUD_RATE
// clock freq: CLOCK_FREQ
// cycles_per_bit: CLOCK_FREQ / BAUD_RATE
// sample_index: (cycles_per_bit - 1) >> 1, assume cycles_per_bit > 0
// sample_count
// DATA_BITS: 8
// STOP_BITS: 1, 2, 1.5
// previous_data
// current_data
// drop: previous_data & ~current_data

// is_active: 

// baud rate: 115200
// what if we set the baud rate to 1?
// then we need to sample at every cycle.
// so the sample_index is MAX_COUNT
module uart_receiver
    #(
        parameter CYCLES_PER_SYMBOL = 125_000_000 / 115_200,
        parameter DATA_BITS = 8
    )
    (
        input clk,
        input signal_in,
        input data_ready, // sink is ready to accept data
        output reg [0:7] data_out,
        output reg data_valid // data is valid from source
    );
	localparam MAX_COUNT = CYCLES_PER_SYMBOL;
	localparam SAMPLE_INDEX = (MAX_COUNT - 1) >> 1;

	integer count = 0;
    wire sample_pulse = count == SAMPLE_INDEX;

    localparam START_BITS = 1;
    localparam STOP_BITS = 1; // practically could be 1, 1.5, 2. But we only care about the first sample of the stop bit.
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
		count <= (count + 1 == MAX_COUNT) ? 0 : count + 1;
	end

    reg [0:MAX_SAMPLE_COUNT-1] buffer;

    always @(posedge clk) begin
        if (~scanning & ~signal_in) begin
            scanning <= 1'b1;
        end
        if (data_valid & data_ready) begin
            data_valid <= 1'b0;
        end
        if (do_sample) begin
            buffer[sample_count] <= signal_in;
            if (sample_count == MAX_SAMPLE_COUNT - 1) begin
                scanning <= 1'b0;
                data_out <= {buffer[8], buffer[7], buffer[6], buffer[5], buffer[4], buffer[3], buffer[2], buffer[1]};
                data_valid <= 1'b1;
            end
            if (sample_count == MAX_SAMPLE_COUNT - 1)
                sample_count <= 0;
            else
                sample_count <= sample_count + 1;
        end
    end

endmodule
