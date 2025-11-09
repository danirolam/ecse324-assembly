
.section .vectors, "ax"
.align 2
B _start // reset vector
B SERVICE_UND // undefined instruction vector
B SERVICE_SVC // software interrupt vector
B SERVICE_ABT_INST // aborted prefetch vector

B SERVICE_ABT_DATA // aborted data vector
.word 0 // unused vector
B SERVICE_IRQ // IRQ interrupt vector
B SERVICE_FIQ // FIQ interrupt vector

.align

.equ TIM_ADDR, 0xFFFEC600       @ Base address for the ARM A9 Private Timer
.equ HEX0_3_ADDR, 0xFF200020    @ Address for HEX0, 1, 2, 3
.equ HEX4_5_ADDR, 0xFF200030    @ Address for HEX4, 5
.equ PB_SLOWER,  0x01   @ Bitmask for PB0
.equ PB_FASTER, 0x02   @ Bitmask for PB1
.equ PB_REVERSE, 0x04   @ Bitmask for PB2
.equ PB_PAUSE,   0x08   @ Bitmask for PB3
.equ SW_ADDR, 0xFF200040        @ Memory address for slider switches [cite: 56, 986]
.equ LED_ADDR, 0xFF200000       @ Memory address for LEDs [cite: 66, 938]
.equ PB_ADDR, 0xFF200050        @ Base address for all Pushbutton registers [cite: 998]



.text
.align
.global _start
_start:
    /* Set up stack pointers for IRQ and SVC processor modes */
    MOV R1, #0b11010010        // interrupts masked, MODE = IRQ
    MSR CPSR_c, R1             // change to IRQ mode
    LDR SP, =0xFFFFFFFC        // set IRQ stack to A9 on-chip memory (aligned)
    
    /* Change to SVC (supervisor) mode with interrupts disabled */
    MOV R1, #0b11010011        // interrupts masked, MODE = SVC
    MSR CPSR_c, R1             // change to supervisor mode
    LDR SP, =0x3FFFFFFC        // set SVC stack to top of DDR3 memory

    
    LDR V5, =current_msg_ptr
    LDR V6, =rotation_offset
    LDR V8, =direction
    LDR V7, =pause_state
    LDR R7, =speed_index
    LDR R5, =timer_load_values  @ R5 = base address of timer speed table
    LDR R6, =LED_patterns       @ R6 = base address of LED pattern table
    LDR R12, =last_switch_state
    
    @ dEFAUlt program state
    LDR V1, =MSG_COFFEE         @ Set default message
    STR V1, [V5]
    MOV V1, #0
    STR V1, [V6]                @ rotation_offset = 0
    STR V1, [V7]                @ pause_state = 0 (not paused)
    STR V1, [R12]               @ last_switch_state = 0
    MOV V1, #1
    STR V1, [V8]                @ direction = 1
    MOV V1, #2                  @ Default speed index = 2 (0.25s)
    STR V1, [R7]
    
    @ Configuration and enabling interrupts
    BL CONFIG_GIC               @ Configure the GIC (Timer + PBs)
    
    @ Enable Pushbutton Interrupts 
    MOV A1, #0xF                @ A1 = mask for PB0-3
    BL enable_PB_INT_ASM
    
    @ Configure and Start the Timer
    LDR V1, [R7]                @ V1 = speed_index (2)
    LSL V1, V1, #2              @ V1 = index * 4 (byte offset)
    LDR A1, [R5, V1]            @ A1 = load timer_load_values[2] (50M)
    @ Control bits: Enable (bit 0), Auto-reload (bit 1), IRQ Enable (bit 2)
    MOV A2, #0b111              
    BL ARM_TIM_config_ASM       @ Start the timer
    
    @ Enable master IRQ switch in CPU
    MOV R0, #0b01010011 // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0
    

IDLE:

    BL read_slider_switches_ASM @ A1 = current switch value
    LDR V1, [R12]               @ V1 = last switch value
    CMP A1, V1
    BNE HANDLE_SWITCH_CHANGE    @ If changed, jump to handler

CHECK_FLAGS:
    BL HANDLE_TIMER_TICK        @ checks tim_int_flag
    
    BL HANDLE_PB_CLICK          @ checks PB
    
    @ 4. Update Displays
    BL DISPLAY_MESSAGE          @ Redraw the HEX displays
    BL UPDATE_LEDS              @ redraw the LEDs
    
    B IDLE                      @ loop forever

@ Checks if the switch value has changed and updates the message
HANDLE_SWITCH_CHANGE:
    @ A1 holds the new switch value
    
    @ @ Reset state
    @ MOV V1, #0
    @ STR V1, [V6]                @ rotation_offset = 0
    @ MOV V1, #1
    @ STR V1, [V8]                @ direction = 1
    
    @ @ Reset speed to default (0.25s)
    @ MOV V1, #2                  @ V1 = default speed index 2
    @ STR V1, [R7]                @ save to speed_index
    @ BL UPDATE_TIMER_LOAD        @ update the timer hardware
    
    @ A1 holds the new switch value
    STR A1, [R12]               @ Save new switch value
    
    @ Find new message pointer first
    CMP A1, #0x00
    LDREQ V1, =MSG_COFFEE       @ if 0x00
    BEQ IS_VALID_SWITCH
    
    CMP A1, #0x01
    LDREQ V1, =MSG_CAFE5        @ if 0x01
    BEQ IS_VALID_SWITCH
    
    CMP A1, #0x02
    LDREQ V1, =MSG_CAb5         @ if 0x02
    BEQ IS_VALID_SWITCH
    
    CMP A1, #0x04
    LDREQ V1, =MSG_ACE          @ if 0x04
    BEQ IS_VALID_SWITCH
    
    CMP A1, #0x08
    LDREQ V1, =MSG_LOADS        @ if 0x08
    BEQ IS_VALID_SWITCH

    CMP A1, #0x10
    LDREQ V1, =MSG_CAFEBEEF     @ if 0x10
    BEQ IS_VALID_SWITCH
    
    @ If gets here, its an invalid switch
    LDR V1, =MSG_BLANK
    B SET_MSG_PTR_EXIT          @ Branch, skipping the state reset 
    
    
IS_VALID_SWITCH:
    @ A valid switch was found, so reset state
    MOV R0, #0
    STR R0, [V6]                @ rotation_offset = 0
    MOV R0, #1
    STR R0, [V8]                @ direction = 1
    
    @ Reset speed to default (0.25s)
    MOV R0, #2                  @ R0 = default speed index 2
    STR R0, [R7]                @ save to speed_index
    BL UPDATE_TIMER_LOAD        @ update the timer hardware


SET_MSG_PTR_EXIT:
    STR V1, [V5]                @ Save the new message pointer
    B CHECK_FLAGS               @ Go back to the main IDLE loop




@ Checks the tim_int_flag and rotates the message
HANDLE_TIMER_TICK:
    PUSH {V1, V2, LR}
    LDR V1, =tim_int_flag
    LDR V2, [V1]                @ V2 = tim_int_flag value
    CMP V2, #1                  @ Has the timer ticked?
    BNE END_TIMER_TICK          @ If not, just return
    
    @ Timer has ticked, reset flag
    MOV V2, #0
    STR V2, [V1]                @ tim_int_flag = 0
    
    @ Check if paused
    LDR V1, [V7]                @ V1 = pause_state
    CMP V1, #1
    BEQ END_TIMER_TICK          @ If paused, do nothing
    
    @ Not paused, so rotate
    BL ROTATE_MESSAGE
    
END_TIMER_TICK:
    POP {V1, V2, LR}
    BX LR

HANDLE_PB_CLICK:
    PUSH {R0, R1, R2, R3, LR}     @ Save A1-A4 (R0-R3) and LR
    LDR R0, =PB_int_flag
    LDR R1, [R0]                  @ R1 = PB_int_flag value
    CMP R1, #0
    BEQ END_PB_CLICK            
    MOV R2, #0
    STR R2, [R0]                  @ PB_int_flag = 0

    TST R1, #PB_PAUSE
    BLNE TOGGLE_PAUSE

    LDR R2, [V7]                  @ R2 = pause_state
    CMP R2, #1
    BEQ END_PB_CLICK            

    TST R1, #PB_REVERSE
    BLNE REVERSE_DIRECTION
    TST R1, #PB_FASTER
    BLNE SPEED_UP
    TST R1, #PB_SLOWER
    BLNE SLOW_DOWN

END_PB_CLICK:
    POP {R0, R1, R2, R3, LR}      @ Restore A1-A4 and LR
    BX LR


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


CONFIG_GIC:
    PUSH {LR}
    /* To configure the FPGA KEYS interrupt (ID 73):
    * 1. set the target to cpu0 in the ICDIPTRn register
    * 2. enable the interrupt in the ICDISERn register */
    /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
    /* NOTE: you can configure different interrupts
    by passing their IDs to R0 and repeating the next 3 lines */
    MOV R0, #73 // KEY port (Interrupt ID = 73)
    MOV R1, #1 // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT
    @ Addtion
    MOV R0, #29 // Timer (Interrupt ID = 29)
    MOV R1, #1 // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT
    /* configure the GIC CPU Interface */
    LDR R0, =0xFFFEC100 // base address of CPU Interface
    /* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
    /* Set the enable bit in the CPU Interface Control Register (ICCICR).
    * This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
    /* Set the enable bit in the Distributor Control Register (ICDDCR).
    * This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =0xFFFED000
    STR R1, [R0]
    POP {PC}

    /*
* Configure registers in the GIC for an individual Interrupt ID
* We configure only the Interrupt Set Enable Registers (ICDISERn) and
* Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
* values are used for other registers in the GIC
* Arguments: R0 = Interrupt ID, N
* R1 = CPU target
*/
CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
    /* Configure Interrupt Set-Enable Registers (ICDISERn).
    * reg_offset = (integer_div(N / 32) * 4
    * value = 1 << (N mod 32) */
    LSR R4, R0, #3 // calculate reg_offset
    BIC R4, R4, #3 // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4 // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1 // enable
    LSL R2, R5, R2 // R2 = value
    /* Using the register address in R4 and the value in R2 set the
    * correct bit in the GIC register */
    LDR R3, [R4] // read current register value
    ORR R3, R3, R2 // set the enable bit
    STR R3, [R4] // store the new register value
    /* Configure Interrupt Processor Targets Register (ICDIPTRn)
    * reg_offset = integer_div(N / 4) * 4
    * index = N mod 4 */
    BIC R4, R0, #3 // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4 // R4 = word address of ICDIPTR
    AND R2, R0, #0x3 // N mod 4
    ADD R4, R2, R4 // R4 = byte address in ICDIPTR
    /* Using register address in R4 and the value in R2 write to
    * (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, LR}     @ pop R4, R5, and the saved LR back into LR
    BX LR               @ Branch (return) to the address in LR

/*--- Undefined instructions --------------------------------------*/
SERVICE_UND:
    B SERVICE_UND
/*--- Software interrupts ----------------------------------------*/
SERVICE_SVC:
    B SERVICE_SVC
/*--- Aborted data reads ------------------------------------------*/
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA
/*--- Aborted instruction fetch -----------------------------------*/
SERVICE_ABT_INST:
    B SERVICE_ABT_INST
/*--- IRQ ---------------------------------------------------------*/
SERVICE_IRQ:
    PUSH {R0-R7, LR}
    /* Read the ICCIAR from the CPU Interface */
    LDR R4, =0xFFFEC100
    LDR R5, [R4, #0x0C] // read from ICCIAR
    /* NOTE: Check which interrupt has occurred (check interrupt IDs)
    Then call the corresponding ISR
    If the ID is not recognized, branch to UNEXPECTED
    See the assembly example provided in the DE1-SoC Computer Manual
    on page 46 */

Pushbutton_check:
    CMP R5, #73
    BEQ KEY_ISR_HANDLER     @ Check for PB (73)
    Timer_check:
    CMP R5, #29
    BEQ TIMER_ISR_HANDLER   @ Check for Timer (29)
    
UNEXPECTED:
    B EXIT_IRQ              @ Not an ID we handle, just exit
    
KEY_ISR_HANDLER:
    BL KEY_ISR              @ Call the PB subroutine
    B EXIT_IRQ              @ Branch to exit
    
TIMER_ISR_HANDLER:
    BL ARM_TIM_ISR          @ Call the Timer subroutine
    B EXIT_IRQ              @ Branch to exit

EXIT_IRQ:
    STR R5, [R4, #0x10] // write to ICCEOIR
    POP {R0-R7, LR}
    SUBS PC, LR, #4

/*--- FIQ ---------------------------------------------------------*/
SERVICE_FIQ:
    B SERVICE_FIQ



KEY_ISR:
    PUSH {R0, R1}             @ Save registers used
    
    @ 1- Read the edge capture register
    LDR R0, =PB_ADDR
    LDR R1, [R0, #12]
    
    @ 2. Write this value to our "flag"
    LDR R0, =PB_int_flag
    STR R1, [R0]
    
    @ 3. Clear the interrupt
    LDR R0, =PB_ADDR
    STR R1, [R0, #12]
    
    POP {R0, R1}              @ Restore registers
    BX LR                     @ Return to SERVICE_IRQ

ARM_TIM_ISR:
    PUSH {R0, R1, R2, R3, LR}       @ Save scratch registers (A1-A4)

    @ Write '1' to our "flag"
    LDR R0, =tim_int_flag
    MOV R1, #1
    STR R1, [R0]

    @ Clear the interrupt
    BL ARM_TIM_clear_INT_ASM    @ This call uses A2, A3

    POP {R0, R1, R2, R3, LR}        @ Restore scratch registers
    BX LR                       @ Return to SERVICE_IRQ


@ Rotates the message
ROTATE_MESSAGE:
    PUSH {V1, V2, LR}
    LDR V1, [V6]                        @ V1 = rotation_offset
    LDR V2, [V8]                        @ V2 = direction
    ADD V1, V1, V2                      @ offset = offset + direction
    
    @ Handle wrap-around (for 16-char messages)
    CMP V1, #16             
    MOVEQ V1, #0
    CMP V1, #-1
    MOVEQ V1, #15
    
    STR V1, [V6]                        @ save new rotation_offset
    POP {V1, V2, LR}
    BX LR

@ Reverses the direction of rotation
REVERSE_DIRECTION:
    PUSH {V1, LR}
    LDR V1, [V8]                            @ V1 = current direction (1 or -1)
    RSB V1, V1, #0                      @ V1 = 0 - V1 (Flips sign)
    STR V1, [V8]                        @ save the new direction
    POP {V1, LR}
    BX LR

@ Toggles the pause state
TOGGLE_PAUSE:
    PUSH {V1, LR}
    LDR V1, [V7]                        @ V1 = pause_state
    EOR V1, V1, #1                      @ V1 = V1 XOR 1 (flips 0 to 1, 1 to 0)
    STR V1, [V7]                        @ save new pause_state
    POP {V1, LR}
    BX LR

@ Decreases speed (increases timer duration)
SLOW_DOWN:
    PUSH {V1, LR}
    LDR V1, [R7]                        @ V1 = speed_index
    CMP V1, #0                          @ cmp if speed == 0
    BEQ END_SPEED_CHANGE                @ If yes, do nothing
    SUB V1, V1, #1                      @ speed_index--
    STR V1, [R7]                        @ save new index
    BL UPDATE_TIMER_LOAD                @ Helper to update the timer hardware

END_SPEED_CHANGE:
    POP {V1, LR}
    BX LR
    
@ Increases speed (decreases timer duration)
SPEED_UP:
    PUSH {V1, LR}
    LDR V1, [R7]                        @ V1 = speed_index
    CMP V1, #4                          @ Is speed already at max (index 4)?
    BEQ END_SPEED_CHANGE                 @ If yes, do nothing
    ADD V1, V1, #1                      @ speed_index++
    STR V1, [R7]                        @ Save new index
    BL UPDATE_TIMER_LOAD                @ Helper to update the timer hardware
    B END_SPEED_CHANGE                  @ BX LR is in SLOW_DOWN

@ Helper to read new speed_index and update the timer hardware
UPDATE_TIMER_LOAD:
    PUSH {A1, A2, V1, LR}               @ Save A1, A2 (args for config)
    LDR V1, [R7]                        @ V1 = new speed_index
    LSL V1, V1, #2                      @ V1 = index * 4
    LDR A1, [R5, V1]                    @ A1 = timer_load_values[new_index]
    MOV A2, #0b111                      @ A2 = Enable, Auto, IRQ Enable
    BL ARM_TIM_config_ASM
    POP {A1, A2, V1, LR}
    BX LR

@ Displays the 6 characters on the 6 HEX displays
DISPLAY_MESSAGE:
    PUSH {V1-V4, LR}                    @ Don't need to save V5, V6 anymore
    LDR V1, [V5]                        @ V1 = get message pointer
    LDR V2, [V6]                        @ V2 = get rotation offset
    MOV V3, #0                          @ V3 = loop counter i=0

DISPLAY_LOOP:
    CMP V3, #6                          
    BGE END_DISPLAY_LOOP                
    
    ADD V4, V3, V2                      @ V4 = idx
    
    @ handle wrap-around for index (Mod 16)
    CMP V4, #16                        
    SUBGE V4, V4, #16
    CMP V4, #0
    ADDLT V4, V4, #16
    
    LDRB A2, [V1, V4]                   @ A2 = get char code from message[V4]
    
    @ A1 = bitmask for current display (left-to-right)
    MOV A1, #1
    MOV A3, #5                          @ USE A3 (scratch register)
    SUB A3, A3, V3                      @ A3 = 5 - i
    LSL A1, A1, A3                      @ A1 = 1 << (5 - i)
    
    PUSH {V1-V4}                        
    BL HEX_write_ASM
    POP {V1-V4}                         
    
    ADD V3, V3, #1                      
    B DISPLAY_LOOP
END_DISPLAY_LOOP:
    POP {V1-V4, LR}
    BX LR


@ Updates the LEDs based on pause_state and speed_index
UPDATE_LEDS:
    PUSH {A1, V1, V2, LR}
    LDR V1, [V7]                        @ V1 = pause_state
    CMP V1, #1
    MOV A1, #0                          @ A1 = 0 (LEDs off) if paused
    LDRNE V2, [R7]                      @ If NOT paused, V2 = speed_index
    LSLNE V2, V2, #2                    @ V2 = index * 4
    LDRNE A1, [R6, V2]                  @ A1 = LED_patterns[speed_index]
    
    BL write_LEDs_ASM
    POP {A1, V1, V2, LR}
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


@ from part 1


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







.align

PB_int_flag:
    .word 0x0                 @ Flag for PB ISR
tim_int_flag:
    .word 0x0  

pause_state:
    .word 0
speed_index:
    .word 0

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


@ Messgaes but now padded to 16 chars
MSG_COFFEE:
    .byte 12, 0, 15, 15, 14, 14, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 @ C, 0, F, F, E, E (10 blanks)
MSG_CAFE5:
    .byte 12, 10, 15, 14, 5, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 @ C, A, F, E, 5, BLANK (11 blanks)
MSG_CAb5:
    .byte 12, 10, 11, 5, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 @ C, A, b, 5, BLANK... (12 blanks)
MSG_ACE:
    .byte 10, 12, 14, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 @ A, C, E, BLANK... (13 blanks)
MSG_BLANK:
    .byte 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 @ 16 BLANKS
MSG_LOADS:
    .byte 7, 0, 10, 13, 5, 7, 0, 0, 1, 5, 16, 16, 16, 16, 16, 16 @ 7,0,A,d,5,7,0,0,1,5 (6 blanks)
MSG_CAFEBEEF:
    .byte 12, 10, 15, 14, 16, 11, 14, 14, 15, 16, 12, 0, 15, 15, 14, 14 @ CAFE bEEF C0FFEE (16 chars total)

.align

@ 5 speeds
timer_load_values:
    .word 200000000           @ Index 0 
    .word 100000000           @ Index 1
    .word 50000000            @ Index 2 (Default)
    .word 25000000            @ Index 3 (x0.125)
    .word 12500000            @ Index 4 

.align 

LED_patterns:
    .word 0b0000000011        @ Index 0 (2 LEDs)
    .word 0b0000001111      
    .word 0b0000111111      
    .word 0b0011111111       
    .word 0b1111111111        @ Index 4 10 leds

.align

@ Lookup table for the 6 HEX display addresses
HEX_display_addresses:
    .word 0xFF200020        @ Address for HEX0
    .word 0xFF200021        @ Address for HEX1
    .word 0xFF200022        @ Address for HEX2
    .word 0xFF200023        @ Address for HEX3
    .word 0xFF200030        @ Address for HEX4
    .word 0xFF200031        @ Address for HEX5

.align

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

