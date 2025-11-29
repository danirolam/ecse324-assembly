.text
.global read_PS2_data_ASM

.equ PS2_DATA_REGISTER, 0xFF200100


read_PS2_data_ASM:
    PUSH {R1, R2, R3}
    LDR R1, =PS2_DATA_REGISTER  @ load the address of the PS2_data_reg
    LDR R2, [R1]                @ load the value at PS2_data_reg

    @ Check the RVALID (Bit 15) could also compare with 0X8000 to get first bit 
    LSR R3, R2, #15             @ moving bit 15 to bit 0
    AND R3, R3, #1              @ R3 AND 0x1
    CMP R3, #1
    BNE rvalid_false

    AND R2, R2, #0xFF           @ R2 AND 1111 1111 = extract lowest 8 bits
    STRB R2, [R0]               @ store the byte = 8 bits at address R0

    MOV R0, #1
    B success_read

rvalid_false:
    MOV R0, #0

success_read:
    POP {R1, R2, R3}
    BX LR