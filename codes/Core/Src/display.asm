;-------------------------------------------------------------------------------
; display.asm - 4-digit seven-segment display routines
;-------------------------------------------------------------------------------
CLEAR_DISPLAY:
            MOV disp0, #SEG_BLANK_IDX
            MOV disp1, #SEG_BLANK_IDX
            MOV disp2, #SEG_BLANK_IDX
            MOV disp3, #SEG_BLANK_IDX
            RET

DISPLAY_SCAN:
            MOV A, scan_digit
            ANL A, #03H
            MOV scan_digit, A
            JZ DISP_D0
            CJNE A, #01H, DISP_NOT_D1
            MOV A, disp1
            LCALL LOAD_SEG_CODE
            MOV P1, A
            ANL P0, #03FH
            ORL P0, #040H            ; A=1,B=0 -> digit 1
            SJMP DISP_NEXT
DISP_NOT_D1:
            CJNE A, #02H, DISP_D3
            MOV A, disp2
            LCALL LOAD_SEG_CODE
            MOV P1, A
            ANL P0, #03FH
            ORL P0, #080H            ; A=0,B=1 -> digit 2
            SJMP DISP_NEXT
DISP_D3:
            MOV A, disp3
            LCALL LOAD_SEG_CODE
            MOV P1, A
            ANL P0, #03FH
            ORL P0, #0C0H            ; A=1,B=1 -> digit 3
            SJMP DISP_NEXT
DISP_D0:
            MOV A, disp0
            LCALL LOAD_SEG_CODE
            MOV P1, A
            ANL P0, #03FH            ; A=0,B=0 -> digit 0
DISP_NEXT:
            INC scan_digit
            RET

LOAD_SEG_CODE:
            ANL A, #1FH
            MOV DPTR, #SEG_TABLE
            MOVC A, @A+DPTR
            RET

SHOW_REACTION_TIME:
            ; Convert full 16-bit reaction time in score_hi:score_lo to 4 decimal digits.
            ; This avoids the old low-byte-only display error for times above 255ms.
            LCALL BIN16_TO_BCD4
            MOV disp0, bcd_ones
            MOV disp1, bcd_tens
            MOV disp2, bcd_hund
            MOV disp3, bcd_thou
            RET

LOAD_RHYTHM_PATTERNS:
            MOV A, rhythm_target
            LCALL LOAD_RHYTHM_LED_PATTERN
            MOV rhythm_pat, A
            RET

LOAD_RHYTHM_LED_PATTERN:
            ANL A, #07H
            MOV DPTR, #RHYTHM_LED_TABLE
            MOVC A, @A+DPTR
            RET

SHOW_RHYTHM_SCORE:
            MOV disp3, #SEG_L_IDX
            MOV A, rhythm_target
            INC A
            MOV disp2, A
            MOV bcd_tens, #00H
            MOV A, rhythm_score
            MOV bcd_ones, A
SRS_TENS_LOOP:
            MOV A, bcd_ones
            CLR C
            SUBB A, #10
            JC SRS_DONE
            MOV bcd_ones, A
            INC bcd_tens
            SJMP SRS_TENS_LOOP
SRS_DONE:
            MOV disp1, bcd_tens
            MOV disp0, bcd_ones
            RET

BIN16_TO_BCD4:
            MOV bcd_thou, #00H
            MOV bcd_hund, #00H
            MOV bcd_tens, #00H
            MOV bcd_ones, #00H
            MOV conv_lo, score_lo
            MOV conv_hi, score_hi
BCD_1000_LOOP:
            CLR C
            MOV A, conv_lo
            SUBB A, #0E8H
            MOV R0, A
            MOV A, conv_hi
            SUBB A, #03H
            JC BCD_100_LOOP
            MOV conv_hi, A
            MOV conv_lo, R0
            INC bcd_thou
            SJMP BCD_1000_LOOP
BCD_100_LOOP:
            MOV A, conv_lo
            MOV bcd_ones, A
BCD_H_LOOP:
            MOV A, bcd_ones
            CLR C
            SUBB A, #100
            JC BCD_T_LOOP
            MOV bcd_ones, A
            INC bcd_hund
            SJMP BCD_H_LOOP
BCD_T_LOOP:
            MOV A, bcd_ones
            CLR C
            SUBB A, #10
            JC BCD_DONE
            MOV bcd_ones, A
            INC bcd_tens
            SJMP BCD_T_LOOP
BCD_DONE:
            RET
