%.fst: %.vvp
	vvp $< -fst

%.vvp: %.v
	iverilog -g2012 -o $@ $<
