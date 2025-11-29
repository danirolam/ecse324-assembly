@ part1.s 
@ Write an assembly library to control the screen

@ Screen resolution 320 x 240
@ x (width): 0 to 319
@ y (height): 0 to 239


.text
.global VGA_draw_point_ASM

@ Constants
.equ PIXEL_BUFFER_BASE, 0xC8000000
.equ SCREEN_WIDTH, 320
.equ SCREEN_HEIGHT, 240

@ R0 = x; R1 = y; R2 = c = color
VGA_draw_point_ASM:
    @ Check if x is valid
    CMP R0, #0
    BLT stop_drawing
    CMP R0, #320
    BGE stop_drawing

    @ Check if y is valid
    CMP R1, #0
    BLT stop_drawing
    CMP R1, #240
    BGE stop_drawing

    @ Calculation of address
    LDR R3, =PIXEL_BUFFER_BASE
    ADD R3, R3, R0, LSL #1          @ Base + (x*2)
    ADD R3, R3, R1, LSL #10         @ Base + (x*2) + (y*1024)

    STRH R2, [R3]

stop_drawing:
    BX LR


@ Clear the screen by writing 0 to each pixel
@ Need to iterate each pixel 0 to 319 and 0 to 239
VGA_clear_pixelbuff_ASM:
    PUSH {R4, R5, LR}
    MOV R4, #0

@ Check if x >= 320
check_x:
    CMP R4, #320
    BGE all_cleared

    MOV R5, #0

@ Check if y >= 240
check_y:    
    CMP R5, #240
    BGE increment_x

    MOV R0, R4
    MOV R1, R5
    MOV R2, #0                      @ R2 = c = color, set it to black

    BL VGA_draw_point_ASM

    ADD R5, R5, #1
    B check_y

increment_x:
    ADD R4, R4, #1
    B check_x

all_cleared:
    POP {R4, R5, PC}

    

@ Character Buffer Constants
.equ CHAR_BUFFER_BASE, 0xC9000000
.equ CHAR_WIDTH, 80
.equ CHAR_HEIGHT, 60

VGA_write_char_ASM:
    CMP R0, #0
    BLT end_write_char
    CMP R0, #80
    BGE end_write_char

    CMP R1, #0
    BLT end_write_char
    CMP R1, #60
    BGE end_write_char

    LDR R3, =CHAR_BUFFER_BASE
    ADD R3, R3, R1, LSL #7
    ADD R3, R3, r0

    STRB R2, [R3]

end_write_char:
BX LR


@ Clear the character buffer by writing 0 to each possition
.global VGA_clear_charbuff_ASM
VGA_clear_charbuff_ASM:
    PUSH {R4, R5, LR}
    MOV R4, #0                      @ counter for x

@ Check if x >= 320
check_char_x:
    CMP R4, #80
    BGE all_char_cleared

    MOV R5, #0                      @ initialize y (R5) counter 

@ Check if y >= 240
check_char_y:    
    CMP R5, #60
    BGE increment_char_x

    MOV R0, R4                      @ x
    MOV R1, R5                      @ y
    MOV R2, #0                      @ R2 = c = color, set it to null

    BL VGA_write_char_ASM

    ADD R5, R5, #1                  @ increment char y
    B check_char_y

increment_char_x:
    ADD R4, R4, #1
    B check_char_x

all_char_cleared:
    POP {R4, R5, PC}



