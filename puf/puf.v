// DELAY_LUTS=7 RO=120MHz
// =5 170MHz
// =4 216MHz
// =3 276MHz
// =2 345MHz
// =1 533MHz
module ro(output wire out,
	  input wire disable);
   parameter DELAY_LUTS = 1;
   
   wire chain[DELAY_LUTS+1:0];
   assign chain[0] = chain[DELAY_LUTS+1];
   assign out = chain[1];

   generate
      genvar i;
      for(i=0; i<=DELAY_LUTS; i=i+1) begin: delayline
         (* keep *) (* noglobal *)
         TRELLIS_SLICE #(.LUT0_INITVAL((i==0)?16'd1:16'd2))
         chain_lut(.F0(chain[i+1]), .A0(chain[i]),
		   .B0(disable), .C0(0), .D0(0));
      end
   endgenerate
endmodule

module dff(input d,
           input clk,
           input rst,
           output reg q,
           output qn);

   always @ (posedge clk or posedge rst)
     if (rst)
       q <= 0;
     else
       q <= d;

   assign qn = ~q;
endmodule // dff

module ripple #(parameter ACC = 5)
   (input rst,
    input clk,
    output [ACC-1:0] out);
   wire [ACC-1:0] q;
   wire [ACC-1:0] qn;

   assign out = qn;

   generate
      genvar i;
      for(i=0; i<ACC; i=i+1) begin: ripple_counter
         dff ripple_int(.d(qn[i]), .clk((i==0)?clk:q[i-1]),
			.rst(rst), .q(q[i]), .qn(qn[i]));
      end
   endgenerate
endmodule // ripple

module ro_pair #(parameter ACC = 5, NDLY = 2)
   (input rst,
    input clk,
    input en,
    output e,
    output [ACC-1:0] co);
  
   wire ro1_out, ro2_out;
   wire [ACC-1 :0] cnt1, cnt2;
   reg [ACC-1 :0] syn_cnt1, syn_cnt2;

   ro #(.DELAY_LUTS(NDLY))
   ro1(ro1_out, !en);
   ro #(.DELAY_LUTS(NDLY))
   ro2(ro2_out, !en);

   ripple #(.ACC(ACC))
   ripple1(rst, ro1_out, cnt1);
   ripple #(.ACC(ACC))
   ripple2(rst, ro2_out, cnt2);

   always @(posedge clk) begin
      if (rst) begin
	syn_cnt1 <= 0;
	syn_cnt2 <= 0;
      end
      else if (en) begin
	syn_cnt1 <= cnt1;
	syn_cnt2 <= cnt2;
      end
   end

   assign e = (syn_cnt1 > syn_cnt2)?  1'b1: 1'b0;
   assign co = e ? (syn_cnt1 - syn_cnt2) : (syn_cnt2 - syn_cnt1);
endmodule

module ro_pair_puf
  #(parameter NROP = 256, ACC = 7, NDLY = 4, NSTOP = 512)
   (input clk,
    input rst,
    output reg [NROP-1:0] e_v,
    output reg [ACC*NROP-1:0] co_v,
    input req_valid,
    output reg req_ready,
    output reg req_busy,
    output reg res_valid,
    input res_ready);

   reg [3:0] state;
   reg en;
   reg [11:0] count;

   generate
      genvar i;
      for (i=0; i<NROP; i=i+1) begin : ro_pair_instance
         ro_pair #(.ACC(ACC), .NDLY(NDLY)) ro_pair_int
	     (rst, clk, en, e_v[i], co_v[ACC*(i+1)-1:ACC*i]);
      end
   endgenerate

   localparam S_IDLE = 2;
   localparam S_START = 3;
   localparam S_MEAS = 4;
   localparam S_POST = 5;

   always @(posedge clk) begin
      if (rst) begin
         state <= S_IDLE;
         req_ready <= 0;
         res_valid <= 0;
         req_busy <= 0;
	 en <= 0;
      end
      else if (state == S_IDLE) begin
         if (req_valid == 1'b1) begin
            req_ready <= 1;
            req_busy <= 1;
            state <= S_START;
         end
      end
      else if (state == S_START) begin
         req_ready <= 0;
         en <= 1;
         count <= 0;
         state <= S_MEAS;
      end
      else if (state == S_MEAS) begin
         if (count == NSTOP) begin
	    en <= 0;
	 end
	 // Wait until ripple carry done. ACC times would be enough.
	 else if (count == NSTOP + ACC) begin
	    res_valid <= 1;
            state <= S_POST;
	 end
	 count <= count + 1;
      end
      else if (state == S_POST) begin
         if (res_ready) begin
            res_valid <= 0;
            state <= S_IDLE;
         end
      end
   end // always @ (posedge clk)

endmodule   
