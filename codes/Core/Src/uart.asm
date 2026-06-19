;-------------------------------------------------------------------------------
; uart.asm - UART output helpers
;-------------------------------------------------------------------------------
UART_PUTCHAR:
            JNB TI0, UART_PUTCHAR
            CLR TI0
            MOV SBUF0, A
UART_WAIT_SENT:
            JNB TI0, UART_WAIT_SENT
            RET

UART_SEND_CRLF:
            MOV A, #0DH
            LCALL UART_PUTCHAR
            MOV A, #0AH
            LCALL UART_PUTCHAR
            RET

UART_SEND_STRING:
            CLR A
            MOVC A, @A+DPTR
            JZ UART_STR_DONE
            LCALL UART_PUTCHAR
            INC DPTR
            SJMP UART_SEND_STRING
UART_STR_DONE:
            RET

UART_BANNER:
            MOV DPTR, #MSG_BANNER
            LCALL UART_SEND_STRING
            LCALL UART_SEND_CRLF
            RET

UART_SEND_START:
            MOV DPTR, #MSG_START
            LCALL UART_SEND_STRING
            LCALL UART_SEND_CRLF
            RET

UART_SEND_FAIL:
            MOV DPTR, #MSG_FAIL
            LCALL UART_SEND_STRING
            LCALL UART_SEND_CRLF
            RET

UART_SEND_SCORE:
            MOV DPTR, #MSG_SCORE
            LCALL UART_SEND_STRING
            MOV A, score_hi
            LCALL UART_SEND_HEX
            MOV A, score_lo
            LCALL UART_SEND_HEX
            MOV DPTR, #MSG_MS
            LCALL UART_SEND_STRING
            LCALL UART_SEND_CRLF
            RET

UART_SEND_HEX:
            MOV uart_temp, A
            SWAP A
            ANL A, #0FH
            LCALL UART_HEX_NIBBLE
            MOV A, uart_temp
            ANL A, #0FH
            LCALL UART_HEX_NIBBLE
            RET

UART_HEX_NIBBLE:
            ADD A, #030H
            CJNE A, #03AH, HEX_CHECK
HEX_CHECK:
            JC HEX_OUT
            ADD A, #07H
HEX_OUT:
            LCALL UART_PUTCHAR
            RET
