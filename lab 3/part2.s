

.equ TIM_ADDR, 0xFFFEC600       @ Base address for the ARM A9 Private Timer
.equ HEX0_3_ADDR, 0xFF200020    @ Address for HEX0, 1, 2, 3
.equ HEX4_5_ADDR, 0xFF200030    @ Address for HEX4, 5




.global _start


_start:

    LDR A1, =50000000         @ Clock = 200MHz = 200 million cycles per second, we need 0.25 seconds so 200 million * 0.25 = 50 million
    MOV A2, #0b011              @ bit 0 = enable, bit 1 = auto-reload

    BL ARM_TIM_config_ASM       @ start timer

    MOV A1, #0x3F 
    BL HEX_clear_ASM            @ clear all displays

    MOV V1, #0                  @ V1 = counter from 0 to 15


@ Timer exercise

TIMER_TEST_LOOP:
    BL ARM_TIM_read_INT_ASM     @ A1 = 1 if finshed, else 0
    CMP A1, #1
    BEQ TIMER_FINISHED
    B TIMER_TEST_LOOP

TIMER_FINISHED:
    BL ARM_TIM_clear_INT_ASM    @ reset the bit 0 (F)
    ADD V1, V1, #1              @ increment counter
    CMP V1, #16                 
    MOVEQ V1, #0

    MOV A1, #0x01
    MOV A2, V1
    BL HEX_write_ASM

    B TIMER_TEST_LOOP



@ Setting up the A9 Private Timer
@ pre- A1: Number to count down from
@ pre- A2: Control bits for the timer
ARM_TIM_config_ASM:
    LDR A3, =TIM_ADDR           @ load base address of the timer
    STR A1, [A3, #0x00]         @ load the load value into A1
    STR A2, [A3, #0x08]         @ load the control bits 
    BX LR

@ Returns F  from the timer from the interrupt state register
ARM_TIM_read_INT_ASM:
    LDR A2, =TIM_ADDR           @load base address of timer
    LDR A1, [A2, #12]           @ A1 = interrupt status register (0xFFFEC60C)
    AND A1, A1, #1              @ get only bit 0 
    BX LR

@ Clear the "F" value int he interrupt restate register
ARM_TIM_clear_INT_ASM:
    LDR A2, =TIM_ADDR           @ A2 = base address timer
    MOV A3, #1
    STR A3, [A2, #12]           @ write 1 to interrupt state register to clear the bit 0
    BX LR





@ 1- HEX displays (from part1.s)

@ Clear all selected displays
@ pre- A1: receiving sleected displays to modify (e.g.: 0b001100 = modify HEX2 & HEX3)
HEX_clear_ASM:
    PUSH {V1-V4, LR}

    LDR V1, =HEX_display_addresses      @ base address of address table      
    MOV V2, #0                          @ loop counter (from 0 to 5)
    MOV V3, #0x00                       @ value to write (0x00 = all segments off)

clear_loop:
    CMP V2, #6                          @ check if counter less than 6
    BGE clear_loop_end       
 
    @ Check the ith bit of A1 if it is set
    MOV V4, #1                          @ V4 = 1
    LSL V4, V4, V2                      @ V4 = V4 * 2^(V2)
    TST A1, V4                          @ test bit by bit
    BEQ clear_skip_index                @ if all bits same (not set), skip

    @ Else, bit is set
    LDR V4, [V1, V2, LSL #2]            @ V4 = hex_display_address[i], V1 + V2 (index) * 4 (because each address = 4 bytes = word)
    STRB V3, [V4]                       @ Store a byte (V3 = 0x00) at V4
    
clear_skip_index:
    ADD V2, V2, #1                      @ i++
    B clear_loop                        @ repeat loop


clear_loop_end:
    POP {V1-V4, LR}                     @ restore registers
    BX LR                               @ return



@ Turn On all segments in the HEX display
@ pre- A1: which displays to modify
HEX_flood_ASM:
PUSH {V1-V4, LR}
    LDR V1, =HEX_display_addresses      @ base address of address table      
    MOV V2, #0                          @ loop counter (from 0 to 5)
    MOV V3, #0xFF                       @ value to write (0xFF = all segments on)

flood_loop:
    CMP V2, #6                          @ check if counter less than 6
    BGE flood_loop_end       
 
    @ Check the ith bit of A1 if it is set
    MOV V4, #1                          @ V4 = 1
    LSL V4, V4, V2                      @ shift V4 left to compare if it corresponds to one of the hex to modify
    TST A1, V4                          @ test bit by bit
    BEQ flood_skip_index                      @ if all bits same (not set), skip

    @ Else, bit is set
    LDR V4, [V1, V2, LSL #2]            @ V4 = hex_display_address[i], V1 + V2 (index) * 4 (because each address = 4 bytes = word)
    STRB V3, [V4]                       @ Store a byte (V3 = 0x00) at V4
    
flood_skip_index:
    ADD V2, V2, #1                      @ i++
    B flood_loop                        @ repeat loop


flood_loop_end:
    POP {V1-V4, LR}                     @ restore registers
    BX LR                               @ return




@ Write a hex digit to selected displays
@ pre- A1: which displays to write
@ pre- A2: value to write (0-15)
HEX_write_ASM:
    PUSH {V1-V5, LR}

    LDR V1, =HEX_display_addresses      @ V1 = base of address table
    LDR V3, =HEX_CODES                  @ V3 = base of 7-segment pattern table

    LDRB V3, [V3, A2]                   @ V3 = pattern for value to write

    MOV V2, #0                          @ loop counter  (from 0 to 5)

write_loop:
    CMP V2, #6                          @ check if counter less than 6
    BGE write_loop_end       
 
    @ Check the ith bit of A1 if it is set
    MOV V4, #1                          @ V4 = 1
    LSL V4, V4, V2                      @ shift V4 left to compare if it corresponds to one of the hex to modify
    TST A1, V4                          @ test bit by bit
    BEQ write_skip_index                @ if all bits same, skip

    @ Else, bit is set
    LDR V4, [V1, V2, LSL #2]            @ V4 = hex_display_address[i], V1 + V2 (index) * 4 (because each address = 4 bytes = word)
    STRB V3, [V4]                       @ store a byte (V3 = pattern) at V4  

write_skip_index:
    ADD V2, V2, #1                      @ i++
    B write_loop                        @ repeat loop

write_loop_end:
    POP {V1-V5, LR}                     @ restore registers
    BX LR                               @ return










.align


@ Lookup table for the 6 HEX display addresses
HEX_display_addresses:
    .word 0xFF200020        @ Address for HEX0
    .word 0xFF200021        @ Address for HEX1
    .word 0xFF200022        @ Address for HEX2
    .word 0xFF200023        @ Address for HEX3
    .word 0xFF200030        @ Address for HEX4
    .word 0xFF200031        @ Address for HEX5

@ Changed look for clarity
HEX_CODES:
    .byte 0b00111111  @ 0
    .byte 0b00000110  @ 1
    .byte 0b01011011  @ 2
    .byte 0b01001111  @ 3
    .byte 0b01100110  @ 4
    .byte 0b01101101  @ 5
    .byte 0b01111101  @ 6
    .byte 0b00000111  @ 7
    .byte 0b01111111  @ 8
    .byte 0b01101111  @ 9
    .byte 0b01110111  @ A
    .byte 0b01111100  @ b
    .byte 0b00111001  @ C
    .byte 0b01011110  @ d
    .byte 0b01111001  @ E
    .byte 0b01110001  @ F
    .byte 0b00000000  @ BLANK (16)