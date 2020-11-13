module matrix_rom #(parameter M = 256, N = 128, MEM_INIT_FILE = "")
   (input clk,
    input [7:0] r_addr,
    output [N-1:0] r_data);

   reg [N-1:0] ram[0:M-1];
   reg [7:0] r_addr_reg;

   initial begin
      if (MEM_INIT_FILE != "") begin
	 $readmemh(MEM_INIT_FILE, ram);
      end
   end

   always @(posedge clk) begin
      r_addr_reg <= r_addr;
   end

   assign r_data = ram[r_addr_reg];

endmodule

module matmlt #(parameter M = 256, N = 128)
   (input clk,
    input rst,
    input [N-1:0] x_in,
    output reg [M-1:0] mlt_out,
    input req_valid,
    output reg req_ready,
    output reg req_busy,
    output reg res_valid,
    input res_ready);

   reg [8:0] i;
   wire ma_bit;

   reg [3:0] state;
   localparam S_IDLE = 1;
   localparam S_LOOP = 2;
   localparam S_POST = 3;

   wire [7:0] r_addr;
   wire [N-1:0] r_data;

   matrix_rom #(.MEM_INIT_FILE("./PublicMatrix.dat"))
     A(.clk(clk),
       .r_addr(r_addr),
       .r_data(r_data));

   assign r_addr = i[7:0];
   assign ma_bit = ^(r_data & x_in);
   
   always @(posedge clk) begin
      if (rst) begin
         req_ready <= 0;
         res_valid <= 0;
         req_busy <= 0;
	 state <= S_IDLE;
      end
      else if (state == S_IDLE) begin
	 i <= 0;
	 mlt_out <= 0;
         if (req_valid) begin
            req_ready <= 1;
            req_busy <= 1;
            state <= S_LOOP;
         end
      end
      else if (state == S_LOOP) begin
	 if (i == M) begin
	    res_valid <= 1;
	    req_busy <= 0;
	    state <= S_POST;
	 end
	 mlt_out <= { ma_bit, mlt_out[M-1:1] };
	 i <= i + 1;
      end
      else if (state == S_POST) begin
         if (res_ready) begin
            res_valid <= 0;
            state <= S_IDLE;
         end
      end
   end // always @ (posedge clk)
	 
endmodule    
