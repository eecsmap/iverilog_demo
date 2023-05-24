module test();
	reg clk = 0;
	always #3 clk = ~clk;
	reg do_sample;
	always @(posedge clk) begin
		$display("[%t] do_sample %d", $time, do_sample);
	end
	uart_receiver ur(.clk(clk), .do_sample(do_sample));
	initial begin
		$dumpfile("demo.fst");
		$dumpvars(0, test);
		$display("hello world!");
		#90;
		$finish;
	end
endmodule

module uart_receiver(
	input clk,
	output do_sample
	);
	localparam MAX_COUNT = 4;
	localparam SAMPLE_INDEX = (MAX_COUNT - 1) >> 1;
	integer count = 0;
	assign do_sample = count == SAMPLE_INDEX;
	always @(posedge clk) begin
		$display("count: %d", count);
		count <= (count + 1 == MAX_COUNT) ? 0 : count + 1;
	end
endmodule
