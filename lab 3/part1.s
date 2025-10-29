// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
.equ SW_ADDR, 0xFF200040
read_slider_switches_ASM:
    LDR A2, =SW_ADDR // load the address of slider switch state
    LDR A1, [A2] // read slider switch state
    BX LR
// LEDs Driver
// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
.equ LED_ADDR, 0xFF200000
write_LEDs_ASM:
    LDR A2, =LED_ADDR // load the address of the LEDs' state
    STR A1, [A2] // update LED state with the contents of A1
    BX LR



.global _start

_start:

@ GETTING STARTED PART: infinite loop
LOOP: 
    BL read_slider_switches_ASM     @ Branch and Link, after this, switch state is in A1
    BL write_LEDs_ASM               @ Branch and Link, takes A1 from previous call, sends it to LED
    B LOOP                          @ infinite loop


@ 1- HEX displays

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




@ DATA for hex displays

.align      @ Allows data to start on addresses divisible by 4

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
