
ARCH=ecp5
DEVICE=um5g-85k
PACKAGE=CABGA381
PINCONSTRAINTS=$(ARCH)/ecp5-evn.lpf
BITSTREAM=top_ecp5.svf

#QUIET=-q
#QUIET=--verbose --debug

.PHONY: all prog sim clean

.PRECIOUS: %.json %.asc %.bin %.rpt %.txtcfg

KECCAK_DIRS := sha3-fpga/freecores-sha3/low_throughput_core/rtl
KECCAK_RTL := rconst.v round.v f_permutation.v
KECCAK_SRC := $(foreach f,$(KECCAK_RTL),$(KECCAK_DIRS)/$(f))
SHA3_SRC := sha3-fpga/sha3.v
PUF_SRC := puf/puf.v
MAT_DIRS := matrix
MAT_RTL := matmlt.v matram.v matrom.v
MAT_SRC := $(foreach f,$(MAT_RTL),$(MAT_DIRS)/$(f))
GJ_SRC := gj/gjelim.v
PLL_SRC := ecp5/pll.v

PUF_TB_SRC := puf/puf_tb.v

all: $(BITSTREAM)

prog: $(BITSTREAM)
	openocd -f $(ARCH)/ecp5-evn.openocd.conf -c "transport select jtag; init; svf progress quiet $<; exit"


clean:
	-rm -f *.json
	-rm -f *.asc
	-rm -f *.bin
	-rm -f *.rpt
	-rm -f *.txtcfg
	-rm -f *.svf
	-rm -f *_tb.test
	-rm -f *.vvp
	-rm -f *.vcd
	-rm -f *.out
	-rm -f *.log
	-rm -f *~

top_$(ARCH).json: top.v $(SHA3_SRC) $(KECCAK_SRC) $(PUF_SRC) $(MAT_SRC) $(GJ_SRC) $(PLL_SRC)

tb.vvp: tb.v $(SHA3_SRC) $(KECCAK_SRC) $(PUF_TB_SRC) $(MAT_SRC) $(GJ_SRC)
	iverilog -s testbench -o $@ $^

sim: tb.vvp
	vvp -N $<
	gtkwave testbench.vcd soc.gtkw

%_ecp5.json: %.v
	yosys -Q $(QUIET) -p 'synth_ecp5 -nomux -top $(subst .v,,$<) -json $@' $^

%_ecp5.txtcfg: %_ecp5.json
	nextpnr-ecp5 $(QUIET) -l $(subst .json,,$<)-pnr.log --ignore-loops --placer sa --$(DEVICE) --package $(PACKAGE) --lpf $(PINCONSTRAINTS) --json $< --textcfg $@

%_ecp5.svf: %_ecp5.txtcfg
	ecppack --svf $@ $<
