// ---------------------------------------------------------------------------
// Title        : Comprehensive SMEPMP (Supervisor Mode Enhanced Physical 
//                Memory Protection) Verification
// Authors      : Abdullah Jhatial
// Contact      : https://github.com/Abdullah-10xe
//
// Description  : 
//   This test verifies access behavior of the MSECCFG CSR across different 
//   privilege modes (M/S/U). It also validates PMP setup, lock behavior, and 
//   MML (Machine Mode Lockdown) enablement.
//
//    Methodology:
//     1. Clear all PMP configuration and address registers.
//     2. Configure PMP entries
//     3. (If enabled) Disable virtual memory by clearing SATP.
//     4. Test MSECCFG access in Supervisor mode if macro defined:
//          - Attempt write/read (expect illegal instruction).
//     5. Test MSECCFG access in User mode if macro defined:
//          - Attempt write/read (expect illegal instruction).
//     6. Test MSECCFG access in Machine mode:
//          - Write and read back from mseccfg .
//
//Expected behaviour : S/U mode raises the illegal exception M-Mode will R/W warl
// Dependencies: model_test.h, arch_test.h
// ---------------------------------------------------------------------------

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr")

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
.section .text.init
.globl rvtest_entry_point

rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine=True;",load_byte_hit)

// ---------------------------------------------------------------------------
// PMP configuration constants
// ---------------------------------------------------------------------------
#ifndef RVMODEL_PMP_GRAIN
  #define RVMODEL_PMP_GRAIN 0
#endif

#ifndef RVMODEL_NUM_PMPS
  #define RVMODEL_NUM_PMPS 16
#endif

#ifdef TEST
#define SET_RLB_MMWP_MML   0x7
#define TOP_ADDRESS        -1
#define UMODE
#define SMODE 
// ---------------------------------------------------------------------------
// Signature region for test results
// ---------------------------------------------------------------------------
RVTEST_SIGBASE(x13, begin_signature1)

.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align	3

// ---------------------------------------------------------------------------
// Test setup: Clear all PMP configuration and address registers
// ---------------------------------------------------------------------------
Test_setup:
  .set pmpcfgi , CSR_PMPCFG0
  .rept RVMODEL_NUM_PMPS/4
    csrw pmpcfgi ,x0
    .set pmpcfgi ,pmpcfgi+1
  .endr

  .set pmpaddri ,CSR_PMPADDR0
  .rept RVMODEL_NUM_PMPS
    csrw pmpaddri ,x0
    .set pmpaddri,pmpaddri+1
  .endr

// ---------------------------------------------------------------------------
// Configure PMP entry 0 to cover Address Space
// ---------------------------------------------------------------------------
LI(a4,TOP_ADDRESS )
srli a4,a4,2
csrw pmpaddr0,a4

LI(a4,0x0F )
csrw pmpcfg0,a4

// ---------------------------------------------------------------------------
// Disable virtual memory if strap routine enabled
// ---------------------------------------------------------------------------
#ifdef rvtest_strap_routine
  csrw satp, x0     // Disable address translation
#endif

nop

// ---------------------------------------------------------------------------
// Test cases: Write/Read MSECCFG in S/U/M modes
// ---------------------------------------------------------------------------

// --- Supervisor mode ---
SU_mode_case:
#ifdef  SMODE
RVTEST_GOTO_LOWER_MODE smode
LI(a4 ,SET_RLB_MMWP_MML)
csrw mseccfg ,a4
nop
nop
csrr a4,mseccfg
nop
nop
RVTEST_SIGUPD(x13, a4) 
#endif
// --- User mode ---
#ifdef UMODE
U_MODE :
RVTEST_GOTO_LOWER_MODE umode

nop
nop
csrr a4,mstatus
nop
nop
LI(a4 ,SET_RLB_MMWP_MML)
csrw mseccfg ,a4
nop
nop
csrr a4,mseccfg
nop
nop
RVTEST_SIGUPD(x13, a4) 
#endif
// --- Machine mode ---
M_mode_case:
RVTEST_GOTO_MMODE
LI(a4,RLB_SET)
csrw mseccfg,a4
csrr a4,mseccfg
RVTEST_SIGUPD(x13,a4)

// ---------------------------------------------------------------------------
// Setup PMP for end-of-test region
// ---------------------------------------------------------------------------
LA(a4,end_all)
srli a4,a4,2
csrw pmpaddr0,a4

LI( a4 ,TOP_ADDRESS)
csrw pmpaddr1,a4

LI ( a4,0x8C )
csrw pmpcfg0,a4

// Lock PMP and enable MML
LI ( a4 ,0x7 )
csrw mseccfg ,a4

// Update PMP config with new permissions
LI ( a4,0x0A8A )
csrw pmpcfg0,a4
csrr a4,mseccfg

nop
#endif

// ---------------------------------------------------------------------------
// End of test
// ---------------------------------------------------------------------------
RVTEST_CODE_END
RVMODEL_HALT

end_all:

RVTEST_DATA_BEGIN
rvtest_data:
.word 0xbabecafe// test data (if any) goes here
RVTEST_DATA_END
.align 4
RVMODEL_DATA_BEGIN
  rvtest_sig_begin:
    .globl begin_signature
    .align 4
begin_signature1:
    .word 0xdeadbeef
    .word 0xdeadbeef
    .word 0xdeadbeef
    .word 0xdeadbeef
    .globl end_signature
end_signature1:
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 128*(XLEN/32),4,0xdeadbeef
tsig_end_canary:
CANARY;
#endif
#ifdef rvtest_gpr_save
gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef
#endif
rvtest_sig_end:
RVMODEL_DATA_END
