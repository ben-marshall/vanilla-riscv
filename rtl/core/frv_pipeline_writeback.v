
//
// module: frv_pipeline_writeback
//
//  Responsible for finalising all instruction writeback behaviour.
//  - Jumps/control flow changes
//  - CSR accesses
//  - GPR writeback.
//
module frv_pipeline_writeback (

input              g_clk           , // global clock
input              g_resetn        , // synchronous reset

`ifdef RVFI
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

input  wire [XL:0] rvfi_s4_rs1_rdata, // Source register data 1
input  wire [XL:0] rvfi_s4_rs2_rdata, // Source register data 2
input  wire [ 4:0] rvfi_s4_rs1_addr , // Source register address 1
input  wire [ 4:0] rvfi_s4_rs2_addr , // Source register address 2
input  wire [XL:0] rvfi_s4_mem_wdata, // Memory write data.
`endif

input  wire [ 4:0] s4_rd           , // Destination register address
input  wire [XL:0] s4_opr_a        , // Operand A
input  wire [XL:0] s4_opr_b        , // Operand B
input  wire [ 4:0] s4_uop          , // Micro-op code
input  wire [ 4:0] s4_fu           , // Functional Unit
input  wire        s4_trap         , // Raise a trap?
input  wire [ 1:0] s4_size         , // Size of the instruction.
input  wire [31:0] s4_instr        , // The instruction word
output wire        s4_busy         , // Can this stage accept new inputs?
input  wire        s4_valid        , // Are the stage inputs valid?

output wire [ 4:0] fwd_s4_rd       , // Writeback stage destination reg.
output wire [XL:0] fwd_s4_wdata    , // Write data for writeback stage.
output wire        fwd_s4_load     , // Writeback stage has load in it.
output wire        fwd_s4_csr      , // Writeback stage has CSR op in it.

output wire        gpr_wen         , // GPR write enable.
output wire [ 4:0] gpr_rd          , // GPR destination register.
output wire [XL:0] gpr_wdata       , // GPR write data.

input  wire        int_trap_req    , // Request WB stage trap an interrupt
input  wire [ 5:0] int_trap_cause  , // Cause of interrupt
output wire        int_trap_ack    , // WB stage acknowledges the taken trap.

output wire        trap_cpu        , // A trap occured due to CPU
output wire        trap_int        , // A trap occured due to interrupt
output wire [ 5:0] trap_cause      , // A trap occured due to interrupt
output wire [XL:0] trap_mtval      , // Value associated with the trap.
output wire [XL:0] trap_pc         , // PC value associated with the trap.

output wire        exec_mret       , // MRET instruction executed.

input  wire [XL:0] csr_mepc        ,
input  wire [XL:0] csr_mtvec       ,

output wire [XL:0] trs_pc          , // Trace program counter.
output wire [31:0] trs_instr       , // Trace instruction.
output wire        trs_valid       , // Trace output valid.

output wire        csr_en          , // CSR Access Enable
output wire        csr_wr          , // CSR Write Enable
output wire        csr_wr_set      , // CSR Write - Set
output wire        csr_wr_clr      , // CSR Write - Clear
output wire [11:0] csr_addr        , // Address of the CSR to access.
output wire [XL:0] csr_wdata       , // Data to be written to a CSR
input  wire [XL:0] csr_rdata       , // CSR read data

output wire        cf_req          , // Control flow change request
output wire [XL:0] cf_target       , // Control flow change target
input  wire        cf_ack          , // Control flow change acknowledge.

output wire        hold_lsu_req    , // Don't make LSU requests yet.

input  wire [31:0] mmio_rdata      , // MMIO read data
input  wire        mmio_error      , // MMIO error

input  wire        dmem_recv       , // Instruction memory recieve response.
output wire        dmem_ack        , // Data memory ack response.
input  wire        dmem_error      , // Error
input  wire [XL:0] dmem_rdata        // Read data

);


// Common core parameters and constants
`include "frv_common.vh"

// Value taken by the PC on a reset.
parameter FRV_PC_RESET_VALUE = 32'h8000_0000;

wire  pipe_progress = s4_valid && !s4_busy;

assign s4_busy = fu_cfu && cfu_busy ||
                (cf_req && !cf_ack) ||
                 fu_lsu && lsu_busy ;

// Don't make LSU memory requests until writeback stage is sure it won't
// raise an exception.
assign hold_lsu_req = cf_req || lsu_busy || trap_int;

//
// PC computation
// -------------------------------------------------------------------------

reg  [XL:0] s4_pc;
wire [XL:0] pc_plus_isize = s4_pc + {29'b0, s4_size,1'b0};

wire [XL:0] n_s4_pc       = cf_req && !trap_int ? cf_target      :
                                cfu_tgt_ld_opra ? s4_opr_a       :
                                                  pc_plus_isize  ;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        s4_pc <= FRV_PC_RESET_VALUE;
    end else if(trap_int && cf_req && cf_ack) begin
        s4_pc <= cf_target;
    end else if(pipe_progress || (cf_req && cf_ack)) begin
        s4_pc <= n_s4_pc;
    end
end

//
// Operation Decoding
// -------------------------------------------------------------------------

wire fu_alu = s4_fu[P_FU_ALU];
wire fu_mul = s4_fu[P_FU_MUL];
wire fu_lsu = s4_fu[P_FU_LSU];
wire fu_cfu = s4_fu[P_FU_CFU];
wire fu_csr = s4_fu[P_FU_CSR];

//
// Functional Unit: ALU
// -------------------------------------------------------------------------

wire        alu_gpr_wen     = fu_alu;
wire [XL:0] alu_gpr_wdata   = s4_opr_a;

//
// Functional Unit: MUL
// -------------------------------------------------------------------------

wire        mul_gpr_wen     = fu_mul;
wire [XL:0] mul_gpr_wdata   = s4_opr_a;

//
// Functional Unit: CSR
// -------------------------------------------------------------------------

reg csr_done;

wire n_csr_done = !pipe_progress && (csr_done || csr_en);

always @(posedge g_clk) begin
    if(!g_resetn) begin
        csr_done <= 1'b0;
    end else begin
        csr_done <= n_csr_done;
    end
end

assign      csr_en          = fu_csr && !csr_done;
assign      csr_wr          = fu_csr && s4_uop[CSR_WRITE];
assign      csr_wr_set      = fu_csr && s4_uop[CSR_SET  ];
assign      csr_wr_clr      = fu_csr && s4_uop[CSR_CLEAR];
assign      csr_addr        = s4_opr_b[11:0];
assign      csr_wdata       = s4_opr_a;

wire        csr_read        = fu_csr && s4_uop[CSR_READ];

wire        csr_gpr_wen     = csr_read && !csr_done;
wire [XL:0] csr_gpr_wdata   = csr_rdata;

//
// Functional Unit: CFU
// -------------------------------------------------------------------------

// Correctly predicted control flow changes
wire cfu_pt_c   = fu_cfu && s4_uop == CFU_PT_C ; // Correctly predict taken
wire cfu_pt_w   = fu_cfu && s4_uop == CFU_PT_W ; // Incorrectly predict taken
wire cfu_pnt_c  = fu_cfu && s4_uop == CFU_PNT_C; // Correctly predict not taken
wire cfu_pnt_w  = fu_cfu && s4_uop == CFU_PNT_W; // Incorrectly predict not taken

wire cfu_pred_wrong     = cfu_pt_w || cfu_pnt_w;
wire cfu_pred_correct   = cfu_pt_c || cfu_pnt_c;

// CFU just needs to write link register. Don't perform a CF change.
wire cfu_uop_link   = fu_cfu && s4_uop == CFU_LINK;

// A "normal" control flow change due to an (in)direct jump or conditional
// branch instruction.
wire cfu_tgt_reg    = fu_cfu && (s4_uop == CFU_JALR || s4_uop == CFU_LINK);
wire cfu_tgt_direct = fu_cfu &&  s4_uop == CFU_JALI ;
wire cfu_cf_taken   = cfu_pred_wrong || (cfu_tgt_reg && !cfu_uop_link);

wire cfu_tgt_ld_opra= cfu_tgt_reg || cfu_tgt_direct || cfu_pt_c || cfu_pnt_w;
wire cfu_tgt_ld_npc =                                  cfu_pt_w || cfu_pnt_c;

// "Special" control flow change instructions which jump to the current MTVEC
wire cfu_ebreak     = fu_cfu && s4_uop == CFU_EBREAK;
wire cfu_ecall      = fu_cfu && s4_uop == CFU_ECALL ;

// A trap caused by the CFU
wire cfu_trap       = cfu_ebreak || cfu_ecall;

wire cfu_mret       = fu_cfu &&  s4_uop == CFU_MRET ;

// Pulsed signal indicating to the CSRs we just returned from an M mode
// trap handler.
assign exec_mret    = cfu_mret && pipe_progress;

// Control flow change target should go to the trap handler.
wire cfu_tgt_trap   = cfu_trap || s4_trap || lsu_trap || trap_int;

// We need to write the next natural PC to a register.
wire cfu_link       = fu_cfu && (s4_uop == CFU_JALI     ||
                                 s4_uop == CFU_JALR     ||
                                 s4_uop == CFU_LINK     );

// Control flow change occuring due to anything except an interrupt.
// Separate out interrupts for easier RVFI tracking of events.
wire   cf_req_noint = cfu_cf_taken || cfu_trap || cfu_mret || s4_trap ||
                      lsu_trap     ;

// Any sort of control flow change is occuring.
assign cf_req       = cf_req_noint || trap_int  ;

// CFU operation finishing this cycle.
wire cfu_finish_now = cf_req && cf_ack;

wire [31:0] cf_target_noint = 
    {XLEN{cfu_tgt_ld_opra}}  & s4_opr_a      |
    {XLEN{cfu_tgt_ld_npc }}  & pc_plus_isize |
    {XLEN{cfu_tgt_reg    }}  & s4_opr_a      |
    {XLEN{cfu_mret       }}  & csr_mepc      ;

// Given a control flow change, this is where we are going.
assign cf_target    = 
          cfu_tgt_trap    ? csr_mtvec : cf_target_noint;

// CFU operation finished, but pipeline still stalled.
reg     cfu_done;
wire    n_cfu_done = !pipe_progress && (cfu_done || cfu_finish_now) ;

// The CFU operation is complete and the pipeline can progress.
wire    cfu_busy = fu_cfu && 
                   !(cfu_done || cfu_finish_now) &&
                   (cfu_cf_taken ||cfu_trap || cfu_mret);

always @(posedge g_clk) if(!g_resetn) begin
    cfu_done <= 1'b0;
end else begin
    cfu_done <= n_cfu_done;
end

// CFU only writes to GPRs due to a jump and link instruction.
wire cfu_gpr_wen = cfu_link;

// Always writes the "next" PC value, i.e. instruction following the jump.
wire [XL:0] cfu_gpr_wdata = pc_plus_isize;


//
// Functional Unit: LSU
// -------------------------------------------------------------------------

//
// Are we expecting an MMIO access?
wire        lsu_mmio        = fu_lsu    && s4_opr_a[4];

//
// Are we recieving a data memory response which we expected?
wire        lsu_txn_recv    = lsu_load               &&
                              dmem_recv && dmem_ack  &&
                              lsu_rsp_expected       ;

//
// Track whether we've already seen the expected memory response for the
// current writeback stage instruction.
wire        n_lsu_rsp_seen  = 
    !pipe_progress && (lsu_rsp_seen || lsu_mmio || (dmem_recv && dmem_ack));

reg         lsu_rsp_seen;

//
// Do we *expect* to see a data memory response, given the current
// instruction?
wire        lsu_rsp_expected= fu_lsu && !lsu_rsp_seen && !lsu_mmio;

//
// Only accept data memory responses if we expect them.
assign      dmem_ack    = lsu_rsp_expected;

wire        lsu_gpr_wen     = (lsu_txn_recv && !dmem_error ||
                               lsu_mmio     && !mmio_error  ) &&
                              !lsu_rsp_seen &&  lsu_load       ;

wire [XL:0] lsu_gpr_wdata   = lsu_rdata;

wire        lsu_load    = fu_lsu && s4_uop[LSU_LOAD];
wire        lsu_store   = fu_lsu && s4_uop[LSU_STORE]   ;
wire        lsu_byte    = s4_uop[2:1] == LSU_BYTE;
wire        lsu_half    = s4_uop[2:1] == LSU_HALF;
wire        lsu_word    = s4_uop[2:1] == LSU_WORD;
wire        lsu_signed  = s4_uop[LSU_SIGNED]  ;
wire [XL:0] lsu_addr    = s4_opr_b;

//
// Strobe bits communicated from memory stage
wire [ 3:0] lsu_strb    = s4_opr_a[3:0];

//
// Are we still waiting for the memory response?
wire        lsu_busy    =
    fu_lsu && !(
        lsu_rsp_seen || (dmem_recv && dmem_ack) || lsu_mmio
    );

wire [31:0] mem_rdata = lsu_mmio ? mmio_rdata : dmem_rdata;

//
// Re-arrange the byte data on a memory read response as needed.
wire [ 7: 0] rdata_b0 =
    {8{lsu_strb[0]                       }} & mem_rdata[ 7: 0] |
    {8{lsu_byte && lsu_addr[1:0] == 2'b01}} & mem_rdata[15: 8] |
    {8{lsu_byte && lsu_addr[1:0] == 2'b10}} & mem_rdata[23:16] |
    {8{lsu_half && lsu_addr[  1] == 1'b1 }} & mem_rdata[23:16] |
    {8{lsu_byte && lsu_addr[1:0] == 2'b11}} & mem_rdata[31:24] ;

wire [ 7: 0] rdata_b1 =
    {8{lsu_byte && lsu_signed            }} & {8{rdata_b0[7] }} |
    {8{lsu_half && lsu_addr[  1] == 1'b0 }} &  mem_rdata[15: 8] |
    {8{lsu_word                          }} &  mem_rdata[15: 8] |
    {8{lsu_half && lsu_addr[  1] == 1'b1 }} &  mem_rdata[31:24] ;

wire [15: 0] rdata_h1 =
    {16{lsu_byte && lsu_signed           }} & {16{rdata_b1[7]}} |
    {16{lsu_half && lsu_signed           }} & {16{rdata_b1[7]}} |
    {16{lsu_word                         }} &  mem_rdata[31:16] ;

//                         31....16,15.....8,7......0
wire [XL:0] lsu_rdata   = {rdata_h1,rdata_b1,rdata_b0};

//
// LSU Bus error? Due to MMIO or DMEM bus?
wire        lsu_b_error = lsu_rsp_expected && dmem_error && dmem_recv ||
                          lsu_mmio         && mmio_error              ;

wire        lsu_trap    = lsu_b_error;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        lsu_rsp_seen <= 1'b0;
    end else begin
        lsu_rsp_seen <= n_lsu_rsp_seen;
    end
end

//
// GPR writeback and forwarding
// -------------------------------------------------------------------------

assign gpr_rd   = s4_rd;

assign gpr_wen  = !s4_trap &&
    (csr_gpr_wen || alu_gpr_wen || lsu_gpr_wen ||
     cfu_gpr_wen || mul_gpr_wen );

assign gpr_wdata= {32{csr_gpr_wen}} & csr_gpr_wdata |
                  {32{alu_gpr_wen}} & alu_gpr_wdata |
                  {32{lsu_gpr_wen}} & lsu_gpr_wdata |
                  {32{cfu_gpr_wen}} & cfu_gpr_wdata |
                  {32{mul_gpr_wen}} & mul_gpr_wdata ;

assign fwd_s4_rd    = gpr_rd;
assign fwd_s4_wdata = gpr_wdata;
assign fwd_s4_load  = fu_lsu && lsu_load;
assign fwd_s4_csr   = fu_csr;

//
// It's a trap!
// -------------------------------------------------------------------------

// Is there a pending interrupt control flow change to be made?
reg    trap_int_pending;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        trap_int_pending <= 1'b0;
    end else if(trap_int_pending) begin
        trap_int_pending <= !(cf_req && cf_ack);
    end else begin
        trap_int_pending <= int_trap_req && !pipe_progress;
    end
end

// TODO
assign int_trap_ack = 1'b0;

// Trap occured due to CPU exception or instruction.
assign trap_cpu   = cfu_trap || lsu_trap || s4_trap;

 // A trap occured due to interrupt. trap_cpu takes priority.
assign trap_int   = (int_trap_req || trap_int_pending) &&
                    !trap_cpu && !lsu_rsp_expected;

assign trap_cause = // Cause of the trap.
    lsu_b_error && lsu_load     ? TRAP_LDACCESS :
    lsu_b_error && lsu_store    ? TRAP_STACCESS :
    cfu_ebreak                  ? TRAP_BREAKPT  :
    cfu_ecall                   ?   TRAP_ECALLM :
    trap_int                    ? int_trap_cause:
                                  s4_opr_a[5:0] ;

// TODO: Make this useful.
assign trap_mtval = 32'b0   ; // Value associated with the trap.

assign trap_pc    = s4_pc   ; // PC value associated with the trap.

//
// Instruction Tracing
// -------------------------------------------------------------------------

assign trs_pc   = s4_pc;
assign trs_instr= s4_instr;

// Trace packet valid iff:
// - The instruction has non-zero size AND
//   - The pipeline is progressing OR
//   - A control flow change finished this cycle.
assign trs_valid= 
    |s4_size && ((s4_valid && !s4_busy) || (cf_req && cf_ack && !cfu_done));


//
// RISC-V Formal
//
//  This section contains tracking and interface code used only to make sure
//  that the RVFI interface gives consistent results.
//  Typically, this just means catching and storing data which the
//  core doesn't need to keep, but that needs to be output with each
//  RVFI packet.
//
// -------------------------------------------------------------------------

`ifdef RVFI

reg  [63:0] rvfi_order_counter;
wire [63:0] n_rvfi_order_counter = rvfi_order_counter + 1;

assign rvfi_order = rvfi_order_counter;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        rvfi_order_counter <= 0;
    end else if(rvfi_valid) begin
        rvfi_order_counter <= n_rvfi_order_counter;
    end
end


//
// If GPR writeback finishes before the pipeline moves on, save what we
// wrote so we report it correctly.
reg [ 4:0] saved_gpr_waddr;
reg [XL:0] saved_gpr_wdata;
reg        use_saved_gpr_wdata;

wire       n_use_saved_gpr_wdata =
    !pipe_progress && (use_saved_gpr_wdata || gpr_wen);

always @(posedge g_clk) begin
    if(!g_resetn) begin
        use_saved_gpr_wdata <= 1'b0;
    end else begin
        use_saved_gpr_wdata <= n_use_saved_gpr_wdata;
    end
end

always @(posedge g_clk) begin
    if(!g_resetn) begin
        saved_gpr_wdata <= 0;
        saved_gpr_waddr <= 0;
    end else if(gpr_wen) begin
        saved_gpr_wdata <= gpr_wdata;
        saved_gpr_waddr <= gpr_rd   ;
    end
end

//
// If memory read transactions complete before the pipeline moves on,
// save what we read so we report it correctly.
reg [XL:0] saved_mem_rdata;
reg        use_saved_mem_rdata;

wire       n_use_saved_mem_rdata =
    !pipe_progress && (use_saved_mem_rdata || (dmem_recv && dmem_ack));

always @(posedge g_clk) begin
    if(!g_resetn) begin
        use_saved_mem_rdata <= 1'b0;
    end else begin
        use_saved_mem_rdata <= n_use_saved_mem_rdata;
    end
end

always @(posedge g_clk) begin
    if(!g_resetn) begin
        saved_mem_rdata <= 0;
    end else if(dmem_recv && dmem_ack) begin
        saved_mem_rdata <= dmem_rdata;
    end
end

//
// Track if this is the first instruction after an interrupt.

reg  intr_tracker;
wire n_intr_tracker = trap_int || intr_tracker;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        intr_tracker <= 1'b0;
    end else if(intr_tracker) begin
        intr_tracker <= !pipe_progress;
    end else if(pipe_progress) begin
        intr_tracker <= n_intr_tracker;
    end
end

//
// Assume we never get an MMIO error, because RVFI can't handle them well.
always @(posedge g_clk) begin
    assume(!mmio_error);
end

assign rvfi_valid = trs_valid;
assign rvfi_insn  = trs_instr;
assign rvfi_trap  = trap_cpu ;
assign rvfi_intr  = intr_tracker;

assign rvfi_rs1_addr = rvfi_s4_rs1_addr ;
assign rvfi_rs2_addr = rvfi_s4_rs2_addr ;
assign rvfi_rs1_rdata= rvfi_s4_rs1_rdata;
assign rvfi_rs2_rdata= rvfi_s4_rs2_rdata;

assign rvfi_rd_addr  = use_saved_gpr_wdata ? saved_gpr_waddr :
                       gpr_wen             ? gpr_rd          : 0;
assign rvfi_rd_wdata = |s4_rd && !trap_cpu ?
                       (use_saved_gpr_wdata ? saved_gpr_wdata : gpr_wdata) : 0;

assign rvfi_pc_rdata = trs_pc   ; 
assign rvfi_pc_wdata = n_s4_pc  ;

assign rvfi_mem_addr = {s4_opr_b[XL:2], 2'b00} ;
assign rvfi_mem_rmask= fu_lsu && lsu_load  ? lsu_strb : 4'b0000 ;
assign rvfi_mem_wmask= fu_lsu && lsu_store ? lsu_strb : 4'b0000 ;
assign rvfi_mem_rdata= lsu_mmio            ? mmio_rdata      :
                       use_saved_mem_rdata ? saved_mem_rdata :
                                             dmem_rdata;
assign rvfi_mem_wdata= rvfi_s4_mem_wdata;

// Constant assignments to features of RVFI not supported/relevent.
assign rvfi_halt  = 0;
assign rvfi_mode  = 0;

`endif

endmodule
