# REQUIRES: riscv
# RUN: rm -rf %t && split-file %s %t && cd %t

# RUN: llvm-mc -filetype=obj -triple=riscv32-unknown-elf -mattr=+relax a.s -o rv32.o
# RUN: llvm-mc -filetype=obj -triple=riscv64-unknown-elf -mattr=+relax a.s -o rv64.o

# Confirm the assembler emits the new PCREL_BASE_IDX_* relocations.
# RUN: llvm-readobj -r rv32.o | FileCheck --check-prefix=RELOC %s
# RUN: llvm-readobj -r rv64.o | FileCheck --check-prefix=RELOC %s

# Without gp-relax the BASE_IDX_ADD is a hint (no byte change) and the
# LO12_{I,S} resolve like the matching %pcrel_lo sequence.
# RUN: ld.lld rv32.o lds -o rv32
# RUN: ld.lld rv64.o lds -o rv64
# RUN: llvm-objdump -td -M no-aliases --no-show-raw-insn rv32 | FileCheck %s
# RUN: llvm-objdump -td -M no-aliases --no-show-raw-insn rv64 | FileCheck %s

# gp-relax for PCREL_BASE_IDX_* is not yet implemented in LLD, so the link
# must succeed and produce the same instruction bytes as the no-relax case.
# RUN: ld.lld --relax-gp --undefined=__global_pointer$ rv32.o lds -o rv32-gp
# RUN: ld.lld --relax-gp --undefined=__global_pointer$ rv64.o lds -o rv64-gp
# RUN: llvm-objdump -td -M no-aliases --no-show-raw-insn rv32-gp | FileCheck %s
# RUN: llvm-objdump -td -M no-aliases --no-show-raw-insn rv64-gp | FileCheck %s

# RELOC: R_RISCV_PCREL_HI20 array
# RELOC: R_RISCV_PCREL_BASE_IDX_LO12_I .Lpcrel_hi0
# RELOC: R_RISCV_PCREL_BASE_IDX_ADD .Lpcrel_hi0
# RELOC: R_RISCV_PCREL_BASE_IDX_LO12_I .Lpcrel_hi0
# RELOC: R_RISCV_PCREL_BASE_IDX_LO12_S .Lpcrel_hi0

# CHECK:      auipc   a1, 0x100
# CHECK-NEXT: addi    a1, a1, -0x4
# CHECK-NEXT: add     a0, a0, a1
# CHECK-NEXT: lw      a0, -0x4(a0)
# CHECK-NEXT: sw      a0, -0x4(a0)

#--- a.s
.global _start
_start:
  slli a0, a0, 2
.Lpcrel_hi0:
  auipc a1, %pcrel_hi(array)
  addi  a1, a1, %pcrel_base_idx_lo(.Lpcrel_hi0)
  add   a0, a0, a1, %pcrel_base_idx_add(.Lpcrel_hi0)
  lw    a0, %pcrel_base_idx_lo(.Lpcrel_hi0)(a0)
  sw    a0, %pcrel_base_idx_lo(.Lpcrel_hi0)(a0)

.section .sdata,"aw"
array:
  .zero   4080
  .size   array, 4080

#--- lds
SECTIONS {
  .text 0x100000 : { *(.text) }
  .sdata 0x200000 : { }
}
