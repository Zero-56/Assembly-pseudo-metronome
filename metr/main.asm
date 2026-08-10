stm8/

	#include "mapping.inc"
	#include "stm8s105c6.inc"
	
	segment 'ram0'
bpm ds.b 
timesignatures ds.b 4 ;four signatures 1/4->4/4
beat_display ds.b
signature_counter ds.b
max_signature ds.b
			segment 'rom'
digits  dc.b %10000001, $f3, %01001001, %01100001, $33, $25, $05, $f1, 0, $21
duty_cycles dc.w 0, 1667, 6111, 11111 ;0, 15, 55, 100%

main.l
	; initialize SP
	ldw X,#stack_end
	ldw SP,X

	#ifdef RAM0	
	; clear RAM0
ram0_start.b EQU $ram0_segment_start
ram0_end.b EQU $ram0_segment_end
	ldw X,#ram0_start
clear_ram0.l
	clr (X)
	incw X
	cpw X,#ram0_end	
	jrule clear_ram0
	#endif

	#ifdef RAM1
	; clear RAM1
ram1_start.w EQU $ram1_segment_start
ram1_end.w EQU $ram1_segment_end	
	ldw X,#ram1_start
clear_ram1.l
	clr (X)
	incw X
	cpw X,#ram1_end	
	jrule clear_ram1
	#endif

	; clear stack
stack_start.w EQU $stack_segment_start
stack_end.w EQU $stack_segment_end
	ldw X,#stack_start
clear_stack.l
	clr (X)
	incw X
	cpw X,#stack_end	
	jrule clear_stack

	;variable config
	mov bpm, #90
	mov beat_display, #0 ;initially all LEDS OFF
	mov max_signature, #4 ; asked to do 4/4 
	clr signature_counter
	clrw x
	ld a, #1 ;pass by value via accumulator for the next call
	call fill_timesignatures
	
	;timer config
	call config_tim2
	call config_tim3
	
	;IO Config
	;buttons
	mov PA_DDR, #0 ;all as inpout
	mov PA_CR1, #$ff ;all as pullup to avoid stray floats
	bset PA_CR2, #3 ;interrup enable
	mov EXTI_CR1, #%00000010 ;falling edge, when btn pressed first
	mov PE_DDR, #0 ;all as inpout
	mov PE_CR1, #$ff ;all as pullup to avoid stray floats
	bset PE_CR2, #5 ;interrup enable
	mov EXTI_CR2, #%00000001 ;rising edge, when btn pressed released
	
	;LEDs
	mov PB_DDR,#$ff ;out
	mov PB_CR1, #$ff ;all push pull to avoid surprises :)
	bset PD_DDR, #4 ;out
	bset PD_CR1, #4 ;push-pull
	
	;Display
	;transistor
	mov PG_DDR, #%00000001 ;transistor 0 OUT (left display)
	mov PG_CR1, #%00000001 ;transistor in push-pull
	bset PG_ODR, #0 ;display OFF initially
	;segments
	mov PC_DDR, #$ff ;all out
	mov PC_CR1, #$ff ;all push-pull
	
	rim 
infinite_loop.l
	jra infinite_loop

config_tim2
	MOV TIM2_CR1,#%00000001 ; counter enable ON
	MOV TIM2_IER,#$00 ; no interrupts
	MOV TIM2_CCMR1,#%01100000 ; PWM mode 1 + CC1 as output
	MOV TIM2_CCER1,#%00000001 ; enable CC1 output
	ldw x, #11111 ;2MHz/180Hz
	ld a, xh
	ld TIM2_ARRH, a
	ld a, xl
	ld TIM2_ARRL, a
	
	ldw x, #0 ;initial duty cycle is zero
	ld a, xh
	ld TIM2_CCR1H, a
	ld a, xl
	ld TIM2_CCR1L, a
	ret
	
config_tim3
	MOV TIM3_CR1,#%00000000 ; TIM3 initilally OFF
	MOV TIM3_PSCR,#$06 ; prescaler  = 2^^6 = 64
	BSET TIM3_EGR,#0 ; force UEV to update prescaler
	MOV TIM3_IER,#$01 ; TIM3 interrupt on update enabled
	bres TIM3_SR1, #0
	;ARR calculation
	;ldw x, #31250 ;2MHz/64 (prescaler) 
	;ld a, bpm ;in our case 90
	;div x, a ; we divide the 2MHz/64 with bpm
	ldw x, #20833 ;2MHz/(64*(90/60)) divided by prescaler times bp second
	ld a, xh
	ld TIM3_ARRH, a
	ld a, xl
	ld TIM3_ARRL, a
	ret
	
fill_timesignatures.l
	ld (timesignatures,x), a
	incw x
	inc a
	cp a, #5 ;after the 4/4 has been reached
	jrne fill_timesignatures
	ret

	interrupt NonHandledInterrupt
NonHandledInterrupt.l
	iret
	
	interrupt LEDBeat	
LEDBeat.l
	;Display
	clrw x
	ld a, signature_counter
	inc a ;since signature counter starts at 0
	ld xl, a
	ld a, (digits,x)
	ld PC_ODR, a
	bres PG_ODR, #0 ;display ON
	
	;TIM2 duty cycle
	clrw x
	ld a, signature_counter
	sll a ;beasue its an array of words, the index needs to be doubled
	ld xl, a ; now x has counter thats used as a index for duty cycle array
	ldw x, (duty_cycles,x) ;x now has duty cycle value
	ld a, xh
	ld TIM2_CCR1H, a
	ld a, xl
	ld TIM2_CCR1L, a
	clrw x ;just to be safe
	
	;LED lightup
	mov PB_ODR, beat_display
	sll beat_display  ;move to left
	bset beat_display, #0 ;set the new zero to one
	inc signature_counter ;counts the beats made
	ld a, signature_counter
	cp a, max_signature
	jrne endISR
	mov beat_display, #1 ;initially one LED is on 
	clr signature_counter
endISR.l
	bres TIM3_SR1, #0 ;reset interrupt flag
	iret
	
	interrupt start
start.l
;starting with resetting the beat counters
	mov beat_display, #1 ;initially one LED is on 
	clr signature_counter
	MOV TIM3_CR1,#%00000001 ;TIM3 ON
	MOV TIM2_CR1,#%00000001
	iret
	
	interrupt stop
stop.l
	;all lights off
	clr PB_ODR
	bset PG_ODR, #0
	;timer3 off
	MOV TIM3_CR1,#%00000000
	;set duty cycle of TIM2 to zero (cleaner, always turns off D4)
	clrw x
	ld a, xh
	ld TIM2_CCR1H, a
	ld a, xl
	ld TIM2_CCR1L, a
	iret

	segment 'vectit'
	dc.l {$82000000+main}									; reset
	dc.l {$82000000+NonHandledInterrupt}	; trap
	dc.l {$82000000+NonHandledInterrupt}	; irq0
	dc.l {$82000000+NonHandledInterrupt}	; irq1
	dc.l {$82000000+NonHandledInterrupt}	; irq2
	dc.l {$82000000+start}	; irq3
	dc.l {$82000000+NonHandledInterrupt}	; irq4
	dc.l {$82000000+NonHandledInterrupt}	; irq5
	dc.l {$82000000+NonHandledInterrupt}	; irq6
	dc.l {$82000000+stop}	; irq7
	dc.l {$82000000+NonHandledInterrupt}	; irq8
	dc.l {$82000000+NonHandledInterrupt}	; irq9
	dc.l {$82000000+NonHandledInterrupt}	; irq10
	dc.l {$82000000+NonHandledInterrupt}	; irq11
	dc.l {$82000000+NonHandledInterrupt}	; irq12
	dc.l {$82000000+NonHandledInterrupt}	; irq13
	dc.l {$82000000+NonHandledInterrupt}	; irq14
	dc.l {$82000000+LEDBeat}	; irq15 TIM3
	dc.l {$82000000+NonHandledInterrupt}	; irq16
	dc.l {$82000000+NonHandledInterrupt}	; irq17
	dc.l {$82000000+NonHandledInterrupt}	; irq18
	dc.l {$82000000+NonHandledInterrupt}	; irq19
	dc.l {$82000000+NonHandledInterrupt}	; irq20
	dc.l {$82000000+NonHandledInterrupt}	; irq21
	dc.l {$82000000+NonHandledInterrupt}	; irq22
	dc.l {$82000000+NonHandledInterrupt}	; irq23
	dc.l {$82000000+NonHandledInterrupt}	; irq24
	dc.l {$82000000+NonHandledInterrupt}	; irq25
	dc.l {$82000000+NonHandledInterrupt}	; irq26
	dc.l {$82000000+NonHandledInterrupt}	; irq27
	dc.l {$82000000+NonHandledInterrupt}	; irq28
	dc.l {$82000000+NonHandledInterrupt}	; irq29

	end
