
# Instruction Table

**Integer ALU Instructions:**

Instruction  | Action                   | uOP code
-------------|--------------------------|--------------------------------------
`add        `| rd <= rs1 + rs2          | {00, 001}
`addi       `| rd <= rs1 + imm          | {00, 001}
`c_add      `| rd <= rs1 + rs2          | {00, 001}
`c_addi     `| rd <= rs1 + imm          | {00, 001}
`c_addi16sp `| rd <= rs1 + imm          | {00, 001}
`c_addi4spn `| rd <= rs1 + imm          | {00, 001}
`c_mv       `| rd <= rs1                | {00, 001}
`auipc      `| rd <= pc + imm20         | {00, 001}
`c_sub      `| rd <= rs1 - rs2          | {00, 000}
`sub        `| rd <= rs1 - rs2          | {00, 000}
`and        `| rd <= rs1 & rs2          | {01, 001}
`andi       `| rd <= rs1 & rs2          | {01, 001}
`c_and      `| rd <= rs1 & rs2          | {01, 001}
`c_andi     `| rd <= rs1 & imm          | {01, 001}
`lui        `| rd <= {imm20, 12'b0}     | {01, 010}
`c_li       `| rd <= imm                | {01, 010}
`c_lui      `| rd <= imm                | {01, 010}
`c_nop      `| nop                      | {01, 010}
`or         `| rd <= rs1 or rs2         | {01, 010}
`ori        `| rd <= rs1 or rs2         | {01, 010}
`c_or       `| rd <= rs1 or rs2         | {01, 010}
`c_xor      `| rd <= rs1 ^ rs2          | {01, 100}
`xor        `| rd <= rs1 ^ rs2          | {01, 100}
`xori       `| rd <= rs1 ^ imm          | {01, 100}
`slt        `| rd <= rs1 < rs2          | {10, 001}
`slti       `| rd <= rs1 < imm          | {10, 001}
`sltu       `| rd <= rs1 < rs2          | {10, 010}
`sltiu      `| rd <= rs1 < imm          | {10, 010}
`sra        `| rd <= rs1 >>> rs2        | {11, 001}
`srai       `| rd <= rs1 >>> rs2        | {11, 001}
`c_srai     `| rd <= rs1 >>> imm        | {11, 001}
`c_srli     `| rd <= rs1 >>  imm        | {11, 010}
`srl        `| rd <= rs1 >> rs2         | {11, 010}
`srli       `| rd <= rs1 >> rs2         | {11, 010}
`sll        `| rd <= rs1 << rs2         | {11, 100}
`slli       `| rd <= rs1 << rs2         | {11, 100}
`c_slli     `| rd <= rs1 <<  imm        | {11, 100}


**Control Flow Instructions:**

Instruction  | Action                               | uOP code
-------------|--------------------------------------|--------------------------
`beq        `| pc <= pc + (rs1 == rs2 ? imm : 4)    | {00, 001}
`c_beqz     `| pc <= pc + (rs1==rs2 ? imm : 2)      | {00, 001}
`bge        `| pc <= pc + (rs1 >= rs2 ? imm : 4)    | {00, 010}
`bgeu       `| pc <= pc + (rs1 >= rs2 ? imm : 4)    | {00, 011}
`blt        `| pc <= pc + (rs1 <  rs2 ? imm : 4)    | {00, 100}
`bltu       `| pc <= pc + (rs1 <  rs2 ? imm : 4)    | {00, 101}
`bne        `| pc <= pc + (rs1 != rs2 ? imm : 4)    | {00, 110}
`c_bnez     `| pc <= pc + (rs1!=rs2 ? imm : 2)      | {00, 110}
`c_ebreak   `| pc <= mtvec                          | {01, 000}
`ebreak     `| pc <= mtvec                          | {01, 000}
`ecall      `| pc <= mtvec                          | {01, 000}
`c_j        `| pc <= pc + imm                       | {10, 000}
`c_jr       `| pc <= rs1                            | {10, 000}
`c_jal      `| pc <= pc + imm, rd <= pc + 2         | {10, 001}
`jal        `| pc <= pc + imm, rd <= pc + 4         | {10, 001}
`c_jalr     `| pc <= rs1, rd <= pc + 2              | {10, 001}
`jalr       `| pc <= pc + rs1, rd <= pc + 4         | {10, 001}
`mret       `| pc <= mepc                           | {11, 000}


**Memory Instructions:**

Instruction  | Action                   | uOP code
-------------|--------------------------|--------------------------------------
`lb         `| rd <= mem[rs1 + imm]     | {01, 011}
`lbu        `| rd <= mem[rs1 + imm]     | {01, 010}
`lh         `| rd <= mem[rs1 + imm]     | {01, 101}
`lhu        `| rd <= mem[rs1 + imm]     | {01, 100}
`lw         `| rd <= mem[rs1 + imm]     | {01, 110}
`c_lw       `| rd <= mem[rs1 + imm]     | {01, 110}
`c_lwsp     `| rd <= mem[rs1 + imm]     | {01, 110}
`c_sw       `| mem[rs1+imm] <= rs2      | {10, 110}
`c_swsp     `| mem[rs1+imm] <= rs2      | {10, 110}
`sb         `| mem[rs2+imm] <= rs1      | {10, 010}
`sh         `| mem[rs2+imm] <= rs1      | {10, 100}
`sw         `| mem[rs2+imm] <= rs1      | {10, 110}


**CSR Instructions:**

Instruction  | Action                   | uOP code
-------------|--------------------------|--------------------------------------
`csrrc      `| rd <= csr, csr <= rs1    | {rw,scf}
`csrrci     `| rd <= csr, csr <= rs1    | {rw,scf}
`csrrs      `| rd <= csr, csr <= rs1    | {rw,scf}
`csrrsi     `| rd <= csr, csr <= rs1    | {rw,scf}
`csrrw      `| rd <= csr, csr <= rs1    | {rw,scf}
`csrrwi     `| rd <= csr, csr <= rs1    | {rw,scf}


**Mul/Div Instructions:**

Instruction  | Action                   | uOP code
-------------|--------------------------|--------------------------------------
`div        `| rd <= rs1 / rs2          | {11, 000}
`divu       `| rd <= rs1 / rs2          | {11, 001}
`mul        `| rd <= rs1 * rs2          | {01, 000}
`mulh       `| rd <= rs1 * rs2          | {01, 100}
`mulhsu     `| rd <= rs1 * rs2          | {01, 111}
`mulhu      `| rd <= rs1 * rs2          | {01, 101}
`rem        `| rd <= rs1 % rs2          | {10, 000}
`remu       `| rd <= rs1 % rs2          | {10, 001}

---

# Dispatch Stage Operand Assignment.

**Integer ALU Instructions:**

Instruction  | `opr_a`      | `opr_b`       | `opr_c`
-------------|--------------|---------------|-----------------
`add        `|  rs1         |  rs2          |  0
`addi       `|  rs1         |  imm          |  0
`c_add      `|  rs1         |  rs2          |  0
`c_addi     `|  rs1         |  imm          |  0
`c_addi16sp `|  rs1         |  rs2          |  0
`c_addi4spn `|  rs1         |  rs2          |  0
`c_mv       `|  rs1         |  0            |  0
`auipc      `|  PC          |  imm          |  0
`c_sub      `|  rs1         |  rs2          |  0
`sub        `|  rs1         |  rs2          |  0
`and        `|  rs1         |  rs2          |  0
`andi       `|  rs1         |  imm          |  0
`c_and      `|  rs1         |  rs2          |  0
`c_andi     `|  rs1         |  imm          |  0
`lui        `|  0           |  imm          |  0
`c_li       `|  0           |  imm          |  0
`c_lui      `|  0           |  imm          |  0
`c_nop      `|  0           |  0            |  0
`or         `|  rs1         |  rs2          |  0
`ori        `|  rs1         |  imm          |  0
`c_or       `|  rs1         |  rs2          |  0
`c_xor      `|  rs1         |  rs2          |  0
`xor        `|  rs1         |  rs2          |  0
`xori       `|  rs1         |  imm          |  0
`slt        `|  rs1         |  rs2          |  0
`slti       `|  rs1         |  imm          |  0
`sltu       `|  rs1         |  rs2          |  0
`sltiu      `|  rs1         |  imm          |  0
`sra        `|  rs1         |  rs2          |  0
`srai       `|  rs1         |  imm          |  0
`c_srai     `|  rs1         |  imm          |  0
`c_srli     `|  rs1         |  imm          |  0
`srl        `|  rs1         |  rs2          |  0
`srli       `|  rs1         |  imm          |  0
`sll        `|  rs1         |  rs2          |  0
`slli       `|  rs1         |  imm          |  0
`c_slli     `|  rs1         |  imm          |  0


**Control Flow Instructions:**

Instruction  | `opr_a`      | `opr_b`       | `opr_c`
-------------|--------------|---------------|-----------------
`beq        `|  rs1         |  rs2          | PC+imm
`c_beqz     `|  rs1         |  rs2          | PC+imm
`bge        `|  rs1         |  rs2          | PC+imm
`bgeu       `|  rs1         |  rs2          | PC+imm
`blt        `|  rs1         |  rs2          | PC+imm
`bltu       `|  rs1         |  rs2          | PC+imm
`bne        `|  rs1         |  rs2          | PC+imm
`c_bnez     `|  rs1         |  rs2          | PC+imm
`c_ebreak   `|  0           |  0            | 0
`ebreak     `|  0           |  0            | 0
`ecall      `|  0           |  0            | 0                  
`c_j        `|  0           |  0            | PC+imm
`c_jal      `|  0           |  0            | PC+imm
`jal        `|  0           |  0            | PC+imm
`c_jr       `|  rs1         |  0            | 0
`c_jalr     `|  rs1         |  0            | 0
`jalr       `|  rs1         |  imm          | 0
`mret       `|  0           |  0            | 0


**Memory Instructions:**

Instruction  | `opr_a`      | `opr_b`       | `opr_c`
-------------|--------------|---------------|-----------------
`lb         `|  rs1         |  imm          | 0
`lbu        `|  rs1         |  imm          | 0
`lh         `|  rs1         |  imm          | 0
`lhu        `|  rs1         |  imm          | 0
`lw         `|  rs1         |  imm          | 0
`c_lw       `|  rs1         |  imm          | 0
`c_lwsp     `|  rs1         |  imm          | 0
`c_sw       `|  rs1         |  imm          | rs2
`c_swsp     `|  rs1         |  imm          | rs2
`sb         `|  rs1         |  imm          | rs2
`sh         `|  rs1         |  imm          | rs2
`sw         `|  rs1         |  imm          | rs2


**CSR Instructions:**

Instruction  | `opr_a`      | `opr_b`       | `opr_c`
-------------|--------------|---------------|-----------------
`csrrc      `|  rs1         |  o            | csraddr
`csrrci     `|  imm         |  o            | csraddr
`csrrs      `|  rs1         |  o            | csraddr
`csrrsi     `|  imm         |  o            | csraddr
`csrrw      `|  rs1         |  o            | csraddr
`csrrwi     `|  imm         |  o            | csraddr


**Mul/Div Instructions:**

Instruction  | `opr_a`      | `opr_b`       | `opr_c`
-------------|--------------|---------------|-----------------
`div        `|  rs1         |  rs2          | 0
`divu       `|  rs1         |  rs2          | 0
`mul        `|  rs1         |  rs2          | 0
`mulh       `|  rs1         |  rs2          | 0
`mulhsu     `|  rs1         |  rs2          | 0
`mulhu      `|  rs1         |  rs2          | 0
`rem        `|  rs1         |  rs2          | 0
`remu       `|  rs1         |  rs2          | 0

