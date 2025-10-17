N: .word 4
matrix: .short 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
vector: .space 32
.global _start


_start:
	@ load the given values (initialize)
	@ assignments:
	@ R0 = row, R1 = column, R2 = seq (index), R3 = direction
	@ R4 = N (here 4), R5 = N*N, R6 = matrix, R7 = vector (1D array of the output)
	@ R8, R9, R10 = temp registers
	
	LDR R4, N	@ this is the matrix dimension
	MUL R5, R4, R4	@calculating the quantity of elements
	MOV R0, #0 
	MOV R1, #0
	MOV R2, #0	@ seq!!
	MOV R3,	#1	@ same as in C (1 for up/right, -1 for down/left)
	LDR R6, =matrix	@ loading base address of matrix (and below for vector)
	LDR R7, =vector
	
doing_zigzag:
	@ this is the main loop of the C program (for (; seq<n*n; seq++))
	CMP R2, R5	@ comparing seq with num of elements
	BGE stop	@ if R2 >= R5, go to stop branch
	
	@ calculating address of matrix[row][column]
	MUL R8, R0, R4	@ caluculating how many element to skip before getting to the correct row
	ADD R8, R8, R1	@ adding the column index to get to the correct element we need
	LSL R8, R8, #1	@ shifting by 1 = multiply by 2, this way we get memory address of the element in R8
	ADD R9, R6, R8	@ adding our calculated address to the intial address at R6 (final address)
	
	LDRH R10, [R9]	@ loading the value at the final address
	LSL R8, R2, #1	@ R8 = seq*2 (shifting = *2)
	ADD R9, R7, R8	@ final address in the vecotr
	STRH R10, [R9]	@ store value
	
	@ updating row and col (depends on dir)
	CMP R3, #1	@ checking if dir = 1
	BNE move_down_left	@ if not equal, we move_down_left! if equal, code continues down
	
move_up_right:	@ follows given R3 = 1 = dir
	SUB R8, R4, #1
	
	CMP R1, R8
	BEQ at_right_edge	@ if equal, go to at_right_edge
	
	CMP R0, #0	@ if row = 0, we are at top edge
	BEQ at_top_edge	
	
in_middle_up:	@ movement up then right 
	ADD R1, R1, #1 @ COL ++
	SUB R0, R0, #1 @ ROW --
	B end_if_else
	
at_right_edge:
    ADD     R0, R0, #1	@ row++
    MOV     R3, #-1	@ dir = -1
    B       end_if_else

at_top_edge:
    ADD     R1, R1, #1	@ col++
    MOV     R3, #-1	@ dir = -1
    B       end_if_else	
	
	
move_down_left: @ the else block in C
	SUB R8, R4, #1	@ R8 = n-1
	CMP R0, R8	@ row == n-1
	BEQ at_bottom_edge
	
	CMP R1, #0
	BEQ at_left_edge
	
in_middle_down:
	SUB R1, R1, #1	@ col--
	ADD R0, R0, #1	@ row++
	B end_if_else

at_bottom_edge:
	ADD R1, R1, #1
	MOV R3, #1
	B end_if_else

at_left_edge:
	ADD R0, R0, #1
	MOV R3, #1
	B end_if_else

end_if_else:
	ADD R2, R2, #1	@ increment index of vector (seq)
	B doing_zigzag	@ repeat
	
stop: b stop
	