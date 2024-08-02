	.include "tm-pru.inc"
	;* Bit inputs in register R10 . Each byte in register holds one bit 

	.global main
main:
	ldi32	r0, PRU1_PRU0_INTERRUPT
	xor	r2,r2,r2	;* Prevbit= 0
	ldi32	r3,0		;* Initialise count
	
	lbco 	&r5, C4, 4,4
	clr	r5,r5,4
	sbco 	&r5, C4,4,4	;* Enable OCP


	ldi32	r1, 0x10000	;* Shared RAM Address.  This locn contains DDR start (start=headpointer, start+4 onwards = data) - loaded by linux appln
	lbbo	&r6, r1,0,8	;* Read DDR address and count to r6/r7
	mov	r8,r6		;* Copy start address to r8. Required later for circular buffer
	add	r9,r6,r7	;* End Addr=Start Addr + Count
	ldi32	r26, CTPPR_0
	ldi32	r5, 0x00000220	;* C28 =00_0220_00 = PRU0 CFG Reg
	sbbo	&r5, r26, 0,4
	lbco    &r26, c28,0,4 	;* Enable CYCLE counter
	set	r26,r26, 3
	sbco	&r26,c28,0,4

	xor	r27,r27,r27	;* To count from 0 to 3 for shifting count and writing to memory

	sub	r19,r7,4	; Subtract the size of buffer indicator from total size
	lsr	r19,r19,1	; Divides the remaining buffer size by 2
	add	r19,r19,1	; Inorder to delay the midpoint interrupt by the time for a byte. To avoid false ping interrupt during the time of pong interrupt
	ldi32	r20, 0		; Indicates writing in ping buffer
	ldi32	r21, 1		; Indicates writing in pong buffer
	ldi32	r22, 0		; count indicator

				
				;* Clear entire buffer
loop1:
	sbbo	&r3,r6, 0,4	;* Write 0
	add	r6, r6, 4	;* Increment DDR pointer
	qble	loop1, r9,r6	;* End of buffer
	add	r6,r8,4		;* Yes, initialise to DDR start


	sbbo	&r20,r8, 0,4	; Write ping indicator to DDR Start - Init		

acquire:
	wbs	r31,30		;* wait and clear buffer ready signal from PRU1
	sbco	&r0,c0,0x24,4
	xin	10,&r10,8	;* Get acquired data from other PRU

	sbbo	&r10,r6, 0,8	; Write acquired 2* 32bit valueto DDR
	add	r22, r22, 8	; Increment the counter

	qbge	label1, r22, r19	
	sbbo	&r21,r8, 0,4	; Write pong indicator to DDR start	
	ldi 	r31.b0, PRU0_ARM_INTERRUPT+16	; Generate ARM interrupt
	ldi32	r22,0		; Initialize the counter in order to halt issuing interrupts multiple times

label1: add	r6, r6, 8	;* Increment DDR pointer
	qblt	loop2, r9,r6	;* End of buffer
	add	r6,r8,4		;* Yes, initialise to DDR start +4; DDR Start=Head Pointer
	sbbo	&r20,r8, 0,4	; Write ping indicator to DDR Start
	ldi	r31.b0, PRU0_ARM_INTERRUPT+16	; Generate ARM interrpt
	ldi32	r22,0		; Initialize the counter
loop2:
	jmp	acquire
	HALT			;* Not required since the program loops infinitely

