// ---------------------------------------------------------------------------
// Copyright (c) 2025. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Title       	 : ACTS for SMEPMP Rule Lock Bypass (RLB) Verification
// Authors     	 : Abdullah Jhatial
// Contact	  	 : https://github.com/Abdullah-10xe
// Test Plan     : https://docs.google.com/spreadsheets/d/10nzG7CR1VP7XvQDaEkK3NrWb0W8dXFUt0H6VPZ99yVY/edit?gid=0#gid=0
//-----------------------------------------------------------------------------------------------------------------------------------------------
// Description   : This test validates SMEPMP behavior when the Rule Lock Bypass
//                 (RLB) bit in mseccfg is enabled. It verifying PMP permission overrides
//                 When L bit is set , and also verify the read only zero state of RLB bit
//
// Methodology  
// Step 1        : Clear all PMP configuration and address registers.
// Step 2        : Enable RLB in mseccfg and configure PMP regions with Lock bit
// Step 3        : Switch between RWX, RX, and OFF states under locked PMP regions
//                 and log PMPCFG register states.
// Step 4        : Validate that when PMPCFG is set to OFF with Lock, and unset RLB ,then set RLB
//                 readbacks mseccfg return zero (zero-held state).For rlb
// Step 5        : Update signature after each configuration to track behavior.
//
//------------------------------------------------------------------------------------------------------------------------------------------------
// Test Cases   : 
// Case 1       : RLB functionality check
//                - Enable RLB
//                - Configure PMP regions with  Lock
//                - Switch permissions (LRWX,LRX,RWX,OFF)
//                - Verify signature reflects PMP/MSECCFG state transitions
//
// Case 2       : RLB zero-held state check
//                - Lock PMP region with OFF
//                - Disable and re-enable RLB dynamically
//                - Verify that mseccfg RLB bit read zero
//                - Update signature with observed behavior
//
//------------------------------------------------------------------------------------------------------------------------------------------------
// Verification : 
//   - For each case, PMP/MSECCFG register states are logged via signature.
//   - Ensures RLB allows controlled PMP permission overrides even with Lock set.
//   - Confirms zero-held readback behavior when PMP is OFF + Lock with setting RLB and reading back RLB.
//------------------------------------------------------------------------------------------------------------------------------------------------
// Expected Behavior   :
//   - Case 1: RLB allows PMP state changes despite Lock bit being set.
//   - Case 2: OFF + Lock with RLB ensures PMP readbacks return zero as per spec.
// Dependencies        : model_test.h, arch_test.h
// ------------------------------------------------------------------------------------------------------------------------------------------------

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr")

.section .text.init
.globl rvtest_entry_point

rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine=True;",load_byte_hit)

// ---------------------------------------------------------------------------
// PMP constants and defaults
// ---------------------------------------------------------------------------
#ifndef RVMODEL_PMP_GRAIN
  #define RVMODEL_PMP_GRAIN 0
#endif

#ifndef RVMODEL_NUM_PMPS
  #define RVMODEL_NUM_PMPS 16
#endif

#ifdef TEST
#ifdef rvtest_strap_routine
  csrw satp, x0      // Disable address translation if enabled
#endif

// ---------------------------------------------------------------------------
// PMP/MSECCFG configuration constants
// ---------------------------------------------------------------------------

#define PMPCFG_OFF           0x00      // PMP OFF
#define PMPCFG_OFF_L         0x80      // OFF with lock
#define PMPCFG_TOR_LRWX      0x8F     // TOR, locked, RWX
#define PMPCFG_TOR_LRX       0x8D     // TOR, locked, RX
#define PMPCFG_TOR_RWX       0x0F     // TOR, RWX
#define TEST_CODE_RANGE  test_code_end
#define CODE_SPACE       end_all

// ---------------------------------------------------------------------------
// Signature base for logging test results
// ---------------------------------------------------------------------------
RVTEST_SIGBASE(x13, begin_signature1)

.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align	3

// ---------------------------------------------------------------------------
// Macro: RLB_TEST
// Description:
//   - Enables RLB (Rule Lock Bypass).
//   - Configures PMP regions with different locked/unlocked permissions.
//   - Updates the test signature with PMP/MSECCFG register states.
// Purpose:
//   Validates RLB functionality when switching PMP permissions while Lock bit is set
// ---------------------------------------------------------------------------
.macro RLB_TEST   

  LI ( a4,RLB_SET )
  csrw mseccfg ,a4
  csrr a4,mseccfg
  RVTEST_SIGUPD(x13,a4)

  LA ( a4,TEST_CODE_RANGE )
  srli a4,a4,PMP_ADDR_SHIFT
  csrw pmpaddr0 ,a4

  LI ( a4,PMPCFG_TOR_LRWX )
  csrw pmpcfg0,a4

  LA ( a4, CODE_SPACE )
  srli a4,a4,PMP_ADDR_SHIFT
  csrw pmpaddr0 ,a4
  csrr a4,pmpaddr0
  RVTEST_SIGUPD(x13,a4)

  LI ( a4 ,PMPCFG_TOR_LRX )
  csrw pmpcfg0 ,a4
  csrr a4,pmpcfg0
  RVTEST_SIGUPD(x13,a4)

  csrw pmpcfg0 ,PMPCFG_TOR_RWX
  csrr a4,pmpcfg0
  RVTEST_SIGUPD(x13,a4)

  LI ( a4,PMPCFG_OFF )
  csrw pmpcfg0, a4
  csrw mseccfg ,x0    // Clear MSECCFG
.endm

// ---------------------------------------------------------------------------
// Macro: RLB_ONLY_READ_ZERO
// Description:
//   - Tests that when PMP is set to OFF (locked), reads return zero.
//   - Checks RLB transitions when enabling/disabling MSECCFG bits.
// Purpose:
//   Validates RLB zero-held state (readback behavior).
// ---------------------------------------------------------------------------
.macro RLB_ONLY_READ_ZERO
  LI ( a4, RLB_SET )
  csrw mseccfg ,a4
  csrr a4,mseccfg
  RVTEST_SIGUPD(x13,a4)

  LI ( a4, PMPCFG_OFF_L )
  csrw pmpcfg0,a4

  LI ( a4, RLB_SET )
  csrc mseccfg,a4
  csrr a4,mseccfg
  RVTEST_SIGUPD(x13,a4)

  LI ( a4,RLB_SET )
  csrs mseccfg,a4
  csrr a4,mseccfg
  RVTEST_SIGUPD(x13,a4)
.endm

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

  // Case 1: RLB functionality check

  RLB_TEST

  // Case 2: RLB zero-held state check
   
   RLB_ONLY_READ_ZERO

nop
test_code_end:
#endif


RVTEST_CODE_END
RVMODEL_HALT

end_all:

RVTEST_DATA_BEGIN
rvtest_data:
  .word 0xbabecafe    // test data (if any) goes here
RVTEST_DATA_END


.align 4
RVMODEL_DATA_BEGIN
  rvtest_sig_begin:
    .globl begin_signature
    .align 4
begin_signature1:
    .rept 128
    .word 0xdeadbeef
    .endr
    .globl end_signature
end_signature1:

// Optional mtrap handler signature storage
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
  CANARY;
mtrap_sigptr:
  .fill 128*(XLEN/32),4,0xdeadbeef
tsig_end_canary:
  CANARY;
#endif

// Optional GPR save area
#ifdef rvtest_gpr_save
gpr_save:
  .fill 32*(XLEN/32),4,0xdeadbeef
#endif

rvtest_sig_end:
RVMODEL_DATA_END
