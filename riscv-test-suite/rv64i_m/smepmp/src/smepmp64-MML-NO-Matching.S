//----------------------------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Copyright (c) 2025. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Title       	 : ACTS for SMEPMP MML non Matching Fetch Access  
// Authors     	 : Abdullah Jhatial
// Contact	  	 : https://github.com/Abdullah-10xe
// Test Plan     : https://docs.google.com/spreadsheets/d/10nzG7CR1VP7XvQDaEkK3NrWb0W8dXFUt0H6VPZ99yVY/edit?gid=0#gid=0
//-----------------------------------------------------------------------------------------------------------------------------------------------
// Description   : This test verifies inst-fetch-access fault should occur , When MML is set and inst access has not any  matching pmp entry
//
// Note          : The region permissions are configured at the start of the test
//
// Methodology  
// Step 1        : Clear all PMP configuration and address registers.
// Step 2        : Configure initial permissions for code, data and set MML bit
// Step 3       : Verify  with Read Write and Execute on non matching region (region under test)
//
//------------------------------------------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------------------------------------
// Expected Behavior   : Instruction Access Fault on region under test
// Dependencies        : model_test.h, arch_test.h
// ------------------------------------------------------------------------------------------------------------------------------------------------


#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV64I_Zicsr")

.section .text.init
.globl rvtest_entry_point

rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine=True; def rvtest_strap_routine = True;", MML_NO_Matching_Entry )

#ifndef RVMODEL_PMP_GRAIN
  #define RVMODEL_PMP_GRAIN 0
#endif

#ifndef RVMODEL_NUM_PMPS
  #define RVMODEL_NUM_PMPS 16
#endif

#ifdef TEST

	csrw satp, x0																	

#define UMODE  True
#define SMODE  True

#define INSTRUCTION            0x00150513
#define ADDRESS_SPACE          -1
#define pmpcfg_bits            8
#define SET_PMPCFGi(PMP3CFG_PR,PMP2CFG_PR,PMP1CFG_PR,PMP0CFG_PR) \
                    ((PMP3CFG_PR<<(PMP3_CFG_SHIFT))  |           \
                    (PMP2CFG_PR<<(PMP2_CFG_SHIFT))   |           \
                    (PMP1CFG_PR << (PMP1_CFG_SHIFT)) |           \
                    (PMP0CFG_PR))



RVTEST_SIGBASE(x13, begin_signature1)
.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align	3

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

.macro TOR_PMPADDR  ADDRESS  pmpaddri
 la a4,  \ADDRESS 
 srli a4,a4,PMP_ADDR_SHIFT
 csrw \pmpaddri,a4
.endm

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
// Description : Repeats RWX_Access for different privilege levels.
// Behavior    :
//   - Always performs access in M-mode
// ---------------------------------------------------------------------------
.macro RWX_VERIF ADDRESS
 RWX_Access \ADDRESS-4
.endm

// Set all pmpaddr and pmpcfg set to zero

Test_SETup:
  .SET pmpcfgi , CSR_PMPCFG0
  .rept RVMODEL_NUM_PMPS/8
     csrw pmpcfgi ,x0
  .SET pmpcfgi ,pmpcfgi+2
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

// Region under test region
// Region under test region
.if RVMODEL_PMP_GRAIN ==0
.align 3
.else 
.align RVMODEL_PMP_GRAIN
.endif
region_under_test_start:
.if RVMODEL_PMP_GRAIN ==0
.rept 2
addi a6,a6,1
.endr
.endif
.if RVMODEL_PMP_GRAIN >0
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
.endif
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
