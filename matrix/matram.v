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
