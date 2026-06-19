;-------------------------------------------------------------------------------
; isr.asm - Timer0/Timer2/INT0 interrupt services
;-------------------------------------------------------------------------------
TIMER0_ISR:
            PUSH ACC
            PUSH PSW
            MOV TH0, #TIMER0_RELOAD_H
            MOV TL0, #TIMER0_RELOAD_L

            LCALL DISPLAY_SCAN

            MOV A, beep_count
            JZ T0_BEEP_OFF
            SETB P3.1
            DEC beep_count
            SJMP T0_TIME
T0_BEEP_OFF:
            CLR P3.1

T0_TIME:
            INC ms_sub
            MOV A, ms_sub
            ANL A, #1FH
            JNZ T0_PWM
            MOV A, game_state
            CJNE A, #ST_WAIT, T0_PWM
            MOV A, led_pattern
            RL A
            JNZ T0_LED_OK
            MOV A, #0FEH
T0_LED_OK:
            MOV led_pattern, A

T0_PWM:
            LCALL LED_PWM_SERVICE

T0_EXIT:
            POP PSW
            POP ACC
            RETI

;-------------------------------------------------------------------------------
; Timer2 ISR: exact 1 ms game time base, independent from display refresh work.
; Timer2 auto-reloads in hardware, so ISR execution length does not stretch
; the reaction-time tick.
;-------------------------------------------------------------------------------
TIMER2_ISR:
            PUSH ACC
            PUSH PSW
            CLR TF2H
            CLR TF2L

            MOV A, wait_tick
            ORL A, wait_hi
            JZ T2_SHOW_TIMER
            MOV A, wait_tick
            JNZ T2_DEC_WAIT_LO
            MOV A, wait_hi
            JZ T2_SHOW_TIMER
            DEC wait_hi
            MOV wait_tick, #0FFH
            SJMP T2_SHOW_TIMER
T2_DEC_WAIT_LO:
            DEC wait_tick

T2_SHOW_TIMER:
            MOV A, show_timer
            JZ T2_REACT
            DEC show_timer

T2_REACT:
            MOV A, timing_flag
            JZ T2_RHYTHM
            INC react_lo
            MOV A, react_lo
            JNZ T2_RHYTHM
            INC react_hi

T2_RHYTHM:
            MOV A, game_state
            CJNE A, #ST_PLAY, T2_EXIT
            MOV A, game_mode
            CJNE A, #MODE_RHYTHM, T2_EXIT
            MOV A, rhythm_tick
            JZ T2_RHYTHM_ADVANCE
            DEC rhythm_tick
            SJMP T2_EXIT
T2_RHYTHM_ADVANCE:
            MOV A, rhythm_diff
            CJNE A, #DIFF_LOW, T2_RHYTHM_NOT_LOW
            MOV rhythm_tick, #220
            SJMP T2_RHYTHM_SPEED_DONE
T2_RHYTHM_NOT_LOW:
            CJNE A, #DIFF_HIGH, T2_RHYTHM_NORMAL_SPEED
            MOV rhythm_tick, #90
            SJMP T2_RHYTHM_SPEED_DONE
T2_RHYTHM_NORMAL_SPEED:
            MOV rhythm_tick, #160
T2_RHYTHM_SPEED_DONE:
            MOV A, led_pattern
            RL A
            MOV led_pattern, A

T2_EXIT:
            POP PSW
            POP ACC
            RETI

;-------------------------------------------------------------------------------
; INT0 ISR: not used. KINT is polled and debounced in the main loop.
;-------------------------------------------------------------------------------
INT0_ISR:
            RETI
