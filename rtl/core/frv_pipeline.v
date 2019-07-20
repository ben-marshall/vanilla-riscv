
//
// module: frv_pipeline
//
//  The top level of the CPU data pipeline
//
module frv_pipeline (

input               g_clk           , // global clock
input               g_resetn        , // synchronous reset

`ifdef FORMAL
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

output wire [XL:0]  trs_pc          , // Trace program counter.
output wire [31:0]  trs_instr       , // Trace instruction.
output wire         trs_valid       , // Trace output valid.

output wire         imem_cen        , // Chip enable
output wire         imem_wen        , // Write enable
input  wire         imem_error      , // Error
input  wire         imem_stall      , // Memory stall
output wire [3:0]   imem_strb       , // Write strobe
output wire [31:0]  imem_addr       , // Read/Write address
input  wire [31:0]  imem_rdata      , // Read data
output wire [31:0]  imem_wdata      , // Write data

output wire         dmem_cen        , // Chip enable
output wire         dmem_wen        , // Write enable
input  wire         dmem_error      , // Error
input  wire         dmem_stall      , // Memory stall
output wire [3:0]   dmem_strb       , // Write strobe
output wire [31:0]  dmem_addr       , // Read/Write address
input  wire [31:0]  dmem_rdata      , // Read data
output wire [31:0]  dmem_wdata        // Write data

);

// Value taken by the PC on a reset.
parameter FRV_PC_RESET_VALUE = 32'h8000_0000;

// Use a BRAM/DMEM friendly register file?
parameter BRAM_REGFILE = 0;

// Use buffered pipeline handshake protocol?
parameter BUFFER_HANDSHAKE = 0;

// Common core parameters and constants
`include "frv_common.vh"

// -------------------------------------------------------------------------

wire        cf_req     ; // Control flow change request
wire [XL:0] cf_target  ; // Control flow change destination
wire        cf_ack     ; // Control flow change acknolwedge

//
// Front-end register pipeline control.
wire        s2_p_valid ; // Pipeline control signals
wire        s2_p_busy  ; // Pipeline control signals

//
// Outputs from front-end pipeline register.
wire [ 4:0] s2_rd      ; // Destination register address
wire [ 4:0] s2_rs1     ; // Source register address 1
wire [ 4:0] s2_rs2     ; // Source register address 2
wire [31:0] s2_imm     ; // Decoded immediate
wire [31:0] s2_pc      ; // Program counter
wire [ 4:0] s2_uop     ; // Micro-op code
wire [ 4:0] s2_fu      ; // Functional Unit
wire        s2_trap    ; // Raise a trap?
wire [ 7:0] s2_opr_src ; // Operand sources for dispatch stage.
wire [ 1:0] s2_size    ; // Size of the instruction.
wire [31:0] s2_instr   ; // The instruction word

wire        csr_en     ; // CSR Access Enable
wire        csr_wr     ; // CSR Write Enable
wire        csr_wr_set ; // CSR Write - Set
wire        csr_wr_clr ; // CSR Write - Clear
wire [11:0] csr_addr   ; // Address of the CSR to access.
wire [XL:0] csr_wdata  ; // Data to be written to a CSR
wire [XL:0] csr_rdata  ; // CSR read data

wire [XL:0] csr_mepc   ; // Current MEPC.
wire [XL:0] csr_mtvec  ; // Current MTVEC.

wire        exec_mret  ; // MRET instruction executed.

wire        trap_cpu   ; // A trap occured due to CPU
wire        trap_int   ; // A trap occured due to interrupt
wire [ 5:0] trap_cause ; // Cause code for the trap.
wire [XL:0] trap_mtval ; // Value associated with the trap.
wire [XL:0] trap_pc    ; // PC value associated with the trap.

// -------------------------------------------------------------------------


//
// instance : frv_pipeline_front
//
//  Front-end of the pipeline. Responsible for instruction fetch and decode.
//
frv_pipeline_front i_pipeline_front(
.g_clk       (g_clk       ), // global clock
.g_resetn    (g_resetn    ), // synchronous reset
.cf_req      (cf_req      ), // Control flow change request
.cf_target   (cf_target   ), // Control flow change destination
.cf_ack      (cf_ack      ), // Control flow change acknolwedge
.imem_cen    (imem_cen    ), // Chip enable
.imem_wen    (imem_wen    ), // Write enable
.imem_error  (imem_error  ), // Error
.imem_stall  (imem_stall  ), // Memory stall
.imem_strb   (imem_strb   ), // Write strobe
.imem_addr   (imem_addr   ), // Read/Write address
.imem_rdata  (imem_rdata  ), // Read data
.imem_wdata  (imem_wdata  ), // Write data
.s2_p_valid  (s2_p_valid  ), // Pipeline control signals
.s2_p_busy   (s2_p_busy   ), // Pipeline control signals
.s2_rd       (s2_rd       ), // Destination register address
.s2_rs1      (s2_rs1      ), // Source register address 1
.s2_rs2      (s2_rs2      ), // Source register address 2
.s2_imm      (s2_imm      ), // Decoded immediate
.s2_pc       (s2_pc       ), // Program counter
.s2_uop      (s2_uop      ), // Micro-op code
.s2_fu       (s2_fu       ), // Functional Unit
.s2_trap     (s2_trap     ), // Raise a trap?
.s2_opr_src  (s2_opr_src  ), // Operand sources for dispatch stage.
.s2_size     (s2_size     ), // Size of the instruction.
.s2_instr    (s2_instr    )  // The instruction word.
);


//
// instance: frv_pipeline_back
//
//  The backend of the instruction execution pipeline. Responsible for
//  gathering instruction operands, dispatching them to execute and
//  writing back their results.
//
frv_pipeline_back #(
.BRAM_REGFILE(BRAM_REGFILE)
) i_pipeline_back(
.g_clk        (g_clk        ), // global clock
.g_resetn     (g_resetn     ), // synchronous reset
.s2_p_busy    (s2_p_busy    ), // Can this stage accept new inputs?
.s2_p_valid   (s2_p_valid   ), // Is this input valid?
.s2_rd        (s2_rd        ), // Destination register address
.s2_rs1       (s2_rs1       ), // Source register address 1
.s2_rs2       (s2_rs2       ), // Source register address 2
.s2_imm       (s2_imm       ), // Decoded immediate
.s2_pc        (s2_pc        ), // Program counter
.s2_uop       (s2_uop       ), // Micro-op code
.s2_fu        (s2_fu        ), // Functional Unit
.s2_trap      (s2_trap      ), // Raise a trap?
.s2_opr_src   (s2_opr_src   ), // Operand sources for dispatch stage.
.s2_size      (s2_size      ), // Size of the instruction.
.s2_instr     (s2_instr     ), // The instruction word
.cf_req       (cf_req       ), // Control flow change request
.cf_target    (cf_target    ), // Control flow change target
.cf_ack       (cf_ack       ), // Control flow change acknowledge.
.trap_cpu     (trap_cpu     ), // A trap occured due to CPU
.trap_int     (trap_int     ), // A trap occured due to interrupt
.trap_cause   (trap_cause   ), // Cause of a trap.
.trap_mtval   (trap_mtval   ), // Value associated with the trap.
.trap_pc      (trap_pc      ), // PC value associated with the trap.
.csr_mepc     (csr_mepc     ), // Current MEPC.
.csr_mtvec    (csr_mtvec    ), // Current MTVEC.
.csr_en       (csr_en       ), // CSR Access Enable
.csr_wr       (csr_wr       ), // CSR Write Enable
.csr_wr_set   (csr_wr_set   ), // CSR Write - Set
.csr_wr_clr   (csr_wr_clr   ), // CSR Write - Clear
.csr_addr     (csr_addr     ), // Address of the CSR to access.
.csr_wdata    (csr_wdata    ), // Data to be written to a CSR
.csr_rdata    (csr_rdata    ), // CSR read data
.trs_pc       (trs_pc       ), // Trace program counter.
.trs_instr    (trs_instr    ), // Trace instruction.
.trs_valid    (trs_valid    ), // Trace output valid.
.dmem_cen     (dmem_cen     ), // Chip enable
.dmem_wen     (dmem_wen     ), // Write enable
.dmem_error   (dmem_error   ), // Error
.dmem_stall   (dmem_stall   ), // Memory stall
.dmem_strb    (dmem_strb    ), // Write strobe
.dmem_addr    (dmem_addr    ), // Read/Write address
.dmem_rdata   (dmem_rdata   ), // Read data
.dmem_wdata   (dmem_wdata   )  // Write data
);

//
// instance: frv_csrs
//
//  Responsible for keeping control/status registers up to date.
//
frv_csrs i_csrs (
.g_clk            (g_clk            ), // global clock
.g_resetn         (g_resetn         ), // synchronous reset
.csr_en           (csr_en           ), // CSR Access Enable
.csr_wr           (csr_wr           ), // CSR Write Enable
.csr_wr_set       (csr_wr_set       ), // CSR Write - Set
.csr_wr_clr       (csr_wr_clr       ), // CSR Write - Clear
.csr_addr         (csr_addr         ), // Address of the CSR to access.
.csr_wdata        (csr_wdata        ), // Data to be written to a CSR
.csr_rdata        (csr_rdata        ), // CSR read data
.csr_mepc         (csr_mepc         ), // Current MEPC.
.csr_mtvec        (csr_mtvec        ), // Current MTVEC.
.exec_mret        (exec_mret        ), // MRET instruction executed.
.trap_cpu         (trap_cpu         ), // A trap occured due to CPU
.trap_int         (trap_int         ), // A trap occured due to interrupt
.trap_cause       (trap_cause       ), // Cause of a trap.
.trap_mtval       (trap_mtval       ), // Value associated with the trap.
.trap_pc          (trap_pc          )  // PC value associated with the trap.
);

endmodule

