	; Rozklad cisla na prvocinitele

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

input_buffer:
	.space 20

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

	; ----------- program -------------

	.text
	.global _start

_start:
	;     initialize SP
	mov.l #stack, ER7

	;     initialize the sieve
	mov.l #sieve, ER6
	mov.l #primes, ER5
	jsr   @prime_sieve

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

	mov.l #input_buffer, ER6
	jsr   @ascii_decode

	;     if the number is less than 2, skip
	cmp.w #2, R0
	blo   main_loop

	;     print 'n='
	mov.l #output_buffer, ER6
	jsr   @ascii_encode

	mov.b #'=', R2L
	mov.b R2L, @ER6
	inc.l #1, ER6

	;     print the factorization
	mov.w R0, R3
	mov.l #primes, ER5
	jsr   @prime_factorize

	;     add newline
	mov.b #'\n', R2L
	mov.b R2L, @ER6

	;     show output
	mov.w #PUTS, R0
	mov.l #ptr_output, ER1
	jsr   @syscall

	jmp main_loop

	; ----------- functions -----------

	; fn prime_sieve

	; generates a prime sieve from 0 to 255
	; fills the output buffer with found primes, leaving the rest empty

	; <- @ER5 - output buffer (64B)
	; <- @ER6 - sieve buffer (256B)

prime_sieve:
	;     save registers
	stm.l ER0-ER3, @-ER7

	;     store end of sieve
	mov.l ER6, ER3
	add.l #256, ER3

	;     skip 0 and 1
	inc.l #2, ER6

	;     set all bytes in sieve to FF
	mov.w #0xFFFF, R0
	jsr   @fill_buffer

	;     clear iterator and filler
	xor.l ER0, ER0
	xor.l ER1, ER1

	;     first prime is 2
	mov.b #2, R0L

prime_sieve_loop:
	;     if the number is marked 0, skip it
	mov.b @ER6, R1L
	beq   prime_sieve_loop_next

	;     add the number to prime list
	mov.b R0L, @ER5
	inc.l #1, ER5

	jsr @prime_sieve_mark_multiples

prime_sieve_loop_next:
	;     loop until we reach 256 (overflow)
	inc.b R0L
	bvs   prime_sieve_end

	;     move the sieve pointer
	inc.l #1, ER6

	jmp prime_sieve_loop

prime_sieve_end:
	;     restore registers
	ldm.l @ER7+, ER0-ER3

	rts

	; fn prime_sieve_mark_multiples

	; marks all multiples of the number in given buffer

	; <- R0L - number
	; <- @ER3 - end of the sieve
	; <- @ER6 - sieve[number]

prime_sieve_mark_multiples:
	push.l ER6

prime_sieve_mark_loop:
	;     step through the sieve in multiples of the current number
	;     until we reach the end of the sieve (ER5)
	add.l ER0, ER6
	cmp.l ER3, ER6
	bcc   prime_sieve_mark_loop_end

	;     mark them as 0
	mov.b R1H, @ER6

	jmp prime_sieve_mark_loop

prime_sieve_mark_loop_end:
	pop.l ER6

	rts

	; fn prime_factorize

	; factorizes a number into its prime factors
	; write directly to the output buffer

	; <- R3 - number
	; <- @ER5 - pointer to primes array
	; <- @ER6 - pointer to output buffer

prime_factorize:
	;      save registers
	push.l ER2
	push.l ER3
	push.l ER4

	;     prepare the registers
	xor.l ER2, ER2
	xor.w E3, E3
	xor.l ER4, ER4

	; loop through the primes and try to divide the number
	; until the number is 1

prime_factorize_loop:

	;     load the prime
	mov.b @ER5, R2L

	;   if it is 0, we are at the end of the list
	beq prime_factorize_print_remaining

prime_factorize_division_loop:

	;     save the current value
	mov.w R3, R4

	;       divide the number by the prime
	divxu.w R2, ER3

	;     if the remainder after division isn't 0, end the loop
	cmp.w #0, E3
	bne   prime_factorize_division_loop_end

	;     increase the power
	inc.w #1, E4

	jmp prime_factorize_division_loop

prime_factorize_division_loop_end:

	;     restore the number
	xor.w E3, E3
	mov.w R4, R3

	;     if the power is 0, skip printing
	cmp.w #0, E4
	beq   prime_factorize_division_loop_skip_print

	;     write the prime to the output buffer
	mov.w R2, R0
	jsr   @ascii_encode

	;     if power is 1, skip printing it
	cmp.w #1, E4
	beq   prime_factorize_division_loop_skip_print_power

	mov.b #'^', R0L
	mov.b R0L, @ER6
	inc.l #1, ER6

	;     write the power to the output buffer
	mov.w E4, R0
	jsr   @ascii_encode

prime_factorize_division_loop_skip_print_power:
	;     print '*'
	mov.b #'*', R0L
	mov.b R0L, @ER6
	inc.l #1, ER6

prime_factorize_division_loop_skip_print:

	;     reset the power
	xor.w E4, E4

	;     if the number is 1, we are done
	cmp.w #1, R3
	beq   prime_factorize_end

	;     move to next prime
	inc.l #1, ER5

	jmp prime_factorize_loop

prime_factorize_print_remaining:
	;     write the number to the output buffer
	mov.w R3, R0
	jsr   @ascii_encode

prime_factorize_end:
	;     if we have an asterisk at the end, remove it
	mov.b @(-1, ER6), R0L
	cmp.b #'*', R0L
	bne   prime_factorize_end_skip_asterisk

	dec.l #1, ER6

	mov.b #0, R0L
	mov.b R0L, @ER6

prime_factorize_end_skip_asterisk:
	pop.l ER4
	pop.l ER3
	pop.l ER2

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
	mov.b @ER6+, R1L

	;     if the char is CR, we are done
	cmp.b #'\n', R1L
	beq   ascii_decode_end

	;       convert the char to number
	add.b   #-'0', R1L
	;       multiply the result by the radix
	mulxu.w E1, ER0
	;       add current digit
	add.w   R1, R0

	jmp @ascii_decode_loop

ascii_decode_end:
	pop.l ER1

	rts

	; fn ascii_encode

	; encodes a number into ascii in given base

	; <- R0 - number
	; <- R1 - radix
	; <- @ER6 - pointer to buffer

ascii_encode:
	push.l ER0
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

	;     store the char on the stack
	mov.b R2L, @-ER7

	;     increase the character counter
	inc.w #1, E2

	;     loop until the number is 0
	cmp.l #0, ER0
	bne   ascii_encode_push_loop

ascii_encode_pop_loop:
	; pop all chars from the stack to the output buffer

	;     pop and store
	mov.b @ER7+, R2L
	mov.b R2L, @ER6

	;     move the pointer
	inc.l #1, ER6

	;     loop until the counter is 0
	dec.w #1, E2
	bne   ascii_encode_pop_loop

ascii_encode_end:
	pop.l ER2
	pop.l ER0
	rts

	; fn fill_buffer

	; fills the buffer with given value
	; length has to be even number of bytes

	; <- R0 - value
	; <- @ER3 - end of buffer
	; <- @ER6 - start of buffer

fill_buffer:
	push.l ER3

fill_buffer_loop:
	;     store the byte
	mov.w R0, @-ER3
	cmp.l ER6, ER3
	bne   fill_buffer_loop

fill_buffer_end:
	pop.l ER3
	rts

	.end
