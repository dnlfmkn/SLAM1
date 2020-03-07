; NOTE: Please Clean and Build after opening the project for
;       the first time.
 
;**************************************************************************
;			    CONTROL
;**************************************************************************
; Aim:
;   - Add direction control logic for autonomous vehicle.
;**************************************************************************
    
#include <p16f877.inc> 
;--------------------------------------------------------------------------
; Set Configuration Bits (Disable Watchdog Timer)
;--------------------------------------------------------------------------
; CONFIG
; __config 0xFFFB
  __CONFIG _FOSC_EXTRC & _WDTE_OFF & _PWRTE_OFF & _BOREN_ON & _LVP_ON & _CPD_OFF & _WRT_OFF & _CP_OFF
STATUS	EQU    0x03
PORTB	EQU    0x06
TRISB	EQU    0x86

EN1_2	EQU    0x07
IN1	EQU    0x06	
IN2	EQU    0x05	
EN3_4   EQU    0x04
IN3	EQU    0x03
IN4     EQU    0x02
     
ALL_FWD_LED	   EQU    0x00	    ; red PORTD pins
ALL_REV_LED	   EQU    0x01	    ; green
RT_TRN_FWD_LED     EQU    0x02	    ; yellow
RT_TRN_REV_LED	   EQU    0x03	    ; white
LFT_TRN_FWD_LED	   EQU    0x04	    ; blue
LFT_TRN_REV_LED	   EQU    0x05	    ; red again because LED colors are limited
    
;--------------------------------------------------------------------------
;   Allocate memory blocks for delay variables.
;--------------------------------------------------------------------------
 
		CBLOCK 0x20
		       counter
		       Kount99_6us
		       Kount100us
		       Kount10ms
		       Kount1s
		       Kount5
		ENDC
		
;--------------------------------------------------------------------------
;   Set the reset vector.
;--------------------------------------------------------------------------

		org	    0x0000
		goto	    start
		nop
		nop
		nop
		nop	
		
;--------------------------------------------------------------------------
;			  ALL-FORWARD LOGIC
;--------------------------------------------------------------------------
		
all_forward     bsf	PORTB, EN1_2	    ; turn on all enables
		bsf	PORTB, EN3_4
		bcf	PORTB, IN1	    ; clear IN1 & IN3 and set IN2 & IN 4 to set  
		bsf	PORTB, IN2	    ; left and right axes forward respectively
		bcf	PORTB, IN3
		bsf     PORTB, IN4
		call	delay1s
		return
	
;--------------------------------------------------------------------------
;			  ALL-REVERSE LOGIC
;--------------------------------------------------------------------------
		
all_reverse	bsf	PORTB, EN1_2	    ; turn on all enables
		bsf	PORTB, EN3_4
		bsf	PORTB, IN1	    ; set IN1 & IN3 and clear IN2 & IN 4 to set  
		bcf	PORTB, IN2	    ; left and right axes in reverse respectively
		bsf	PORTB, IN3
		bcf     PORTB, IN4
		call	delay1s
		return

;--------------------------------------------------------------------------
;			  RIGHT-TURN LOGIC
;--------------------------------------------------------------------------
; Right-turn (forward) logic			  
;--------------------------------------------------------------------------
		
rt_turn_fwd	bsf	PORTB, EN3_4
		bsf	PORTB, EN1_2
		bcf	PORTB, IN3
		bcf	PORTB, IN4
		bcf	PORTB, IN1
		bsf	PORTB, IN2
		call	delay1s
		return
					  
;--------------------------------------------------------------------------
; Right-turn (reverse) logic			  
;--------------------------------------------------------------------------
		
rt_turn_rev	bsf	PORTB, EN3_4
		bsf	PORTB, EN1_2
		bcf	PORTB, IN3
		bcf	PORTB, IN4
		bsf	PORTB, IN1
		bcf	PORTB, IN2
		call	delay1s
		return
		
;--------------------------------------------------------------------------
;			  LEFT-TURN LOGIC
;--------------------------------------------------------------------------
; Left-turn (forward) logic			  
;--------------------------------------------------------------------------
		
left_turn_fwd   bsf	PORTB, EN1_2
		bsf	PORTB, EN3_4
		bcf	PORTB, IN1
		bcf	PORTB, IN2
		bcf	PORTB, IN3
		bsf	PORTB, IN4
		call	delay1s
		return

;--------------------------------------------------------------------------
; Left-turn (reverse) logic			  
;--------------------------------------------------------------------------
	
left_turn_rev	bsf	PORTB, EN1_2
		bsf	PORTB, EN3_4
		bcf	PORTB, IN1
		bcf	PORTB, IN2
		bsf	PORTB, IN3
		bcf	PORTB, IN4
		call	delay1s
		return
		
;--------------------------------------------------------------------------
;			ONE SECOND DELAY LOGIC
;--------------------------------------------------------------------------
delay99_6us		             ; runs for 498 cycles <-> 99.6us
		movlw	0xA5         ; move 165'd to W register
		movwf	Kount99_6us  ; move 165'd to GPR
impl_99_6us
		decfsz	Kount99_6us
		goto	impl_100us
		return
	
delay100us			     ; runs for 500 cycles
		movlw	0xA5         ; move 165'd to W register
		movwf	Kount100us   ; move 165'd to register
impl_100us
		decfsz	Kount100us
		goto	impl_100us
		nop
		nop
		return

delay10ms		             ; runs for 50,000 cycles
		movlw	0x63         ; move 99'd to W register
		movwf	Kount10ms
impl_10ms
		call	delay100us
		decfsz	Kount10ms
		goto	impl_10ms
		nop
		nop
		return

delay1s
		movlw	0x63
		movwf	Kount1s
impl_1s
		call	delay10ms
		call	delay99_6us
		clrwdt
		decfsz	Kount1s
		goto	impl_1s
		nop
		nop
		return
		
;--------------------------------------------------------------------------
;				MAIN
;--------------------------------------------------------------------------
start		    bcf		STATUS, 0x06  ; ensure we can either be in bank 0/1
		    bsf		STATUS, 0x05  ; switch to bank 1 to access TRISB
		    movlw	0x01
		    movwf	TRISB	      ; make pins 2-7 of PORTB outputs
		    movlw       0x00
		    movwf       TRISD	      ; make pins 0-6 of PORTD outputs       
		    banksel     PORTB	      ; switch to the bank containing PORTB
		    clrf	PORTB	      ; deactivate all pins of PORTB
		    banksel     PORTD
		    clrf        PORTD
		
		    movlw	0x05
		    movwf	Kount5
		
all_fwd_test	    call	all_forward
		    bsf		PORTD, ALL_FWD_LED 
		    decfsz	Kount5
		    goto	all_fwd_test
		    movlw	0x05
		    movwf	Kount5
		    bcf		PORTD, ALL_FWD_LED
all_rev_test	    call	all_reverse
		    bsf         PORTD, ALL_REV_LED
		    decfsz	Kount5
		    goto	all_rev_test
		    movlw	0x05
		    movwf	Kount5
		    bcf         PORTD, ALL_REV_LED   
rt_turn_fwd_test    call	rt_turn_fwd
		    bsf         PORTD, RT_TRN_FWD_LED
		    decfsz	Kount5
		    goto	rt_turn_fwd_test
		    movlw	0x05
		    movwf	Kount5
		    bcf         PORTD, RT_TRN_FWD_LED
rt_turn_rev_test    call	rt_turn_rev
		    bsf         PORTD, RT_TRN_REV_LED
		    decfsz	Kount5
		    goto	rt_turn_rev_test
		    movlw	0x05
		    movwf	Kount5
		    bcf         PORTD, RT_TRN_REV_LED		    
lft_turn_fwd_test   call	left_turn_fwd
		    bsf         PORTD, LFT_TRN_FWD_LED
		    decfsz	Kount5
		    goto	lft_turn_fwd_test
		    movlw	0x05
		    movwf	Kount5
		    bcf         PORTD, LFT_TRN_FWD_LED
lft_turn_rev_test   call	left_turn_rev
		    bsf         PORTD, LFT_TRN_REV_LED
		    decfsz	Kount5
		    goto	lft_turn_rev_test  
		    bcf         PORTD, LFT_TRN_REV_LED
		    movlw	0xFF
		    movwf       TRISB
		    END



