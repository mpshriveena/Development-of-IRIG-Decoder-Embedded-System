;*Set the date and time to avoid clock skew error: sudo date -s 2023-11-08T10:23:00
;*Open IRIG DATA ACQUISITION folder
;*cd nvsd
;*sudo ./configpin.sh
;*sudo ./pin_setup.sh
;*cd IRIG DATA ACQUISITION
;*COMMANDS FOR EXECUTION
;*MAKE CLEAN..........MAKE..........MAKE RUN

	.include "tm-pru.inc"
	.asg 32, PRU0_R31_VEC_VALID
    	.asg 3, PRU_EVTOUT_0 
	.asg r23,DATA
	.asg r22,TEMP
	.asg r2,HOUR
	.asg r3,MINUTE
	.asg r4,SECOND
	.asg r6,COUNT
	.asg r7,ITERATE
	.asg r8,ISPEAK
	.asg r9,DATAWIDTH
	.asg r10,PREVDATA
	.asg r11,CURRENTDATA
	.asg r12,SAMPLENO
	.asg r13,SYNCUPPERLIMIT
	.asg r14,ISTWOSYNC
	.asg r15,BYTECOUNTER
	.asg r16,BITCOUNTER
	.global main

GETBIT .macro
	lsl DATA,DATA,1
	qbbs loop1,r31,10
	jmp loop2
loop1:
	set DATA,DATA,0
loop2:
	nop
	.endm                             ;4 instructions

COUNTSTART .macro
	ldi32 COUNT,0
	ldi32 ITERATE,0
	mov TEMP,DATA			  ;*3 instruction
CHECKONE:
	qbbs COUNTONE,TEMP,ITERATE
	jmp INCREMENTITERATE
COUNTONE:
	add COUNT,COUNT,1
INCREMENTITERATE:
	add ITERATE,ITERATE,1
	qbne CHECKONE,ITERATE,16          ;*( 16 x 4 = 64 instructions )
	.endm

CHECKONESFORWIDTH .macro
	ldi32 ISPEAK,0
	qble CALCULATEWIDTH,COUNT,12
	jmp SKIPCALCULATEWIDTH
CALCULATEWIDTH:
	add DATAWIDTH,DATAWIDTH,1
	nop
	jmp ENDCALCULATEWIDTH
SKIPCALCULATEWIDTH:
	qbne SETISPEAK,DATAWIDTH,0
	jmp ENDCALCULATEWIDTH
SETISPEAK:
	set ISPEAK,ISPEAK,0
ENDCALCULATEWIDTH:
	nop
	.endm                               ;*6 instructions

WHICHPEAK .macro
	mov PREVDATA,CURRENTDATA
	ldi32 CURRENTDATA,0
	ldi32 ISPEAK,0
	qble CHECKSYNC,DATAWIDTH,208
	qble CHECKBITONE,DATAWIDTH,112
	qble CHECKBITZERO,DATAWIDTH,16
	jmp NOBITDETECTED
CHECKSYNC:
	qbge SYNCDETECTED,DATAWIDTH,SYNCUPPERLIMIT
	nop
	nop
	nop
	jmp NOBITDETECTED
SYNCDETECTED:
	ldi32 CURRENTDATA,1
	nop
	nop
	nop
	jmp ENDWHICHPEAK
CHECKBITONE:
	qbge BITONEDETECTED,DATAWIDTH,192
	nop
	nop
	jmp NOBITDETECTED
BITONEDETECTED:
	ldi32 CURRENTDATA,2
	nop
	nop
	jmp ENDWHICHPEAK
CHECKBITZERO:
	qbge BITZERODETECTED,DATAWIDTH,96
	nop
	jmp NOBITDETECTED
BITZERODETECTED:
	ldi32 CURRENTDATA,3
	nop
	jmp ENDWHICHPEAK
NOBITDETECTED:
	ldi32 CURRENTDATA,4
ENDWHICHPEAK:
	ldi32 DATAWIDTH,0
	.endm                             ;*11 instructions

MAINTAINSAMPLINGRATE .macro
MAINTAIN:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop                                        ;*23
	sub SAMPLENO,SAMPLENO,1
	qbne MAINTAIN,SAMPLENO,0      ;*6148 instructions
	ldi32 SAMPLENO,245
	.endm

CHECKTWOSYNC .macro
	qbeq ISTWOSYNCNOP,ISTWOSYNC,1
	qbne CURRENTDATANOT1,CURRENTDATA,1
	qbne PREVDATANOT1,PREVDATA,1
	ldi32 ISTWOSYNC,1
	jmp ENDCHECKTWOSYNC
ISTWOSYNCNOP:
	nop
CURRENTDATANOT1:
	nop
	nop
	jmp ENDCHECKTWOSYNC
PREVDATANOT1:
	nop
	nop
ENDCHECKTWOSYNC:
	nop
	.endm                                 ;*6 instructions

CALCULATEBYTEANDBITCOUNTER .macro
	qbeq STARTCOUNT,BYTECOUNTER,11
	qbeq STARTCOUNT,BYTECOUNTER,0
	add BITCOUNTER,BITCOUNTER,1
	qbeq RESETBITCOUNTER,BITCOUNTER,10
	qbeq DISCARDALL,CURRENTDATA,1
	jmp ENDNORMALCOUNT
STARTCOUNT:
	ldi32 BYTECOUNTER,1
	ldi32 BITCOUNTER,1
	jmp ENDSTARTCOUNTER
RESETBITCOUNTER:
	qbne DISCARDALL,CURRENTDATA,1
	SBBO &BYTECOUNTER,r29,0,4
	ldi R31.b0, PRU0_R31_VEC_VALID | PRU_EVTOUT_0
	ldi32 BITCOUNTER,0
	add BYTECOUNTER,BYTECOUNTER,1
	jmp ENDRESETBITCOUNTER
DISCARDALL:
	ldi32 ISTWOSYNC,0
	ldi32 BYTECOUNTER,0
	ldi32 BITCOUNTER,0
	ldi32 SECOND,0
	ldi32 MINUTE,0
	ldi32 HOUR,0
	jmp ENDCALCULATEBYTEANDBITCOUNTER
ENDSTARTCOUNTER:
	nop
ENDNORMALCOUNT:
	nop
ENDRESETBITCOUNTER:
	nop
	nop
	nop
	nop
ENDCALCULATEBYTEANDBITCOUNTER:
	nop                                   ;*12 instructions
	.endm

FORBYTEONE .macro
	qbeq BYTE1SKIPBIT0,BITCOUNTER,0
	qbeq BYTE1SKIPBIT1,BITCOUNTER,1
	qbeq BYTE1SKIPBIT6,BITCOUNTER,6
	lsr SECOND,SECOND,1
	qbeq SETSECONDBIT,CURRENTDATA,2
	jmp MAINTAINBYTE1
SETSECONDBIT:
	set SECOND,SECOND,7
	jmp ENDPUSHBYTEONE
BYTE1SKIPBIT0:
	nop
BYTE1SKIPBIT1:
	nop
BYTE1SKIPBIT6:
	nop
	nop
	nop
MAINTAINBYTE1:
	nop
ENDPUSHBYTEONE:
	qbne ENDFORBYTEONE,BITCOUNTER,9
	lsr SECOND,SECOND,1
	SBBO   &SECOND, r29, 12, 4
	nop
ENDFORBYTEONE:
	nop
	.endm                                ;*9 instructions

FORBYTETWO .macro
	qbeq BYTE2SKIPBIT0,BITCOUNTER,0
	qbeq BYTE2SKIPBIT5,BITCOUNTER,5
	lsr MINUTE,MINUTE,1
	qbeq SETMINUTEBIT,CURRENTDATA,2
	jmp MAINTAINBYTE2
SETMINUTEBIT:
	set MINUTE,MINUTE,7
	jmp ENDPUSHBYTETWO
BYTE2SKIPBIT0:
	nop
BYTE2SKIPBIT5:
	nop
	nop
	nop
MAINTAINBYTE2:
	nop
ENDPUSHBYTETWO:
	qbne ENDFORBYTETWO,BITCOUNTER,9
	SBBO   &MINUTE, r29, 8, 4
ENDFORBYTETWO:
	nop
	.endm                                ;*9 instructions

FORBYTETHREE .macro
	qbeq BYTE3SKIPBIT0,BITCOUNTER,0
	qbeq BYTE3SKIPBIT5,BITCOUNTER,5
	lsr HOUR,HOUR,1
	qbeq SETHOURBIT,CURRENTDATA,2
	jmp MAINTAINBYTE3
SETHOURBIT:
	set HOUR,HOUR,7
	jmp ENDPUSHBYTETHREE
BYTE3SKIPBIT0:
	nop
BYTE3SKIPBIT5:
	nop
	nop
	nop
MAINTAINBYTE3:
	nop
ENDPUSHBYTETHREE:
	qbne ENDFORBYTETHREE,BITCOUNTER,7
	SBBO   &HOUR, r29, 4, 4
ENDFORBYTETHREE:
	nop
	.endm                                ;*9 instructions



main:
	ldi32 r29, 0x00000000
	ldi32 DATA,0
	ldi32 TEMP,0
	ldi32 ITERATE,0
	ldi32 COUNT,0
	ldi32 ISPEAK,0
	ldi32 DATAWIDTH,0
	ldi32 PREVDATA,0
	ldi32 CURRENTDATA,0
	ldi32 SAMPLENO,245
	ldi32 SYNCUPPERLIMIT,288
	ldi32 ISTWOSYNC,0
	ldi32 BYTECOUNTER,0
	ldi32 BITCOUNTER,0
	ldi32 SECOND,0
	ldi32 MINUTE,0
	ldi32 HOUR,0

START:
	GETBIT
	COUNTSTART
	CHECKONESFORWIDTH                   ;*80 instructions
	MAINTAINSAMPLINGRATE
	qbne SKIPALLCHECK,ISPEAK,1          ;*49 instructions
	WHICHPEAK                           ;*12 instructions
	CHECKTWOSYNC                        ;*7 instructions
	qbne SKIP,ISTWOSYNC,1               ;*46 instructions
	CALCULATEBYTEANDBITCOUNTER          ;*13 instructions
	qbeq CALLFORBYTE1,BYTECOUNTER,1     ;*10 instructions           49 instructions
	qbeq CALLFORBYTE2,BYTECOUNTER,2     ;*10 instructions           49 instructions
	qbeq CALLFORBYTE3,BYTECOUNTER,3     ;*10 instructions           49 instructions
	jmp MAINTAINSKIP

CALLFORBYTE1:
	FORBYTEONE
	nop
	nop
	jmp NOPUSH                          ;*49 instructions
CALLFORBYTE2:
	FORBYTETWO
	nop
	jmp NOPUSH                          ;*49 instructions
CALLFORBYTE3:
	FORBYTETHREE
	jmp NOPUSH                          ;*49 instructions
SKIPALLCHECK:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop           ;*20
SKIP:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
MAINTAINSKIP:
	nop
	nop
	nop
	nop
	nop
	nop
	nop          ;*27
NOPUSH:
	nop
	jmp START




	 