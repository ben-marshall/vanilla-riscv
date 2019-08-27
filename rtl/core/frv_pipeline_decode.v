

//
// module: frv_pipeline_decode
//
//  Decode stage of the CPU, responsible for turning RISC-V encoded
//  instructions into wider pipeline encodings.
//
module frv_pipeline_decode(

input  wire        g_clk         , // global clock
input  wire        g_resetn      , // synchronous reset

input  wire        s1_valid      , // Is the input data valid?
output wire        s1_busy       , // Is this stage ready for new inputs?
input  wire [31:0] s1_data       , // Data word to decode.
input  wire        s1_error      , // Is s1_data associated with a fetch error?

input  wire        s1_flush      , // Flush pipe stage register.
input  wire        s1_bubble     , // Insert a bubble into the pipeline.
output wire [ 4:0] s1_rs1_addr   ,
output wire [ 4:0] s1_rs2_addr   ,
input  wire [XL:0] s1_rs1_rdata  ,
input  wire [XL:0] s1_rs2_rdata  ,

output wire        s1_cf_req     , // Predicted control flow change
output wire [XL:0] s1_cf_target  , // Predicted control flow change target
input  wire        s1_cf_ack     , // Predicted control flow change ack

input  wire        cf_req        , // Control flow change request
input  wire [XL:0] cf_target     , // Control flow change target
input  wire        cf_ack        , // Control flow change acknowledge.

`ifdef RVFI
output reg  [ 4:0] rvfi_s2_rs1_addr,
output reg  [ 4:0] rvfi_s2_rs2_addr,
output reg  [XL:0] rvfi_s2_rs1_data,
output reg  [XL:0] rvfi_s2_rs2_data,
`endif

output wire        s2_valid      , // Is the output data valid?
input  wire        s2_busy       , // Is the next stage ready for new inputs?
output wire [ 4:0] s2_rd         , // Destination register address
output wire [XL:0] s2_opr_a      , // Operand A
output wire [XL:0] s2_opr_b      , // Operand B
output wire [XL:0] s2_opr_c      , // Operand C
output wire        s2_cf_pred    , // Control flow prediction
output wire [ 4:0] s2_uop        , // Micro-op code
output wire [ 4:0] s2_fu         , // Functional Unit (alu/mem/jump/mul/csr)
output wire        s2_trap       , // Raise a trap?
output wire [ 1:0] s2_size       , // Size of the instruction.
output wire [31:0] s2_instr        // The instruction word

);

// Common core parameters and constants
`include "frv_common.vh"

// Value taken by the PC on a reset.
parameter FRV_PC_RESET_VALUE = 32'h8000_0000;

// If set, trace the instruction word through the pipeline. Otherwise,
// set it to zeros and let it be optimised away.
parameter TRACE_INSTR_WORD = 1'b1;

// From (buffered) pipeline register of next stage.
wire   p_s2_busy;

wire pipe_progress = s1_valid && !s1_busy;

assign s1_busy      = p_s2_busy || s1_bubble || pcf_stall;
wire   n_s2_valid   = (s1_valid || s1_bubble ) && !pcf_stall;

wire [ 4:0] n_s2_rd         ; // Destination register address
wire [XL:0] n_s2_opr_a      ; // Operand A
wire [XL:0] n_s2_opr_b      ; // Operand B
wire [XL:0] n_s2_opr_c      ; // Operand C
wire [XL:0] n_s2_imm        ; // 
wire [XL:0] n_s2_pc_imm     ; // 
wire [ 4:0] n_s2_uop        ; // Micro-op code
wire [ 4:0] n_s2_fu         ; // Functional Unit (alu/mem/jump/mul/csr)
wire        n_s2_trap       ; // Raise a trap?
wire [ 1:0] n_s2_size       ; // Size of the instruction.
wire [31:0] n_s2_instr      ; // The instruction word
wire [ 7:0] n_s2_opr_src    ; // Operand sourcing.

//
// Instruction Decoding
// -------------------------------------------------------------------------

wire [XL:0] d_data =  s1_data;

// Includes individual instruction decoding.
`include "frv_pipeline_decode.vh"

//
// Functional Unit Decoding / Selection
// -------------------------------------------------------------------------

assign n_s2_fu[P_FU_ALU] = 
    dec_add        || dec_addi       || dec_c_add      || dec_c_addi     ||
    dec_c_addi16sp || dec_c_addi4spn || dec_c_mv       || dec_auipc      ||
    dec_c_sub      || dec_sub        || dec_and        || dec_andi       ||
    dec_c_and      || dec_c_andi     || dec_lui        || dec_c_li       ||
    dec_c_lui      || dec_c_nop      || dec_or         || dec_ori        ||
    dec_c_or       || dec_c_xor      || dec_xor        || dec_xori       ||
    dec_slt        || dec_slti       || dec_sltu       || dec_sltiu      ||
    dec_sra        || dec_srai       || dec_c_srai     || dec_c_srli     ||
    dec_srl        || dec_srli       || dec_sll        || dec_slli       ||
    dec_c_slli     ;

assign n_s2_fu[P_FU_MUL] = 
    dec_div        || dec_divu       || dec_mul        || dec_mulh       ||
    dec_mulhsu     || dec_mulhu      || dec_rem        || dec_remu       ;

assign n_s2_fu[P_FU_CFU] = 
    dec_beq        || dec_c_beqz     || dec_bge        || dec_bgeu       ||
    dec_blt        || dec_bltu       || dec_bne        || dec_c_bnez     ||
    dec_c_ebreak   || dec_ebreak     || dec_ecall      || dec_c_j        ||
    dec_c_jr       || dec_c_jal      || dec_jal        || dec_c_jalr     ||
    dec_jalr       || dec_mret       ;

assign n_s2_fu[P_FU_LSU] = 
    dec_lb         || dec_lbu       || dec_lh          || dec_lhu        ||
    dec_lw         || dec_c_lw      || dec_c_lwsp      || dec_c_sw       ||
    dec_c_swsp     || dec_sb        || dec_sh          || dec_sw         ;

assign n_s2_fu[P_FU_CSR] =
    dec_csrrc      || dec_csrrci     || dec_csrrs      || dec_csrrsi     ||
    dec_csrrw      || dec_csrrwi     ;

//
// Encoding field extraction
// -------------------------------------------------------------------------

wire [4:0] dec_rs1_32 = s1_data[19:15];
wire [4:0] dec_rs2_32 = s1_data[24:20];
wire [4:0] dec_rd_32  = s1_data[11: 7];

wire       instr_16bit= s1_data[1:0] != 2'b11;
wire       instr_32bit= s1_data[1:0] == 2'b11;

assign     n_s2_size[0]  = instr_16bit;
assign     n_s2_size[1]  = instr_32bit;

generate if (TRACE_INSTR_WORD) begin
    assign     n_s2_instr    = instr_16bit ? {16'b0, s1_data[15:0]} : s1_data ;
end else begin
    assign     n_s2_instr    = 32'b0;
end endgenerate

//
// Micro-OP Decoding / Selection
// -------------------------------------------------------------------------

wire [4:0] uop_alu = 
    {5{dec_add       }} & ALU_ADD   |
    {5{dec_addi      }} & ALU_ADD   |
    {5{dec_c_add     }} & ALU_ADD   |
    {5{dec_c_addi    }} & ALU_ADD   |
    {5{dec_c_addi16sp}} & ALU_ADD   |
    {5{dec_c_addi4spn}} & ALU_ADD   |
    {5{dec_c_mv      }} & ALU_ADD   |
    {5{dec_auipc     }} & ALU_ADD   |
    {5{dec_c_sub     }} & ALU_SUB   |
    {5{dec_sub       }} & ALU_SUB   |
    {5{dec_and       }} & ALU_AND   |
    {5{dec_andi      }} & ALU_AND   |
    {5{dec_c_and     }} & ALU_AND   |
    {5{dec_c_andi    }} & ALU_AND   |
    {5{dec_lui       }} & ALU_OR    |
    {5{dec_c_li      }} & ALU_OR    |
    {5{dec_c_lui     }} & ALU_OR    |
    {5{dec_c_nop     }} & ALU_OR    |
    {5{dec_or        }} & ALU_OR    |
    {5{dec_ori       }} & ALU_OR    |
    {5{dec_c_or      }} & ALU_OR    |
    {5{dec_c_xor     }} & ALU_XOR   |
    {5{dec_xor       }} & ALU_XOR   |
    {5{dec_xori      }} & ALU_XOR   |
    {5{dec_slt       }} & ALU_SLT   |
    {5{dec_slti      }} & ALU_SLT   |
    {5{dec_sltu      }} & ALU_SLTU  |
    {5{dec_sltiu     }} & ALU_SLTU  |
    {5{dec_sra       }} & ALU_SRA   |
    {5{dec_srai      }} & ALU_SRA   |
    {5{dec_c_srai    }} & ALU_SRA   |
    {5{dec_c_srli    }} & ALU_SRL   |
    {5{dec_srl       }} & ALU_SRL   |
    {5{dec_srli      }} & ALU_SRL   |
    {5{dec_sll       }} & ALU_SLL   |
    {5{dec_slli      }} & ALU_SLL   |
    {5{dec_c_slli    }} & ALU_SLL   ;

wire [4:0] uop_cfu =
    {5{dec_beq       }} & CFU_BEQ   |
    {5{dec_c_beqz    }} & CFU_BEQ   |
    {5{dec_bge       }} & CFU_BGE   |
    {5{dec_bgeu      }} & CFU_BGEU  |
    {5{dec_blt       }} & CFU_BLT   |
    {5{dec_bltu      }} & CFU_BLTU  |
    {5{dec_bne       }} & CFU_BNE   |
    {5{dec_c_bnez    }} & CFU_BNE   |
    {5{dec_c_ebreak  }} & CFU_EBREAK|
    {5{dec_ebreak    }} & CFU_EBREAK|
    {5{dec_ecall     }} & CFU_ECALL |
    {5{dec_c_j       }} & CFU_JALI  |
    {5{dec_c_jr      }} & CFU_JALR  |
    {5{dec_c_jal     }} & CFU_JALI  |
    {5{dec_jal       }} & CFU_JALI  |
    {5{dec_c_jalr    }} & CFU_JALR  |
    {5{dec_jalr      }} & CFU_JALR  |
    {5{dec_mret      }} & CFU_MRET  ;

wire [1:0] lsu_width = 
    {2{dec_lb        }} & LSU_BYTE |
    {2{dec_lbu       }} & LSU_BYTE |
    {2{dec_lh        }} & LSU_HALF |
    {2{dec_lhu       }} & LSU_HALF |
    {2{dec_lw        }} & LSU_WORD |
    {2{dec_c_lw      }} & LSU_WORD |
    {2{dec_c_lwsp    }} & LSU_WORD |
    {2{dec_c_sw      }} & LSU_WORD |
    {2{dec_c_swsp    }} & LSU_WORD |
    {2{dec_sb        }} & LSU_BYTE |
    {2{dec_sh        }} & LSU_HALF |
    {2{dec_sw        }} & LSU_WORD ;

wire [4:0] uop_lsu;

assign uop_lsu[2:1]      = lsu_width;

assign uop_lsu[LSU_LOAD] = 
    dec_lb     ||
    dec_lbu    ||
    dec_lh     ||
    dec_lhu    ||
    dec_lw     ||
    dec_c_lw   ||
    dec_c_lwsp ;

assign uop_lsu[LSU_STORE] = 
    dec_sb     ||
    dec_sh     ||
    dec_sw     ||
    dec_c_sw   ||
    dec_c_swsp ;

assign uop_lsu[LSU_SIGNED] = 
    dec_lb     ||
    dec_lh     ; 

wire [4:0] uop_mul = 
    {5{dec_div   }} & MUL_DIV    |
    {5{dec_divu  }} & MUL_DIVU   |
    {5{dec_mul   }} & MUL_MUL    |
    {5{dec_mulh  }} & MUL_MULH   |
    {5{dec_mulhsu}} & MUL_MULHSU |
    {5{dec_mulhu }} & MUL_MULHU  |
    {5{dec_rem   }} & MUL_REM    |
    {5{dec_remu  }} & MUL_REMU   ;

wire [4:0] uop_csr;

wire       csr_op = 
    dec_csrrc  || dec_csrrci || dec_csrrs  || dec_csrrsi || dec_csrrw  ||
    dec_csrrwi ;

wire csr_no_write = ((dec_csrrs  || dec_csrrc ) && dec_rs1_32 == 0) ||
                    ((dec_csrrsi || dec_csrrci) && dec_rs1_32 == 0) ;

wire csr_no_read  = (dec_csrrw || dec_csrrwi) && dec_rd_32 == 0;

assign uop_csr[CSR_READ ] = csr_op && !csr_no_read ;
assign uop_csr[CSR_WRITE] = csr_op && !csr_no_write;
assign uop_csr[CSR_SET  ] = dec_csrrs || dec_csrrsi ;
assign uop_csr[CSR_CLEAR] = dec_csrrc || dec_csrrci ;
assign uop_csr[CSR_SWAP ] = dec_csrrw || dec_csrrwi ;

assign n_s2_uop =
    uop_alu |
    uop_cfu |
    uop_lsu |
    uop_mul |
    uop_csr ;

//
// Register Address Decoding
// -------------------------------------------------------------------------

// Source register 1, given a 16-bit instruction
wire [4:0] dec_rs1_16 = 
    {5{dec_c_add     }} & {s1_data[11:7]      } |
    {5{dec_c_addi    }} & {s1_data[11:7]      } |
    {5{dec_c_jalr    }} & {s1_data[11:7]      } |
    {5{dec_c_jr      }} & {s1_data[11:7]      } |
    {5{dec_c_slli    }} & {s1_data[11:7]      } |
    {5{dec_c_swsp    }} & {REG_SP            } |
    {5{dec_c_addi16sp}} & {REG_SP            } |
    {5{dec_c_addi4spn}} & {REG_SP            } |
    {5{dec_c_lwsp    }} & {REG_SP            } |
    {5{dec_c_and     }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_andi    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_beqz    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_bnez    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_lw      }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_or      }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_srai    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_srli    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_sub     }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_sw      }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_xor     }} & {2'b01, s1_data[9:7]} ;
    
// Source register 2, given a 16-bit instruction
wire [4:0] dec_rs2_16 = 
    {5{dec_c_beqz    }} & {       REG_ZERO   } |
    {5{dec_c_bnez    }} & {       REG_ZERO   } |
    {5{dec_c_add     }} & {       s1_data[6:2]} |
    {5{dec_c_mv      }} & {       s1_data[6:2]} |
    {5{dec_c_swsp    }} & {       s1_data[6:2]} |
    {5{dec_c_and     }} & {2'b01, s1_data[4:2]} |
    {5{dec_c_or      }} & {2'b01, s1_data[4:2]} |
    {5{dec_c_sub     }} & {2'b01, s1_data[4:2]} |
    {5{dec_c_sw      }} & {2'b01, s1_data[4:2]} |
    {5{dec_c_xor     }} & {2'b01, s1_data[4:2]} ;

// Destination register, given a 16-bit instruction
wire [4:0] dec_rd_16 = 
    {5{dec_c_addi16sp}} & {REG_SP} |
    {5{dec_c_addi4spn}} & {2'b01, s1_data[4:2]} |
    {5{dec_c_and     }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_andi    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_jal     }} & {REG_RA} |
    {5{dec_c_jalr    }} & {REG_RA} |
    {5{dec_c_add     }} & {s1_data[11:7]} |
    {5{dec_c_addi    }} & {s1_data[11:7]} |
    {5{dec_c_li      }} & {s1_data[11:7]} |
    {5{dec_c_lui     }} & {s1_data[11:7]} |
    {5{dec_c_lwsp    }} & {s1_data[11:7]} |
    {5{dec_c_mv      }} & {s1_data[11:7]} |
    {5{dec_c_slli    }} & {s1_data[11:7]} |
    {5{dec_c_lw      }} & {2'b01, s1_data[4:2]} |
    {5{dec_c_or      }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_srai    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_srli    }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_sub     }} & {2'b01, s1_data[9:7]} |
    {5{dec_c_xor     }} & {2'b01, s1_data[9:7]} ;


assign s1_rs1_addr = instr_16bit ? dec_rs1_16 : dec_rs1_32;
assign s1_rs2_addr = instr_16bit ? dec_rs2_16 : dec_rs2_32;

wire lsu_no_rd = uop_lsu[LSU_STORE] && n_s2_fu[P_FU_LSU];
wire cfu_no_rd = (uop_cfu!=CFU_JALI && uop_cfu!=CFU_JALR) &&
                n_s2_fu[P_FU_CFU];

// Destination register address carries trap cause if need be.
assign n_s2_rd    = 
                 lsu_no_rd || cfu_no_rd ? 0  :
                    n_s2_trap           ? trap_cause[4:0]   :
                 {5{instr_16bit && |n_s2_fu}} & dec_rd_16 | 
                 {5{instr_32bit && |n_s2_fu}} & dec_rd_32 ;

//
// Immediate Decoding
// -------------------------------------------------------------------------

wire [31:0] imm32_i = {{20{s1_data[31]}}, s1_data[31:20]};

wire [11:0] imm_csr_a = s1_data[31:20];

wire [31:0] imm32_s = {{20{s1_data[31]}}, s1_data[31:25], s1_data[11:7]};

wire [31:0] imm32_b = 
    {{19{s1_data[31]}},s1_data[31],s1_data[7],s1_data[30:25],s1_data[11:8],1'b0};

wire [31:0] imm32_u = {s1_data[31:12], 12'b0};

wire [31:0] imm32_j = 
    {{11{s1_data[31]}},s1_data[31],s1_data[19:12],s1_data[20],s1_data[30:21],1'b0};

wire [31:0] imm_addi16sp = {
    {23{s1_data[12]}},s1_data[4:3],s1_data[5],s1_data[2],s1_data[6],4'b0};

wire [31:0] imm_addi4spn = {
    22'b0, s1_data[10:7],s1_data[12:11],s1_data[5],s1_data[6],2'b00};

wire [31:0] imm_c_lsw = {
    25'b0,s1_data[5],s1_data[12:10], s1_data[6], 2'b00};

wire [31:0] imm_c_addi = {
    {27{s1_data[12]}}, s1_data[6:2]};

wire [31:0] imm_c_lui  = {
    {15{s1_data[12]}}, s1_data[6:2],12'b0};

wire [31:0] imm_c_shamt = {
    27'b0,s1_data[6:2]};

wire [31:0] imm_c_lwsp = {
    24'b0,s1_data[3:2], s1_data[12], s1_data[6:4], 2'b00};

wire [31:0] imm_c_swsp = {
    24'b0,s1_data[8:7], s1_data[12:9], 2'b0};

wire [31:0] imm_c_j = {
    {21{s1_data[12]}}, // 11 - sign extended
    s1_data[8], // 10
    s1_data[10:9], // 9:8
    s1_data[6], // 7
    s1_data[7], // 6
    s1_data[2], // 5
    s1_data[11], // 4
    s1_data[5:3], // 3:1,
    1'b00
};

wire [31:0] imm_c_bz = {
    {24{s1_data[12]}},s1_data[6:5],s1_data[2],s1_data[11:10],s1_data[4:3],1'b0
};

wire use_imm32_i = dec_andi || dec_slti   || dec_jalr   || dec_lb     ||
                   dec_lbu  || dec_lh     || dec_lhu    || dec_lw     ||
                   dec_ori  || dec_sltiu  || dec_xori   || dec_addi   ; 
wire use_imm32_j = dec_jal  ;
wire use_imm32_s = dec_sb   || dec_sh     || dec_sw     ;
wire use_imm32_u = dec_auipc|| dec_lui    ;
wire use_imm32_b = dec_beq  || dec_bge    || dec_bgeu   || dec_blt    ||
                   dec_bltu || dec_bne  ;
wire use_imm_csr = dec_csrrc || dec_csrrs || dec_csrrw;
wire use_imm_csri= dec_csrrci || dec_csrrsi || dec_csrrwi;
wire use_imm_shfi= dec_slli || dec_srli || dec_srai;

wire use_pc_imm  = use_imm32_b  || use_imm32_j  || dec_c_beqz   ||
                   dec_c_bnez   || dec_c_j      || dec_c_jal     ;

// Immediate which will be added to the program counter.
wire [31:0] n_s2_imm_pc = 
    {32{use_imm32_b   }} & imm32_b      |
    {32{use_imm32_j   }} & imm32_j      |
    {32{use_imm32_u   }} & imm32_u      |
    {32{dec_c_beqz    }} & imm_c_bz     |
    {32{dec_c_bnez    }} & imm_c_bz     |
    {32{dec_c_j       }} & imm_c_j      |
    {32{dec_c_jal     }} & imm_c_j      ;

assign n_s2_imm = 
                           n_s2_imm_pc     |
    {32{use_imm32_i   }} & imm32_i      |
    {32{use_imm32_s   }} & imm32_s      |
    {32{dec_c_addi    }} & imm_c_addi   |
    {32{dec_c_addi16sp}} & imm_addi16sp |
    {32{dec_c_addi4spn}} & imm_addi4spn |
    {32{dec_c_andi    }} & imm_c_addi   |
    {32{dec_c_li      }} & imm_c_addi   |
    {32{dec_c_lui     }} & imm_c_lui    |
    {32{dec_c_lw      }} & imm_c_lsw    |
    {32{dec_c_lwsp    }} & imm_c_lwsp   |
    {32{dec_c_slli    }} & imm_c_shamt  |
    {32{dec_c_srli    }} & imm_c_shamt  |
    {32{dec_c_srai    }} & imm_c_shamt  |
    {32{dec_c_sw      }} & imm_c_lsw    |
    {32{dec_c_swsp    }} & imm_c_swsp   |
    {32{use_imm_csri  }} & {imm_csr_a, 15'b0, s1_data[19:15]} |
    {32{use_imm_csr   }} & {imm_csr_a, 20'b0} |
    {32{dec_fence_i   }} & 32'd4        |
    {32{use_imm_shfi  }} & {27'b0, s1_data[24:20]} ;

//
// Operand Sourcing.
// -------------------------------------------------------------------------

assign n_s2_opr_src[DIS_OPRA_RS1 ] = // Operand A sources RS1
    dec_add        || dec_addi       || dec_c_add      || dec_c_addi     ||
    dec_c_addi16sp || dec_c_addi4spn || dec_c_mv       || dec_c_sub      ||
    dec_sub        || dec_and        || dec_andi       || dec_c_and      ||
    dec_c_andi     || dec_or         || dec_ori        || dec_c_or       ||
    dec_c_xor      || dec_xor        || dec_xori       || dec_slt        ||
    dec_slti       || dec_sltu       || dec_sltiu      || dec_sra        ||
    dec_srai       || dec_c_srai     || dec_c_srli     || dec_srl        ||
    dec_srli       || dec_sll        || dec_slli       || dec_c_slli     ||
    dec_beq        || dec_c_beqz     || dec_bge        || dec_bgeu       ||
    dec_blt        || dec_bltu       || dec_bne        || dec_c_bnez     ||
    dec_c_jr                         || dec_c_jalr     || dec_jalr       ||
    dec_lb         || dec_lbu        || dec_lh         || dec_lhu        ||
    dec_lw         || dec_c_lw       || dec_c_lwsp     || dec_c_sw       ||
    dec_c_swsp     || dec_sb         || dec_sh         || dec_sw         ||
    dec_csrrc      || dec_csrrs      || dec_csrrw      || dec_div        ||
    dec_divu       || dec_mul        || dec_mulh       || dec_mulhsu     ||
    dec_mulhu      || dec_rem        || dec_remu       ;

assign n_s2_opr_src[DIS_OPRA_PC  ] = // Operand A sources PC+immediate
    dec_auipc       ;

assign n_s2_opr_src[DIS_OPRA_CSRI] = // Operand A sources CSR mask immediate
    dec_csrrci     || dec_csrrsi     || dec_csrrwi     ;


assign n_s2_opr_src[DIS_OPRB_RS2 ] = // Operand B sources RS2
    dec_add        || dec_c_add      || 
    dec_c_sub      || dec_sub        || dec_and        || dec_c_and      ||
    dec_or         || dec_c_or       || dec_c_xor      || dec_xor        ||
    dec_slt        || dec_sltu       || dec_sra        || dec_srl        ||
    dec_sll        || dec_beq        || dec_c_beqz     || dec_bge        ||
    dec_bgeu       || dec_blt        || dec_bltu       || dec_bne        ||
    dec_c_bnez     || dec_div        || dec_divu       || dec_mul        ||
    dec_mulh       || dec_mulhsu     || dec_mulhu      || dec_rem        ||
    dec_remu       || dec_c_mv        ;

assign n_s2_opr_src[DIS_OPRB_IMM ] = // Operand B sources immediate
    dec_addi       || dec_c_addi     || dec_andi       || dec_c_andi     ||
    dec_lui        || dec_c_li       || dec_c_lui      || dec_ori        ||
    dec_xori       || dec_slti       || dec_sltiu      || dec_srai       ||
    dec_c_srai     || dec_c_srli     || dec_srli       || dec_slli       ||
    dec_c_slli     || dec_auipc      || dec_jalr       || dec_lb         ||
    dec_lbu        || dec_lh         || dec_lhu        || dec_lw         ||
    dec_c_lw       || dec_c_lwsp     || dec_c_sw       || dec_c_swsp     ||
    dec_sb         || dec_sh         || dec_sw         || dec_c_addi16sp ||
    dec_c_addi4spn  ;


assign n_s2_opr_src[DIS_OPRC_RS2 ] = // Operand C sources RS2
    dec_c_sw       || dec_c_swsp     || dec_sb         || dec_sh         ||
    dec_sw          ;

assign n_s2_opr_src[DIS_OPRC_CSRA] = // Operand C sources CSR address immediate
    dec_csrrc      || dec_csrrci     || dec_csrrs      || dec_csrrsi     ||
    dec_csrrw      || dec_csrrwi      ;

assign n_s2_opr_src[DIS_OPRC_PCIM] = // Operand C sources PC+immediate
    dec_beq        || dec_c_beqz     || dec_bge        || dec_bgeu       ||
    dec_blt        || dec_bltu       || dec_bne        || dec_c_bnez     ||
    dec_c_j        || dec_c_jal      || dec_jal         ;

//
// Trap catching
// -------------------------------------------------------------------------

wire [5:0] trap_cause =
    invalid_instr   ? TRAP_IOPCODE  :
    s1_error         ? TRAP_IACCESS  :
                      0             ;

assign n_s2_trap         = s1_valid && (s1_error || invalid_instr);

//
// Any extra decode / operand packing/unpacking.
// -------------------------------------------------------------------------

wire [31:0] csr_addr = {20'b0, n_s2_imm[31:20]};
wire [31:0] csr_imm  = {27'b0, s1_rs1_addr    };

//
// Static branch prediction
// -------------------------------------------------------------------------

//dec_beq        || dec_c_beqz     || dec_bge        || dec_bgeu       ||
//dec_blt        || dec_bltu       || dec_bne        || dec_c_bnez     ||

wire   pcf_predict_taken =
        dec_c_j     || dec_c_jal      || dec_jal         ;

wire   n_s2_cf_pred = pcf_predict_taken ? CF_PREDICT_TAKEN          :
                                          CF_PREDICT_NOT_TAKEN      ;

assign s1_cf_req    = pcf_predict_taken && !s1_bubble && !p_s2_busy;

assign s1_cf_target = pc_plus_imm;

wire   pcf_stall    = s1_cf_req && !s1_cf_ack;


//
// PC computation
// -------------------------------------------------------------------------

reg  [XL:0] program_counter;

wire [XL:0] n_pc_offset       = {29'b0, n_s2_size,1'b0}   ;

wire [XL:0] n_program_counter = program_counter + n_pc_offset;

always @(posedge g_clk) begin
    if(!g_resetn) begin
        program_counter <= FRV_PC_RESET_VALUE;
    end else if(cf_req && cf_ack) begin
        program_counter <= cf_target;
    end else if(s1_valid && !s1_busy) begin
        program_counter <= n_program_counter;
    end
end

wire [XL:0] pc_plus_imm             ; // Sum of PC and immediate.

assign      pc_plus_imm = program_counter + n_s2_imm_pc;

//
// Operand Source decoding
// -------------------------------------------------------------------------

// Operand A sourcing.
wire opra_src_rs1  = n_s2_opr_src[DIS_OPRA_RS1 ];
wire opra_src_pc   = n_s2_opr_src[DIS_OPRA_PC  ];
wire opra_src_csri = n_s2_opr_src[DIS_OPRA_CSRI];

assign n_s2_opr_a = 
    {XLEN{opra_src_rs1    }} & s1_rs1_rdata   |
    {XLEN{opra_src_pc     }} & program_counter|
    {XLEN{opra_src_csri   }} & csr_imm        ;

// Operand B sourcing.
wire oprb_src_rs2  = n_s2_opr_src[DIS_OPRB_RS2 ];
wire oprb_src_imm  = n_s2_opr_src[DIS_OPRB_IMM ];

assign n_s2_opr_b =
    {XLEN{oprb_src_rs2    }} & s1_rs2_rdata   |
    {XLEN{oprb_src_imm    }} & n_s2_imm       ;

// Operand C sourcing.
wire oprc_src_rs2  = n_s2_opr_src[DIS_OPRC_RS2 ];
wire oprc_src_csra = n_s2_opr_src[DIS_OPRC_CSRA];
wire oprc_src_pcim = n_s2_opr_src[DIS_OPRC_PCIM];

assign n_s2_opr_c = 
    {XLEN{oprc_src_rs2    }} & s1_rs2_rdata   |
    {XLEN{oprc_src_csra   }} & csr_addr       |
    {XLEN{oprc_src_pcim   }} & pc_plus_imm    ;

//
// Pipeline Register.
// -------------------------------------------------------------------------

localparam RL = 147;

`ifdef RVFI
always @(posedge g_clk) begin
    if(!g_resetn || s1_flush) begin
        rvfi_s2_rs1_addr <= 0;
        rvfi_s2_rs2_addr <= 0;
        rvfi_s2_rs1_data <= 0;
        rvfi_s2_rs2_data <= 0;
    end else if (pipe_progress) begin
        rvfi_s2_rs1_addr <= s1_rs1_addr;
        rvfi_s2_rs1_data <= s1_rs1_rdata;
        rvfi_s2_rs2_addr <= s1_rs2_addr;
        rvfi_s2_rs2_data <= s1_rs2_rdata;
    end
end
`endif

wire [RL-1:0] p_mr;

wire [RL-1:0] p_in = {
 s1_bubble ?  5'b0 : n_s2_rd   , // Destination register address
 n_s2_opr_a                , // Operand A
 n_s2_opr_b                , // Operand B
 n_s2_opr_c                , // Operand C
 n_s2_cf_pred              , // Control flow prediction.
 s1_bubble ?  5'b0 : n_s2_uop  , // Micro-op code
 s1_bubble ?  5'b0 : n_s2_fu   , // Functional Unit (alu/mem/jump/mul/csr)
 s1_bubble ?  1'b0 : n_s2_trap , // Raise a trap?
 s1_bubble ?  2'b0 : n_s2_size , // Size of the instruction.
 s1_bubble ? 32'b0 : n_s2_instr  // The instruction word
};

wire [RL-1:0] p_out;

assign {
 s2_rd         , // Destination register address
 s2_opr_a      , // Operand A
 s2_opr_b      , // Operand B
 s2_opr_c      , // Operand C
 s2_cf_pred    , // Control flow prediction.
 s2_uop        , // Micro-op code
 s2_fu         , // Functional Unit (alu/mem/jump/mul/csr)
 s2_trap       , // Raise a trap?
 s2_size       , // Size of the instruction.
 s2_instr        // The instruction word
} = p_out;

frv_pipeline_register #(
.BUFFER_HANDSHAKE(1'b0),
.RLEN(RL)
) i_decode_pipereg (
.g_clk    (g_clk        ), // global clock
.g_resetn (g_resetn     ), // synchronous reset
.i_data   (p_in         ), // Input data from stage N
.i_valid  (n_s2_valid   ), // Input data valid?
.o_busy   (p_s2_busy    ), // Stage N+1 ready to continue?
.mr_data  (p_mr         ), // Most recent data into the stage.
.flush    (s1_flush     ), // Flush the contents of the pipeline
.o_data   (p_out        ), // Output data for stage N+1
.o_valid  (s2_valid     ), // Input data from stage N valid?
.i_busy   (s2_busy      )  // Stage N+1 ready to continue?
);

endmodule

