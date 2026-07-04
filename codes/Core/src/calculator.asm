;--------------------------------------------------------
; calculator.asm — 计算器模式状态机
;
; 正常模式下 K14/KF5 进入计算器模式。
; 计算器模式按键：
;   K0-K9      输入数字（每个操作数最多两位）
;   K10-K13    KF1-KF4，对应 + - * /
;   K14        KF5，Back
;   K15        KF6，等号
;   Kint       由 EXT0_ISR 处理，退出计算器模式
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module calculator

    .globl ENTER_CALC
    .globl CALC_HANDLE_KEY

    .globl SHIFT_LED_BAR

    .area CALC_CODE (CODE)

;--------------------------------------------------------
; ENTER_CALC — K14/KF5：进入计算器模式
;--------------------------------------------------------
ENTER_CALC:
    clr  EA
    mov  LIDOPEN, #0
    mov  SELBIN,  #0xFF
    mov  LIDLO,   #0
    mov  LIDHI,   #0
    mov  HINTLO,  #0
    mov  HINTHI,  #0
    setb EA

    clr  BUZZER
    setb D9_LED
    mov  FULLBIN, #0xFF
    mov  ERRBIN,  #0xFF
    mov  LEDREG,  #0xFF
    mov  LASTBAR, #0
    lcall SHIFT_LED_BAR

    mov  CALCMODE,  #1
    lcall CALC_RESET
    ret

;--------------------------------------------------------
; CALC_RESET — 清空计算器输入和显示缓存
;--------------------------------------------------------
CALC_RESET:
    mov  CALCSTATE, #0
    mov  CALCOP,    #0
    mov  OP1,       #0
    mov  OP2,       #0
    mov  DIGCNT,    #0
    mov  CALCNEG,   #0
    mov  RESLO,     #0
    mov  RESHI,     #0
    lcall CALC_CLEAR_DISP
    ret

CALC_CLEAR_DISP:
    mov  CALCD0, #0x0A
    mov  CALCD1, #0x0A
    mov  CALCD2, #0x0A
    mov  CALCD3, #0x0A
    ret

;--------------------------------------------------------
; CALC_HANDLE_KEY — 计算器模式按键分发
;--------------------------------------------------------
CALC_HANDLE_KEY:
    mov  A, KEYNOW
    cjne A, #14, CHK_EQ
    lcall CALC_BACK
    ret

CHK_EQ:
    cjne A, #15, CHK_DIGIT
    lcall CALC_EQUALS
    ret

CHK_DIGIT:
    clr  C
    subb A, #10
    jnc  CHK_OP
    lcall CALC_INPUT_DIGIT
    ret

CHK_OP:
    mov  A, KEYNOW
    clr  C
    subb A, #10
    mov  TMP, A
    clr  C
    subb A, #4
    jc   CHK_OP_OK
    ret
CHK_OP_OK:
    lcall CALC_INPUT_OP
    ret

;--------------------------------------------------------
; CALC_INPUT_DIGIT — 输入 0-9，单个操作数最多两位
;--------------------------------------------------------
CALC_INPUT_DIGIT:
    mov  A, CALCSTATE
    cjne A, #3, CID_NOT_RESULT
    lcall CALC_RESET        ; 结果后输入数字，开始下一轮
CID_NOT_RESULT:
    mov  A, CALCSTATE
    cjne A, #1, CID_HAVE_SIDE
    mov  CALCSTATE, #2
    mov  DIGCNT, #0
    mov  OP2, #0
    lcall CALC_CLEAR_DISP

CID_HAVE_SIDE:
    mov  A, DIGCNT
    cjne A, #2, CID_ROOM
    ret

CID_ROOM:
    mov  A, CALCSTATE
    cjne A, #2, CID_OP1
    mov  R0, #OP2
    sjmp CID_APPEND
CID_OP1:
    mov  R0, #OP1

CID_APPEND:
    mov  A, @R0
    mov  B, #10
    mul  AB
    add  A, KEYNOW
    mov  @R0, A
    inc  DIGCNT
    lcall CALC_SHOW_INPUT
    ret

;--------------------------------------------------------
; CALC_INPUT_OP — 输入 KF1-KF4 运算符
;   KF1=+，KF2=-，KF3=*，KF4=/
;--------------------------------------------------------
CALC_INPUT_OP:
    mov  A, CALCSTATE
    cjne A, #1, CIO_NEED_OP1
    sjmp CIO_SET
CIO_NEED_OP1:
    mov  A, CALCSTATE
    jnz  CIO_RET
    mov  A, DIGCNT
    jz   CIO_RET
CIO_SET:
    mov  A, TMP
    inc  A                  ; TMP 0-3 -> CALCOP 1-4
    mov  CALCOP, A
    mov  CALCSTATE, #1
    mov  DIGCNT, #0
    mov  OP2, #0
    lcall CALC_SHOW_OP
CIO_RET:
    ret

;--------------------------------------------------------
; CALC_BACK — KF5：退格/返回上一步
;--------------------------------------------------------
CALC_BACK:
    mov  A, CALCSTATE
    cjne A, #3, CB_NOT_RESULT
    lcall CALC_RESET
    ret

CB_NOT_RESULT:
    mov  A, CALCSTATE
    cjne A, #1, CB_NOT_OP
    mov  CALCSTATE, #0
    mov  A, OP1
    clr  C
    subb A, #10
    jc   CB_OP1_ONE
    mov  DIGCNT, #2
    sjmp CB_SHOW_OP1
CB_OP1_ONE:
    mov  DIGCNT, #1
CB_SHOW_OP1:
    lcall CALC_SHOW_INPUT
    ret

CB_NOT_OP:
    mov  A, DIGCNT
    jnz  CB_DEL_DIGIT
    mov  A, CALCSTATE
    cjne A, #2, CB_RET
    mov  CALCSTATE, #1
    lcall CALC_SHOW_OP
CB_RET:
    ret

CB_DEL_DIGIT:
    mov  A, CALCSTATE
    cjne A, #2, CB_DEL_OP1
    mov  R0, #OP2
    sjmp CB_DEL_DO
CB_DEL_OP1:
    mov  R0, #OP1
CB_DEL_DO:
    mov  A, @R0
    mov  B, #10
    div  AB
    mov  @R0, A
    dec  DIGCNT
    lcall CALC_SHOW_INPUT
    ret

;--------------------------------------------------------
; CALC_SHOW_INPUT — 右对齐显示当前操作数
;--------------------------------------------------------
CALC_SHOW_INPUT:
    lcall CALC_CLEAR_DISP
    mov  A, DIGCNT
    jnz  CSI_HAVE
    ret
CSI_HAVE:
    mov  A, CALCSTATE
    cjne A, #2, CSI_OP1
    mov  A, OP2
    sjmp CSI_SPLIT
CSI_OP1:
    mov  A, OP1
CSI_SPLIT:
    mov  B, #10
    div  AB                 ; A=十位，B=个位
    mov  R4, A
    mov  R5, B
    mov  A, DIGCNT
    cjne A, #1, CSI_TWO
    mov  CALCD3, R5
    ret
CSI_TWO:
    mov  CALCD2, R4
    mov  CALCD3, R5
    ret

;--------------------------------------------------------
; CALC_SHOW_OP — 运算符提示：KF1-KF4 对应第 1-4 位显示 8
;--------------------------------------------------------
CALC_SHOW_OP:
    lcall CALC_CLEAR_DISP
    mov  A, CALCOP
    cjne A, #1, CSO_SUB
    mov  CALCD0, #8
    ret
CSO_SUB:
    cjne A, #2, CSO_MUL
    mov  CALCD1, #8
    ret
CSO_MUL:
    cjne A, #3, CSO_DIV
    mov  CALCD2, #8
    ret
CSO_DIV:
    mov  CALCD3, #8
    ret

;--------------------------------------------------------
; CALC_EQUALS — KF6：计算并显示结果
;--------------------------------------------------------
CALC_EQUALS:
    mov  A, CALCSTATE
    cjne A, #2, CE_RET
    mov  A, DIGCNT
    jz   CE_RET

    mov  CALCSTATE, #3
    mov  CALCNEG, #0
    mov  RESHI, #0
    mov  RESLO, #0

    mov  A, CALCOP
    cjne A, #1, CE_SUB

    ; 加法：0-99 + 0-99
    mov  A, OP1
    add  A, OP2
    mov  RESLO, A
    mov  A, #0
    addc A, #0
    mov  RESHI, A
    lcall CALC_SHOW_RESULT
    ret

CE_SUB:
    cjne A, #2, CE_MUL
    mov  A, OP1
    clr  C
    subb A, OP2
    jc   CE_SUB_NEG
    mov  RESLO, A
    lcall CALC_SHOW_RESULT
    ret
CE_SUB_NEG:
    mov  CALCNEG, #1
    mov  A, OP2
    clr  C
    subb A, OP1
    mov  RESLO, A
    lcall CALC_SHOW_RESULT
    ret

CE_MUL:
    cjne A, #3, CE_DIV
    mov  A, OP1
    mov  B, OP2
    mul  AB
    mov  RESLO, A
    mov  RESHI, B
    lcall CALC_SHOW_RESULT
    ret

CE_DIV:
    mov  A, OP2
    jnz  CE_DIV_OK
    lcall CALC_SHOW_ERROR
    ret
CE_DIV_OK:
    mov  A, OP1
    mov  B, OP2
    div  AB                 ; A=商，B=余数
    mov  R4, A
    mov  R5, B
    lcall CALC_SHOW_DIV
CE_RET:
    ret

;--------------------------------------------------------
; CALC_SHOW_RESULT — 显示非除法结果，支持 -99..9801
;--------------------------------------------------------
CALC_SHOW_RESULT:
    lcall CALC_CLEAR_DISP
    mov  A, CALCNEG
    jz   CSR_POS

    mov  CALCD0, #0x0B
    mov  A, RESLO
    mov  B, #10
    div  AB
    mov  R4, A
    mov  R5, B
    mov  A, R4
    jz   CSR_NEG_ONE
    mov  CALCD2, R4
CSR_NEG_ONE:
    mov  CALCD3, R5
    ret

CSR_POS:
    mov  R4, #0             ; 千位
    mov  R5, #0             ; 百位
    mov  R6, #0             ; 十位

CSR_THOUS:
    mov  A, RESHI
    clr  C
    subb A, #0x03
    jc   CSR_HUNDS
    jnz  CSR_SUB_THOUS
    mov  A, RESLO
    clr  C
    subb A, #0xE8
    jc   CSR_HUNDS
CSR_SUB_THOUS:
    mov  A, RESLO
    clr  C
    subb A, #0xE8
    mov  RESLO, A
    mov  A, RESHI
    subb A, #0x03
    mov  RESHI, A
    inc  R4
    sjmp CSR_THOUS

CSR_HUNDS:
    mov  A, RESHI
    jnz  CSR_SUB_HUND
    mov  A, RESLO
    clr  C
    subb A, #100
    jc   CSR_TENS
CSR_SUB_HUND:
    mov  A, RESLO
    clr  C
    subb A, #100
    mov  RESLO, A
    mov  A, RESHI
    subb A, #0
    mov  RESHI, A
    inc  R5
    sjmp CSR_HUNDS

CSR_TENS:
    mov  A, RESLO
    clr  C
    subb A, #10
    jc   CSR_ONES
    mov  RESLO, A
    inc  R6
    sjmp CSR_TENS

CSR_ONES:
    mov  A, R4
    jz   CSR_HUND_DIG
    mov  CALCD0, R4
CSR_HUND_DIG:
    mov  A, R4
    orl  A, R5
    jz   CSR_TEN_DIG
    mov  CALCD1, R5
CSR_TEN_DIG:
    mov  A, R4
    orl  A, R5
    orl  A, R6
    jz   CSR_ONE_DIG
    mov  CALCD2, R6
CSR_ONE_DIG:
    mov  CALCD3, RESLO
    ret

;--------------------------------------------------------
; CALC_SHOW_DIV — 除法显示：前两位商，后两位余数
;--------------------------------------------------------
CALC_SHOW_DIV:
    mov  A, R4
    mov  B, #10
    div  AB
    mov  CALCD0, A
    mov  CALCD1, B
    mov  A, R5
    mov  B, #10
    div  AB
    mov  CALCD2, A
    mov  CALCD3, B
    ret

CALC_SHOW_ERROR:
    mov  CALCD0, #0x0C
    mov  CALCD1, #0x0C
    mov  CALCD2, #0x0C
    mov  CALCD3, #0x0C
    ret
