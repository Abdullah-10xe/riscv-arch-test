// ---------------------------------------------------------------------------
// Copyright (c) 2020. RISC-V International. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Title       	: Comprehensive ACTS For SMEPMP (Supervisor Mode Enchanced Physical Memory Protection) Verification
// Authors     	: Abdullah Jhatial
// Contact	  	: https://github.com/Abdullah-10xe
// Test Plan    : https://docs.google.com/spreadsheets/d/10nzG7CR1VP7XvQDaEkK3NrWb0W8dXFUt0H6VPZ99yVY/edit?gid=0#gid=0
//-----------------------------------------------------------------------------------------------------------------------
// Description  : This test verifies the Reserved Encoding ,Shouodl not be written in PMPICFG when MML is 0 ,or MML is set
// Test         :  
//       When MML is unset     :  case WRITE only   
//                             :  case WRITE EXECUTE          
//                             :  case Locked WRITE           
//                             :  case Locked WRITE EXECUTE 
//        When MML is set      :  case Locled and Execute only
//                             :  case Locked and Write  
//                             :  case Locked ,Write and Execute
// Dependencies :   model_test.h, arch_test.h
// Fault        : No fault expected from test code 
// ---------------------------------------------------------------------------

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV64I_Zicsr")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
RVTEST_CASE(1,"def TEST=True;def rvtest_mtrap_routine = True;", MML_Reserved_Encoding)

#ifndef RVMODEL_PMP_GRAIN
  #define RVMODEL_PMP_GRAIN 0
#endif

#ifndef RVMODEL_NUM_PMPS
  #define RVMODEL_NUM_PMPS 16
#endif

#ifdef TEST
// ---------------------------------------------------------------------------
// Signature Space for Recording Signatures 
// ---------------------------------------------------------------------------
RVTEST_SIGBASE(x13, begin_signature1)
.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align	3
RVTEST_SIGBASE(x13, begin_signature1)
.attribute unaligned_access,0
.attribute stack_align ,16
.option  norvc
.align  3

/* --------------------------------------------------------------------------
   Macro: PMPCFG_SET
   Description: Configure PMP entries with desired permissions.
   Arguments:
     PMPCFGI      - PMP configuration CSR (e.g., pmpcfg0)
     PMPICFG      - PMP config index
     LAXWR        - Access permissions (Load/Access/Write/Read)
     PMPCFGI_SET  - Flag (True/False) to either overwrite or update
   -------------------------------------------------------------------------- */
.macro PMPCFG_SET PMPCFGI  PMPICFG  LAXWR  PMPCFGI_SET  
 .if \PMPCFGI_SET == False
 li a5, CLEAR(\PMPICFG)
 csrc \PMPCFGI,a5
 li a5, SET(\LAXWR,\PMPICFG)
 csrs \PMPCFGI ,a5
 .endif
 .if \PMPCFGI_SET == True
   li a5,\LAXWR
   csrw \PMPCFGI ,a5
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


/* --------------------------------------------------------------------------
   Test Setup: CLEAR all PMP configuration and address registers.
   -------------------------------------------------------------------------- */
Test_setup:
  .SET pmpcfgi , CSR_PMPCFG0
  .rept RVMODEL_NUM_PMPS/8
     csrw pmpcfgi ,x0        // CLEAR PMP configuration register
  .SET pmpcfgi ,pmpcfgi+2
  .endr
  .SET pmpaddri ,CSR_PMPADDR0
  .rept RVMODEL_NUM_PMPS
     csrw pmpaddri ,x0       // CLEAR PMP address register
     .SET pmpaddri,pmpaddri+1
  .endr


/* --------------------------------------------------------------------------
   Test Code: Configure PMP entries with Reserved Encoding 
   -------------------------------------------------------------------------- */
test_code:
 // Test : reserved encoding
 
 PMPCFG_SET pmpcfg0 ,PMP0_CFG_SHIFT ,PMPCFG(TOR,W),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 
 PMPCFG_SET pmpcfg0 ,PMP0_CFG_SHIFT ,PMPCFG(TOR,WX),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 
 PMPCFG_SET pmpcfg0 ,PMP0_CFG_SHIFT ,PMPCFG(TOR,LW),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 
 PMPCFG_SET pmpcfg0 ,PMP1_CFG_SHIFT ,PMPCFG(TOR,LWX),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 /// Set code section as Machine Execute and read and data section/tohost section as read write for both Modes
  TOR_PMPADDR pmpaddr8 , rvtest_entry_point
 TOR_PMPADDR pmpaddr9 , end_code_section
 PMPCFG_SET pmpcfg2 ,PMP1_CFG_SHIFT ,PMPCFG(TOR,LRX),False
 LI(a4,MML_SET)
 csrw mseccfg,a4
 
 TOR_PMPADDR pmpaddr10 , end_code_section
 TOR_PMPADDR pmpaddr11 , rvmodel_data_end
 PMPCFG_SET pmpcfg2 ,PMP3_CFG_SHIFT ,PMPCFG(TOR,WX),False
 
 PMPCFG_SET pmpcfg0 ,PMP0_CFG_SHIFT ,PMPCFG(TOR,LW),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 PMPCFG_SET pmpcfg0 ,PMP0_CFG_SHIFT ,PMPCFG(TOR,LWX),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 PMPCFG_SET pmpcfg0 ,PMP0_CFG_SHIFT ,PMPCFG(TOR,LX),False
 csrr a4,pmpcfg0
 RVTEST_SIGUPD(x13,a4)
 
 
 
 

nop
nop 
j exit
nop
nop
.align 4
region_under_test_start:
addi a6,a6,1
region_under_test_end:
return_to_verif:
 nop
 nop
 jr ra
 nop
 nop
// lable for faciliting test control flow
exit:
#endif
RVTEST_CODE_END
RVMODEL_HALT
end_code_section:

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
   // .fill 528*(XLEN/32),(XLEN/4),0xdeadbeef
   .rept 254
    .word 0xdeadbeef
   .endr
    .globl end_signature
end_signature1:
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 448*(XLEN/32),4,0xdeadbeef
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
