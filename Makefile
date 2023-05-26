uart_receiver.fst:

%.fst: %.vvp
	vvp $< -fst

%.vvp: %.v
	iverilog -g2012 -o $@ $<

clean:
	rm -f *.vvp *.fst
