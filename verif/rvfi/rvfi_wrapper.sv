
//
// module: rvfi_wrapper
//
//  A wrapper around the core which allows it to interface with the
//  riscv-formal framework.
//
module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);

wire         trs_valid       ; // Trace output valid.
wire [31:0]  trs_pc          ; // Trace program counter object.
wire [31:0]  trs_instr       ; // Instruction traced out.

wire         g_resetn = !reset;

parameter XL = 31;

(*keep*) `rvformal_rand_reg         int_external; // External interrupt
(*keep*) `rvformal_rand_reg         int_software; // Software interrupt

(*keep*) wire                       imem_req  ; // Start memory request
(*keep*) wire                       imem_wen  ; // Write enable
(*keep*) wire [3:0]                 imem_strb ; // Write strobe
(*keep*) wire [XL:0]                imem_wdata; // Write data
(*keep*) wire [XL:0]                imem_addr ; // Read/Write address
(*keep*) `rvformal_rand_reg         imem_gnt  ; // request accepted
(*keep*) `rvformal_rand_reg         imem_recv ; // memory recieve response.
(*keep*) wire                       imem_ack  ; // memory ack response.
(*keep*) `rvformal_rand_reg         imem_error; // Error
(*keep*) `rvformal_rand_reg [XL:0]  imem_rdata; // Read data

(*keep*) wire                       dmem_req  ; // Start memory request
(*keep*) wire                       dmem_wen  ; // Write enable
(*keep*) wire [3:0]                 dmem_strb ; // Write strobe
(*keep*) wire [31:0]                dmem_wdata; // Write data
(*keep*) wire [31:0]                dmem_addr ; // Read/Write address
(*keep*) `rvformal_rand_reg         dmem_gnt  ; // request accepted
(*keep*) `rvformal_rand_reg         dmem_recv ; // memory recieve response.
(*keep*) wire                       dmem_ack  ; // memory ack response.
(*keep*) `rvformal_rand_reg         dmem_error; // Error
(*keep*) `rvformal_rand_reg [XL:0]  dmem_rdata; // Read data

frv_core i_dut(
.g_clk          (clock          ), // global clock
.g_resetn       (g_resetn       ), // synchronous reset
.rvfi_valid     (rvfi_valid     ),
.rvfi_order     (rvfi_order     ),
.rvfi_insn      (rvfi_insn      ),
.rvfi_trap      (rvfi_trap      ),
.rvfi_halt      (rvfi_halt      ),
.rvfi_intr      (rvfi_intr      ),
.rvfi_mode      (rvfi_mode      ),
.rvfi_rs1_addr  (rvfi_rs1_addr  ),
.rvfi_rs2_addr  (rvfi_rs2_addr  ),
.rvfi_rs1_rdata (rvfi_rs1_rdata ),
.rvfi_rs2_rdata (rvfi_rs2_rdata ),
.rvfi_rd_addr   (rvfi_rd_addr   ),
.rvfi_rd_wdata  (rvfi_rd_wdata  ),
.rvfi_pc_rdata  (rvfi_pc_rdata  ),
.rvfi_pc_wdata  (rvfi_pc_wdata  ),
.rvfi_mem_addr  (rvfi_mem_addr  ),
.rvfi_mem_rmask (rvfi_mem_rmask ),
.rvfi_mem_wmask (rvfi_mem_wmask ),
.rvfi_mem_rdata (rvfi_mem_rdata ),
.rvfi_mem_wdata (rvfi_mem_wdata ),
.trs_pc         (trs_pc         ), // Trace program counter.
.trs_instr      (trs_instr      ), // Trace instruction.
.trs_valid      (trs_valid      ), // Trace output valid.
.int_external   (int_external   ), // External interrupt trigger line.
.int_software   (int_software   ), // Software interrupt trigger line.
.imem_req       (imem_req       ), // Start memory request
.imem_wen       (imem_wen       ), // Write enable
.imem_strb      (imem_strb      ), // Write strobe
.imem_wdata     (imem_wdata     ), // Write data
.imem_addr      (imem_addr      ), // Read/Write address
.imem_gnt       (imem_gnt       ), // request accepted
.imem_recv      (imem_recv      ), // Instruction memory recieve response.
.imem_ack       (imem_ack       ), // Instruction memory ack response.
.imem_error     (imem_error     ), // Error
.imem_rdata     (imem_rdata     ), // Read data
.dmem_req       (dmem_req       ), // Start memory request
.dmem_wen       (dmem_wen       ), // Write enable
.dmem_strb      (dmem_strb      ), // Write strobe
.dmem_wdata     (dmem_wdata     ), // Write data
.dmem_addr      (dmem_addr      ), // Read/Write address
.dmem_gnt       (dmem_gnt       ), // request accepted
.dmem_recv      (dmem_recv      ), // Data memory recieve response.
.dmem_ack       (dmem_ack       ), // Data memory ack response.
.dmem_error     (dmem_error     ), // Error
.dmem_rdata     (dmem_rdata     )  // Read data
);

endmodule
