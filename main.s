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

sieve:
	.space 256

primes:
	.space 64

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

	;     initialize the sieve
	mov.l #sieve, ER6
	mov.l #primes, ER5
	jsr   @generate_prime_sieve

	; loop for the rest of the program

main_loop:
	;     show prompt
	mov.w #PUTS, R0
	mov.l #ptr_prompt, ER1
	jsr   @syscall

	;     read input
	mov.w #GETS, R0
	mov.l #ptr_input, ER1
	jsr   @syscall

	;     IO is in base 10
	mov.w #10, R1

	mov.l @ptr_input, ER6
	jsr   @ascii_decode

	cmp.w #2, R0
	blt   main_loop

	mov.l @ptr_output, ER6
	jsr   @ascii_encode

	;     add newline
	mov.b #'\n', R2L
	mov.b R2L, @ER6

	;     show output
	mov.w #PUTS, R0
	mov.l #ptr_output, ER1
	jsr   @syscall

	jmp main_loop

end:
	;   end with an infinite loop
	jmp @end

	; ----------- functions -----------

	; fn generate_prime_sieve

	; generates a prime sieve from 0 to 255
	; fills the output buffer with found primes, leaving the rest empty

	; <- @ER5 - pointer to output buffer (64B)
	; <- @ER6 - pointer to working buffer (256B)

generate_prime_sieve:
	push.l ER0
	push.l ER1
	push.l ER2

	;      save the pointer
	push.l ER6

	;     start iteration at 2
	mov.w #2, E0
	inc.l #2, ER6

	;     filler value
	mov.w #0xFFFF, R0

generate_prime_sieve_fill_loop:
	; set all bytes in sieve to 1

	;     loop until the counter is 256
	cmp.w #256, E0
	bge   generate_prime_sieve_fill_loop_end

	;     store the byte
	mov.w R0, @ER6

	;     increase the pointer
	inc.l #2, ER6

	;     increase the counter
	add.w #2, E0

	jmp generate_prime_sieve_fill_loop

generate_prime_sieve_fill_loop_end:

	;     reset the pointer
	pop.l ER6

	;     clear iterator and filler
	xor.l ER0, ER0

	;     start at 2 and mark all multiples as 0
	mov.b #2, R0L
	add.l #2, ER6

	;     prepare R1 (copy space)
	xor.w R1, R1

generate_prime_sieve_loop:
	;     check if the number is marked as prime
	mov.b @ER6, R1L
	cmp.b #0, R1L
	;     if it isn't, go to the next number
	beq   generate_prime_sieve_loop_skip

	mov.b R0L, @ER5
	inc.l #1, ER5

	jsr @generate_prime_sieve_mark_multiples

generate_prime_sieve_loop_skip:

	cmp.w #255, R0
	bge   generate_prime_sieve_end

	;     increase the number until we reach 256
	inc.b R0L
	inc.l #1, ER6

	jmp generate_prime_sieve_loop

generate_prime_sieve_end:
	pop.l ER2
	pop.l ER1
	pop.l ER0

	rts

	; fn generate_prime_sieve_mark_multiples

	; marks all multiples of the number as 0

	; !!! overwrites ER0-2

	; <- R0 - number
	; <- @ER6 - pointer to the buffer + the number

generate_prime_sieve_mark_multiples:
	;      store the original pointer
	push.l ER6

	;     save current number for iteration
	mov.w R0, E1

generate_prime_sieve_mark_loop:
	;     step through the sieve in multiples of the current number
	;     until we reach the end of the sieve (256)
	add.l ER0, ER6
	add.w R0, E1
	cmp.w #256, E1
	bge   generate_prime_sieve_mark_loop_end

	;     mark them as 0
	mov.b R1H, @ER6

	jmp generate_prime_sieve_mark_loop

generate_prime_sieve_mark_loop_end:
	;     restore the original pointer
	pop.l ER6
	rts

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
