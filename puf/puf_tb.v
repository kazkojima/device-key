// A dummy module for testbench.

module ro_pair_puf
  #(parameter NROP = 256, ACC = 7, NDLY = 4, NSTOP = 512)
   (input rst,
    input clk,
    output [NROP-1:0] e_v,
    output [ACC*NROP-1:0] co_v,
    input req_valid,
    output reg req_ready,
    output reg req_busy,
    output reg res_valid,
    input res_ready);

   reg [3:0] state;
   reg en;
   reg [11:0] count;

   localparam S_IDLE = 2;
   localparam S_START = 3;
   localparam S_MEAS = 4;
   localparam S_POST = 5;

   // Only for NROP = 256, ACC = 7.
   assign e_v = 256'h69070dda01975c8c120c3aada1b282394e7f032fa9cf32f4cb2259a0897dfc04;
   assign co_v = 1792'h7d8110490416f758dba97b8998ac251f584694e8f3b705400264f84ba6778b3183c690fb7c978e922e9b96753d920d9320fb6db5087afef46eb647530875b1e5d44c25c050368e25f77fda264893403c7c77578209c03ca436dd09441a1882141406b4d17e184db234a40968348d6c36731ea0f7493e3e2fb66f9425b93de1048adaa61706908fc3607e6b653edfc146ed3f2cdc8c84674bfb6c77f4e76dd2380b444511ef1dbd906342447a86137f49aa45aab5ae248a2c22e754e170f1cee6ab0387a22217091f552a63464135e88c5a1ba552b33caffd9093b80705f629bb;

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
