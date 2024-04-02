	; Prevod cisla z desitkove do hex. soustavy

	.h8300s

	.section .vects, "a", @progbits

rs:
	.long _start

	; ----------- symboly -------------

	;    simulated IO area
	.equ syscall, 0x1FF00
	.equ PUTS, 0x0114
	.equ GETS, 0x0113

	; ----------- data ----------------

	.data
	.align 2

	; TODO: revert back to reading the input

input_buffer:
	;      .space 20
	.asciz "65530\n"

output_buffer:
	.space 20

prompt:
	.asciz "Zadejte cislo k rozlozeni: "

	.align 2

ptr_input:
	.long input_buffer

ptr_output:
	.long output_buffer

ptr_prompt:
	.long prompt

	.align 2

	;      stack
	.space 100

stack:
	; stack end + 1

	; ----------- program -------------

	.text
	.global _start

_start:
	mov.l #stack, ER7

	;     show prompt
	mov.w #PUTS, R0
	mov.l #ptr_prompt, ER1
	jsr   @syscall

	; read input
	; mov.w #GETS, R0
	; mov.l #ptr_input, ER1
	; jsr   @syscall

	;     IO is in base 10
	mov.w #10, R1

	mov.l @ptr_input, ER6
	jsr   @ascii_decode

	mov.l @ptr_output, ER6
	jsr   @ascii_encode

	;     add newline
	mov.b #'\n', R2L
	mov.b R2L, @ER6

	;     show output
	mov.w #PUTS, R0
	mov.l #ptr_output, ER1
	jsr   @syscall

end:
	;   end with a infinite loop
	jmp @end

	; fn ascii_decode

	; decodes a decimal number (max value is word)

	; <- R1 - radix
	; <- @ER6 - pointer to buffer ending with CR
	; -> ER0   - number

ascii_decode:
	push.l ER1

	;     store the radix
	mov.w R1, E1

	;     clear R0 and R1
	xor.w R0, R0
	xor.w R1, R1

ascii_decode_loop:
	mov.b @ER6, R1L

	;     if the char is CR, we are done
	cmp.b #'\n', R1L
	beq   ascii_decode_end

	;       convert the char to number
	add.b   #-'0', R1L
	;       multiply the result by the radix
	mulxu.w E1, ER0
	;       add current digit
	add.w   R1, R0
	;       move to the next digit
	inc.l   #1, ER6
	jmp     @ascii_decode_loop

ascii_decode_end:
	pop.l ER1

	rts

	; fn ascii_encode

	; encodes a number into ascii in given base

	; <- R0 - number
	; <- R1 - radix
	; <- @ER6 - pointer to buffer

ascii_encode:
	push.l ER2

	;     clear ER2
	;     R2 is used as a temporary register for char conversion
	;     E2 is used as a counter for the number of chars
	xor.l ER2, ER2

ascii_encode_push_loop:
	divxu.w R1, ER0

	mov.w E0, R2
	xor.w E0, E0

	;     convert the number to ascii
	add.b #'0', R2L

	;      store the char on the stack
	;      TODO: two characters can be pushed at once to save space
	push.w R2

	;     increase the character counter
	inc.w #1, E2

	;     loop until the number is 0
	cmp.l #0, ER0
	bne   ascii_encode_push_loop

ascii_encode_pop_loop:
	; pop all chars from the stack to the output buffer

	;     pop the char
	pop.w R2

	;     store the char in the output buffer
	mov.b R2L, @ER6

	;     move the pointer
	inc.l #1, ER6

	;     decrease the counter
	dec.w #1, E2

	;     loop until the counter is 0
	;     TODO: perhaps the check can be simplified to just one bxx
	;     but it depends on how dec.w sets the flags
	cmp.w #0, E2
	bne   ascii_encode_pop_loop

ascii_encode_end:
	pop.l ER2
	rts

	.end
