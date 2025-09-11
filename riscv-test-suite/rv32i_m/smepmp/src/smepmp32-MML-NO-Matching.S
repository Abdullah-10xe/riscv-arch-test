// ---------------------------------------------------------------------------
// Copyright (c) 2025. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Title       	 : ACTS for SMEPMP MML non Matching Fetch Access  
// Authors     	 : Abdullah Jhatial
// Contact	  	 : https://github.com/Abdullah-10xe
// Test Plan     : https://docs.google.com/spreadsheets/d/10nzG7CR1VP7XvQDaEkK3NrWb0W8dXFUt0H6VPZ99yVY/edit?gid=0#gid=0
//-----------------------------------------------------------------------------------------------------------------------------------------------
// Description   : This test verifies inst-fetch-access should occur , When MML is set and inst access has not any pmp matching entry
//
// Note          : The region permissions are configured at the start of the test
//
// Methodology  
// Step 1        : Clear all PMP configuration and address registers.
// Step 2        : Configure initial permissions for code, data
// Step 3       : Verify access the test under region with fetch access.
//
//------------------------------------------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------------------------------------
// Expected Behavior   : Instruction Access Fault on region under test
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
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine=True; def rvtest_strap_routine = True;", MML_NO_Matching )

#ifndef RVMODEL_PMP_GRAIN
  #define RVMODEL_PMP_GRAIN 0
#endif

#ifndef RVMODEL_NUM_PMPS
  #define RVMODEL_NUM_PMPS 16
#endif

#ifdef TEST
#define INSTRUCTION            0x00150513
#define ADDRESS_SPACE          -1
#define pmpcfg_bits            8
#define SET_PMPCFGi(PMP3CFG_PR,PMP2CFG_PR,PMP1CFG_PR,PMP0CFG_PR) \
                    ((PMP3CFG_PR<<(PMP3_CFG_SHIFT))  |           \
                    (PMP2CFG_PR<<(PMP2_CFG_SHIFT))   |           \
                    (PMP1CFG_PR << (PMP1_CFG_SHIFT)) |           \
                    (PMP0CFG_PR))

// ---------------------------------------------------------------------------
// Signature Space for Recording Signatures 
// ---------------------------------------------------------------------------
RVTEST_SIGBASE(x13, begin_signature1)
.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align	4
csrw satp, x0	
/* --------------------------------------------------------------------------
   Macro: PMPCFG_SET
   Description: Configure PMP entries with desired permissions.
   Arguments:
     PMPCFGI      - PMP configuration CSR (e.g., pmpcfg0)
     PMPICFG      - PMP config index
     LAXWR        - Access permissions (Load/Access/Write/Read)
     PMPCFGI_SET  - Flag (True/False) to either overwrite or update
   -------------------------------------------------------------------------- */
.macro pmpcfg_SET pmpcfgi   pmpicfg LAXWR pmpcfgSETi
 .if \pmpcfgSETi !=1
 li a5, CLEAR(\pmpicfg)
 csrc \pmpcfgi,a5
 li a5, SET(\LAXWR,\pmpicfg)
 csrs \pmpcfgi ,a5
 .endif
 .if \pmpcfgSETi ==1
   li a5,\LAXWR
   csrw \pmpcfgi ,a5
 .endif
.endm
// ---------------------------------------------------------------------------
// Macro: TOR_PMPADDR
// Description : Writes a physical address into PMPADDRi for TOR matching.
// Notes       : Address is shifted right by 2 (word aligned).
// ---------------------------------------------------------------------------
.macro TOR_PMPADDR  ADDRESS  pmpaddri
 la a4,  \ADDRESS 
 srli a4,a4,PMP_ADDR_SHIFT
 csrw \pmpaddri,a4
.endm
// ---------------------------------------------------------------------------
// Macro: RWX_Access
// Description : Attempts Read/Write/Execute operations on a test region.
// Behavior    :
//   1. Executes a jump to the test region (verifies Execute permission).
//   2. Attempts store operations (sb/sh/sw).
//   3. Attempts load operations (lb/lh/lw).
//   4. Updates the test signature with the results.
// ---------------------------------------------------------------------------
.macro RWX_Access  REGION_UNDER_TEST
 nop
 nop
 jal ra,\REGION_UNDER_TEST      // Try execute
 nop
 nop
 RVTEST_SIGUPD(x13,a6)          // Update signature after execution
 nop
 nop
 LA( a4,\REGION_UNDER_TEST)     // Load base address
 LI( a5,INSTRUCTION)
 sb a5,0(a4)                    //  store byte
 nop
 nop
 sh a5,0(a4)                    //  store halfword
 nop
 nop 
 sw a5,0(a4)                    //  store word
 nop
 nop
 lb a5,0(a4)                    //  load byte
 nop
 nop
 lh a5,0(a4)                    //  load halfword
 nop
 nop
 lw a5,0(a4)                    //  load word
 nop
 nop
 RVTEST_SIGUPD(x13,a0)          // Update signature after load
 nop
 nop
.endm

// ---------------------------------------------------------------------------
// Macro: RWX_VERIF
// Description :  RWX_Access for different privilege levels.
// ---------------------------------------------------------------------------
.macro RWX_VERIF ADDRESS
 RWX_Access \ADDRESS-4
.endm

// ---------------------------------------------------------------------------
// Test_setup : CLEAR all PMP entries before beginning
// ---------------------------------------------------------------------------

Test_SETup:
  .SET pmpcfgi , CSR_PMPCFG0
  .rept RVMODEL_NUM_PMPS/4
     csrw pmpcfgi ,x0
  .SET pmpcfgi ,pmpcfgi+1
  .endr
  .SET pmpaddri ,CSR_PMPADDR0
  .rept RVMODEL_NUM_PMPS
     csrw pmpaddri ,x0
     .SET pmpaddri,pmpaddri+1
  .endr



initial_permission_setup_start:

/* Set up  regions with  permissions , but region under test  is not included */

TOR_PMPADDR rvtest_entry_point,pmpaddr0
TOR_PMPADDR region_under_test_start ,pmpaddr1

TOR_PMPADDR region_under_test_end,pmpaddr2
TOR_PMPADDR  end_code_section ,  pmpaddr3
PMPCFG_SET pmpcfg0 ,0,SET_PMPCFGi( PMPCFG(TOR,LRX) ,PMPCFG(OFF,NONE) ,PMPCFG(TOR,LRX),PMPCFG(OFF,NONE)) ,True

TOR_PMPADDR end_code_section,pmpaddr4
TOR_PMPADDR   data_end_section,pmpaddr5
LI(a4,MML_SET)
csrw mseccfg,a4
PMPCFG_SET pmpcfg1 ,0,SET_PMPCFGi( PMPCFG(OFF,NONE) ,PMPCFG(OFF,NONE) ,PMPCFG(TOR,WX),PMPCFG(OFF,NONE)) ,True

nop
nop
initial_permission_setup_end:

TEST_CODE:
nop
nop
RWX_VERIF region_under_test_end
//  Exit the Test code 
nop
nop
j exit
nop
nop

test_code_end_start:

region_under_test_start:
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
region_under_test_end:

// Return to Verif code as it is raises instruction access fault or succcessful execution 

return_to_verif:
 nop
 nop
 jr ra

exit:
#endif
RVTEST_CODE_END
RVMODEL_HALT
end_code_section:
.align 4
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
    .rept  256
      .word 0xdeadbeef
    .endr
    .globl end_signature
end_signature1:
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
  .rept  256
      .word 0xdeadbeef
    .endr
tsig_end_canary:
CANARY;
#endif
#ifdef rvtest_gpr_save
gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef
#endif
rvtest_sig_end:
RVMODEL_DATA_END
data_end_section:
