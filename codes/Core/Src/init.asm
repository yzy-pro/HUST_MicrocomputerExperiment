;-------------------------------------------------------------------------------
; init.asm - reset entry and MCU peripheral initialization
;-------------------------------------------------------------------------------
            ORG 0100H
START:
            MOV SP, #70H
            LCALL INIT_DEVICE
            LCALL CLEAR_DISPLAY
            MOV game_state, #ST_IDLE
            MOV rand_seed, #5AH
            MOV best_lo, #0FFH
            MOV best_hi, #0FFH
            MOV led_pattern, #0FEH
            MOV led_pwm, #00H
            MOV timing_flag, #00H
            MOV last_key, #KEY_NONE
            MOV beep_count, #00H
            MOV show_timer, #00H
            MOV kint_value, #00H
            MOV wait_tick, #00H
            MOV wait_hi, #00H
            MOV game_mode, #MODE_REACT
            MOV rhythm_tick, #00H
            MOV rhythm_score, #00H
            MOV rhythm_diff, #DIFF_LOW
            MOV rhythm_target, #00H
            MOV rhythm_pat, #0FEH
            LCALL UART_BANNER

            LJMP MAIN_LOOP

INIT_DEVICE:
            LCALL PCA_INIT
            LCALL OSC_INIT
            LCALL PORT_IO_INIT
            LCALL TIMER0_INIT
            LCALL TIMER2_INIT
            LCALL UART0_INIT
            SETB EA
            RET

PCA_INIT:
            ANL PCA0MD, #0BFH        ; disable watchdog
            MOV PCA0MD, #000H
            RET

OSC_INIT:
            MOV OSCICN, #083H        ; internal oscillator enabled, near max frequency
            RET

PORT_IO_INIT:
            ; P0.4/P0.5 UART, P0.6/P0.7 digit select push-pull.
            MOV P0MDOUT, #0D0H       ; P0.4 TXD, P0.6, P0.7 push-pull
            MOV P1MDOUT, #0FFH       ; 7-seg segment pins push-pull
            MOV P2MDOUT, #00FH       ; keypad rows push-pull, columns input
            MOV P3MDOUT, #01AH       ; P3.1 buzzer, P3.3 data, P3.4 clock push-pull
            MOV P3, #00H
            MOV P2, #0FFH
            MOV P1, #00H
            MOV P0SKIP, #00H
            MOV P1SKIP, #00H
            MOV P2SKIP, #00H
            MOV XBR0, #01H           ; enable UART0 on crossbar
            MOV XBR1, #40H           ; enable crossbar and weak pullups
            ; External INT0 on P0.1, low active. IT01CF low nibble selects INT0 pin.
            MOV IT01CF, #01H         ; IN0SL=1 -> P0.1, low active default
            SETB IT0                 ; edge triggered
            CLR EX0                  ; KINT is handled by polling with debounce
            RET

TIMER0_INIT:
            ANL TMOD, #0F0H
            ORL TMOD, #001H          ; Timer0 mode 1, 16-bit
            ANL CKCON, #0F8H         ; SCA1..0=00, T0M=0, Timer0 uses SYSCLK/12
            MOV TH0, #TIMER0_RELOAD_H
            MOV TL0, #TIMER0_RELOAD_L
            SETB ET0
            SETB TR0
            RET

TIMER2_INIT:
            CLR TR2
            MOV TMR2CN, #00H         ; 16-bit auto-reload timer mode
            ANL CKCON, #0CFH         ; Timer2 high/low bytes use SYSCLK/12
            MOV TMR2RLL, #TIMER0_RELOAD_L
            MOV TMR2RLH, #TIMER0_RELOAD_H
            MOV TMR2L, #TIMER0_RELOAD_L
            MOV TMR2H, #TIMER0_RELOAD_H
            CLR TF2L
            CLR TF2H
            SETB ET2
            SETB TR2
            RET

UART0_INIT:
            ; UART0 mode 1, variable baud. Timer1 mode 2 for 9600 baud approximate at 24.5MHz.
            ANL TMOD, #00FH
            ORL TMOD, #020H          ; Timer1 mode 2
            ORL CKCON, #008H         ; T1M=1, Timer1 uses SYSCLK
            MOV TH1, #UART1_RELOAD
            MOV TL1, #UART1_RELOAD
            MOV SCON0, #050H         ; 8-bit UART, REN enabled
            SETB TR1
            SETB TI0
            RET
