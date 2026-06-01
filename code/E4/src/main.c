
void ext0_isr(void) __interrupt(0) __naked {
    __asm
        push acc
        push psw

        ; KINT pressed: if lid is open, close early
        mov a, 0x4D          ; LIDOPEN
        jz EX0_DONE

        mov 0x4D, #0x00      ; LIDOPEN=0
        mov 0x4E, #0xFF      ; SELBIN=FF
        mov 0x42, #0x00      ; LIDLO=0
        mov 0x43, #0x00      ; LIDHI=0
        mov 0x44, #0x00      ; BLKDIV=0
        mov 0x45, #0x00      ; BLKFLG=0
        setb 0x80            ; P0.0=1, D9 off

EX0_DONE:
        pop psw
        pop acc
        reti
    __endasm;
}

void timer0_isr(void) __interrupt(1) __naked {
    __asm
        push acc
        push psw

        ; 1ms reload @24.5MHz/12
        mov 0x8C, #0xF8      ; TH0
        mov 0x8A, #0x06      ; TL0

        ; lid countdown: LIDLO/LIDHI
        mov a, 0x42
        orl a, 0x43
        jz T0_SKIP_LID

        mov a, 0x42
        jnz T0_DEC_LO
        dec 0x43
T0_DEC_LO:
        dec 0x42

        mov a, 0x42
        orl a, 0x43
        jnz T0_SKIP_LID

        ; timeout: close lid
        mov 0x4D, #0x00      ; LIDOPEN=0
        mov 0x4E, #0xFF      ; SELBIN=FF
        setb 0x80            ; P0.0=1, D9 off
T0_SKIP_LID:

        ; 5Hz blink flag (toggle every 100ms)
        inc 0x44             ; BLKDIV
        mov a, 0x44
        cjne a, #100, T0_HINT
        mov 0x44, #0
        mov a, 0x45          ; BLKFLG
        xrl a, #1
        mov 0x45, a

T0_HINT:
        ; full-hint countdown HINTLO/HINTHI
        mov a, 0x46
        orl a, 0x47
        jz T0_END

        mov a, 0x46
        jnz T0_DEC_HL
        dec 0x47
T0_DEC_HL:
        dec 0x46

        mov a, 0x46
        orl a, 0x47
        jnz T0_END
        mov 0x4F, #0xFF      ; FULLBIN=FF

T0_END:
        pop psw
        pop acc
        reti
    __endasm;
}

void main(void) __naked {
    __asm
        ; ===== IRAM =====
CAP0    = 0x30
CAP1    = 0x31
CAP2    = 0x32
CAP3    = 0x33
KEYNOW  = 0x34
KEYLAST = 0x35
ROWIDX  = 0x36
TMP     = 0x37
CNT     = 0x38
LEDREG  = 0x39
LASTBAR = 0x3B

LIDLO   = 0x42
LIDHI   = 0x43
BLKDIV  = 0x44
BLKFLG  = 0x45
HINTLO  = 0x46
HINTHI  = 0x47

LIDOPEN = 0x4D
SELBIN  = 0x4E
FULLBIN = 0x4F

        ; init MCU
        anl 0xD9, #0xBF
        mov 0xD9, #0x00
        mov 0xA4, #0xC1      ; P0.7/P0.6 + P0.0 push-pull
        mov 0xA5, #0xFF      ; P1 seg
        mov 0xA6, #0x0F      ; P2 row out/col in
        mov 0xA7, #0x1A      ; P3.1(buzzer off), P3.3/P3.4 for 74HCT164
        mov 0xF3, #0xFF
        mov 0xE2, #0x40
        mov 0xB2, #0x83

        setb 0x80            ; D9 off
        clr 0xB1             ; P3.1=0, buzzer off
        mov 0xA0, #0xFF

        ; timer0 mode1 + interrupt
        anl 0x89, #0xF0
        orl 0x89, #0x01
        mov 0x8C, #0xF8
        mov 0x8A, #0x06
        setb 0xA9            ; ET0
        setb 0x88            ; IT0=1 (falling-edge INT0)
        setb 0xA8            ; EX0 enable
        setb 0xAF            ; EA
        setb 0x8C            ; TR0

        mov KEYLAST, #0xFF
        mov LIDOPEN, #0
        mov SELBIN, #0xFF
        mov FULLBIN, #0xFF
        mov LIDLO, #0
        mov LIDHI, #0
        mov BLKDIV, #0
        mov BLKFLG, #0
        mov HINTLO, #0
        mov HINTHI, #0

        ; LEDs off initially
        mov LEDREG, #0xFF
        mov LASTBAR, #0x00
        lcall SHIFT_LED_BAR

        ; pseudo-random seed from running timer + port read
        mov CNT, #60
SEED_SPIN:
        lcall DELAY_DIG
        djnz CNT, SEED_SPIN
        mov a, 0x8A          ; TL0
        xrl a, 0x8C          ; TH0
        xrl a, 0xA0          ; P2

        ; generate 4 capacities in 0..9
        mov b, #10
        div ab
        mov CAP0, b

        mov a, b
        mov b, #17
        mul ab
        add a, #31
        mov b, #10
        div ab
        mov CAP1, b

        mov a, b
        mov b, #13
        mul ab
        add a, #7
        mov b, #10
        div ab
        mov CAP2, b

        mov a, b
        mov b, #11
        mul ab
        add a, #9
        mov b, #10
        div ab
        mov CAP3, b

MAIN_LOOP:
        lcall UPDATE_LED_BAR

        mov CNT, #40
REFRESH_LOOP:
        lcall REFRESH_ALL
        djnz CNT, REFRESH_LOOP

        lcall SCAN_KEY
        mov KEYNOW, a
        cjne a, #0xFF, HAVE_KEY
        mov KEYLAST, #0xFF
        sjmp MAIN_LOOP

HAVE_KEY:
        cjne a, KEYLAST, KEY_EDGE
        sjmp MAIN_LOOP

KEY_EDGE:
        mov KEYLAST, a

        ; category keys only: 0..3 -> K7 K8 K9 KF6
        clr c
        subb a, #4
        jc CAT_KEY
        sjmp MAIN_LOOP

CAT_KEY:
        mov a, KEYNOW
        mov TMP, a

        mov a, LIDOPEN
        jz LID_CLOSED

        ; lid open: only same category can deliver
        mov a, TMP
        cjne a, SELBIN, MAIN_LOOP
        lcall DEC_CAP_IF_GT0
        sjmp MAIN_LOOP

LID_CLOSED:
        lcall GET_CAP
        jnz OPEN_LID

        ; show F for 1s
        mov a, TMP
        mov FULLBIN, a
        clr 0xAF
        mov HINTLO, #0xE8
        mov HINTHI, #0x03
        setb 0xAF
        sjmp MAIN_LOOP

OPEN_LID:
        mov LIDOPEN, #1
        mov a, TMP
        mov SELBIN, a
        clr 0xAF
        mov LIDLO, #0x40      ; 8000 = 0x1F40
        mov LIDHI, #0x1F
        setb 0xAF
        mov BLKDIV, #0
        mov BLKFLG, #0
        clr 0x80              ; D9 on
        sjmp MAIN_LOOP

GET_CAP:
        mov a, TMP
        cjne a, #0, GC1
        mov a, CAP0
        ret
GC1:    cjne a, #1, GC2
        mov a, CAP1
        ret
GC2:    cjne a, #2, GC3
        mov a, CAP2
        ret
GC3:    mov a, CAP3
        ret

DEC_CAP_IF_GT0:
        mov a, TMP
        cjne a, #0, DC1
        mov a, CAP0
        jz DC_FULL
        dec CAP0
        ret
DC1:    cjne a, #1, DC2
        mov a, CAP1
        jz DC_FULL
        dec CAP1
        ret
DC2:    cjne a, #2, DC3
        mov a, CAP2
        jz DC_FULL
        dec CAP2
        ret
DC3:    mov a, CAP3
        jz DC_FULL
        dec CAP3
        ret
DC_FULL:
        mov a, TMP
        mov FULLBIN, a
        clr 0xAF
        mov HINTLO, #0xE8
        mov HINTHI, #0x03
        setb 0xAF
        ret

; ---------- LED progress bar D1~D8 ----------
UPDATE_LED_BAR:
        mov a, LIDOPEN
        jnz ULB_OPEN
        mov a, LASTBAR
        cjne a, #0xFF, ULB_CLOSE_APPLY
        ret
ULB_CLOSE_APPLY:
        mov a, #0xFF
        mov LEDREG, a
        mov LASTBAR, a
        lcall SHIFT_LED_BAR
        ret

ULB_OPEN:
        ; proper 16-bit compare: if LID >= threshold then level
        ; >= 7000 (0x1B58) ? level=8
        mov a, LIDHI
        clr c
        subb a, #0x1B
        jc ULB_LE7
        jnz ULB_GE8
        mov a, LIDLO
        clr c
        subb a, #0x58
        jc ULB_LE7
ULB_GE8:
        mov a, #8
        ljmp ULB_IDX

ULB_LE7:
        ; >= 6000 (0x1770) ? level=7
        mov a, LIDHI
        clr c
        subb a, #0x17
        jc ULB_LE6
        jnz ULB_GE7
        mov a, LIDLO
        clr c
        subb a, #0x70
        jc ULB_LE6
ULB_GE7:
        mov a, #7
        ljmp ULB_IDX

ULB_LE6:
        ; >= 5000 (0x1388) ? level=6
        mov a, LIDHI
        clr c
        subb a, #0x13
        jc ULB_LE5
        jnz ULB_GE6
        mov a, LIDLO
        clr c
        subb a, #0x88
        jc ULB_LE5
ULB_GE6:
        mov a, #6
        ljmp ULB_IDX

ULB_LE5:
        ; >= 4000 (0x0FA0) ? level=5
        mov a, LIDHI
        clr c
        subb a, #0x0F
        jc ULB_LE4
        jnz ULB_GE5
        mov a, LIDLO
        clr c
        subb a, #0xA0
        jc ULB_LE4
ULB_GE5:
        mov a, #5
        ljmp ULB_IDX

ULB_LE4:
        ; >= 3000 (0x0BB8) ? level=4
        mov a, LIDHI
        clr c
        subb a, #0x0B
        jc ULB_LE3
        jnz ULB_GE4
        mov a, LIDLO
        clr c
        subb a, #0xB8
        jc ULB_LE3
ULB_GE4:
        mov a, #4
        ljmp ULB_IDX

ULB_LE3:
        ; >= 2000 (0x07D0) ? level=3
        mov a, LIDHI
        clr c
        subb a, #0x07
        jc ULB_LE2
        jnz ULB_GE3
        mov a, LIDLO
        clr c
        subb a, #0xD0
        jc ULB_LE2
ULB_GE3:
        mov a, #3
        ljmp ULB_IDX

ULB_LE2:
        ; >= 1000 (0x03E8) ? level=2
        mov a, LIDHI
        clr c
        subb a, #0x03
        jc ULB_LE1
        jnz ULB_GE2
        mov a, LIDLO
        clr c
        subb a, #0xE8
        jc ULB_LE1
ULB_GE2:
        mov a, #2
        ljmp ULB_IDX

ULB_LE1:
        mov a, LIDHI
        orl a, LIDLO
        jz ULB_ZERO
        mov a, #1
        ljmp ULB_IDX
ULB_ZERO:
        mov a, #0

ULB_IDX:
        mov dptr, #LED_BAR_TAB
        movc a, @a+dptr
ULB_APPLY:
        mov LEDREG, a
        xrl a, LASTBAR
        jz ULB_RET
        mov a, LEDREG
        mov LASTBAR, a
        lcall SHIFT_LED_BAR
ULB_RET:
        ret

SHIFT_LED_BAR:
        clr 0xAF             ; EA=0, avoid ISR preemption during shift
        mov a, LEDREG
        mov r0, #8
SLB_LP:
        mov c, acc.7
        mov 0xB3, c          ; P3.3 DAT
        setb 0xB4            ; P3.4 CLK
        nop
        clr 0xB4
        rl a
        djnz r0, SLB_LP
        setb 0xAF            ; EA=1
        ret

; ---------- display ----------
REFRESH_ALL:
        ; rightmost: CAP3 (reversed display order)
        mov a, CAP3
        mov dptr, #SEG_TAB
        movc a, @a+dptr
        lcall APPLY_OVR3
        mov 0x90, a
        anl 0x80, #0x3F
        lcall DELAY_DIG

        mov a, CAP2
        mov dptr, #SEG_TAB
        movc a, @a+dptr
        lcall APPLY_OVR2
        mov 0x90, a
        anl 0x80, #0x3F
        orl 0x80, #0x40
        lcall DELAY_DIG

        mov a, CAP1
        mov dptr, #SEG_TAB
        movc a, @a+dptr
        lcall APPLY_OVR1
        mov 0x90, a
        anl 0x80, #0x3F
        orl 0x80, #0x80
        lcall DELAY_DIG

        mov a, CAP0
        mov dptr, #SEG_TAB
        movc a, @a+dptr
        lcall APPLY_OVR0
        mov 0x90, a
        anl 0x80, #0x3F
        orl 0x80, #0xC0
        lcall DELAY_DIG
        ret

APPLY_OVR0:
        mov TMP, #0
        sjmp AO_C
APPLY_OVR1:
        mov TMP, #1
        sjmp AO_C
APPLY_OVR2:
        mov TMP, #2
        sjmp AO_C
APPLY_OVR3:
        mov TMP, #3
AO_C:
        push acc
        mov a, FULLBIN
        cjne a, TMP, AO_BL
        pop acc
        mov a, #0x8E         ; F
        ret
AO_BL:
        pop acc
        mov b, a
        mov a, LIDOPEN
        jz AO_RET
        mov a, TMP
        cjne a, SELBIN, AO_RET
        mov a, BLKFLG
        jz AO_RET_B
        mov a, #0x00
        ret
AO_RET_B:
        mov a, b
        ret
AO_RET:
        mov a, b
        ret

DELAY_DIG:
        mov r6, #8
DD1:    mov r5, #180
DD2:    djnz r5, DD2
        djnz r6, DD1
        ret

; ---------- keypad ----------
; 返回 A=0..15 (row*4+col), 无键=0xFF
SCAN_KEY:
        ; row0
        mov ROWIDX, #0
        mov 0xA0, #0xFE
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        ; row1
        mov ROWIDX, #1
        mov 0xA0, #0xFD
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        ; row2
        mov ROWIDX, #2
        mov 0xA0, #0xFB
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        ; row3
        mov ROWIDX, #3
        mov 0xA0, #0xF7
        lcall READ_COL
        cjne a, #0xFF, KEY_OK

        mov 0xA0, #0xFF
        mov a, #0xFF
        ret

KEY_OK:
        ; 消抖后重读当前行
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

        ; 查映射表得到 label_code
        mov dptr, #KEY_REMAP_TAB
        movc a, @a+dptr
        ret

READ_COL:
        mov a, 0xA0
        anl a, #0xF0
        cjne a, #0xF0, HAS_COL
        mov a, #0xFF
        ret
HAS_COL:
        jb 0xA4, RC1
        mov a, #0
        ret
RC1:    jb 0xA5, RC2
        mov a, #1
        ret
RC2:    jb 0xA6, RC3
        mov a, #2
        ret
RC3:    jb 0xA7, RCN
        mov a, #3
        ret
RCN:    mov a, #0xFF
        ret

DEBOUNCE_DELAY:
        mov r7, #30
DB1:
        lcall REFRESH_ALL
        djnz r7, DB1
        ret

LED_BAR_TAB:
        .byte 0xFF,0xFE,0xFC,0xF8,0xF0,0xE0,0xC0,0x80,0x00
SEG_TAB:
        .byte 0xFC,0x60,0xDA,0xF2,0x66,0xB6,0xBE,0xE0,0xFE,0xF6
KEY_REMAP_TAB:
        .byte 12,4,1,15,8,5,2,11,9,6,13,7,10,0,14,3
    __endasm;
}
