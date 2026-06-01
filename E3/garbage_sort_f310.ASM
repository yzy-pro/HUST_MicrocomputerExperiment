$include (inc/C8051F310.INC)

; Recyclable garbage sorting system for C8051F310.
; Pure A51/Keil-style assembly source.
;
; Default GPIO mapping used by this file:
;   P0       segment data, low-active common-anode table
;   P2.0-3   digit select, low-active
;   P2.7     buzzer, low-active
;   P1       D1-D8 remaining-time progress bar, low-active
;   P3.2     Kint / INT0, falling-edge early close
;   P3.4-7   F1-F4 keys, low-active
;
; If your board uses the matrix keypad in the photo, only SCAN_KEYS and the
; KEY_Fx bit aliases need to be changed. The state machine is independent.

;------------------------------------------------------------------------------
; Internal RAM
;------------------------------------------------------------------------------
BIN0        DATA 30H
BIN1        DATA 31H
BIN2        DATA 32H
BIN3        DATA 33H

DISP0       DATA 34H
DISP1       DATA 35H
DISP2       DATA 36H
DISP3       DATA 37H

ACTIVE_BIN  DATA 38H       ; FFH=no open cover, 0..3=active bin
MODE        DATA 39H       ; 0 idle, 1 open, 2 beep/full/error
SCAN_IDX    DATA 3AH
KEY_LAST    DATA 3BH
KEY_NOW     DATA 3CH
KEY_EVENT   DATA 3DH
KEY_CODE    DATA 3EH       ; 0..3 F1-F4, FFH none
RAND_SEED   DATA 3FH

MS_L        DATA 40H
MS_H        DATA 41H
FLASH_CNT   DATA 42H       ; 0..99, toggle every 100ms
FLASH_FLAG  DATA 43H
ONESEC_CNT  DATA 44H

TMP0        DATA 45H
TMP1        DATA 46H
TMP2        DATA 47H

;------------------------------------------------------------------------------
; Constants and bit aliases
;------------------------------------------------------------------------------
MODE_IDLE   EQU 00H
MODE_OPEN   EQU 01H
MODE_BEEP   EQU 02H
NO_BIN      EQU 0FFH
KEY_NONE    EQU 0FFH

BEEP_ON     EQU 07FH       ; P2.7 low, digit-select lines high
BEEP_SCAN_H EQU 070H       ; keep P2.7 low while scanning
QUIET_SCAN_H EQU 0F0H

; C8051F310 internal oscillator 24.5MHz, Timer0 uses SYSCLK/12.
; 24500000/12/1000 = 2041.67 counts, reload = 65536-2042 = F806H.
T0_RELOAD_H EQU 0F8H
T0_RELOAD_L EQU 006H

KEY_F1      BIT P3.4
KEY_F2      BIT P3.5
KEY_F3      BIT P3.6
KEY_F4      BIT P3.7

;------------------------------------------------------------------------------
; Interrupt vectors
;------------------------------------------------------------------------------
            ORG 0000H
            LJMP START

            ORG 0003H
            LJMP KINT_ISR

            ORG 000BH
            LJMP TIMER0_ISR

;------------------------------------------------------------------------------
; Main program
;------------------------------------------------------------------------------
            ORG 0100H
START:
            MOV  SP,#5FH
            LCALL INIT_DEVICE
            LCALL INIT_RAM

            MOV  RAND_SEED,#05AH

            MOV  TMOD,#01H          ; Timer0 mode 1, 16-bit timer
            MOV  CKCON,#00H         ; Timer0 clock = SYSCLK / 12
            LCALL T0_RELOAD_1MS
            SETB TR0                ; start early to stir random seed

            LCALL INIT_BINS
            LCALL CLOSE_COVER

            SETB IT0                ; INT0 falling edge
            CLR  IE0
            MOV  IE,#083H           ; EA + ET0 + EX0

MAIN_LOOP:
            LCALL SCAN_KEYS
            MOV  A,KEY_EVENT
            JZ   MAIN_LOOP
            MOV  A,KEY_CODE
            CJNE A,#KEY_NONE,HANDLE_KEY
            SJMP MAIN_LOOP

HANDLE_KEY:
            MOV  TMP0,A
            MOV  A,TMP0
            LCALL HANDLE_BIN_KEY
            SJMP MAIN_LOOP

;------------------------------------------------------------------------------
; Initialization
;------------------------------------------------------------------------------
INIT_RAM:
            MOV  P0,#0FFH
            MOV  P1,#0FFH
            MOV  P2,#0FFH
            MOV  P3,#0FFH
            MOV  KEY_LAST,#KEY_NONE
            MOV  KEY_NOW,#KEY_NONE
            MOV  KEY_EVENT,#00H
            MOV  KEY_CODE,#KEY_NONE
            MOV  SCAN_IDX,#00H
            RET

; Generate four capacities in range 0..9.
INIT_BINS:
            MOV  R0,#BIN0
            MOV  R7,#04H
INIT_BIN_LOOP:
            MOV  A,RAND_SEED
            RL   A
            XRL  A,#039H
            ADD  A,TL0
            MOV  RAND_SEED,A
            ANL  A,#00FH
            MOV  TMP0,A
            CLR  C
            SUBB A,#00AH
            JC   INIT_LT_10
            MOV  TMP0,A
INIT_LT_10:
            MOV  A,TMP0
            MOV  @R0,A
            INC  R0
            DJNZ R7,INIT_BIN_LOOP
            LCALL UPDATE_ALL_DISPLAY
            RET

;------------------------------------------------------------------------------
; Key and bin state handling
;------------------------------------------------------------------------------
HANDLE_BIN_KEY:
            MOV  TMP0,A
            MOV  A,MODE
            CJNE A,#MODE_OPEN,CLOSED_BIN_KEY

            MOV  A,TMP0
            CJNE A,ACTIVE_BIN,IGNORE_BIN_KEY
            MOV  A,#01H
            LCALL DEPOSIT_MANY
IGNORE_BIN_KEY:
            RET

CLOSED_BIN_KEY:
            MOV  A,MODE
            JZ   TRY_OPEN_BIN
            RET

TRY_OPEN_BIN:
            MOV  A,TMP0
            LCALL READ_BIN_BY_A
            JZ   BIN_FULL_REFUSE
            MOV  A,TMP0
            LCALL OPEN_COVER
            RET

BIN_FULL_REFUSE:
            MOV  A,TMP0
            LCALL SHOW_FULL
            LCALL START_BEEP_1S
            RET

; Input A = number of bags. Basic mode uses A=1 when pressing the same F key.
DEPOSIT_MANY:
            MOV  TMP1,A
            MOV  A,MODE
            CJNE A,#MODE_OPEN,DEPOSIT_IGNORE
            MOV  A,ACTIVE_BIN
            CJNE A,#NO_BIN,DEPOSIT_ACTIVE
DEPOSIT_IGNORE:
            RET

DEPOSIT_ACTIVE:
            LCALL READ_BIN_BY_A
            MOV  TMP2,A
            CLR  C
            SUBB A,TMP1
            JC   DEPOSIT_FULL

            MOV  A,TMP2
            CLR  C
            SUBB A,TMP1
            MOV  TMP2,A
            MOV  A,ACTIVE_BIN
            LCALL WRITE_BIN_BY_A
            LCALL UPDATE_ALL_DISPLAY
            RET

DEPOSIT_FULL:
            MOV  A,ACTIVE_BIN
            LCALL SHOW_FULL
            LCALL START_BEEP_1S
            RET

OPEN_COVER:
            MOV  ACTIVE_BIN,A
            MOV  MODE,#MODE_OPEN
            MOV  MS_L,#00H
            MOV  MS_H,#00H
            MOV  FLASH_CNT,#00H
            MOV  FLASH_FLAG,#01H
            MOV  ONESEC_CNT,#00H
            MOV  P1,#00H            ; D1-D8 all on: 8s remaining
            LCALL UPDATE_ALL_DISPLAY
            RET

CLOSE_COVER:
            MOV  ACTIVE_BIN,#NO_BIN
            MOV  MODE,#MODE_IDLE
            MOV  MS_L,#00H
            MOV  MS_H,#00H
            MOV  FLASH_CNT,#00H
            MOV  FLASH_FLAG,#01H
            MOV  ONESEC_CNT,#00H
            MOV  P1,#0FFH
            MOV  P2,#0FFH
            LCALL UPDATE_ALL_DISPLAY
            RET

SHOW_FULL:
            MOV  TMP0,A
            LCALL UPDATE_ALL_DISPLAY
            MOV  A,#0FH             ; F
            LCALL WRITE_DISP_BY_TMP0
            RET

SHOW_ERROR:
            MOV  TMP0,A
            LCALL UPDATE_ALL_DISPLAY
            MOV  A,#0EH             ; E, reserved for optional extension
            LCALL WRITE_DISP_BY_TMP0
            RET

START_BEEP_1S:
            MOV  MODE,#MODE_BEEP
            MOV  MS_L,#00H
            MOV  MS_H,#00H
            MOV  P2,#BEEP_ON
            RET

;------------------------------------------------------------------------------
; Data helpers
;------------------------------------------------------------------------------
READ_BIN_BY_A:
            ADD  A,#BIN0
            MOV  R0,A
            MOV  A,@R0
            RET

WRITE_BIN_BY_A:
            ADD  A,#BIN0
            MOV  R0,A
            MOV  A,TMP2
            MOV  @R0,A
            RET

WRITE_DISP_BY_TMP0:
            MOV  TMP1,A
            MOV  A,TMP0
            ADD  A,#DISP0
            MOV  R0,A
            MOV  A,TMP1
            MOV  @R0,A
            RET

UPDATE_ALL_DISPLAY:
            MOV  DISP0,BIN0
            MOV  DISP1,BIN1
            MOV  DISP2,BIN2
            MOV  DISP3,BIN3
            RET

;------------------------------------------------------------------------------
; Key scan with edge detection
;------------------------------------------------------------------------------
SCAN_KEYS:
            MOV  KEY_EVENT,#00H
            MOV  KEY_CODE,#KEY_NONE

            JNB  KEY_F1,KEY_F1_DOWN
            SJMP KEY_NOT_F1
KEY_F1_DOWN:
            MOV  KEY_NOW,#00H
            SJMP KEY_DECIDE

KEY_NOT_F1:
            JNB  KEY_F2,KEY_F2_DOWN
            SJMP KEY_NOT_F2
KEY_F2_DOWN:
            MOV  KEY_NOW,#01H
            SJMP KEY_DECIDE

KEY_NOT_F2:
            JNB  KEY_F3,KEY_F3_DOWN
            SJMP KEY_NOT_F3
KEY_F3_DOWN:
            MOV  KEY_NOW,#02H
            SJMP KEY_DECIDE

KEY_NOT_F3:
            JNB  KEY_F4,KEY_F4_DOWN
            SJMP KEY_NONE_DOWN
KEY_F4_DOWN:
            MOV  KEY_NOW,#03H
            SJMP KEY_DECIDE

KEY_NONE_DOWN:
            MOV  KEY_NOW,#KEY_NONE

KEY_DECIDE:
            MOV  A,KEY_NOW
            CJNE A,KEY_LAST,KEY_CHANGED
            RET

KEY_CHANGED:
            MOV  KEY_LAST,A
            CJNE A,#KEY_NONE,KEY_PRESSED
            RET

KEY_PRESSED:
            MOV  KEY_CODE,A
            MOV  KEY_EVENT,#01H
            LCALL DELAY_20MS
            RET

DELAY_20MS:
            MOV  R6,#028H
D20_OUTER:
            MOV  R7,#0F8H
D20_INNER:
            DJNZ R7,D20_INNER
            DJNZ R6,D20_OUTER
            RET

;------------------------------------------------------------------------------
; Interrupt service routines
;------------------------------------------------------------------------------
TIMER0_ISR:
            PUSH ACC
            PUSH PSW
            PUSH B
            PUSH DPL
            PUSH DPH
            PUSH 00H
            PUSH 01H
            PUSH 07H

            LCALL T0_RELOAD_1MS
            LCALL SCAN_DISPLAY
            LCALL TICK_STATE

            POP  07H
            POP  01H
            POP  00H
            POP  DPH
            POP  DPL
            POP  B
            POP  PSW
            POP  ACC
            RETI

KINT_ISR:
            PUSH ACC
            PUSH PSW
            MOV  A,MODE
            CJNE A,#MODE_OPEN,KINT_EXIT
            LCALL CLOSE_COVER
KINT_EXIT:
            POP  PSW
            POP  ACC
            RETI

TICK_STATE:
            MOV  A,MODE
            CJNE A,#MODE_OPEN,TICK_NOT_OPEN

            INC  MS_L
            MOV  A,MS_L
            JNZ  OPEN_MS_OK
            INC  MS_H
OPEN_MS_OK:
            INC  FLASH_CNT
            MOV  A,FLASH_CNT
            CJNE A,#064H,OPEN_NOT_100MS
            MOV  FLASH_CNT,#00H
            MOV  A,FLASH_FLAG
            XRL  A,#01H
            MOV  FLASH_FLAG,A

OPEN_NOT_100MS:
            MOV  A,MS_L
            CJNE A,#0E8H,OPEN_NOT_SECOND
            MOV  A,MS_H
            CJNE A,#03H,OPEN_NOT_SECOND
            MOV  MS_L,#00H
            MOV  MS_H,#00H
            INC  ONESEC_CNT
            LCALL UPDATE_PROGRESS_LED
            MOV  A,ONESEC_CNT
            CJNE A,#08H,OPEN_TICK_DONE
            LCALL CLOSE_COVER
OPEN_TICK_DONE:
            RET
OPEN_NOT_SECOND:
            RET

TICK_NOT_OPEN:
            CJNE A,#MODE_BEEP,TICK_DONE
            INC  MS_L
            MOV  A,MS_L
            JNZ  BEEP_MS_OK
            INC  MS_H
BEEP_MS_OK:
            MOV  A,MS_L
            CJNE A,#0E8H,TICK_DONE
            MOV  A,MS_H
            CJNE A,#03H,TICK_DONE
            LCALL CLOSE_COVER
TICK_DONE:
            RET

T0_RELOAD_1MS:
            MOV  TH0,#T0_RELOAD_H
            MOV  TL0,#T0_RELOAD_L
            RET

;------------------------------------------------------------------------------
; Display and progress output
;------------------------------------------------------------------------------
UPDATE_PROGRESS_LED:
            MOV  A,ONESEC_CNT
            MOV  DPTR,#PROGRESS_TABLE
            MOVC A,@A+DPTR
            MOV  P1,A
            RET

SCAN_DISPLAY:
            LCALL GET_P2_SCAN_HIGH
            ORL  A,#00FH
            MOV  P2,A

            MOV  A,SCAN_IDX
            ADD  A,#DISP0
            MOV  R0,A
            MOV  A,@R0
            MOV  B,A

            MOV  A,MODE
            CJNE A,#MODE_OPEN,DISPLAY_NO_BLINK
            MOV  A,SCAN_IDX
            CJNE A,ACTIVE_BIN,DISPLAY_NO_BLINK
            MOV  A,FLASH_FLAG
            JNZ  DISPLAY_LIT
            MOV  A,#0FFH
            SJMP DISPLAY_WRITE_SEG

DISPLAY_LIT:
DISPLAY_NO_BLINK:
            MOV  A,B
            MOV  DPTR,#SEG_TABLE
            MOVC A,@A+DPTR

DISPLAY_WRITE_SEG:
            MOV  P0,A
            MOV  A,SCAN_IDX
            MOV  DPTR,#DIGIT_SELECT_TABLE
            MOVC A,@A+DPTR
            MOV  R7,A
            LCALL GET_P2_SCAN_HIGH
            ORL  A,R7
            MOV  P2,A

            INC  SCAN_IDX
            MOV  A,SCAN_IDX
            CJNE A,#04H,DISPLAY_DONE
            MOV  SCAN_IDX,#00H
DISPLAY_DONE:
            RET

GET_P2_SCAN_HIGH:
            MOV  A,MODE
            CJNE A,#MODE_BEEP,P2_QUIET_HIGH
            MOV  A,#BEEP_SCAN_H
            RET
P2_QUIET_HIGH:
            MOV  A,#QUIET_SCAN_H
            RET

PROGRESS_TABLE:
            DB   00H,01H,03H,07H,0FH,1FH,3FH,7FH,0FFH

; Low-active common-anode 7-segment codes: 0..9,A,b,C,d,E,F
SEG_TABLE:
            DB   0C0H,0F9H,0A4H,0B0H,099H,092H,082H,0F8H
            DB   080H,090H,088H,083H,0C6H,0A1H,086H,08EH

DIGIT_SELECT_TABLE:
            DB   0FEH,0FDH,0FBH,0F7H

;------------------------------------------------------------------------------
; C8051F310 hardware initialization
;------------------------------------------------------------------------------
PCA_INIT:
            ANL  PCA0MD,#0BFH       ; disable watchdog enable bit first
            MOV  PCA0MD,#000H       ; watchdog off
            RET

OSCILLATOR_INIT:
            MOV  OSCICN,#083H       ; internal HF oscillator, divide by 1
            MOV  CLKSEL,#000H       ; SYSCLK from internal oscillator
            RET

PORT_IO_INIT:
            MOV  P0MDOUT,#0FFH      ; segments
            MOV  P1MDOUT,#0FFH      ; progress LEDs
            MOV  P2MDOUT,#08FH      ; digit selects + buzzer
            MOV  P3MDOUT,#000H      ; keys as open-drain inputs
            MOV  P3,#0FFH
            MOV  XBR1,#040H         ; enable crossbar and weak pullups
            RET

INIT_DEVICE:
            LCALL PCA_INIT
            LCALL OSCILLATOR_INIT
            LCALL PORT_IO_INIT
            RET

            END
