;-------------------------------------------------------------------------------
; main.asm - main loop dispatcher
;-------------------------------------------------------------------------------
MAIN_LOOP:
            LCALL SCAN_KINT
            MOV kint_value, A
            JZ MAIN_NO_KINT
            LCALL HANDLE_KINT

MAIN_NO_KINT:
            MOV A, game_state
            CJNE A, #ST_PLAY, MAIN_SCAN_DEBOUNCED
            LCALL SCAN_KEY_RAW       ; in play state, capture the first key edge quickly
            SJMP MAIN_KEY_SCANNED
MAIN_SCAN_DEBOUNCED:
            LCALL SCAN_KEY
MAIN_KEY_SCANNED:
            MOV key_value, A
            MOV A, key_value
            CJNE A, #KEY_NONE, MAIN_HAS_MATRIX_KEY
            SJMP MAIN_NO_FUNC_KEY

MAIN_HAS_MATRIX_KEY:
            CJNE A, #0FH, MAIN_CHECK_DIFF_KEY
            LCALL HANDLE_MODE_KEY
            SJMP MAIN_NO_FUNC_KEY

MAIN_CHECK_DIFF_KEY:
            LCALL HANDLE_DIFFICULTY_KEY

MAIN_NO_FUNC_KEY:
            MOV A, game_state
            CJNE A, #ST_IDLE, MAIN_NOT_IDLE
            LCALL STATE_IDLE
            SJMP MAIN_LOOP

MAIN_NOT_IDLE:
            CJNE A, #ST_WAIT, MAIN_NOT_WAIT
            LCALL STATE_WAIT
            SJMP MAIN_LOOP

MAIN_NOT_WAIT:
            CJNE A, #ST_SHOW, MAIN_NOT_SHOW
            LCALL STATE_SHOW
            SJMP MAIN_LOOP

MAIN_NOT_SHOW:
            CJNE A, #ST_PLAY, MAIN_NOT_PLAY
            LCALL STATE_PLAY
            SJMP MAIN_LOOP

MAIN_NOT_PLAY:
            CJNE A, #ST_SUCCESS, MAIN_NOT_SUCCESS
            LCALL STATE_SUCCESS
            SJMP MAIN_LOOP

MAIN_NOT_SUCCESS:
            CJNE A, #ST_FAIL, MAIN_LOOP
            LCALL STATE_FAIL
            SJMP MAIN_LOOP
