;-------------------------------------------------------------------------------
; keypad.asm - matrix keypad and KINT scanning
;-------------------------------------------------------------------------------
SCAN_KEY:
            LCALL SCAN_KEY_RAW
            CJNE A, #KEY_NONE, SK_DEBOUNCE
            RET
SK_DEBOUNCE:
            MOV last_key, A
            LCALL DEBOUNCE_DELAY
            LCALL SCAN_KEY_RAW
            CJNE A, last_key, SK_NONE
            RET
SK_NONE:
            MOV A, #KEY_NONE
            RET

SCAN_KEY_RAW:
            MOV R4, #00H             ; row index
            MOV R5, #0FEH            ; active low row pattern
SCAN_ROW_LOOP:
            MOV A, R5
            ORL A, #0F0H
            MOV P2, A
            NOP
            NOP
            MOV A, P2
            ANL A, #0F0H
            CJNE A, #0F0H, KEY_FOUND
            MOV A, R5
            RL A
            ORL A, #0F0H
            MOV R5, A
            INC R4
            CJNE R4, #04H, SCAN_ROW_LOOP
            MOV A, #KEY_NONE
            RET

KEY_FOUND:
            MOV R6, #00H             ; col index
            JNB P2.4, KEY_COL_DONE
            INC R6
            JNB P2.5, KEY_COL_DONE
            INC R6
            JNB P2.6, KEY_COL_DONE
            INC R6
            JNB P2.7, KEY_COL_DONE
            MOV A, #KEY_NONE
            RET
KEY_COL_DONE:
            MOV A, R6
            RL A
            RL A                     ; column * 4
            ADD A, R4
            RET

WAIT_MATRIX_RELEASE:
            LCALL SCAN_KEY_RAW
            CJNE A, #KEY_NONE, WAIT_MATRIX_RELEASE
            LCALL DEBOUNCE_DELAY
            RET

;-------------------------------------------------------------------------------
; KINT scanning with debounce
; KINT is on P0.1 and is low active.
; Returns A=01H once per stable press, or A=00H if no valid press.
; It also waits for release so one physical press cannot start multiple rounds.
;-------------------------------------------------------------------------------
SCAN_KINT:
            JB P0.1, KINT_NONE       ; high means not pressed
            LCALL DEBOUNCE_DELAY
            JB P0.1, KINT_NONE
KINT_WAIT_RELEASE:
            JNB P0.1, KINT_WAIT_RELEASE
            LCALL DEBOUNCE_DELAY
            MOV A, #01H
            RET
KINT_NONE:
            MOV A, #00H
            RET

DEBOUNCE_DELAY:
            MOV R2, #40
DB_D1:      MOV R3, #200
DB_D2:      DJNZ R3, DB_D2
            DJNZ R2, DB_D1
            RET
