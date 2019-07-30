
//
// module: frv_pipeline_memory
//
//  Memory stage of the pipeline, responsible making memory requests.
//
module frv_pipeline_memory(

input              g_clk           , // global clock
input              g_resetn        , // synchronous reset

input  wire        flush           , // Flush this pipeline stage.

input  wire [ 4:0] s3_rd           , // Destination register address
input  wire [XL:0] s3_opr_a        , // Operand A
input  wire [XL:0] s3_opr_b        , // Operand B
input  wire [ 4:0] s3_uop          , // Micro-op code
input  wire [ 4:0] s3_fu           , // Functional Unit
input  wire        s3_trap         , // Raise a trap?
input  wire [ 1:0] s3_size         , // Size of the instruction.
input  wire [31:0] s3_instr        , // The instruction word
output wire        s3_busy         , // Can this stage accept new inputs?
input  wire        s3_valid        , // Is this input valid?

output wire [ 4:0] fwd_s3_rd       , // Writeback stage destination reg.
output wire [XL:0] fwd_s3_wdata    , // Write data for writeback stage.
output wire        fwd_s3_load     , // Writeback stage has load in it.
output wire        fwd_s3_csr      , // Writeback stage has CSR op in it.

`ifdef RVFI
input  wire [XL:0] rvfi_s3_rs1_rdata, // Source register data 1
input  wire [XL:0] rvfi_s3_rs2_rdata, // Source register data 2
input  wire [ 4:0] rvfi_s3_rs1_addr , // Source register address 1
input  wire [ 4:0] rvfi_s3_rs2_addr , // Source register address 2
output reg  [XL:0] rvfi_s4_rs1_rdata, // Source register data 1
output reg  [XL:0] rvfi_s4_rs2_rdata, // Source register data 2
output reg  [ 4:0] rvfi_s4_rs1_addr , // Source register address 1
output reg  [ 4:0] rvfi_s4_rs2_addr , // Source register address 2
output reg  [XL:0] rvfi_s4_mem_wdata, // Memory write data.
`endif

input  wire        hold_lsu_req    , // Hold LSU requests for now.

output wire        mmio_en         , // MMIO enable
output wire        mmio_wen        , // MMIO write enable
output wire [31:0] mmio_addr       , // MMIO address
output wire [31:0] mmio_wdata      , // MMIO write data

output wire        dmem_req        , // Start memory request
output wire        dmem_wen        , // Write enable
output wire [3:0]  dmem_strb       , // Write strobe
output wire [XL:0] dmem_wdata      , // Write data
output wire [XL:0] dmem_addr       , // Read/Write address
input  wire        dmem_gnt        , // request accepted

output wire [ 4:0] s4_rd           , // Destination register address
output wire [XL:0] s4_opr_a        , // Operand A
output wire [XL:0] s4_opr_b        , // Operand B
output wire [ 4:0] s4_uop          , // Micro-op code
output wire [ 4:0] s4_fu           , // Functional Unit
output wire        s4_trap         , // Raise a trap?
output wire [ 1:0] s4_size         , // Size of the instruction.
output wire [31:0] s4_instr        , // The instruction word
input  wire        s4_busy         , // Can this stage accept new inputs?
output wire        s4_valid          // Is this input valid?

);


// Base address of the memory mapped IO region.
parameter   MMIO_BASE_ADDR        = 32'h0000_1000;
parameter   MMIO_BASE_MASK        = 32'hFFFF_F000;

// Common core parameters and constants
`include "frv_common.vh"


//
// Stalling / Pipeline Progression
// -------------------------------------------------------------------------

// Input into pipeline register, which then drives s3_p_valid;
wire   p_valid   = s3_valid && !s3_busy;

// Is this stage currently busy?
assign s3_busy = p_busy                   ||
                 lsu_valid  && !lsu_ready ;

// Is the next stage currently busy?
wire   p_busy    ;

wire pipe_progress = !s3_busy && s3_valid;

//
// Operation Decoding
// -------------------------------------------------------------------------

wire fu_lsu = s3_fu[P_FU_LSU];
wire fu_csr = s3_fu[P_FU_CSR];


//
// Functional Unit Interfacing: LSU
// -------------------------------------------------------------------------

wire        lsu_valid  = fu_lsu         ; // Inputs are valid.
wire        lsu_a_error                 ; // Address error. TODO
wire        lsu_ready                   ; // Load/Store instruction complete.

wire        lsu_mmio                    ; // Is this an MMIO access?

wire        lsu_load   = s3_uop[LSU_LOAD ];
wire        lsu_store  = s3_uop[LSU_STORE];

wire [XL:0] lsu_addr   = s3_opr_a; // Memory address to access.
wire [XL:0] lsu_wdata  = s3_opr_b; // Data to write to memory.
wire        lsu_byte   = s3_uop[2:1] == LSU_BYTE;
wire        lsu_half   = s3_uop[2:1] == LSU_HALF;
wire        lsu_word   = s3_uop[2:1] == LSU_WORD;
wire        lsu_signed = s3_uop[LSU_SIGNED]  ;

wire [5:0]  lsu_cause = 
           (   lsu_load&&lsu_a_error)? TRAP_LDALIGN  :
           (lsu_store  &&lsu_a_error)? TRAP_STALIGN  :
                                        0            ;

wire [XL:0] n_s4_opr_a_lsu = {27'b0,lsu_mmio,dmem_strb};
wire [XL:0] n_s4_opr_b_lsu = lsu_addr;

//
// Trapping
// -------------------------------------------------------------------------

wire n_s4_trap   = s3_trap || (fu_lsu && lsu_a_error) ; // Raise a trap?

wire[4:0] n_s4_rd     =     s3_trap  ? s3_rd         :
                   fu_lsu&&lsu_a_error ? lsu_cause[4:0]:
                                       s3_rd         ;

//
// Next pipestage value progression.
// -------------------------------------------------------------------------

wire [XL:0] n_s4_opr_a  = lsu_valid ? n_s4_opr_a_lsu : s3_opr_a; // Operand A
wire [XL:0] n_s4_opr_b  = lsu_valid ? n_s4_opr_b_lsu : s3_opr_b; // Operand B
wire [ 4:0] n_s4_uop    = s3_uop  ; // Micro-op code
wire [ 4:0] n_s4_fu     = s3_fu   ; // Functional Unit
wire [ 1:0] n_s4_size   = s3_size ; // Size of the instruction.
wire [31:0] n_s4_instr  = s3_instr; // The instruction word

//
// Forwaring / bubbling signals.
// -------------------------------------------------------------------------

assign fwd_s3_rd    = s3_rd             ; // Stage destination reg.
assign fwd_s3_wdata = s3_opr_a          ;
assign fwd_s3_load  = fu_lsu && lsu_load; // Stage has load in it.
assign fwd_s3_csr   = fu_csr            ; // Stage has CSR op in it.

//
// Submodule instances.
// -------------------------------------------------------------------------

//
// instance: frv_lsu
//
//  Load store unit. Responsible for all data accesses.
//
frv_lsu #(
.MMIO_BASE_ADDR(MMIO_BASE_ADDR),
.MMIO_BASE_MASK(MMIO_BASE_MASK)
) i_lsu(
.g_clk       (g_clk       ), // Global clock
.g_resetn    (g_resetn    ), // Global reset.
.lsu_valid   (lsu_valid   ), // Inputs are valid.
.lsu_a_error (lsu_a_error ), // Address error.
.lsu_ready   (lsu_ready   ), // Outputs are valid / instruction complete.
.lsu_mmio    (lsu_mmio    ), // Is this an MMIO access?
.pipe_prog   (pipe_progress),// Pipeline is progressing this cycle.
.lsu_addr    (lsu_addr    ), // Memory address to access.
.lsu_wdata   (lsu_wdata   ), // Data to write to memory.
.lsu_load    (lsu_load    ), // Load instruction.
.lsu_store   (lsu_store   ), // Store instruction.
.lsu_byte    (lsu_byte    ), // Byte operation width.
.lsu_half    (lsu_half    ), // Halfword operation width.
.lsu_word    (lsu_word    ), // Word operation width.
.lsu_signed  (lsu_signed  ), // Sign extend loaded data?
.hold_lsu_req(hold_lsu_req), // Don't make LSU requests yet.
.mmio_en     (mmio_en     ), // MMIO enable
.mmio_wen    (mmio_wen    ), // MMIO write enable
.mmio_addr   (mmio_addr   ), // MMIO address
.mmio_wdata  (mmio_wdata  ), // MMIO write data
.dmem_req    (dmem_req    ), // Start memory request
.dmem_wen    (dmem_wen    ), // Write enable
.dmem_strb   (dmem_strb   ), // Write strobe
.dmem_wdata  (dmem_wdata  ), // Write data
.dmem_addr   (dmem_addr   ), // Read/Write address
.dmem_gnt    (dmem_gnt    )  // request accepted
);

//
// Pipeline Register
// -------------------------------------------------------------------------

localparam RL = 114;


wire [RL-1:0] pipe_reg_out;

wire [RL-1:0] pipe_reg_in = {
    n_s4_rd           , // Destination register address
    n_s4_opr_a        , // Operand A
    n_s4_opr_b        , // Operand B
    n_s4_uop          , // Micro-op code
    n_s4_fu           , // Functional Unit
    n_s4_trap         , // Raise a trap?
    n_s4_size         , // Size of the instruction.
    n_s4_instr          // The instruction word
};


assign {
    s4_rd             , // Destination register address
    s4_opr_a          , // Operand A
    s4_opr_b          , // Operand B
    s4_uop            , // Micro-op code
    s4_fu             , // Functional Unit
    s4_trap           , // Raise a trap?
    s4_size           , // Size of the instruction.
    s4_instr            // The instruction word
} = pipe_reg_out;

frv_pipeline_register #(
.RLEN(RL),
.BUFFER_HANDSHAKE(1'b0)
) i_mem_pipereg(
.g_clk    (g_clk            ), // global clock
.g_resetn (g_resetn         ), // synchronous reset
.i_data   (pipe_reg_in      ), // Input data from stage N
.i_valid  (p_valid          ), // Input data valid?
.o_busy   (p_busy           ), // Stage N+1 ready to continue?
.mr_data  (                 ), // Most recent data into the stage.
.flush    (flush            ), // Flush the contents of the pipeline
.o_data   (pipe_reg_out     ), // Output data for stage N+1
.o_valid  (s4_valid         ), // Input data from stage N valid?
.i_busy   (s4_busy          )  // Stage N+1 ready to continue?
);

`ifdef RVFI

always @(posedge g_clk) begin
    if(!g_resetn || flush) begin
        rvfi_s4_rs1_rdata <= 0; // Source register data 1
        rvfi_s4_rs2_rdata <= 0; // Source register data 2
        rvfi_s4_rs1_addr  <= 0; // Source register address 1
        rvfi_s4_rs2_addr  <= 0; // Source register address 2
    end else if(pipe_progress) begin
        rvfi_s4_rs1_rdata <= rvfi_s3_rs1_rdata;
        rvfi_s4_rs2_rdata <= rvfi_s3_rs2_rdata;
        rvfi_s4_rs1_addr  <= rvfi_s3_rs1_addr ;
        rvfi_s4_rs2_addr  <= rvfi_s3_rs2_addr ;
    end
end

reg [31:0] mem_wdata_store;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        rvfi_s4_mem_wdata <= 0;
    end else if(p_valid && !p_busy && dmem_req && dmem_gnt) begin
        rvfi_s4_mem_wdata <= dmem_wdata;
    end else if(p_valid && !p_busy) begin
        rvfi_s4_mem_wdata <= mem_wdata_store;
    end
end

always @(posedge g_clk) begin
    if(!g_resetn) begin
        mem_wdata_store <= 0;
    end else if(dmem_req && dmem_gnt) begin
        mem_wdata_store <= dmem_wdata;
    end
end

`endif // RVFI

endmodule
