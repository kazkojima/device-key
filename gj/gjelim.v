module matrix_ram #(parameter M = 256, N = 128, MEM_INIT_FILE = "")
   (input clk,
    input wr_en,
    input [7:0] w_addr,
    input [7:0] r_addr,
    input [N:0] w_data,
    output [N:0] r_data);

   reg [N:0] ram[0:M-1];
   reg [7:0] r_addr_reg;

   initial begin
      if (MEM_INIT_FILE != "") begin
	 $readmemh(MEM_INIT_FILE, ram);
      end
   end

   always @(posedge clk) begin
      r_addr_reg <= r_addr;
      if (wr_en) begin
	 ram[w_addr] <= w_data;
      end
   end

   assign r_data = ram[r_addr_reg];

endmodule // matrix_ram

module gjelim #(parameter M = 256, N = 128, ACC = 7)
   (input clk,
    input rst,
    input [M-1:0] x_v, // b - e
    input [ACC*M-1:0] co_v,
    output reg [N-1:0] s,
    input req_valid,
    output reg req_ready,
    output reg req_busy,
    output reg res_valid,
    input res_ready);

   reg [7:0] perm [M-1:0];
   reg [N-1:0] mask_j;
   reg [M-1:0] done, mask_i, mask_idx;
   wire [7:0] r_addr, w_addr;
   reg [N:0] w_data;
   wire [N:0] r_data;
   reg wr_en;
   reg [N:0] row;
   reg [N:0] cand;
   reg [8:0] i, idx;
   reg [7:0] j;
   reg [ACC-1:0] m, c;
   wire [ACC-1:0] co [0:M-1];

   reg [3:0] state;
   localparam S_IDLE = 1;
   localparam S_PRELOAD_STEP1 = 2;
   localparam S_PRELOAD_STEP2 = 3;
   localparam S_PRELOAD_STEP3 = 4;
   localparam S_ELIM_STEP1 = 5;
   localparam S_ELIM_STEP2 = 6;
   localparam S_ELIM_STEP3 = 7;
   localparam S_ELIM_STEP4 = 8;
   localparam S_ELIM_STEP5 = 9;
   localparam S_ELIM_STEP6 = 10;
   localparam S_POST_STEP1 = 11;
   localparam S_POST_STEP2 = 12;
   localparam S_POST_WAIT = 13;

   reg [3:0] m_state;
   localparam M_RM = 1;
   localparam M_W = 2;
   localparam M_E = 3;

   matrix_ram #(.MEM_INIT_FILE("./PublicMatrix.dat"))
     xA(.clk(clk),
	.wr_en(wr_en),
	.w_addr(w_addr),
	.r_addr(r_addr),
	.w_data(w_data),
	.r_data(r_data));

   assign r_addr = (state == S_ELIM_STEP4 || state == S_POST_STEP1) ?
		   idx[7:0] : i[7:0];
   assign w_addr = i[7:0];
   
   genvar b;

   generate
      for(b=0; b<M; b=b+1)
	begin : L0
	   assign co[b] = co_v[b*ACC+ACC-1:b*ACC];
	end
   endgenerate
       
   always @(posedge clk) begin
      if (rst) begin
         req_ready <= 0;
         res_valid <= 0;
         req_busy <= 0;
	 wr_en <= 0;
	 state <= S_IDLE;
      end
      else if (state == S_IDLE) begin
	 i <= 0;
	 mask_i <= 1;
	 j <= 0;
	 mask_j <= 1;
	 mask_idx <= 0;
	 done <= 0;
	 s <= 0;
         if (req_valid) begin
            req_ready <= 1;
            req_busy <= 1;
            state <= S_PRELOAD_STEP1;
         end
      end
      else if (state == S_PRELOAD_STEP1) begin
	 if (i == M) begin
	    m <= 0;
	    idx <= 0;
	    i <= 0;
	    mask_i <= 1;
	    m_state <= M_RM;
	    state <= S_ELIM_STEP1;
	 end
	 else begin
	    m_state <= M_RM;
	    state <= S_PRELOAD_STEP2;
	 end
      end
      else if (state == S_PRELOAD_STEP2) begin
	 perm[i] <= 0;
	 if (m_state == M_RM) begin
	    m_state <= M_E;
	 end
	 else if (m_state == M_E) begin
	    // Read-modify-write
	    w_data <= { ((x_v & mask_i) ? 1'b1 :1'b0), r_data[N-1:0] };
	    m_state <= M_RM;
	    state <= S_PRELOAD_STEP3;
	 end
      end
      else if (state == S_PRELOAD_STEP3) begin
	 if (m_state == M_RM) begin
	    //$display("i %d w_data %x", i, w_data);
	    wr_en <= 1;
	    m_state <= M_W;
	 end
	 else if (m_state == M_W) begin
	    wr_en <= 0;
	    m_state <= M_E;
	 end
	 else if (m_state == M_E) begin
	    m_state <= M_RM;
	    i <= i + 1;
	    mask_i <= { mask_i[M-2:0], 1'b0 };
	    state <= S_PRELOAD_STEP1;
	 end
      end
      else if (state == S_ELIM_STEP1) begin
	 // For j in 1:N
	 if (j == N) begin
	    j <= 0;
	    mask_j <= 1;
	    // preload perm[0]
	    idx <= perm[0];
	    m_state <= M_RM;
	    state <= S_POST_STEP1;
	 end
	 else begin
            // Find a candidate row.
	    if (m_state == M_RM) begin
	       m_state <= M_E;
	    end
	    else if (m_state == M_E) begin
	       //$display("i %d r_data %x", i, r_data);
	       row <= r_data;
	       c <= co[i[7:0]];
	       m_state <= M_RM;
	       state <= S_ELIM_STEP2;
	    end
	 end
      end
      else if (state == S_ELIM_STEP2) begin
	 // For i in 1:M
	 if (i == M) begin
	    // Assert(mask_idx != 0);
            // Mark that row 'done' and record the index of row.
	    //$display("j=%d idx=%d", j, idx);
	    done <= done | mask_idx;
	    perm[j] <= idx;
	    i <= 0;
	    mask_i <= 1;
	    state <= S_ELIM_STEP3;
	 end
	 else begin
	    if (!(done & mask_i) && (row & mask_j) && (c > m)) begin
	       //$display("new %d>%d at %d", c, m, i);
	       m <= c;
	       idx <= i;
	       mask_idx <= mask_i;
	    end
	    else begin
	       m <= m;
	       idx <= idx;
	       mask_idx <= mask_idx;
	    end
	    i <= i + 1;
	    mask_i <= { mask_i[M-2:0], 1'b0 };
	    state <= S_ELIM_STEP1;
	 end // else: !if(i == M)
      end
      else if (state == S_ELIM_STEP3) begin
	 // For i in 1:M
	 if (i == M) begin
	    j <= j + 1;
	    mask_j <= { mask_j[N-2:0], 1'b0 };
	    m <= 0;
	    idx <= 0;
	    i <= 0;
	    mask_i <= 1;
	    state <= S_ELIM_STEP1;
	 end
	 else begin
	    if (m_state == M_RM) begin
	       m_state <= M_E;
	    end
	    else if (m_state == M_E) begin
	       row <= r_data;
	       m_state <= M_RM;
	       state <= S_ELIM_STEP4;
	    end
	 end
      end
      else if (state == S_ELIM_STEP4) begin
	 if (m_state == M_RM) begin
	    m_state <= M_E;
	 end
	 else if (m_state == M_E) begin
	    cand <= r_data;
	    m_state <= M_RM;
	    state <= S_ELIM_STEP5;
	 end
      end
      else if (state == S_ELIM_STEP5) begin
         // Eliminate rows with the candidate row.
	 //$display("??? j=%d i=%d %x %x", j, i, row, cand);
	 if (i != idx && (row & mask_j)) begin
	    w_data <= row ^ cand;
	 end
	 else begin
	    w_data <= row;
	 end
	 m_state <= M_RM;
	 state <= S_ELIM_STEP6;
      end
      else if (state == S_ELIM_STEP6) begin
	 if (m_state == M_RM) begin
	    wr_en <= 1;
	    m_state <= M_W;
	 end
	 else if (m_state == M_W) begin
	    wr_en <= 0;
	    m_state <= M_E;
	 end
	 else if (m_state == M_E) begin
	    m_state <= M_RM;
	    i <= i + 1;
	    mask_i <= { mask_i[M-2:0], 1'b0 };
	    state <= S_ELIM_STEP3;
	 end
      end
      else if (state == S_POST_STEP1) begin
	 // Output result with reordering.
	 if (j == N) begin
	    res_valid <= 1;
	    req_busy <= 0;
	    state <= S_POST_WAIT;
	 end
	 else begin
	    if (m_state == M_RM) begin
	       m_state <= M_E;
	    end
	    else if (m_state == M_E) begin
	       row <= r_data;
	       idx <= perm[j+1];
	       m_state <= M_RM;
	       state <= S_POST_STEP2;
	    end
	 end
      end
      else if (state == S_POST_STEP2) begin
	 s <= s | (row[N:N] ? mask_j : 0);
	 j <= j + 1;
	 mask_j <= { mask_j[N-2:0], 1'b0 };
	 state <= S_POST_STEP1;
      end
      else if (state == S_POST_WAIT) begin
         if (res_ready) begin
            res_valid <= 0;
            state <= S_IDLE;
         end
      end
   end // always @ (posedge CLK)
 
endmodule
