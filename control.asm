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
;-------------------------------------------------------------------------------
;				SYSTEM-DEFINED/RESERVED NAMES
;-------------------------------------------------------------------------------
STATUS	EQU    0x03
PORTB	EQU    0x06
TRISB	EQU    0x86
TRISA   EQU    0x85  
PIE1	EQU    0x8C
ADCON0  EQU    0x1F
ADCON1  EQU    0x9F
PIR1    EQU    0x0C
ADRESH  EQU    0x1E
ADRESL	EQU    0x9E  

;-------------------------------------------------------------------------------
;			    USER-DEFINED PORT ALIASES
;-------------------------------------------------------------------------------
EN1_2	EQU    0x07
IN1	EQU    0x06	
IN2	EQU    0x05	
EN3_4   EQU    0x04
IN3	EQU    0x03
IN4     EQU    0x02
ADIE	EQU    0x06		    ; 6th bit of PIE1 register 
ADIF    EQU    0x06		    ; 6th bit of PIR1 register
GO	EQU    0x02		    ; 2nd bit of ADCON0    
     
ALL_FWD_LED	   EQU    0x00	    ; red PORTD pins
ALL_REV_LED	   EQU    0x01	    ; green
RT_TRN_FWD_LED     EQU    0x02	    ; yellow
RT_TRN_REV_LED	   EQU    0x03	    ; white
LFT_TRN_FWD_LED	   EQU    0x04	    ; blue
LFT_TRN_REV_LED	   EQU    0x05	    ; red again because LED colors are limited
    
;--------------------------------------------------------------------------
;		Allocate memory blocks for delay variables.
;--------------------------------------------------------------------------
 
		CBLOCK 0x20
		       counter
		       Kount99_6us
		       Kount100us
		       Kount10ms
		       Kount1s
		       Kount5
		       ADC_RES			   ; ADC result
		       BANG_BANG_THRESH		   ; distance threshold for bang-bang
		       SHOULD_MOVE
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
		
;***************************************************************************
;			  SENSOR LOGIC
;***************************************************************************
; Reference: [http://www.mwftr.com/ucF08/LEC15%20PIC%20AD.pdf]
;		
; The first step is to configure the A/D logic. [See the `init` label]
;
; Afterwards, the `adc` routine (below) is called which converts values from the
; sensor and stores the result in the ADRESH register (last 8 bits) for further
; use.
;
;-------------------------------------------------------------------------------
; NOTE: Since we are restricted to 8 bits, our resolution is from 0-255 max
;
; So, the conversion from adc value to voltage is like so:
;   [analog_voltage] = 5/255 * [adc_val] --> where 5V is maximum range of ADC
;-------------------------------------------------------------------------------
;
; For now, we're implementing Bang-Bang, so once, we hit a distance threshold,
; we stop the vehicle and find free directions to turn to. 
; We'll have this distance threshold be [24 cm] based on experiments. 
;
; In the future, the voltage obtained from the ADC is fed into an equation
; chosen based on experiments run with the IR sensor. The resulting value is the 
; distance from the obstacle. This distance will then be used to calculate the  
; speed at which the vehicle should move to avoid hitting the obstacle.
; 
; For now the equation will be 13*(analog_voltage)^-1
;
; This is *PID control.*
;-------------------------------------------------------------------------------
		
test_distance_thresh	movlw  ADC_RES
			subwf  BANG_BANG_THRESH
			skpnc			; if carry bit is clear, then ADC result > threshold
			nop
			clrf   SHOULD_MOVE	; clear the signal to keep moving
			return
		
;-------------------------------------------------------------------------------
		
;-------------------------------------------------------------------------------
;			    ADC CONVERSION
;-------------------------------------------------------------------------------
		
adc		call    delay10ms
		banksel	ADCON0
		bsf	ADCON0, GO	; triggers the AD conversion
 
adcloop         btfsc   ADCON0, GO	; wait for conversion to be done
		goto	adcloop
		bcf	PIR1, ADIF	; clear conversion finished bit
		movf	ADRESH, 0	; writes result from ADRESH to W register
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
		    
init		    movlw	0xFF	      ; initializing A/D module
		    banksel     TRISA	      ; select bank that has port A	
		    movwf	PORTA	      ; port A pins are outputs	
		    
		    banksel     PIE1
		    bcf		PIE1, ADIE    ; clear PIE1[ADIE] to disable 
					      ; converter interrupt
		    banksel     ADCON0	      ; ADC operation configuration
		    movlw	0xC9
		    movwf	ADCON0
		    
		    banksel     ADCON1	      ; ADC result configuration 
		    movlw       0x80	      ; this byte sets the result as
		    movwf       ADCON1	      ; right-justified in ADRESH-ADRESL
		    
		    banksel     BANG_BANG_THRESH
		    movlw	0x1E	      ; magic
		    movwf	BANG_BANG_THRESH
		    movlw	0x05
		    movwf	Kount5

loop		    banksel     PIR1	      ; PIR1 register contains result of A/D conversion
		    bcf		PIR1, ADIF    ; clear ADIF bit to start the next conversion
		    banksel     ADC_RES
		    clrf	ADC_RES	      ; clear conversion result for next run of ADC
		    call        adc	      	
		    banksel	ADC_RES
			movwf	ADC_RES	           ; after `adc` routine runs, ADC result will be
						   ; written to W register which we can access
						   ; and use to determine the next course of
						   ; action
		    call	test_distance_thresh
test_keep_moving    andwf	SHOULD_MOVE        ; test if should_move is zero
		    skpz
		    nop
		    call	determine_next_direction
		    goto	loop
		
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



