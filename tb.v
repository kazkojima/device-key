`timescale 1 ns / 1 ps

module testbench;
   reg clk;

   always #5 clk = (clk === 1'b0);

   initial
     begin
        state = 0;
	rst = 1'b1;
	rst_count = 0;
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);

        repeat (16) begin
           repeat (40000) @(posedge clk);
           $display("+40000 cycles");
        end
        $finish;
     end

   reg rst;

   reg [127:0] trng_out;
   reg [255:0] pub_b;

   wire [255:0] sha3_out;
   wire sha3_req_ready, sha3_req_busy, sha3_res_valid;
   reg sha3_res_ready, sha3_req_valid;

   wire [255:0] rop_e_v;
   wire [7*256-1:0] rop_co_v;
   wire puf_req_ready, puf_req_busy, puf_res_valid;
   reg puf_res_ready, puf_req_valid;

   wire [255:0] mlt_out;
   wire mlt_req_ready, mlt_req_busy, mlt_res_valid;
   reg mlt_res_ready, mlt_req_valid;

   reg [255:0] v_in;
   wire [127:0] s_out;
   wire gj_req_ready, gj_req_busy, gj_res_valid;
   reg gj_res_ready, gj_req_valid;

//   wire refclk;

//   pll_12_50 pll_inst(clk, clk);

    ro_pair_puf #(.NROP(256), .ACC(7), .NDLY(4), .NSTOP(512))
     puf(.clk(clk), .rst(rst),
	 .e_v(rop_e_v),
	 .co_v(rop_co_v),
	 .req_valid(puf_req_valid),
	 .req_ready(puf_req_ready),
	 .req_busy(puf_req_busy),
	 .res_valid(puf_res_valid),
	 .res_ready(puf_res_ready));

   matmlt #(.M(256), .N(128))
     mm0(.clk(clk), .rst(rst),
      .x_in(trng_out),
      .mlt_out(mlt_out),
      .req_valid(mlt_req_valid),
      .req_ready(mlt_req_ready),
      .req_busy(mlt_req_busy),
      .res_valid(mlt_res_valid),
      .res_ready(mlt_res_ready));

   gjelim #(.M(256), .N(128), .ACC(7))
     gj0(.clk(clk), .rst(rst),
      .x_v(v_in), // b - e
      .co_v(rop_co_v),
      .s(s_out),
      .req_valid(gj_req_valid),
      .req_ready(gj_req_ready),
      .req_busy(gj_req_busy),
      .res_valid(gj_res_valid),
      .res_ready(gj_res_ready));

   sha3 md0(.clk(clk), .rst(rst),
	    .md_in(trng_out),
	    .md_out(sha3_out),
	    .req_valid(sha3_req_valid),
	    .req_ready(sha3_req_ready),
	    .req_busy(sha3_req_busy),
	    .res_valid(sha3_res_valid),
	    .res_ready(sha3_res_ready));

   reg [3:0] rst_count;

   // rst
   always @(posedge clk) begin
      if (&rst_count)
	rst <= 0;
      else
	rst_count <= rst_count + 1;
   end

   // Matmlt - PUF - GJElim
   reg [4:0] state;
   localparam S_INIT = 1;
   localparam S_MLT_START = 2;
   localparam S_MLT_WAIT = 3;
   localparam S_MLT_POST = 4;
   localparam S_MLT_END = 5;
   localparam S_PUF_START = 6;
   localparam S_PUF_WAIT = 7;
   localparam S_PUF_POST = 8;
   localparam S_PUF_END = 9;
   localparam S_GJ_START = 10;
   localparam S_GJ_WAIT = 11;
   localparam S_GJ_POST = 12;
   localparam S_GJ_END = 13;
   localparam S_END = 14;

   always @(posedge clk) begin
      if (rst) begin
	 mlt_res_ready <= 0;
	 puf_res_ready <= 0;
	 gj_res_ready <= 0;
	 state <= S_INIT;
	 mlt_req_valid <= 1;
	 puf_req_valid <= 0;
	 gj_req_valid <= 0;
      end
      else if (state == S_INIT) begin
	 mlt_res_ready <= 0;
	 mlt_req_valid <= 1;
	 state <= S_MLT_START;
      end
      else if (state == S_MLT_START) begin
	 if (mlt_req_ready) begin
	    state <= S_MLT_WAIT;
	 end
      end
      else if (state == S_MLT_WAIT) begin
	 mlt_req_valid <= 0;
	 if (mlt_res_valid) begin
	    state <= S_MLT_POST;
	 end
      end
      else if (state == S_MLT_POST) begin
	 $display($time,,,"mlt_out=%x OK", mlt_out);
	 pub_b <= mlt_out;
	 mlt_res_ready <= 1;
	 state <= S_MLT_END;
      end
      else if (state == S_MLT_END) begin
	 mlt_res_ready <= 0;
	 // Init PUF
	 puf_res_ready <= 0;
	 puf_req_valid <= 1;
	 state <= S_PUF_START;
      end
      else if (state == S_PUF_START) begin
	 if (puf_req_ready) begin
	    state <= S_PUF_WAIT;
	 end
      end
      else if (state == S_PUF_WAIT) begin
	 puf_req_valid <= 0;
	 if (puf_res_valid) begin
	    state <= S_PUF_POST;
	 end
      end
      else if (state == S_PUF_POST) begin
	 pub_b <= pub_b ^ rop_e_v;
	 puf_res_ready <= 1;
	 state <= S_PUF_END;
	 end
      else if (state == S_PUF_END) begin
	 puf_res_ready <= 0;
	 // Init GJ
	 v_in <= pub_b ^ rop_e_v;
	 gj_res_ready <= 0;
	 gj_req_valid <= 1;
	 state <= S_GJ_START;
      end
      else if (state == S_GJ_START) begin
	 if (gj_req_ready) begin
	    state <= S_GJ_WAIT;
	 end
      end
      else if (state == S_GJ_WAIT) begin
	 gj_req_valid <= 0;
	 if (gj_res_valid) begin
	    state <= S_GJ_POST;
	 end
      end
      else if (state == S_GJ_POST) begin
	 if (s_out == trng_out) begin
	    $display($time,,,"s_out=%x OK", s_out);
	 end
	 gj_res_ready <= 1;
	 state <= S_GJ_END;
	 end
      else if (state == S_GJ_END) begin
	 gj_res_ready <= 0;
	 state <= S_END;
      end
      else if (state == S_END) begin
	 // loop for test
	 state <= S_END;
      end
   end

   // SHA3
   reg [3:0] sha3_state = 0;
   localparam S_SHA3_INIT = 4;
   localparam S_SHA3_START = 5;
   localparam S_SHA3_WAIT = 6;
   localparam S_SHA3_POST = 7;
   localparam S_SHA3_END = 8;

   always @(posedge clk) begin
      if (rst) begin
	 sha3_state <= S_SHA3_INIT;
	 sha3_res_ready <= 0;
	 // for test
	 sha3_req_valid <= 1;
	 trng_out <= 128'h139871fcaa59a6eab6afb399292871e9;
      end
      else if (sha3_state == S_SHA3_INIT) begin
	 sha3_res_ready <= 0;
	 sha3_req_valid <= 1;
	 sha3_state <= S_SHA3_START;
      end
      else if (sha3_state == S_SHA3_START) begin
	 if (sha3_req_ready) begin
	    sha3_state <= S_SHA3_WAIT;
	 end
      end
      else if (sha3_state == S_SHA3_WAIT) begin
	 sha3_req_valid <= 0;
	 if (sha3_res_valid) begin
	    sha3_state <= S_SHA3_POST;
	 end
      end
      else if (sha3_state == S_SHA3_POST) begin
	 $display($time,,,"sha3_out=%x", sha3_out);
	 sha3_res_ready <= 1;
	 sha3_state <= S_SHA3_END;
	 end
      else if (sha3_state == S_SHA3_END) begin
	 // loop for test
	 sha3_state <= S_SHA3_END;
      end
   //$display($time,,,"state=%d rst=%d", state, rst);
   end

endmodule // testbench
