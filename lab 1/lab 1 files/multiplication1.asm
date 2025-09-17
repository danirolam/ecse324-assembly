ADD R1, R1, 3      # First input
BGE R1, 0, 3       # If it is negative, branch to the negation input 1
NOR R1, R1, R1     # Set input 1 to be positive
ADD R1, R1, 1      # 
ADD R0, R0, 1      # Count the times of setting value to be positive

ADD R2, R2, -3     # Second input
BGE R2, 0, 3       # If it is negative, branch to the negation input 2
NOR R2, R2, R2     # Set input 2 to be positive
ADD R2, R2, 1      # 
ADD R0, R0, 1      # Count the times of setting value to be positive

AND R3, R3, 0      # Initialize register for results

AND R5, R5, 0      # Initialize flags for branching back
AND R4, R2, 1      # Check last bit
BEQ R4, 0, 2       # If the last bit is 0, branch to shift
BNE R5, 0, -4      # branch back 
ADD R3, R3, R1     # If the last bit is 1, add
LSL R1, R1, 1      # Shift operand 1 to the left
BNE R5, 0, -4      # branch back 
LSR R2, R2, 1      # Shift operand 2 to the right
ADD R5, R5, R2     # Set flag for branching back
BNE R5, 0, -4      # branch back 

BNE R0, 1, 2       # If inputs are set to be positive 0 or 2 times, do not set the result to be positive
NOR R3, R3, R3     # Set results to be positive
ADD R3, R3, 1      # 
ADD R3, R3, 0      # Display results

BEQ R0, R0, -1     # Indicator for the end of the simulation