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
