// ---------------------------------------------------------------------------
// Copyright (c) 2020. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Title       	: Comprehensive ACTS For SMEPMP (Supervisor Mode Enchanced Physical Memory Protection) Verification
// Authors     	: Abdullah Jhatial
// Contact	  	: https://github.com/Abdullah-10xe
// Test Plan    : https://docs.google.com/spreadsheets/d/10nzG7CR1VP7XvQDaEkK3NrWb0W8dXFUt0H6VPZ99yVY/edit?gid=0#gid=0
//-----------------------------------------------------------------------------------------------------------------------
// Description  : This test verifies the functionality  of SMEPMP 
//                when MML bit and Lock bit is set and RLB is zero 
//
// Note         : For Verifing each case we setup the region with permissions at start of the Test as Follow
//              : Set Region under test region at highest Priority the code section ,Data section
//-----------------------------------------------------------------------------------------------------------------------
//
// Note          : For Verifing each CASE we setup the region permissions at start of the Test as follow
//
// Methodeology  
// Step 1        : disable RLB (Rule Lock Bypass) in mseccfg
//
// Step 2        : Configure region for Initial_Permission_Setup , Initial_Permsission_setup at lowest periority with LRX
//
// Step 3        : Set MML (Machine Mode Lockdown) in mseccfg
//
// Step 4        : Configure region from rvtest_entry_point to end_code_section as LWX  
//
// Step 5        : Configure  region for Shared Data Section form end_code_section to rvmodel_data_end as WX
//
// Step 6        : Configure  region for 6 Region Under Test as RW=01 are not writable when RLB is zero 
//                
//
//---------------------------------------------------------------------------------------------------------------------------------------------------
//
// case1        : Set Permission   For Region Under Test As LRWX = 1000
// case2        : Set Permission   For Region Under Test As LRWX = 1100
// case3        : Set Permission   For Region Under Test As LRWX = 1101
// case4        : Set Permission   For Region Under Test As LRWX = 1110
// case5        : Set Permission   For Region Under Test As LRWX = 1111
//
//-----------------------------------------------------------------------------------------------------------------------
// Verifiction  : For each case Execute,Store,Load from region under test at Byte/Half byte/Word granulity in differnt modes 
// Note         : Verifecation in S Mode and U Mode can be Controlled by SMODE ,UMODE Macro in this test file 
//-----------------------------------------------------------------------------------------------------------------------
// Expected     : In Each Case expected Access Fault occur in Each Mode, RWX permissions are enforced as Spec manifest 
// Dependencies : model_test.h, arch_test.h
//Fault         : INSTRUCTION ACCESS FAULT ,LOAD_ASSECC_FAULT,STORE_ACCESS_FAULT
// ---------------------------------------------------------------------------
.option norelax
#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I_Zicsr")

// ---------------------------------------------------------------------------
// Start of Code Region
// ---------------------------------------------------------------------------
.section .text.init
.globl rvtest_entry_point

// ---------------------------------------------------------------------------
// Test Entry Point
// ---------------------------------------------------------------------------
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine=True; def rvtest_strap_routine = True ",SMEPMP_MML_LRWX)

// ---------------------------------------------------------------------------
// PMP Configuration Constants
// ---------------------------------------------------------------------------
#ifndef RVMODEL_PMP_GRAIN
  #define RVMODEL_PMP_GRAIN 0
#endif

#ifndef RVMODEL_NUM_PMPS
  #define RVMODEL_NUM_PMPS 16
#endif

#ifdef TEST
#define SMODE    True
#define UMODE    True	
#define SET_PMPCFGi(PMP3CFG_PR,PMP2CFG_PR,PMP1CFG_PR,PMP0CFG_PR) \
                    ((PMP3CFG_PR<<(PMP3_CFG_SHIFT))  |           \
                    (PMP2CFG_PR<<(PMP2_CFG_SHIFT))   |           \
                    (PMP1CFG_PR << (PMP1_CFG_SHIFT)) |           \
                    (PMP0CFG_PR))															

// ---------------------------------------------------------------------------
// INSTRUCTION ENCODDINGS
// ---------------------------------------------------------------------------
#define INSTRUCTION            0x00150513

// ---------------------------------------------------------------------------
// Signature Space for Recording Signatures 
// ---------------------------------------------------------------------------
RVTEST_SIGBASE(x13, begin_signature1)
.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align	3
csrw satp, x0	
// ---------------------------------------------------------------------------
// Macro: PMPCFG_SET
// Description : Updates PMP configuration registers.
// Parameters  :
//   PMPCFGI     -> PMP configuration CSR (pmpcfg0, pmpcfg1, …)
//   PMPICFG     -> PMP entry index within the CSR (0–3)
//   LAXWR       -> Permission bits (Lock/Access/R/W/X)
//   PMPCFGI_SET -> If True, overwrite the entire register; otherwise update only one entry
// ---------------------------------------------------------------------------
.macro PMPCFG_SET PMPCFGI  PMPICFG  LAXWR  PMPCFGI_SET  
 .if \PMPCFGI_SET == False
   LI(a5, CLEAR(\PMPICFG))     // CLEAR selected PMP entry
   csrc \PMPCFGI,a5              // Apply CLEAR
   LI( a5, SET(\LAXWR,\PMPICFG)) // Load new permissions
   csrs \PMPCFGI ,a5             // Apply permissions
 .endif
 .if \PMPCFGI_SET == True
   LI( a5,\LAXWR)                // Load full config word
   csrw \PMPCFGI ,a5             // Overwrite entire PMPCFGi
 .endif
.endm

// ---------------------------------------------------------------------------
// Macro: TOR_PMPADDR
// Description : Writes a physical address into PMPADDRi for TOR matching.
// Notes       : Address is shifted right by 2 (word aligned).
// ---------------------------------------------------------------------------

.macro TOR_PMPADDR  pmpaddri ADDRESS  
 LA( a4,  \ADDRESS )           
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
 sb a5,0(a4)                    // Try store byte
 nop
 nop
 sh a5,0(a4)                    // Try store halfword
 nop
 nop 
 sw a5,0(a4)                    // Try store word
 nop
 nop
 lb a5,0(a4)                    // Try load byte
 nop
 nop
 lh a5,0(a4)                    // Try load halfword
 nop
 nop
 lw a5,0(a4)                    // Try load word
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
//   - Optionally (if defined) also performs in S-mode and U-mode
// ---------------------------------------------------------------------------
.macro RWX_VERIF ADDRESS
 RWX_Access \ADDRESS-4
 
.endm
// ---------------------------------------------------------------------------
// Test_setup : CLEAR all PMP entries before beginning
// ---------------------------------------------------------------------------
Test_setup:
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

// ---------------------------------------------------------------------------
// initial_permission_setup : Setup PMP before testing
// Notes :
//   - Sets RLB before using L bit
//   - Defines TOR regions for code/data
//   - Enables MML in mseccfg to restrict M-mode
// ---------------------------------------------------------------------------
initial_permission_setup_start:

csrs mseccfg,a4
// Define TOR region with initial execute-only permissions

TOR_PMPADDR pmpaddr14 ,  initial_permission_setup_start
TOR_PMPADDR pmpaddr15,   end_code_section
TOR_PMPADDR pmpaddr12 ,  test_code
TOR_PMPADDR pmpaddr13, region_under_test_start_0
PMPCFG_SET pmpcfg3 ,0,SET_PMPCFGi( PMPCFG(TOR,LRX) ,PMPCFG(OFF,NONE) ,PMPCFG(TOR,RWX),PMPCFG(OFF,NONE)) ,True
TOR_PMPADDR pmpaddr10 ,  region_under_test_start_0
TOR_PMPADDR pmpaddr11, end_code_section

PMPCFG_SET pmpcfg3 ,PMP3_CFG_SHIFT,PMPCFG(TOR,LRX),False 
TOR_PMPADDR pmpaddr12 ,  end_code_section
TOR_PMPADDR pmpaddr13, rvmodel_data_end
PMPCFG_SET pmpcfg3 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LRW),False 
// Enable MML (restricts M-mode after setup)
LI( a4,MML_SET)
csrs mseccfg,a4

TOR_PMPADDR pmpaddr0 ,  region_under_test_start_0
TOR_PMPADDR pmpaddr1, region_under_test_end_0
TOR_PMPADDR pmpaddr2,  region_under_test_start_1
TOR_PMPADDR pmpaddr3 , region_under_test_end_1
PMPCFG_SET pmpcfg0 ,0,SET_PMPCFGi( PMPCFG(TOR,LR) ,PMPCFG(OFF,NONE) ,PMPCFG(TOR,L),PMPCFG(OFF,NONE)) ,True

TOR_PMPADDR pmpaddr4,  region_under_test_start_2
TOR_PMPADDR pmpaddr5 region_under_test_end_2
TOR_PMPADDR pmpaddr6,  region_under_test_start_3
TOR_PMPADDR pmpaddr7 region_under_test_end_3
PMPCFG_SET pmpcfg1 ,0,SET_PMPCFGi( PMPCFG(TOR,LRW),PMPCFG(OFF,NONE),PMPCFG(TOR,LRX),PMPCFG(OFF,NONE)) ,True

TOR_PMPADDR pmpaddr8,  region_under_test_start_4
TOR_PMPADDR pmpaddr9 region_under_test_end_4
PMPCFG_SET pmpcfg2 ,0,SET_PMPCFGi( PMPCFG(TOR,LRX) ,PMPCFG(OFF,NONE) ,PMPCFG(TOR,LRWX),PMPCFG(OFF,NONE)) ,True

RVTEST_GOTO_LOWER_MODE	Smode   
nop
nop
initial_permission_setup_end:

test_code:

// case 1 Inaccessible region s

RWX_VERIF region_under_test_end_0

//Case 2   Locked Execute-only region
 
RWX_VERIF region_under_test_end_1

// Case3 Locked Shared code region: Execute only on both M and S/Umode.*

RWX_VERIF region_under_test_end_2


RWX_VERIF region_under_test_end_3

RWX_VERIF region_under_test_end_4

nop
nop 
j exit
nop
nop
.align 4
.align RVMODEL_PMP_GRAIN
// Region Under 

region_under_test_start_0:
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
region_under_test_end_0:

return_to_verif_0:
 nop
 nop
 jr ra
 nop
 nop
 
region_under_test_start_1:
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
region_under_test_end_1:

return_to_verif_1:
 nop
 nop
 jr ra
 nop
 nop
 
region_under_test_start_2:
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
region_under_test_end_2:

return_to_verif_2:
 nop
 nop
 jr ra
 nop
 nop
 
region_under_test_start_3:
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
region_under_test_end_3:


return_to_verif_3:
 nop
 nop
 jr ra
 nop
 nop


region_under_test_start_4:
.rept (1 << RVMODEL_PMP_GRAIN )
addi a6,a6,1
.endr
region_under_test_end_4:

return_to_verif_4:
 nop
 nop
 jr ra
 nop
 nop
// label for facilitating test control flow
.align 4
exit:
#endif

RVTEST_CODE_END
RVMODEL_HALT

end_code_section:

// Arch test Tempelate 

RVTEST_DATA_BEGIN
.align 4
rvtest_data:
RVTEST_DATA_END
RVMODEL_DATA_BEGIN
  rvtest_sig_begin:
  sig_begin_canary:
  CANARY;
.globl begin_signature
begin_signature1:
   .rept 254
    .word 0xdeadbeef
   .endr
.globl end_signature
end_signature1:
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 512*(XLEN/32),4,0xdeadbeef
tsig_end_canary:
CANARY;
#endif
#ifdef rvtest_gpr_save
gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef
#endif
rvtest_sig_end:
RVMODEL_DATA_END
rvmodel_data_end: