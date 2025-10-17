@ ECSE 324 Lab 2 - Ungraded Practice Exercise: Summation

@ --- Data Definitions ---
@ int a[4] = {1, 2, 3, 4};
matrixA: .word 1, 2, 3, 4   @ Allocate and initialize the first array
lengthA: .word 4            @ Allocate and initialize its length

@ int b[8] = {2, 3, 5, 7, 11, 13, 17, 19};
matrixB: .word 2, 3, 5, 7, 11, 13, 17, 19 @ Allocate and initialize the second array
lengthB: .word 8            @ Allocate and initialize its length

@ we’ll save our results here
results: .space 8           @ Reserve 8 bytes of uninitialized memory for the two results

.global _start              @ Make the '_start' label visible to the linker as the entry point


@ --- Summation Subroutine ---
@ Sums the integers in a given array.
@ pre-- A1: address of array
@ pre-- A2: length of array
@ post- A1: sum of elements
sum:
    @ --- Prologue: Save the caller's state ---
    PUSH    {V1-V3}         @ Save registers V1, V2, and V3 on the stack because we will use them

    @ --- Initialization ---
    @ int answer = 0;
    MOV     V1, #0          @ V1 will be our 'answer' register. Initialize to 0.
    @ for (int index = 0; ...
    MOV     V2, #0          @ V2 will be our 'index' register. Initialize to 0.

@ --- Loop Start ---
sumIter:
    @ --- Loop Condition Check ---
    @ ... index < length; ...
    CMP     V2, A2          @ Compare index (V2) with length (A2). This sets the status flags.
    BGE     sumDone         @ Branch if Greater than or Equal to 'sumDone'. Exits the loop.

    @ --- Loop Body ---
    @ answer += array[index];
    LDR     V3, [A1, V2, LSL #2]  @ Load array[index] into V3. Address is calculated as base(A1) + index(V2)*4.
    ADD     V1, V1, V3      @ Add the loaded value to our running total: answer += V3.

    @ ... index++
    ADD     V2, V2, #1      @ Increment the index.

    B       sumIter         @ Unconditionally branch back to the start of the loop.

@ --- Epilogue: Clean up and return ---
sumDone:
    MOV     A1, V1          @ Per convention, move the final answer into the return register A1.
    POP     {V1-V3}         @ Restore the original values of V1, V2, and V3 from the stack.
    BX      LR              @ Branch and Exchange to the Link Register to return to the caller.


@ --- Main Program Block ---
_start:
    @ --- First Call: sum(a, 4) ---
    LDR     A1, =matrixA    @ Load the ADDRESS of matrixA into A1 (argument 1).
    LDR     A2, lengthA     @ Load the VALUE from lengthA into A2 (argument 2).
    BL      sum             @ Call the 'sum' subroutine.
    LDR     V1, =results    @ Load the ADDRESS of the results area into V1.
    STR     A1, [V1]        @ Store the return value (now in A1) into the first slot of 'results'.

    @ --- Second Call: sum(b, 8) ---
    LDR     A1, =matrixB    @ Load the ADDRESS of matrixB into A1.
    LDR     A2, lengthB     @ Load the VALUE from lengthB into A2.
    BL      sum             @ Call the 'sum' subroutine again.
    STR     A1, [V1, #4]    @ Store the new return value into the second slot (offset by 4 bytes).

@ --- Halt Program ---
inf:
    B       inf             @ An infinite loop to safely stop the processor after the work is done.