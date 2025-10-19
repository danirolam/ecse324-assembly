.global _start
N: 			.word 20 // input parameter n
SEQ: 		.space 21 // Recaman sequence of n+1 elements
			.space 3 // for correct alignment of instructions
_start:
	ldr A1, N // get the input parameter n
	ldr A2, =SEQ // get the address for results
	bl recaman // go!
stop:
	b stop

@ search function checks if a number is already in the array
@ pre-- A1 (tgt): value we are looking for
@ pre-- A2 (*array): base address of the array
@ pre-- A3 (size): num of elements to check
@ post-- A1 (idx): index of the value found, else its -1
search:
	PUSH {V1-V3}	@ saving registers V1 to V3 on the stack
	
	MOV V1, #-1		@ assigning idx = -1 (this is default retrun value)
	MOV V2, #0		@ i = 0 (loop counter)
	
@looping the loop
loop_the_loop:
	CMP V2, A3		@ comapirng V2 (loop counter) with A3 (array size)
	BGE end_loop	@ if V2 greater or equal, end loop
	
	LDRB V3, [A2, V2] @ loading the value of the array into V3, offset is the index because we have chars = 1 byte
	
	CMP V3, A1		@ comparing with target
	BEQ value_found
	
	ADD V2, V2, #1	@ increment counter
	B loop_the_loop @ restart
	
value_found:
	MOV V1, V2		@ give the index to V1
	
end_loop:
	MOV A1, V1		@ return value A1 is set
	POP {V1-V3}
	BX LR
	
	
@ pre-- A1 (num): index of the number to calculate
@ pre-- A2 (*array): base address of the array
@ post-- A1: calculated Nth Recamam number
recaman:
	PUSH {V1-V5, LR}
	
	CMP A1, #0		@ base case
	BEQ base_case
	
	PUSH {A1, A2}	@ good hint, thank you
	SUB A1, A1, #1	@ setting A1 = A1 - 1 
	BL recaman
	MOV V1, A1		@ V1 = prev
	POP {A1, A2}	@ restore original A1 and A2
	
	@ calculating hte two possible next numbers
	SUB V2, V1, A1 	@ rnums = prev - num
	ADD V3, V1, A1	@ rnuma = prev + num
	
	@ checking is rnums is working
	CMP V2, #0 		@ rnums > 0 
	BLE rnuma_instead
	
	@ search(rnums, array, num-1
	SUB     V5, A1, #1 @ V5 = num - 1
	PUSH {A1, A2, LR} @ save registers needed after calling search, LR = link register = return from recaman
	MOV A1, V2		@ A1 = rnums
	MOV A3, V5		@ V5 = num - 1
	BL search
	
	MOV V4, A1		
	POP {A1, A2, LR} @ restore original num, array, and LR
	
	CMP V4, #0		@ check if search result (A1) < 0 (meaning not found)
	BGE rnuma_instead
	
	MOV V5, V2		@ V5 = rnums = V2
	B result
	
	
rnuma_instead:
	MOV V5, V3		@ V5 = final value = rnuma

result:
	STRB V5, [A2, A1] @ store V5 into array[num]
	MOV A1, V5
	B recaman_end
	
base_case:
	MOV V1, #0
	STRB V1, [A2, A1] @ A1 = 0, so V1 = array[0]
	MOV A1, V1
	
recaman_end:
	POP {V1-V5, LR}
	BX LR   


