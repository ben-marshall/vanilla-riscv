
//
// module: frv_cpu_axi
//
//  A wrapper around the frv_cpu core module, which bridges the SRAM
//  memory interfaces with AXI bus interfaces.
//
module frv_cpu_axi (

input               g_clk           , // global clock
input               g_resetn        , // synchronous reset

input  wire         int_external    , // External interrupt trigger line.
input  wire         int_software    , // Software interrupt trigger line.

output wire         trs_valid       , // Trace output valid.
output wire [31:0]  trs_pc          , // Trace program counter object.
output wire [31:0]  trs_instr       , // Instruction traced out.

`ifdef MRV_VERIF_TRACE

output [NRET        - 1 : 0] rvfi_valid     ,
output [NRET *   64 - 1 : 0] rvfi_order     ,
output [NRET * ILEN - 1 : 0] rvfi_insn      ,
output [NRET        - 1 : 0] rvfi_trap      ,
output [NRET        - 1 : 0] rvfi_halt      ,
output [NRET        - 1 : 0] rvfi_intr      ,
output [NRET * 2    - 1 : 0] rvfi_mode      ,

output [NRET *    5 - 1 : 0] rvfi_rs1_addr  ,
output [NRET *    5 - 1 : 0] rvfi_rs2_addr  ,
output [NRET * XLEN - 1 : 0] rvfi_rs1_rdata ,
output [NRET * XLEN - 1 : 0] rvfi_rs2_rdata ,
output [NRET *    5 - 1 : 0] rvfi_rd_addr   ,
output [NRET * XLEN - 1 : 0] rvfi_rd_wdata  ,

output [NRET * XLEN - 1 : 0] rvfi_pc_rdata  ,
output [NRET * XLEN - 1 : 0] rvfi_pc_wdata  ,

output [NRET * XLEN  - 1: 0] rvfi_mem_addr  ,
output [NRET * XLEN/8- 1: 0] rvfi_mem_rmask ,
output [NRET * XLEN/8- 1: 0] rvfi_mem_wmask ,
output [NRET * XLEN  - 1: 0] rvfi_mem_rdata ,
output [NRET * XLEN  - 1: 0] rvfi_mem_wdata ,
`endif

input         imem_aclk      ,
input         imem_aresetn   ,

output        imem_awvalid   ,
input         imem_awready   ,
output [31:0] imem_awaddr    ,
output [ 2:0] imem_awprot    ,

output        imem_wvalid    ,
input         imem_wready    ,
output [31:0] imem_wdata     ,
output [ 3:0] imem_wstrb     ,

input         imem_bvalid    ,
output        imem_bready    ,
input  [ 1:0] imem_bresp     ,

output        imem_arvalid   ,
input         imem_arready   ,
output [31:0] imem_araddr    ,
output [ 2:0] imem_arprot    ,

input         imem_rvalid    ,
output        imem_rready    ,
input  [31:0] imem_rdata     ,
input  [ 1:0] imem_rresp     ,

input         dmem_aclk      ,
input         dmem_aresetn   ,

output        dmem_awvalid   ,
input         dmem_awready   ,
output [31:0] dmem_awaddr    ,
output [ 2:0] dmem_awprot    ,

output        dmem_wvalid    ,
input         dmem_wready    ,
output [31:0] dmem_wdata     ,
output [ 3:0] dmem_wstrb     ,

input         dmem_bvalid    ,
output        dmem_bready    ,
input  [ 1:0] dmem_bresp     ,

output        dmem_arvalid   ,
input         dmem_arready   ,
output [31:0] dmem_araddr    ,
output [ 2:0] dmem_arprot    ,

input         dmem_rvalid    ,
output        dmem_rready    ,
input  [ 1:0] dmem_rresp     ,
input  [31:0] dmem_rdata      

);

parameter FRV_PC_RESET_VALUE = 32'h8000_0000;

// Use a BRAM/DMEM friendly register file?
parameter BRAM_REGFILE = 0;

parameter CSR_MTVEC_RESET_VALUE = 32'hC0000000;
parameter CSR_MVENDORID         = 32'b0;
parameter CSR_MARCHID           = 32'b0;
parameter CSR_MIMPID            = 32'b0;
parameter CSR_MHARTID           = 32'b0;

// Base address of the MMIO region
parameter   MMIO_BASE_ADDR        = 32'h0000_1000;
parameter   MMIO_BASE_MASK        = 32'hFFFF_F000;

// Address of the memory mapped MTIME register
parameter   MMIO_MTIME_ADDR       = MMIO_BASE_ADDR;
// Address of the memory mapped MTIMECMP register
parameter   MMIO_MTIMECMP_ADDR    = MMIO_BASE_ADDR + 8;
// Value of MTIMECMP register on reset.
parameter   MMIO_MTIMECMP_RESET   = 64'hFFFFFFFFFFFFFFFF;

// If set, trace the instruction word through the pipeline. Otherwise,
// set it to zeros and let it be optimised away.
parameter TRACE_INSTR_WORD = 1'b0;

//
// Instruction Memory interface
wire         i_req        ; // Start memory request
wire         i_wen        ; // Write enable
wire [3:0]   i_strb       ; // Write strobe
wire [31:0]  i_wdata      ; // Write data
wire [31:0]  i_addr       ; // Read/Write address
wire         i_gnt        ; // request accepted
wire         i_recv       ; // Instruction memory recieve response.
wire         i_ack        ; // Instruction memory ack response.
wire         i_error      ; // Error
wire [31:0]  i_rdata      ; // Read data

//
// Data Memory interface
wire         d_req        ; // Start memory request
wire         d_wen        ; // Write enable
wire [3:0]   d_strb       ; // Write strobe
wire [31:0]  d_wdata      ; // Write data
wire [31:0]  d_addr       ; // Read/Write address
wire         d_gnt        ; // request accepted
wire         d_recv       ; // Data memory recieve response.
wire         d_ack        ; // Data memory ack response.
wire         d_error      ; // Error
wire [31:0]  d_rdata      ; // Read data


//
// CPU core instance
//
frv_core #(
.BRAM_REGFILE         (BRAM_REGFILE         ),
.FRV_PC_RESET_VALUE   (FRV_PC_RESET_VALUE   ),
.TRACE_INSTR_WORD     (TRACE_INSTR_WORD     )
) i_frv_cpu (
.g_clk           (g_clk           ), // global clock
.g_resetn        (g_resetn        ), // synchronous reset
.int_external    (int_external    ), // External interrupt trigger line.
.int_software    (int_software    ), // Software interrupt trigger line.
.trs_valid       (trs_valid       ), // Trace output valid.
.trs_pc          (trs_pc          ), // Trace program counter object.
.trs_instr       (trs_instr       ), // Instruction traced out.
`ifdef RVFI
.rvfi_valid      (rvfi_valid      ),
.rvfi_order      (rvfi_order      ),
.rvfi_insn       (rvfi_insn       ),
.rvfi_trap       (rvfi_trap       ),
.rvfi_halt       (rvfi_halt       ),
.rvfi_intr       (rvfi_intr       ),
.rvfi_mode       (rvfi_mode       ),
.rvfi_rs1_addr   (rvfi_rs1_addr   ),
.rvfi_rs2_addr   (rvfi_rs2_addr   ),
.rvfi_rs1_rdata  (rvfi_rs1_rdata  ),
.rvfi_rs2_rdata  (rvfi_rs2_rdata  ),
.rvfi_rd_addr    (rvfi_rd_addr    ),
.rvfi_rd_wdata   (rvfi_rd_wdata   ),
.rvfi_pc_rdata   (rvfi_pc_rdata   ),
.rvfi_pc_wdata   (rvfi_pc_wdata   ),
.rvfi_mem_addr   (rvfi_mem_addr   ),
.rvfi_mem_rmask  (rvfi_mem_rmask  ),
.rvfi_mem_wmask  (rvfi_mem_wmask  ),
.rvfi_mem_rdata  (rvfi_mem_rdata  ),
.rvfi_mem_wdata  (rvfi_mem_wdata  ),
`endif
.imem_req      (i_req      ), // Start memory request
.imem_wen      (i_wen      ), // Write enable
.imem_strb     (i_strb     ), // Write strobe
.imem_wdata    (i_wdata    ), // Write data
.imem_addr     (i_addr     ), // Read/Write address
.imem_gnt      (i_gnt      ), // request accepted
.imem_recv     (i_recv     ), // Instruction memory recieve response.
.imem_ack      (i_ack      ), // Response acknowledge
.imem_error    (i_error    ), // Error
.imem_rdata    (i_rdata    ), // Read data
.dmem_req      (d_req      ), // Start memory request
.dmem_wen      (d_wen      ), // Write enable
.dmem_strb     (d_strb     ), // Write strobe
.dmem_wdata    (d_wdata    ), // Write data
.dmem_addr     (d_addr     ), // Read/Write address
.dmem_gnt      (d_gnt      ), // request accepted
.dmem_recv     (d_recv     ), // Instruction memory recieve response.
.dmem_ack      (d_ack      ), // Response acknowledge
.dmem_error    (d_error    ), // Error
.dmem_rdata    (d_rdata    )  // Read data
);


frv_axi_adapter #(
.INSTR_INTERFACE(1'b0),
.RSP_PRIORITY_WR(1'b1)
) i_instr_sram_axi_adapter (
.g_clk           (g_clk        ),
.g_resetn        (g_resetn     ),
.mem_axi_awvalid (imem_awvalid ),
.mem_axi_awready (imem_awready ),
.mem_axi_awaddr  (imem_awaddr  ),
.mem_axi_awprot  (imem_awprot  ),
.mem_axi_wvalid  (imem_wvalid  ),
.mem_axi_wready  (imem_wready  ),
.mem_axi_wdata   (imem_wdata   ),
.mem_axi_wstrb   (imem_wstrb   ),
.mem_axi_bvalid  (imem_bvalid  ),
.mem_axi_bready  (imem_bready  ),
.mem_axi_bresp   (imem_bresp   ),
.mem_axi_arvalid (imem_arvalid ),
.mem_axi_arready (imem_arready ),
.mem_axi_araddr  (imem_araddr  ),
.mem_axi_arprot  (imem_arprot  ),
.mem_axi_rvalid  (imem_rvalid  ),
.mem_axi_rready  (imem_rready  ),
.mem_axi_rdata   (imem_rdata   ),
.mem_axi_rresp   (imem_rresp   ),
.mem_req         (i_req        ), // Start memory request
.mem_wen         (i_wen        ), // Write enable
.mem_strb        (i_strb       ), // Write strobe
.mem_wdata       (i_wdata      ), // Write data
.mem_addr        (i_addr       ), // Read/Write address
.mem_gnt         (i_gnt        ), // request accepted
.mem_recv        (i_recv       ), // Instruction memory recieve response.
.mem_ack         (i_ack        ), // Response acknowledge
.mem_error       (i_error      ), // Error
.mem_rdata       (i_rdata      )  // Read data
);

frv_axi_adapter #(
.INSTR_INTERFACE(1'b0),
.RSP_PRIORITY_WR(1'b1)
) i_data_sram_axi_adapter (
.g_clk           (g_clk        ),
.g_resetn        (g_resetn     ),
.mem_axi_awvalid (dmem_awvalid ),
.mem_axi_awready (dmem_awready ),
.mem_axi_awaddr  (dmem_awaddr  ),
.mem_axi_awprot  (dmem_awprot  ),
.mem_axi_wvalid  (dmem_wvalid  ),
.mem_axi_wready  (dmem_wready  ),
.mem_axi_wdata   (dmem_wdata   ),
.mem_axi_wstrb   (dmem_wstrb   ),
.mem_axi_bvalid  (dmem_bvalid  ),
.mem_axi_bready  (dmem_bready  ),
.mem_axi_bresp   (dmem_bresp   ),
.mem_axi_arvalid (dmem_arvalid ),
.mem_axi_arready (dmem_arready ),
.mem_axi_araddr  (dmem_araddr  ),
.mem_axi_arprot  (dmem_arprot  ),
.mem_axi_rvalid  (dmem_rvalid  ),
.mem_axi_rready  (dmem_rready  ),
.mem_axi_rdata   (dmem_rdata   ),
.mem_axi_rresp   (dmem_rresp   ),
.mem_req         (d_req        ), // Start memory request
.mem_wen         (d_wen        ), // Write enable
.mem_strb        (d_strb       ), // Write strobe
.mem_wdata       (d_wdata      ), // Write data
.mem_addr        (d_addr       ), // Read/Write address
.mem_gnt         (d_gnt        ), // request accepted
.mem_recv        (d_recv       ), // Instruction memory recieve response.
.mem_ack         (d_ack        ), // Response acknowledge
.mem_error       (d_error      ), // Error
.mem_rdata       (d_rdata      )  // Read data
);

endmodule
