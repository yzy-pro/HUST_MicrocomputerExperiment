void main(void) __naked {
    __asm
        ; C8051F310EVM: 扫描4x4矩阵键盘, 在4位数码管显示按键名称
        ; 显示格式:
        ; 数字键 K0~K9 -> "  Kx"
        ; 功能键 KF1~KF6 -> " KFx"

        ; ===== SFR =====
PCA0MD  = 0xD9
P0MDOUT = 0xA4
P1MDOUT = 0xA5
P2MDOUT = 0xA6
P2MDIN  = 0xF3
XBR1    = 0xE2
OSCICN  = 0xB2

        ; ===== IRAM =====
DISP0   = 0x30
DISP1   = 0x31
DISP2   = 0x32
DISP3   = 0x33
KEYNOW  = 0x34
KEYLAST = 0x35
ROWIDX  = 0x36
TMP     = 0x37
CNT     = 0x38

        ; ===== 常量段码(共阴, 高电平亮) =====
SEG_BLK = 0x00
SEG_K   = 0x6E
SEG_F   = 0x8E

        ; ===== 初始化 =====
        anl PCA0MD, #0xBF
        mov PCA0MD, #0x00

        mov P0MDOUT, #0xC0
        mov P1MDOUT, #0xFF
        mov P2MDOUT, #0x0F
        mov P2MDIN,  #0xFF

        mov XBR1, #0x40
        mov OSCICN, #0x83

        ; 初始显示 " K0"
        mov DISP3, #SEG_BLK
        mov DISP2, #SEG_BLK
        mov DISP1, #SEG_K
        mov a, #0
        lcall GET_DIG_SEG
        mov DISP0, a

        mov KEYLAST, #0xFF

MAIN_LOOP:
        mov CNT, #40
LOOP_REFRESH:
        lcall REFRESH_ALL
        djnz CNT, LOOP_REFRESH

        lcall SCAN_KEY
        mov KEYNOW, a

        cjne a, #0xFF, CHECK_CHANGE
        mov KEYLAST, #0xFF
        sjmp MAIN_LOOP

CHECK_CHANGE:
        mov a, KEYNOW
        cjne a, KEYLAST, UPDATE_DISP
        sjmp MAIN_LOOP

UPDATE_DISP:
        lcall REMAP_KEY
        mov KEYNOW, a
        mov KEYLAST, a
        lcall SHOW_KEY_NAME
        sjmp MAIN_LOOP

REFRESH_ALL:
        mov a, DISP0
        mov P1, a
        anl 0x80, #0x3F
        lcall DELAY_DIGIT

        mov a, DISP1
        mov P1, a
        anl 0x80, #0x3F
        orl 0x80, #0x40
        lcall DELAY_DIGIT

        mov a, DISP2
        mov P1, a
        anl 0x80, #0x3F
        orl 0x80, #0x80
        lcall DELAY_DIGIT

        mov a, DISP3
        mov P1, a
        anl 0x80, #0x3F
        orl 0x80, #0xC0
        lcall DELAY_DIGIT
        ret

DELAY_DIGIT:
        mov r6, #10
DLY1:
        mov r5, #220
DLY2:
        djnz r5, DLY2
        djnz r6, DLY1
        ret

; 返回 A=0..15 (row*4+col), 无键=0xFF
SCAN_KEY:
        mov ROWIDX, #0
        mov 0xA0, #0xFE
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        mov ROWIDX, #1
        mov 0xA0, #0xFD
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        mov ROWIDX, #2
        mov 0xA0, #0xFB
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        mov ROWIDX, #3
        mov 0xA0, #0xF7
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        mov 0xA0, #0xFF
        mov a, #0xFF
        ret

KEY_OK:
        lcall DEBOUNCE_DELAY
        mov a, ROWIDX
        cjne a, #0, DB_R1
        mov 0xA0, #0xFE
        sjmp DB_READ
DB_R1:
        cjne a, #1, DB_R2
        mov 0xA0, #0xFD
        sjmp DB_READ
DB_R2:
        cjne a, #2, DB_R3
        mov 0xA0, #0xFB
        sjmp DB_READ
DB_R3:
        mov 0xA0, #0xF7
DB_READ:
        lcall READ_COL
        mov 0xA0, #0xFF

        cjne a, #0xFF, DB_OK
        mov a, #0xFF
        ret

DB_OK:
        mov TMP, a
        mov a, ROWIDX
        rl a
        rl a
        add a, TMP
        ret

READ_COL:
        mov a, 0xA0
        anl a, #0xF0
        cjne a, #0xF0, HAS_COL
        mov a, #0xFF
        ret
HAS_COL:
        jb 0xA4, CHK_C1
        mov a, #0
        ret
CHK_C1:
        jb 0xA5, CHK_C2
        mov a, #1
        ret
CHK_C2:
        jb 0xA6, CHK_C3
        mov a, #2
        ret
CHK_C3:
        jb 0xA7, NO_COL
        mov a, #3
        ret
NO_COL:
        mov a, #0xFF
        ret

DEBOUNCE_DELAY:
        mov r7, #30
DB1:
        lcall REFRESH_ALL
        djnz r7, DB1
        ret

; 输入A=扫描键值(0..15), 输出A=应显示键值编码(0..15)
REMAP_KEY:
        mov dptr, #KEY_REMAP_TAB
        movc a, @a+dptr
        ret

; A = keycode 0..15
SHOW_KEY_NAME:
        mov TMP, a

        mov DISP3, #SEG_BLK
        mov DISP2, #SEG_BLK
        mov DISP1, #SEG_BLK
        mov DISP0, #SEG_BLK

        mov a, TMP
        cjne a, #0, K01
        mov a, #7
        lcall SHOW_K_DIGIT
        ret
K01:    mov a, TMP
        cjne a, #1, K02
        mov a, #8
        lcall SHOW_K_DIGIT
        ret
K02:    mov a, TMP
        cjne a, #2, K03
        mov a, #9
        lcall SHOW_K_DIGIT
        ret
K03:    mov a, TMP
        cjne a, #3, K10
        mov a, #6
        lcall SHOW_KF_DIGIT
        ret

K10:    mov a, TMP
        cjne a, #4, K11
        mov a, #4
        lcall SHOW_K_DIGIT
        ret
K11:    mov a, TMP
        cjne a, #5, K12
        mov a, #5
        lcall SHOW_K_DIGIT
        ret
K12:    mov a, TMP
        cjne a, #6, K13
        mov a, #6
        lcall SHOW_K_DIGIT
        ret
K13:    mov a, TMP
        cjne a, #7, K20
        mov a, #5
        lcall SHOW_KF_DIGIT
        ret

K20:    mov a, TMP
        cjne a, #8, K21
        mov a, #1
        lcall SHOW_K_DIGIT
        ret
K21:    mov a, TMP
        cjne a, #9, K22
        mov a, #2
        lcall SHOW_K_DIGIT
        ret
K22:    mov a, TMP
        cjne a, #10, K23
        mov a, #3
        lcall SHOW_K_DIGIT
        ret
K23:    mov a, TMP
        cjne a, #11, K30
        mov a, #4
        lcall SHOW_KF_DIGIT
        ret

K30:    mov a, TMP
        cjne a, #12, K31
        mov a, #0
        lcall SHOW_K_DIGIT
        ret
K31:    mov a, TMP
        cjne a, #13, K32
        mov a, #1
        lcall SHOW_KF_DIGIT
        ret
K32:    mov a, TMP
        cjne a, #14, K33
        mov a, #2
        lcall SHOW_KF_DIGIT
        ret
K33:    mov a, TMP
        cjne a, #15, SHOW_END
        mov a, #3
        lcall SHOW_KF_DIGIT
SHOW_END:
        ret

SHOW_K_DIGIT:
        mov DISP1, #SEG_K
        lcall GET_DIG_SEG
        mov DISP0, a
        ret

SHOW_KF_DIGIT:
        mov DISP2, #SEG_K
        mov DISP1, #SEG_F
        lcall GET_DIG_SEG
        mov DISP0, a
        ret

GET_DIG_SEG:
        mov dptr, #SEG_TAB
        movc a, @a+dptr
        ret

; 索引=扫描键值, 值=应显示键值编码
; 按你实测关系校准。
KEY_REMAP_TAB:
        .byte 12,4,1,15,8,5,2,11,9,6,13,7,10,0,14,3

SEG_TAB:
        .byte 0xFC,0x60,0xDA,0xF2,0x66,0xB6,0xBE,0xE0,0xFE,0xF6
    __endasm;
}
