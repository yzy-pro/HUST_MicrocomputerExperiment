;-------------------------------------------------------------------------------
; reaction_game.inc - shared constants and internal RAM layout
;-------------------------------------------------------------------------------
$NOMOD51
$include (C8051F310.INC)

; Internal oscillator on the C8051F310 EVM is 24.5 MHz.
; Timer0/Timer2 use SYSCLK/12: 24.5 MHz / 12 = 2.041666 MHz.
; 1 ms needs about 2042 counts, reload = 65536 - 2042 = F806H.
TIMER0_RELOAD_H EQU 0F8H
TIMER0_RELOAD_L EQU 006H

; UART0 uses Timer1 mode 2 with Timer1 clock = SYSCLK.
; Baud ~= 24.5 MHz / (32 * (256 - B0H)) = 9570 bps, close to 9600 8N1.
UART1_RELOAD    EQU 0B0H

ST_IDLE         EQU 00H
ST_WAIT         EQU 01H
ST_SHOW         EQU 02H
ST_PLAY         EQU 03H
ST_SUCCESS      EQU 04H
ST_FAIL         EQU 05H

MODE_REACT      EQU 00H
MODE_RHYTHM     EQU 01H

DIFF_LOW        EQU 00H
DIFF_MID        EQU 01H
DIFF_HIGH       EQU 02H

KEY_NONE        EQU 0FFH

BEEP_SHORT      EQU 18
BEEP_LONG       EQU 80

; 7-seg codes for common-cathode display on this EVM, high active.
; Index: 0..9,A,b,C,d,E,F, blank, dash, r, L
SEG_BLANK_IDX   EQU 10H
SEG_DASH_IDX    EQU 11H
SEG_R_IDX       EQU 12H
SEG_L_IDX       EQU 13H

; Internal RAM variables. These fixed addresses match the original DSEG AT 30H
; allocation so splitting the source does not change runtime state layout.
ms_sub          EQU 30H
scan_digit      EQU 31H
disp0           EQU 32H
disp1           EQU 33H
disp2           EQU 34H
disp3           EQU 35H
key_value       EQU 36H
last_key        EQU 37H
target_key      EQU 38H
rand_seed       EQU 39H
wait_tick       EQU 3AH
wait_hi         EQU 3BH
react_lo        EQU 3CH
react_hi        EQU 3DH
best_lo         EQU 3EH
best_hi         EQU 3FH
score_lo        EQU 40H
score_hi        EQU 41H
game_state      EQU 42H
timing_flag     EQU 43H
beep_count      EQU 44H
led_pattern     EQU 45H
led_pwm         EQU 46H
show_timer      EQU 47H
uart_temp       EQU 48H
bcd_hund        EQU 49H
bcd_tens        EQU 4AH
bcd_ones        EQU 4BH
bcd_thou        EQU 4CH
kint_value      EQU 4DH
conv_lo         EQU 4EH
conv_hi         EQU 4FH
game_mode       EQU 50H
rhythm_tick     EQU 51H
rhythm_score    EQU 52H
rhythm_diff     EQU 53H
rhythm_target   EQU 54H
rhythm_pat      EQU 55H
