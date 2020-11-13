module pll_12_50(input clki, output clko);
    (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
    EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOP_FPHASE(0),
        .CLKOP_CPHASE(11),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(12),
        .CLKFB_DIV(25),
        .CLKI_DIV(6),
        .FEEDBK_PATH("CLKOP")
    ) pll_i (
        .CLKI(clki),
        .CLKFB(clko),
        .CLKOP(clko),
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
    );
endmodule

`define NSTOP 12'd256
`define NROP 256
`define NDLY 4
`define ACC 7

module top(input wire clk,
	   input wire rstn,
           output wire tp0, 
           output wire tp1, 
           output wire tp2, 
 	   output wire [7:0] led);

   wire [`NROP-1:0] rop_e_v;
   wire [`ACC*`NROP-1:0] rop_co_v;
   wire req_ready, req_busy, res_valid;
   reg res_ready;

   wire refclk;

   pll_12_50 pll_inst(clk, refclk);

   ro_pair_puf #(.NROP(`NROP), .ACC(`ACC), .NDLY(`NDLY), .NSTOP(`NSTOP))
   puf(.rst(rst), .clk(refclk),
       .e_v(rop_e_v),
       .co_v(rop_co_v),
       .req_valid(1'b1),
       .req_ready(req_ready),
       .req_busy(req_busy),
       .res_valid(res_valid),
       .res_ready(res_ready));
   
   assign tp0 = &rop_e_v;
   assign tp1 = rop_e_v[0];

   reg [3:0] state;
 
   always @(posedge refclk) begin
      if (rstn == 0) begin
         rst <= 1;
         state <= 0;
      end
      if (state > 3) begin
         rst <= 0;
      end
      else begin
         state <= state + 1;
      end
      if (rst) begin
	 res_ready <= 0;
      end
      else if (state == 4) begin
	 if (res_valid) begin
            res_ready <= 1;
	    led <= ~rop_co_v[6:0];
	    state <= 5;
	 end
      end
      else if (state == 5) begin
         res_ready <= 0;
	 // loop here
      end
   end // always @ (posedge refclk)

endmodule

