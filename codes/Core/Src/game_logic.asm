;-------------------------------------------------------------------------------
; game_logic.asm - game state machine and mode handlers
;-------------------------------------------------------------------------------
STATE_IDLE:
            MOV A, game_mode
            CJNE A, #MODE_RHYTHM, IDLE_SHOW_REACT
            MOV disp3, #SEG_L_IDX
            MOV A, rhythm_diff
            INC A
            MOV disp2, A
            MOV disp1, #00H
            MOV disp0, #00H
            RET
IDLE_SHOW_REACT:
            MOV disp3, #SEG_R_IDX
            MOV disp2, #SEG_BLANK_IDX
            MOV disp1, #00H
            MOV disp0, #00H
            RET

HANDLE_KINT:
            MOV A, game_state
            CJNE A, #ST_IDLE, HK_NOT_IDLE
            LCALL NEW_ROUND
            RET
HK_NOT_IDLE:
            CJNE A, #ST_SUCCESS, HK_NOT_SUCCESS
            LCALL NEW_ROUND
            RET
HK_NOT_SUCCESS:
            CJNE A, #ST_FAIL, HK_DONE
            LCALL NEW_ROUND
HK_DONE:
            RET

HANDLE_MODE_KEY:
            MOV A, game_state
            CJNE A, #ST_IDLE, HMK_NOT_IDLE
            SJMP HMK_TOGGLE
HMK_NOT_IDLE:
            CJNE A, #ST_SUCCESS, HMK_NOT_SUCCESS
            SJMP HMK_TOGGLE
HMK_NOT_SUCCESS:
            CJNE A, #ST_FAIL, HMK_DONE
HMK_TOGGLE:
            MOV A, game_mode
            XRL A, #01H
            MOV game_mode, A
            MOV game_state, #ST_IDLE
            MOV timing_flag, #00H
            MOV wait_tick, #00H
            MOV wait_hi, #00H
            MOV led_pattern, #0FFH
            LCALL LED_WRITE_A
            MOV beep_count, #BEEP_SHORT
            LCALL WAIT_MATRIX_RELEASE
HMK_DONE:
            RET

HANDLE_DIFFICULTY_KEY:
            MOV A, game_mode
            CJNE A, #MODE_RHYTHM, HDK_DONE
            MOV A, game_state
            CJNE A, #ST_IDLE, HDK_NOT_IDLE
            SJMP HDK_CHECK_KEY
HDK_NOT_IDLE:
            CJNE A, #ST_SUCCESS, HDK_NOT_SUCCESS
            SJMP HDK_CHECK_KEY
HDK_NOT_SUCCESS:
            CJNE A, #ST_FAIL, HDK_DONE
HDK_CHECK_KEY:
            MOV A, key_value
            CJNE A, #0AH, HDK_NOT_LOW
            MOV rhythm_diff, #DIFF_LOW
            SJMP HDK_SET_DONE
HDK_NOT_LOW:
            CJNE A, #0BH, HDK_NOT_MID
            MOV rhythm_diff, #DIFF_MID
            SJMP HDK_SET_DONE
HDK_NOT_MID:
            CJNE A, #0CH, HDK_DONE
            MOV rhythm_diff, #DIFF_HIGH
HDK_SET_DONE:
            MOV game_state, #ST_IDLE
            MOV rhythm_score, #00H
            MOV led_pattern, #0FFH
            LCALL LED_WRITE_A
            MOV beep_count, #BEEP_SHORT
            LCALL WAIT_MATRIX_RELEASE
HDK_DONE:
            RET

NEW_ROUND:
            MOV A, game_mode
            CJNE A, #MODE_RHYTHM, NEW_REACTION_ROUND
            LCALL NEW_RHYTHM_ROUND
            RET

NEW_REACTION_ROUND:
            LCALL MAKE_RANDOM
            ; Random wait is about 1..2 seconds.
            ; Base = 1000 ms = 03E8H. Add rand_seed four times:
            ; 03E8H + 0..1020 ms = about 1.0..2.02 s.
            MOV wait_hi, #03H
            MOV wait_tick, #0E8H
            MOV R7, #04H
NR_WAIT_ADD:
            MOV A, wait_tick
            ADD A, rand_seed
            MOV wait_tick, A
            JNC NR_WAIT_NO_CARRY
            INC wait_hi
NR_WAIT_NO_CARRY:
            DJNZ R7, NR_WAIT_ADD
            MOV disp3, #SEG_DASH_IDX
            MOV disp2, #SEG_DASH_IDX
            MOV disp1, #SEG_DASH_IDX
            MOV disp0, #SEG_DASH_IDX
            MOV game_state, #ST_WAIT
            MOV timing_flag, #00H
            MOV beep_count, #BEEP_SHORT
            LCALL UART_SEND_START
            RET

NEW_RHYTHM_ROUND:
            LCALL MAKE_RANDOM
            MOV A, rand_seed
            ANL A, #07H
            MOV rhythm_target, A
            LCALL LOAD_RHYTHM_PATTERNS
            MOV rhythm_score, #00H
            MOV A, rhythm_diff
            CJNE A, #DIFF_LOW, NRR_NOT_LOW
            MOV rhythm_tick, #220
            SJMP NRR_SPEED_DONE
NRR_NOT_LOW:
            CJNE A, #DIFF_HIGH, NRR_NORMAL_SPEED
            MOV rhythm_tick, #90
            SJMP NRR_SPEED_DONE
NRR_NORMAL_SPEED:
            MOV rhythm_tick, #160
NRR_SPEED_DONE:
            MOV led_pattern, #0FEH
            MOV timing_flag, #00H
            MOV wait_tick, #00H
            MOV wait_hi, #00H
            LCALL LED_WRITE_A
            LCALL SHOW_RHYTHM_SCORE
            MOV game_state, #ST_PLAY
            MOV beep_count, #BEEP_SHORT
            LCALL UART_SEND_START
            RET

STATE_WAIT:
            MOV disp3, #SEG_DASH_IDX
            MOV disp2, #SEG_DASH_IDX
            MOV disp1, #SEG_DASH_IDX
            MOV disp0, #SEG_DASH_IDX
            ; A key pressed before target appears is a false start.
            MOV A, key_value
            CJNE A, #KEY_NONE, WAIT_FALSE_START
            MOV A, wait_tick
            ORL A, wait_hi
            JZ WAIT_DONE
            RET
WAIT_FALSE_START:
            MOV game_state, #ST_FAIL
            MOV beep_count, #BEEP_LONG
            RET
WAIT_DONE:
            MOV game_state, #ST_SHOW
            RET

STATE_SHOW:
            LCALL MAKE_RANDOM
            MOV A, rand_seed
            ANL A, #0FH              ; raw random value 0..15
            CLR C
            SUBB A, #0AH             ; only use digit targets 0..9
            JNC SHOW_TARGET_DIGIT_OK ; 10..15 are mapped to 0..5
            ADD A, #0AH              ; restore 0..9 when borrow happened
SHOW_TARGET_DIGIT_OK:
            MOV target_key, A
            MOV disp3, #SEG_BLANK_IDX
            MOV disp2, #SEG_BLANK_IDX
            MOV disp1, #SEG_BLANK_IDX
            MOV disp0, target_key
            CLR EA                   ; keep visible edge and timer start together
            MOV scan_digit, #00H
            LCALL DISPLAY_SCAN       ; drive target digit pins before timing starts
            CLR TR2                  ; restart 1 ms Timer2 at the visible target edge
            MOV TMR2L, #TIMER0_RELOAD_L
            MOV TMR2H, #TIMER0_RELOAD_H
            CLR TF2L
            CLR TF2H
            MOV react_lo, #00H
            MOV react_hi, #00H
            MOV timing_flag, #01H
            SETB TR2
            SETB EA
            MOV beep_count, #BEEP_SHORT
            MOV led_pattern, #07FH
            LCALL LED_WRITE_A
            MOV game_state, #ST_PLAY
            RET

STATE_PLAY:
            MOV A, game_mode
            CJNE A, #MODE_RHYTHM, STATE_REACTION_PLAY
            LCALL STATE_RHYTHM_PLAY
            RET

STATE_REACTION_PLAY:
            ; Fixed timeout: about 1800ms.
            MOV A, react_hi
            CJNE A, #07H, PLAY_READ_KEY
            MOV A, react_lo
            CLR C
            SUBB A, #008H           ; 7*256+8=1800
            JNC PLAY_TIMEOUT

PLAY_READ_KEY:
            MOV A, key_value
            CJNE A, #KEY_NONE, PLAY_HAS_KEY
            RET
PLAY_HAS_KEY:
            ; Capture reaction time immediately at the first detected press.
            ; Then debounce-confirm the same key. The displayed time remains
            ; the first-detection time, not the post-debounce time.
            MOV last_key, A
            CLR ET2
            MOV score_lo, react_lo
            MOV score_hi, react_hi
            SETB ET2
            LCALL DEBOUNCE_DELAY
            LCALL SCAN_KEY_RAW
            CJNE A, last_key, PLAY_DEBOUNCE_REJECT
            MOV timing_flag, #00H
            MOV A, last_key
            CJNE A, target_key, PLAY_WRONG
            LCALL UPDATE_BEST
            LCALL SHOW_REACTION_TIME
            MOV beep_count, #BEEP_SHORT
            MOV game_state, #ST_SUCCESS
            MOV show_timer, #160
            LCALL UART_SEND_SCORE
            RET
PLAY_DEBOUNCE_REJECT:
            RET
PLAY_WRONG:
PLAY_TIMEOUT:
            MOV timing_flag, #00H
            MOV game_state, #ST_FAIL
            MOV show_timer, #120
            MOV beep_count, #BEEP_LONG
            LCALL UART_SEND_FAIL
            RET

STATE_RHYTHM_PLAY:
            MOV A, key_value
            CJNE A, #KEY_NONE, RHYTHM_HAS_KEY
            RET
RHYTHM_HAS_KEY:
            MOV last_key, A
            LCALL DEBOUNCE_DELAY
            LCALL SCAN_KEY_RAW
            CJNE A, last_key, RHYTHM_DEBOUNCE_REJECT
            MOV A, last_key
            CJNE A, #00H, RHYTHM_WRONG
            MOV A, led_pattern
            CJNE A, rhythm_pat, RHYTHM_WRONG
RHYTHM_HIT:
            INC rhythm_score
            LCALL SHOW_RHYTHM_SCORE
            MOV beep_count, #BEEP_SHORT
            LCALL WAIT_MATRIX_RELEASE
            MOV A, rhythm_score
            CLR C
            SUBB A, #20
            JC RHYTHM_CONTINUE
            MOV game_state, #ST_SUCCESS
            MOV led_pattern, #00H
            LCALL LED_WRITE_A
            RET
RHYTHM_CONTINUE:
            RET
RHYTHM_DEBOUNCE_REJECT:
            RET
RHYTHM_WRONG:
            MOV game_state, #ST_FAIL
            MOV beep_count, #BEEP_LONG
            LCALL UART_SEND_FAIL
            RET

STATE_SUCCESS:
            MOV led_pattern, #00H    ; all LEDs on, active-low
            LCALL LED_WRITE_A
            RET

STATE_FAIL:
            MOV disp3, #0FH          ; F
            MOV disp2, #0EH          ; E
            MOV disp1, #SEG_R_IDX    ; r
            MOV disp0, #SEG_R_IDX    ; r
            MOV led_pattern, #0FFH
            LCALL LED_WRITE_A
            RET
