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
	
	
@ pre-- A1: index of the number to calculate
@ pre-- A2 (*array): base address of the array
@ post-- A1: calculated Nth Recamam number
recaman:
	PUSH {V1-V6, LR}
	
	@ base case
	MOV V1, #0
	STRB V1, [A2]	@ store 0 at array[0]
	
	@ check if A1 = 0
	CMP A1, #0
	BEQ recaman_end	@ if yes, end recaman
	
	MOV V1, #1		@ loop counter = 1
	
begin_loop: @ goal: check if number (k) is > target num (A1)
	CMP V1, A1
	BGT recaman_end @ if k > A1, end recaman
	
	SUB V5, V1, #1	@ get index n-1
	LDRB V2, [A2, V5] @ V2 = previous element = array[n-1] (base address + shift to V5 address)
	
	SUB V3, V2, V1	@ V3 = rnums = prev - k
	ADD V4, V2, V1	@ V4 = rnuma = prev + k
	
	@ if rnums <= 0, use rnuma
	CMP V3, #0
	BLE rnuma_instead 
	
	PUSH {A1, A2, LR, V1, V2, V3, V4}
	MOV A1, V3		@ tgt = rnums
	MOV A3, V1		@ size = k
	BL search
	MOV V5, A1 		@ save search result in V5
	POP {A1, A2, LR, V1, V2, V3, V4} @ restore pushed registers
	
	@ check if reuslt < 0 
	CMP V5, #0
	BGE rnuma_instead
	
	MOV V6, V3 		@ V6 = rnums 
	B result

	
rnuma_instead:
	MOV V6, V4		@ V6 = final value = rnuma

result:
	STRB V6, [A2, V1] @ store V6 into array[num] 
	ADD V1, V1, #1	@ increment counter
	B begin_loop

recaman_end:
	LDRB A1, [A2, A1]
	POP {V1-V6, LR}
	BX LR
	


