// --------------------------------------------------------------------------------------------------------------------
// Copyright (c) 2020. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Title       	: Comprehensive ACTS For SMEPMP (Supervisor Mode Enchanced Physical Memory Protection) Verification
// Authors     	: Abdullah Jhatial
// Contact	  	: https://github.com/Abdullah-10xe
// Test Plan    : https://docs.google.com/spreadsheets/d/10nzG7CR1VP7XvQDaEkK3NrWb0W8dXFUt0H6VPZ99yVY/edit?gid=0#gid=0
//-----------------------------------------------------------------------------------------------------------------------
// Description  : This test verifies the functionality  of SMEPMP 
//                when MML bit and Lock bit is set in S/U mode
//
// Note         : For Verifing each case we setup the region permissions at start of the Test as Follow
//              : Locked Shared Code Region (LRWX=1011 )for test.init(code) region , and Sared Data region for other region
//              : Set Region under test region at highest Priority 
//-----------------------------------------------------------------------------------------------------------------------
//
// Note          : For Verifing each CASE we setup the region permissions at start of the Test as follow
//
// Methodeology  
// Step 1        : Enable RLB (Rule Lock Bypass) in mseccfg
//
// Step 2        : Configure region for Initial_Permission_Setup , Initial_Permsission_setup at lowest periority appropriattly as LX 
//
// Step 3        : Set MML (Machine Mode Lockdown) in mseccfg
//
// Step 4        : Configure region from rvtest_entry_point to end_code_section as LWX  
//
// Step 5        : Configure  region for Shared Data Section form end_code_section to rvmodel_data_end as WX
//
// Step 6        : Configure  region for Region Under Test region_under_test to region_under_test_end  at Highest pripority 
//                 - Permissions will be applied dynamically during test case .
//
//---------------------------------------------------------------------------------------------------------------------------------------------------
//   Casess With L bit unset
// Case 0       : MML bit is set in initial permission Setup code  now Unset the MML bit and update the signature  
// Case 1       : Set Permission   For Region Under Test As LRWX = 0000 (Inaccessible region)
// Case 2       : Set Permission   For Region Under Test As LRWX = 0001 (Execute-only region)
// Case 3       : Set Permission   For Region Under Test As LRWX = 0010 (Shared data region: Read/write on M mode, read-only on S/U mode)
// Case 4       : Set Permission   For Region Under Test As LRWX = 0011 (Shared data region: Read/write for both M and S/U mode  )
// Case 5       : Set Permission   For Region Under Test As LRWX = 0100 (Read-only region)
// Case 6       : Set Permission   For Region Under Test As LRWX = 0101 (Read/Execute region)
// Case 7       : Set Permission   For Region Under Test As LRWX = 0110 (Read/Write region)
// Case 8       : Set Permission   For Region Under Test As LRWX = 0111 (Read/Write/Execute region only in SU)
//--------------------------------------------------------------------------------------------------------
//  Casess With Lock bit set
// case1        : Set Permission   For Region Under Test As LRWX = 1000 (Locked inaccessible region)
// case2        : Set Permission   For Region Under Test As LRWX = 1001 (Locked Execute-only region)
// case3        : Set Permission   For Region Under Test As LRWX = 1010 (Locked Shared code region: Execute only on both M and S/U mode  )
// case4        : Set Permission   For Region Under Test As LRWX = 1011 (Locked Shared code region: Execute only on S/U mode,read/execute on M mode)
// case5        : Set Permission   For Region Under Test As LRWX = 1100 (Locked Read-only region)
// case6        : Set Permission   For Region Under Test As LRWX = 1101 (Locked Read/Execute region)
// case7        : Set Permission   For Region Under Test As LRWX = 1110 (Locked Read/Write region)
// case8        : Set Permission   For Region Under Test As LRWX = 1111 (Locked Shared data region: Read only on both M and S/U mode)
//
//-----------------------------------------------------------------------------------------------------------------------
// Verifiction  : For each case Execute,Store,Load from region under test at Byte/Half byte/Word/double word granulity 
// Note         : Verifecation in S Mode , and U Mode can be Controlled by UMODE Macro in this test file 
//-----------------------------------------------------------------------------------------------------------------------
// Expected     : In Each Case expected Access Fault occur in Each Mode, RWX permissions are enforced as Spec manifest 
// Instruction access faults = 11 ,load access fault = 36      ,store access fault= 52
// Dependencies : model_test.h, arch_test.h
//Fault         : INSTRUCTION ACCESS FAULT ,LOAD_ASSECC_FAULT,STORE_ACCESS_FAULT
// ---------------------------------------------------------------------------

#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV64I_Zicsr")

// ---------------------------------------------------------------------------
// Start of Code Region
// ---------------------------------------------------------------------------
.option norelax
.section .text.init
.globl rvtest_entry_point

// ---------------------------------------------------------------------------
// Test Entry Point
// ---------------------------------------------------------------------------
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine=True; def rvtest_strap_routine = True ",SMEPMP_MML_LRWX_TOR,SMEPMP_MML_RWX_TOR)

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
#define UMODE
// ---------------------------------------------------------------------------
// INSTRUCTION ENCODDINGS
// ---------------------------------------------------------------------------
#define INSTRUCTION            0x0015051300150513

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
 LA( a4,\REGION_UNDER_TEST-4)     // Load base address
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
 sd a5,0(a4)                    // Try store word
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
 ld a5,0(a4)                    // Try load word
 nop
 nop
 RVTEST_SIGUPD(x13,a5)          // Update signature after load
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
 
 RVTEST_GOTO_LOWER_MODE	Smode
 RWX_Access \ADDRESS-4
 RVTEST_GOTO_MMODE
 

 #ifdef UMODE 
 RVTEST_GOTO_LOWER_MODE Umode
 RWX_Access \ADDRESS-4
 RVTEST_GOTO_MMODE
 #endif
.endm

// ---------------------------------------------------------------------------
// Test_setup : CLEAR all PMP entries before beginning
// ---------------------------------------------------------------------------
Test_setup:
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

// ---------------------------------------------------------------------------
// initial_permission_setup : Setup PMP before testing
// Notes :
//   - Sets RLB before using L bit
//   - Defines TOR regions for code/data
//   - Enables MML in mseccfg to restrict M-mode
// ---------------------------------------------------------------------------
initial_permission_setup_start:

LI( a4,RLB_SET)
csrs mseccfg,a4

// Define TOR region with initial execute-only permissions
TOR_PMPADDR pmpaddr4 ,  initial_permission_setup_start
TOR_PMPADDR pmpaddr5 , initial_permission_setup_end 
PMPCFG_SET pmpcfg0 ,PMP5_CFG_SHIFT,PMPCFG(TOR,LX),False 

// Enable MML (restricts M-mode after setup)
LI( a4,MML_SET)
csrs mseccfg,a4

// Define code space (LWX = locked R/W/Execute for safety)
TOR_PMPADDR  pmpaddr2 , rvtest_entry_point
TOR_PMPADDR  pmpaddr3 , end_code_section
PMPCFG_SET pmpcfg0 ,PMP3_CFG_SHIFT,PMPCFG(TOR,LWX) ,False

// Shared data region = RW for all modes
TOR_PMPADDR pmpaddr4,end_code_section
TOR_PMPADDR pmpaddr5 ,rvmodel_data_end
PMPCFG_SET pmpcfg0 ,PMP5_CFG_SHIFT,   PMPCFG(TOR,WX),False

// Test region (RWX verification target)
TOR_PMPADDR pmpaddr0 , region_under_test_start
TOR_PMPADDR pmpaddr1 , region_under_test_end

initial_permission_setup_end:

test_code:
//CASE zero stickness of MML
LI( a4,0x1 )
csrc mseccfg,a4
RVTEST_SIGUPD(x13,a4)

// CASE 1 Inaccessible region SET the permsission


PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,NONE),False
RWX_VERIF region_under_test_end

//CASE 2    Execute-only region
 
PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,X) ,False
RWX_VERIF region_under_test_end

// Case3  Shared data region: Read/write on M mode, read-only on S/U mode

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,W)  ,False
RWX_VERIF region_under_test_end


// CASE 4 Shared data region: Read/write for both M and S/U mode 

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,WX) ,False
RWX_VERIF region_under_test_end

// CASE 5  Read-only region in S/U mode only

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT, PMPCFG(TOR,R)  ,False
RWX_VERIF region_under_test_end

//CASE 6  Read/Execute region in S/U mode only

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,RX) ,False
RWX_VERIF region_under_test_end

//CASE 7   Read/Write region in S/U mode only

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,RW) ,False
RWX_VERIF region_under_test_end

 //  Read Write Execute in S/U mode only

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,RWX)  ,False
RWX_VERIF region_under_test_end
/// MML now with Lock bit
// case 1 Inaccessible region 

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,L),False
RWX_VERIF region_under_test_end

//Case 2   Locked Execute-only region
 
PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LX) ,False
RWX_VERIF region_under_test_end

// Case3 Locked Shared code region: Execute only on both M and S/Umode.*

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LW)  ,False
RWX_VERIF region_under_test_end


// case4 Locked Shared code region: Execute only on S/U mode,read/execute on M mode.*

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LWX) ,False
RWX_VERIF region_under_test_end

// Case 5 Locked Read-only region*

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT, PMPCFG(TOR,LR)  ,False
RWX_VERIF region_under_test_end

//Case 6 Locked Read/Execute region

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LRX) ,False
RWX_VERIF region_under_test_end

//Case 7  Locked Read/Write region

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LRW) ,False
RWX_VERIF region_under_test_end

 // Locked Shared data region: Read only on both M and S/U mode.*

PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT,PMPCFG(TOR,LRWX)  ,False
RWX_VERIF region_under_test_end


nop
nop 
j exit
nop
nop

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

// Get back to where Jal instructino is used in verif code

return_to_verif:
 nop
 nop
 jr ra
 nop
 nop
// label for facilitating test control flow

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
   .rept 1024
    .word 0xdeadbeef
   .endr
.globl end_signature
end_signature1:
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 1024*(XLEN/32),4,0xdeadbeef
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
