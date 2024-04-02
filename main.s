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

input_buffer:
	;      .space 20
	.asciz "101\n"

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
	; -> @ER6 - pointer to buffer

ascii_encode:
	push.l ER2

	;     clear R2
	xor.w R2, R2

ascii_encode_loop:
	divxu.w R1, ER0

	mov.w E0, R2
	xor.w E0, E0

	;     convert the number to ascii
	add.b #'0', R2L
	;     store the char
	mov.b R2L, @ER6

	;     move the pointer
	inc.l #1, ER6

	;     if there is nothing left, exit
	cmp.l #0, ER0
	bne   ascii_encode_loop

ascii_encode_end:
	pop.l ER2
	rts

	.end
