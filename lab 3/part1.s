.equ SW_ADDR, 0xFF200040        @ Memory address for slider switches
.equ LED_ADDR, 0xFF200000       @ Memory address for LEDs
.equ HEX0_3_ADDR, 0xFF200020    @ Address for HEX0, 1, 2, 3
.equ HEX4_5_ADDR, 0xFF200030    @ Address for HEX4, 5
.equ PB_ADDR, 0xFF200050     @ Base address for all Pushbutton registers

@ Constants for Pushbuttons
.equ PB_ROTATE, 0x08           @ Bitmask for PB3 (0b1000)
.equ PB_REVERSE, 0x04          @ Bitmask for PB2 (0b0100)


.global _start

_start:
    BL PB_clear_edgecp_ASM      @ clear any old button clicks
    
    @ Loading base addresses of global variables
    LDR V5, =current_msg_ptr    @ V5 = address of current_msg_ptr
    LDR V6, =rotation_offset    @ V6 = address of rotation_offset
    LDR V7, =rotation_count     @ V7 = address of rotation_count
    LDR V8, =direction          @ V8 = address of direction
    LDR R12, =last_switch_state @ R12 = address of last_switch_state

    @ Default state for COFFEE
    LDR V1, =MSG_COFFEE
    STR V1, [V5]                @ current_msg_ptr = address of MSG_COFFEE
    MOV V1, #0
    STR V1, [V6]                @ rotation_offset = 0
    STR V1, [V7]                @ rotation_count = 0
    STR V1, [R12]               @ last_switch_state = 0
    MOV V1, #1
    STR V1, [V8]                @ direction = 1 (left)

@ Polling loop, always running    
MAIN_LOOP:
    BL read_slider_switches_ASM @ A1 = current switch value
    LDR V1, [R12]               @ V1 = last switch value
    CMP A1, V1                  @ comparing to see if it changed
    BNE HANDLE_SWITCH_CHANGE    @ it changed, so go to handle_switch_change
    
CHECK_BUTTONS:
    BL read_PB_edgecp_ASM       
    CMP A1, #0
    BEQ UPDATE_DISPLAY          @ if 0, no buttons were clicked, so skip to display
    
    @ If a button was clicked
    BL PB_clear_edgecp_ASM      @ Reset the latch
    
    @ Check if display is blank. If so, buttons do nothing
    LDR V1, [V5]                @ V1 = the current message pointer
    LDR V2, =MSG_BLANK
    CMP V1, V2                  @ if message pointer == MSG_BLANK
    BEQ UPDATE_DISPLAY          @ if yes skip button logic and just update display
    
    @ Check for PB2 
    TST A1, #PB_REVERSE         @ check if the "reverse" button bit (0b0100) is set
    BLNE REVERSE_DIRECTION      @ if yes jump to reverse direction
    
    @ Check for PB3 (Rotate)
    TST A1, #PB_ROTATE          @ check if the "rotate" button bit (0b1000) is set
    BLNE ROTATE_MESSAGE         @ if yes, jump to rotate message

UPDATE_DISPLAY:
    @ Redraw the 6 HEX displays
    BL DISPLAY_MESSAGE
    
UPDATE_LEDS:
    @ Redraw the LEDs
    LDR A1, [V7]                @ A1 = rotation_count
    LDR V1, = 1023              @ changed requirement
    CMP A1, V1                  @ check if count > 2047
    LDRHI A1, =0x3FF            @ if yes >2047 , load A1 with 0x3FF (all 10 LEDs on)
    BL write_LEDs_ASM           @ write the count value to the LEDs
    
    B MAIN_LOOP                 @ loop forever

@ Helper Subroutines of MAIN_LOOP

@ This is called when the slider switch value changes
HANDLE_SWITCH_CHANGE:
    @ A1 holds the new switch value from MAIN_LOOP
    STR A1, [R12]               @ save new switch value to last_switch_state
    
    @ Reset state variables to default
    MOV V1, #0
    STR V1, [V6]                @ rotation_offset = 0
    STR V1, [V7]                @ rotation_count = 0
    @ MOV V1, #1
    @ STR V1, [V8]                @ direction = 1 (left)
    
    @ Find the correct new message pointer
    CMP A1, #0x00
    LDRNE V1, =MSG_BLANK        @ Default: load blank message pointer
    LDREQ V1, =MSG_COFFEE       @ if 0x00, load C0FFEE pointer
    BEQ SET_MSG_PTR             @ jump to save the pointer
    
    CMP A1, #0x01
    LDREQ V1, =MSG_CAFE5        @ if 0x01, load CAFE5 pointer
    BEQ SET_MSG_PTR
    
    CMP A1, #0x02
    LDREQ V1, =MSG_CAb5         @ if 0x02, load CAb5 pointer
    BEQ SET_MSG_PTR
    
    CMP A1, #0x04
    LDREQ V1, =MSG_ACE          @ if 0x04, load ACE pointer
    @ SET_MSG_PTR follows naturally
    
SET_MSG_PTR:
    STR V1, [V5]                @ save the new message pointer to current_msg_ptr
    B CHECK_BUTTONS             @ go back to the main loop

@ Reverses the direction of rotation
REVERSE_DIRECTION:
    PUSH {V1, LR}               @ save V1 and LR
    LDR V1, [V8]                @ V1 = current direction (1 or -1)
    RSB V1, V1, #0              @ V1 = 0 - V1 (always becomes the opposite)
    STR V1, [V8]                @ save the new direction
    POP {V1, LR}
    BX LR

@ Rotates the message and increments the count
ROTATE_MESSAGE:
    PUSH {V1-V3, LR}            @ save V1-V3 and LR
    LDR V1, [V6]                @ V1 = current rotation_offset
    LDR V2, [V8]                @ V2 = current direction
    
    ADD V1, V1, V2              @ offset = offset + direction
    
    @ Handle wrap-around
    CMP V1, #6
    MOVEQ V1, #0                @ if offset == 6, wrap to 0
    CMP V1, #-1
    MOVEQ V1, #5                @ if offset == -1, wrap to 5
    
    STR V1, [V6]                @ save new rotation_offset
    
    @ Increment LED count
    LDR V3, [V7]                @ V3 = rotation_count
    ADD V3, V3, #1              @ count++
    STR V3, [V7]                @ save new rotation_count
    
    POP {V1-V3, LR}
    BX LR

@ Displays the 6 characters on the 6 HEX displays
DISPLAY_MESSAGE:
    PUSH {V1-V5, LR}            @ save registers for the loop
    
    LDR V1, [V5]                @ V1 = get message pointer (e.g., &MSG_COFFEE)
    LDR V2, [V6]                @ V2 = get rotation offset (e.g., 1)
    
    MOV V3, #0                  @ V3 = loop counter i=0 (for message index 0 to 5)
    
@ Looping through each of the 6 HEX displays
DISPLAY_LOOP:
    CMP V3, #6                  @ is i < 6?
    BGE END_DISPLAY_LOOP        @ if not, end
    
    @ calculate index to show: V4 = i + offset
    ADD V4, V3, V2              @ V4 = idx
    
    @ handle wrap-around for index (Modulo 6)
    CMP V4, #6
    SUBGE V4, V4, #6            @ if idx >= 6, idx = idx - 6
    CMP V4, #0
    ADDLT V4, V4, #6            @ if idx < 0, idx = idx + 6
    
    @ V4 is now the safe message index (0-5)
    LDRB A2, [V1, V4]           @ A2 = get char code from message[V4]
    
    @ A1 = bitmask for current display
    @ We want from left to right so i=0 -> HEX5 (0x20), i=1 -> HEX4 (0x10), ..., i=5 -> HEX0 (0x01)
    @ The logic is: bitmask = 1 << (5 - i)
    MOV A1, #1
    MOV V5, #5
    SUB V5, V5, V3              @ V5 = 5 - i
    LSL A1, A1, V5              @ A1 = 1 << (5 - i) (A1 was 0b000001, now shifted left becomes 0b100000 = 0x20 for i=0)
    
    @ call driver to write this char
    PUSH {V1-V5}                @ save registers before nested call
    BL HEX_write_ASM
    POP {V1-V5}                 @ restore registers
    
    ADD V3, V3, #1              @ i++
    B DISPLAY_LOOP
    
END_DISPLAY_LOOP:
    POP {V1-V5, LR}
    BX LR






// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
read_slider_switches_ASM:
    LDR A2, =SW_ADDR // load the address of slider switch state
    LDR A1, [A2] // read slider switch state
    BX LR

// LEDs Driver
// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
write_LEDs_ASM:
    LDR A2, =LED_ADDR // load the address of the LEDs' state
    STR A1, [A2] // update LED state with the contents of A1
    BX LR




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


@ 2- Pushbuttons

@ Read the current state of pushbuttons
@ posst- A1: if pushbutton currently pressed
read_PB_data_ASM:
    LDR A2, =PB_ADDR                    @ load the address of pushbutton state
    LDR A1, [A2]                        @ read pushbutton state, a word, because the button data is in bits 0-3
    BX LR                               @ return

@ Check if any pushbutton is currently pressed
@ pre- A1: mask of buttons to check (e.g.: 0b0001 = check PB0, 0b0011 = check PB0 & PB1)
@ post- A1: 0 = no button pressed, 1 = at least one button pressed
PB_data_is_pressed_ASM:
    PUSH {A2, A3}                       @ save registers  
    LDR A2, =PB_ADDR                    @ load the address of pushbutton state
    LDR A3, [A2]                        @ read pushbutton state

    TST A3, A1                          @ test A3 with A1 (A1 is the mask of buttons to check)
    MOVNE A1, #1                        @ if any button pressed, set A1 = 1
    MOVEQ A1, #0                        @ else, set A1 = 0

    POP {A2, A3}                        @ restore registers
    BX LR

read_PB_edgecp_ASM:
    LDR A2, =PB_ADDR                    @ load the address of pushbutton state
    LDR A1, [A2, #12]                   @ edgecapture register is at offset 12
    BX LR

@ Checking if specific pushbotton has been pressed
PB_edgecp_is_pressed_ASM:
    PUSH {A2, A3}
    LDR A2, =PB_ADDR
    LDR A3, [A2, #12]       @ Read the *Edgecapture* register into A3
    
    @ Same logic as PB_data_is_pressed_ASM:
    TST A3, A1              
    MOVNE A1, #1                        @ if any button pressed, set A1 = 1
    MOVEQ A1, #0                        @ else, set A1 = 0

    POP {A2, A3}                        @ restore registers
    BX LR

@ Clear pushbutton edgecapture register
@ To clear, write any value to it
PB_clear_edgecp_ASM:
    LDR A2, =PB_ADDR                    @ load the address of pushbutton state
    LDR A3, [A2, #12]                   @ Read the current latch value into A3
    STR A3, [A2, #12]                   @ Write that same value back to clear it
    BX LR

@ Enable interrupt for pushbuttons
enable_PB_INT_ASM:
    PUSH {A2, A3}
    LDR A2, =PB_ADDR                    @ load the address of pushbutton state
    LDR A3, [A2, #8]                    @ interrupt is at +8
    ORR A3, A3, A1                      @ set bits in A3 that are set in A1 ( A3 OR A1 )
    STR A3, [A2, #8]                    @ write back
    POP {A2, A3}
    BX LR

disable_PB_INT_ASM:
    PUSH {A2, A3}
    LDR A2, =PB_ADDR
    LDR A3, [A2, #8]                    @ read current interrupt at +8

    BIC A3, A3, A1                      @ Clear bits in A3 that are set in A1 ( A3 AND NOT A1 )
    
    STR A3, [A2, #8]                    @ Write the *new* combined mask back
    POP {A2, A3}
    BX LR    

@ DATA 

.align      @ Allows data to start on addresses divisible by 4

@ Global variables
current_msg_ptr:
    .word MSG_COFFEE    @ Pointer to the message currently being shown
rotation_offset:
    .word 0             @ Current rotation index (0-5)
direction:
    .word 1             @ 1 for left, -1 for right
rotation_count:
    .word 0             @ Count for the LEDs
last_switch_state:
    .word 0             @ Last read switch value, to detect changes

@ Messages (COFFEE, CAFE5...)
MSG_COFFEE:
    .byte 12, 0, 15, 15, 14, 14  @ C, 0, F, F, E, E
MSG_CAFE5:
    .byte 12, 10, 15, 14, 5, 16  @ C, A, F, E, 5, BLANK
MSG_CAb5:
    .byte 12, 10, 11, 5, 16, 16  @ C, A, b, 5, BLANK, BLANK
MSG_ACE:
    .byte 10, 12, 14, 16, 16, 16 @ A, C, E, BLANK, BLANK, BLANK
MSG_BLANK:
    .byte 16, 16, 16, 16, 16, 16 @ BLANK, BLANK, BLANK, BLANK, BLANK, BLANK

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


@ Pushbutton addresses
