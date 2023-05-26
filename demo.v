module test();
	reg clk = 0;
	always #1 clk = ~clk;
	// uart_receiver ur(.clk(clk), .do_sample(do_sample));
    reg [0:7] out;
    reg data = 1'b1;

    uart_receiver ur(
	    .clk(clk),
        .data(data),
	    .out(out)
	);
	initial begin
		$dumpfile("demo.fst");
		$dumpvars(0, test);
		$display("hello world!");
        #2
        data <= 1'b0;
        #2 data <= 1'b1;
        #2 data <= 1'b0;
        #2 data <= 1'b1;
        #2 data <= 1'b1;
        #2 data <= 1'b0;
        #2 data <= 1'b0;
        #2 data <= 1'b1;
        #2 data <= 1'b0;
        #2 data <= 1'b1;
		#90;
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
module uart_receiver(
	input clk,
    input data,
	output reg [0:7] out
	);
	localparam MAX_COUNT = 1; // one cycle per bit
	localparam SAMPLE_INDEX = (MAX_COUNT - 1) >> 1;

	integer count = 0;
    wire sample_pulse = count == SAMPLE_INDEX;

    localparam START_BITS = 1;
    localparam DATA_BITS = 8;
    localparam STOP_BITS = 1;
    localparam MAX_SAMPLE_COUNT = START_BITS + DATA_BITS + STOP_BITS;
    integer sample_count = 0;

    reg scanning = 1'b0;
    always @(posedge clk) begin
        if (~scanning & ~data) begin
            scanning <= 1'b1;
        end else if (scanning && (sample_count == MAX_SAMPLE_COUNT)) begin
            scanning <= 1'b0;
            sample_count <= 0;
        end
    end

    // ==================================================
    // drop is needed in a corner case
    // when a bit is represented by 1 cycle
    // to get the first low bit detected correctly,
    // we need to do sample on it even if is not scanning.
    // ==================================================
    reg prev_data = 1'b1;
    wire drop = prev_data & ~data;
    always @(posedge clk) begin
        prev_data <= data;
    end

	assign do_sample = sample_pulse && (scanning || drop);
	always @(posedge clk) begin
		$display("count: %d", count);
		count <= (count + 1 == MAX_COUNT) ? 0 : count + 1;
	end

    reg [0:MAX_SAMPLE_COUNT-1] buffer;

    always @(posedge clk) begin
        if (do_sample) begin
            buffer[sample_count] <= data;
            if (sample_count == MAX_SAMPLE_COUNT - 1) begin
                $display("buffer: %b", buffer);
                out <= {buffer[8], buffer[7], buffer[6], buffer[5], buffer[4], buffer[3], buffer[2], buffer[1]};
            end
            sample_count <= sample_count + 1;
        end
    end

endmodule
