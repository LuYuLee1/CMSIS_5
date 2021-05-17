;/*
; * Copyright (c) 2013-2021 Arm Limited. All rights reserved.
; *
; * SPDX-License-Identifier: Apache-2.0
; *
; * Licensed under the Apache License, Version 2.0 (the License); you may
; * not use this file except in compliance with the License.
; * You may obtain a copy of the License at
; *
; * www.apache.org/licenses/LICENSE-2.0
; *
; * Unless required by applicable law or agreed to in writing, software
; * distributed under the License is distributed on an AS IS BASIS, WITHOUT
; * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; * See the License for the specific language governing permissions and
; * limitations under the License.
; *
; * -----------------------------------------------------------------------------
; *
; * Project:     CMSIS-RTOS RTX
; * Title:       ARMv7-M Exception handlers
; *
; * -----------------------------------------------------------------------------
; */


                IF       ({FPU}="FPv4-SP")
FPU_USED        EQU      1
                ELSE
FPU_USED        EQU      0
                ENDIF

I_T_RUN_OFS     EQU      20                     ; osRtxInfo.thread.run offset
TCB_SP_OFS      EQU      56                     ; TCB.SP offset
TCB_SF_OFS      EQU      34                     ; TCB.stack_frame offset

FPCCR           EQU      0xE000EF34             ; FPCCR Address

                PRESERVE8
                THUMB


                AREA     |.constdata|, DATA, READONLY
                EXPORT   irqRtxLib
irqRtxLib       DCB      0                      ; Non weak library reference


                AREA     |.text|, CODE, READONLY


SVC_Handler     PROC
                EXPORT   SVC_Handler
                IMPORT   osRtxUserSVC
                IMPORT   osRtxInfo

                TST      LR,#0x04               ; Determine return stack from EXC_RETURN bit 2
                ITE      EQ
                MRSEQ    R0,MSP                 ; Get MSP if return stack is MSP
                MRSNE    R0,PSP                 ; Get PSP if return stack is PSP

                LDR      R1,[R0,#24]            ; Load saved PC from stack
                LDRB     R1,[R1,#-2]            ; Load SVC number
                CBNZ     R1,SVC_User            ; Branch if not SVC 0

                PUSH     {R0,LR}                ; Save SP and EXC_RETURN
                LDM      R0,{R0-R3,R12}         ; Load function parameters and address from stack
                BLX      R12                    ; Call service function
                POP      {R12,LR}               ; Restore SP and EXC_RETURN
                STM      R12,{R0-R1}            ; Store function return values

SVC_Context
                LDR      R3,=osRtxInfo+I_T_RUN_OFS; Load address of osRtxInfo.thread.run
                LDM      R3,{R1,R2}             ; Load osRtxInfo.thread.run: curr & next
                CMP      R1,R2                  ; Check if thread switch is required
                IT       EQ
                BXEQ     LR                     ; Exit when threads are the same

              IF FPU_USED != 0
                CBNZ     R1,SVC_ContextSave     ; Branch if running thread is not deleted
                TST      LR,#0x10               ; Determine stack frame from EXC_RETURN bit 4
                BNE      SVC_ContextSwitch      ; Branch if not extended stack frame
                LDR      R3,=FPCCR              ; FPCCR Address
                LDR      R0,[R3]                ; Load FPCCR
                BIC      R0,R0,#1               ; Clear LSPACT (Lazy state preservation)
                STR      R0,[R3]                ; Store FPCCR
                B        SVC_ContextSwitch      ; Branch to context switch handling
              ELSE
                CBZ      R1,SVC_ContextSwitch   ; Branch if running thread is deleted
              ENDIF

SVC_ContextSave
                STMDB    R12!,{R4-R11}          ; Save R4..R11
              IF FPU_USED != 0
                TST      LR,#0x10               ; Determine stack frame from EXC_RETURN bit 4
                IT       EQ                     ; If extended stack frame
                VSTMDBEQ R12!,{S16-S31}         ;  Save VFP S16.S31
                STRB     LR, [R1,#TCB_SF_OFS]   ; Store stack frame information
              ENDIF
                STR      R12,[R1,#TCB_SP_OFS]   ; Store SP

SVC_ContextSwitch
                STR      R2,[R3]                ; osRtxInfo.thread.run: curr = next

SVC_ContextRestore
                LDR      R0,[R2,#TCB_SP_OFS]    ; Load SP
              IF FPU_USED != 0
                LDRB     R1,[R2,#TCB_SF_OFS]    ; Load stack frame information
                ORN      LR,R1,#0xFF            ; Set EXC_RETURN
                TST      LR,#0x10               ; Determine stack frame from EXC_RETURN bit 4
                IT       EQ                     ; If extended stack frame
                VLDMIAEQ R0!,{S16-S31}          ;  Restore VFP S16..S31
              ELSE
                MVN      LR,#~0xFFFFFFFD        ; Set EXC_RETURN value
              ENDIF
                LDMIA    R0!,{R4-R11}           ; Restore R4..R11
                MSR      PSP,R0                 ; Set PSP

SVC_Exit
                BX       LR                     ; Exit from handler

SVC_User
                LDR      R2,=osRtxUserSVC       ; Load address of SVC table
                LDR      R3,[R2]                ; Load SVC maximum number
                CMP      R1,R3                  ; Check SVC number range
                BHI      SVC_Exit               ; Branch if out of range

                PUSH     {R0,LR}                ; Save SP and EXC_RETURN
                LDR      R12,[R2,R1,LSL #2]     ; Load address of SVC function
                LDM      R0,{R0-R3}             ; Load function parameters from stack
                BLX      R12                    ; Call service function
                POP      {R12,LR}               ; Restore SP and EXC_RETURN
                STR      R0,[R12]               ; Store function return value

                BX       LR                     ; Return from handler

                ALIGN
                ENDP


PendSV_Handler  PROC
                EXPORT   PendSV_Handler
                IMPORT   osRtxPendSV_Handler

                PUSH     {R0,LR}                ; Save EXC_RETURN
                BL       osRtxPendSV_Handler    ; Call osRtxPendSV_Handler
                POP      {R0,LR}                ; Restore EXC_RETURN
                MRS      R12,PSP                ; Save PSP to R12
                B        SVC_Context            ; Branch to context handling

                ALIGN
                ENDP


SysTick_Handler PROC
                EXPORT   SysTick_Handler
                IMPORT   osRtxTick_Handler

                PUSH     {R0,LR}                ; Save EXC_RETURN
                BL       osRtxTick_Handler      ; Call osRtxTick_Handler
                POP      {R0,LR}                ; Restore EXC_RETURN
                MRS      R12,PSP                ; Save PSP to R12
                B        SVC_Context            ; Branch to context handling

                ALIGN
                ENDP


                END