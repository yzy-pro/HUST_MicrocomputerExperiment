;-------------------------------------------------------------------------------
; tables.asm - ROM lookup tables and UART strings
;-------------------------------------------------------------------------------
RHYTHM_LED_TABLE:
            DB 0FEH,0FDH,0FBH,0F7H,0EFH,0DFH,0BFH,07FH

SEG_TABLE:
            DB 0FCH,060H,0DAH,0F2H,066H,0B6H,0BEH,0E0H
            DB 0FEH,0E6H,0EEH,03EH,09CH,07AH,09EH,08EH
            DB 000H,002H,00AH,01CH

MSG_BANNER:
            DB 'C8051F310 Reaction Game Ready',00H
MSG_START:
            DB 'START',00H
MSG_SCORE:
            DB 'SCORE HEX(ms)=',00H
MSG_MS:
            DB ' ms',00H
MSG_FAIL:
            DB 'FAIL',00H
