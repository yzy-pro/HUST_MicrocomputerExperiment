$NOMOD51
;============================================================
; 文件名：final.asm
; 目标板：C8051F310EVM
; 晶振：24.5MHz
; 说明：
;   本程序按已验证可响应的 main.c 思路重写为 A51 汇编。
;   1. P2.0~P2.3 为键盘行输出，P2.4~P2.7 为列输入；
;   2. 扫描方式为 P2=FE/FD/FB/F7，读高四位列线；
;   3. PDF 中键号按列编号：第一列为 K0/K1/K2/K3；
;   4. 扫描结果先查 KEY_REMAP_TAB，把 row*4+col 转为 PDF 键号；
;   5. K10~K13 分别作为 F1~F4，对应四类垃圾桶；
;   6. K1~K9 为数字键，开盖后可一次性投入 1~9 袋；
;   7. Timer0 只做 1ms 计时，数码管在主循环中刷新。
;============================================================

;---------------- SFR 定义 ----------------
ACC     DATA    0E0H
B       DATA    0F0H
PSW     DATA    0D0H
SP      DATA    081H
DPL     DATA    082H
DPH     DATA    083H
P0      DATA    080H
P1      DATA    090H
P2      DATA    0A0H
P3      DATA    0B0H
TCON    DATA    088H
TMOD    DATA    089H
TL0     DATA    08AH
TH0     DATA    08CH
IE      DATA    0A8H
PCA0MD  DATA    0D9H
XBR0    DATA    0E1H
XBR1    DATA    0E2H
IT01CF  DATA    0E4H
OSCICN  DATA    0B2H
P0MDOUT DATA    0A4H
P1MDOUT DATA    0A5H
P2MDOUT DATA    0A6H
P3MDOUT DATA    0A7H
P2MDIN  DATA    0F3H

P0_0    BIT     080H            ; D9 指示灯，低电平亮
P3_1    BIT     0B1H            ; 蜂鸣器，高电平响
P3_3    BIT     0B3H            ; 74HCT164 串行数据
P3_4    BIT     0B4H            ; 74HCT164 移位时钟
IT0     BIT     TCON.0
TR0     BIT     TCON.4
EX0     BIT     IE.0
ET0     BIT     IE.1
EA      BIT     IE.7
ACC7    BIT     0E7H

;---------------- 内部 RAM 分配 ----------------
CAP0    DATA    030H            ; 1号桶剩余容量
CAP1    DATA    031H            ; 2号桶剩余容量
CAP2    DATA    032H            ; 3号桶剩余容量
CAP3    DATA    033H            ; 4号桶剩余容量
KEYNOW  DATA    034H            ; 当前逻辑键值
KEYLAST DATA    035H            ; 上一次逻辑键值，用于按下沿判断
ROWIDX  DATA    036H            ; 当前扫描行
TMP     DATA    037H            ; 通用临时变量
CNT     DATA    038H            ; 通用计数器
LEDREG  DATA    039H            ; D1~D8 输出字节，0 亮 1 灭
BUZZLO  DATA    03AH            ; 蜂鸣倒计时低字节，单位约 1ms
LASTBAR DATA    03BH            ; 上一次进度灯状态
BUZZHI  DATA    03CH            ; 蜂鸣倒计时高字节

LIDLO   DATA    042H            ; 开盖倒计时低字节
LIDHI   DATA    043H            ; 开盖倒计时高字节
BLKDIV  DATA    044H            ; 闪烁分频
BLKFLG  DATA    045H            ; 闪烁标志
HINTLO  DATA    046H            ; 满桶提示倒计时低字节
HINTHI  DATA    047H            ; 满桶提示倒计时高字节

LIDOPEN DATA    04DH            ; 桶盖状态，0空闲，1打开
SELBIN  DATA    04EH            ; 当前打开/选中的桶号
FULLBIN DATA    04FH            ; 需要显示 F 的桶号，FFH 表示无
ERRBIN  DATA    050H            ; 需要显示 E 的桶号，FFH 表示无

;---------------- 中断向量 ----------------
        ORG     0000H
        LJMP    MAIN
        ORG     0003H
        LJMP    INT0_ISR
        ORG     000BH
        LJMP    T0_ISR
        ORG     0030H

;---------------- 主程序 ----------------
MAIN:
        MOV     SP, #070H
        LCALL   INIT_MCU

        SETB    P0_0            ; D9 熄灭
        CLR     P3_1            ; 蜂鸣器关闭
        MOV     P2, #0FFH       ; 释放键盘行列

        LCALL   INIT_TIMER0

        MOV     KEYLAST, #0FFH
        MOV     LIDOPEN, #00H
        MOV     SELBIN,  #0FFH
        MOV     FULLBIN, #0FFH
        MOV     ERRBIN,  #0FFH
        MOV     LIDLO,   #00H
        MOV     LIDHI,   #00H
        MOV     BLKDIV,  #00H
        MOV     BLKFLG,  #00H
        MOV     HINTLO,  #00H
        MOV     HINTHI,  #00H
        MOV     BUZZLO, #00H
        MOV     BUZZHI, #00H

        MOV     LEDREG, #0FFH   ; D1~D8 全灭
        MOV     LASTBAR, #00H
        LCALL   SHIFT_LED_BAR

        LCALL   MAKE_RANDOM_CAP

MAIN_LOOP:
        LCALL   UPDATE_LED_BAR

        MOV     CNT, #40        ; 刷新一段时间后扫一次键
REFRESH_LOOP:
        LCALL   REFRESH_ALL
        DJNZ    CNT, REFRESH_LOOP

        LCALL   SCAN_KEY
        MOV     KEYNOW, A
        CJNE    A, #0FFH, HAVE_KEY
        MOV     KEYLAST, #0FFH
        SJMP    MAIN_LOOP

HAVE_KEY:
        CJNE    A, KEYLAST, KEY_EDGE
        SJMP    MAIN_LOOP

KEY_EDGE:
        MOV     KEYLAST, A

        MOV     A, KEYNOW
        CJNE    A, #15, NOT_F6
        LCALL   RESET_ALL_CAP   ; F6：清理，四个桶恢复到 9
        SJMP    MAIN_LOOP

NOT_F6:
        MOV     A, KEYNOW
        CJNE    A, #14, NOT_F5
        MOV     A, LIDOPEN      ; F5：开盖后对当前桶投 1 袋
        JZ      MAIN_LOOP
        MOV     A, SELBIN
        CJNE    A, #0FFH, F5_OK
        SJMP    MAIN_LOOP
F5_OK:
        MOV     R2, #1
        LCALL   HANDLE_BAGS
        SJMP    MAIN_LOOP

NOT_F5:
        ; K1~K9 为数字键：开盖后一次性投入多袋。
        MOV     A, KEYNOW
        JZ      MAIN_LOOP       ; K0 不作为投入数量
        CLR     C
        SUBB    A, #10
        JNC     CHECK_FUNC
        LCALL   HANDLE_NUMBER
        SJMP    MAIN_LOOP

CHECK_FUNC:
        ; F1~F4 对应 K10~K13，减 10 后得到桶号 0~3。
        MOV     A, KEYNOW
        CLR     C
        SUBB    A, #10
        MOV     TMP, A
        CLR     C
        SUBB    A, #4
        JC      CAT_KEY
        SJMP    MAIN_LOOP

CAT_KEY:
        LCALL   HANDLE_CATEGORY
        SJMP    MAIN_LOOP

;---------------- 初始化 ----------------
INIT_MCU:
        ANL     PCA0MD, #0BFH   ; 关闭看门狗
        MOV     PCA0MD, #000H
        MOV     P0MDOUT, #0C1H  ; P0.7/P0.6 数码管位选，P0.0 为 D9
        MOV     P1MDOUT, #0FFH  ; P1.0~P1.7 为数码管段选
        MOV     P2MDOUT, #00FH  ; P2.0~P2.3 行输出，P2.4~P2.7 列输入
        MOV     P3MDOUT, #01AH  ; P3.1 蜂鸣器，P3.3/P3.4 控制 74HCT164
        MOV     P2MDIN,  #0FFH
        MOV     XBR0,    #000H
        MOV     XBR1,    #040H  ; 使能交叉开关和弱上拉
        MOV     IT01CF,  #001H  ; INT0 接 P0.1，低电平/下降沿有效
        MOV     OSCICN,  #083H  ; 内部振荡器 24.5MHz
        RET

INIT_TIMER0:
        ANL     TMOD, #0F0H
        ORL     TMOD, #001H     ; Timer0 模式1，16位定时
        MOV     TH0, #0F8H      ; 1ms @ 24.5MHz/12，重装 F806H
        MOV     TL0, #006H
        SETB    ET0
        SETB    IT0             ; INT0 下降沿触发
        SETB    EX0
        SETB    EA
        SETB    TR0
        RET

;---------------- Timer0：1ms 系统计时 ----------------
T0_ISR:
        PUSH    ACC
        PUSH    PSW

        MOV     TH0, #0F8H
        MOV     TL0, #006H

        MOV     A, BUZZLO
        ORL     A, BUZZHI
        JZ      T0_LID
        MOV     A, BUZZLO
        JNZ     T0_DEC_BUZZ_LO
        DEC     BUZZHI
T0_DEC_BUZZ_LO:
        DEC     BUZZLO
        MOV     A, BUZZLO
        ORL     A, BUZZHI
        JNZ     T0_LID
        CLR     P3_1

T0_LID:
        MOV     A, LIDLO
        ORL     A, LIDHI
        JZ      T0_BLINK
        MOV     A, LIDLO
        JNZ     T0_DEC_LO
        DEC     LIDHI
T0_DEC_LO:
        DEC     LIDLO
        MOV     A, LIDLO
        ORL     A, LIDHI
        JNZ     T0_BLINK
        MOV     LIDOPEN, #00H
        MOV     SELBIN, #0FFH
        SETB    P0_0

T0_BLINK:
        INC     BLKDIV
        MOV     A, BLKDIV
        CJNE    A, #100, T0_HINT
        MOV     BLKDIV, #00H
        MOV     A, BLKFLG
        XRL     A, #01H
        MOV     BLKFLG, A

T0_HINT:
        MOV     A, HINTLO
        ORL     A, HINTHI
        JZ      T0_END
        MOV     A, HINTLO
        JNZ     T0_DEC_HL
        DEC     HINTHI
T0_DEC_HL:
        DEC     HINTLO
        MOV     A, HINTLO
        ORL     A, HINTHI
        JNZ     T0_END
        MOV     FULLBIN, #0FFH
        MOV     ERRBIN, #0FFH

T0_END:
        POP     PSW
        POP     ACC
        RETI

;---------------- INT0：KINT 提前关盖 ----------------
INT0_ISR:
        PUSH    ACC
        PUSH    PSW
        MOV     A, LIDOPEN
        JZ      EX0_DONE
        MOV     LIDOPEN, #00H
        MOV     SELBIN,  #0FFH
        MOV     LIDLO,   #00H
        MOV     LIDHI,   #00H
        MOV     BLKDIV,  #00H
        MOV     BLKFLG,  #00H
        SETB    P0_0
EX0_DONE:
        POP     PSW
        POP     ACC
        RETI

;---------------- 按键处理 ----------------
HANDLE_CATEGORY:
        MOV     A, LIDOPEN
        JZ      LID_CLOSED

        ; 桶盖已打开时，只有再次按同一类才继续投 1 袋。
        MOV     A, TMP
        CJNE    A, SELBIN, HC_RET
        MOV     R2, #1
        LCALL   HANDLE_BAGS
HC_RET:
        RET

LID_CLOSED:
        LCALL   GET_CAP
        JNZ     OPEN_LID

        ; 容量为 0：对应数码管显示 F 一秒，并蜂鸣提示，不开盖。
        MOV     A, TMP
        MOV     FULLBIN, A
        MOV     ERRBIN, #0FFH
        MOV     LIDOPEN, #00H
        MOV     SELBIN, #0FFH
        CLR     EA
        MOV     HINTLO, #0E8H
        MOV     HINTHI, #003H
        SETB    EA
        LCALL   BEEP_LONG
        RET

OPEN_LID:
        ; F1~F4 有余量时立即开盖 8 秒，但不扣容量。
        MOV     A, TMP
        MOV     SELBIN, A
        MOV     FULLBIN, #0FFH
        MOV     ERRBIN, #0FFH
        MOV     LIDOPEN, #01H
        CLR     EA
        MOV     LIDLO, #040H    ; 8000ms = 1F40H
        MOV     LIDHI, #01FH
        SETB    EA
        MOV     BLKDIV, #00H
        MOV     BLKFLG, #00H
        CLR     P0_0            ; D9 亮，表示桶盖打开
        RET

HANDLE_NUMBER:
        ; K1~K9 表示一次性投入 1~9 袋。
        ; 只在桶盖已经打开时有效；错误时不改变开关盖状态。
        MOV     A, LIDOPEN
        JZ      HN_RET
        MOV     A, SELBIN
        CJNE    A, #0FFH, HN_HAVE_BIN
        RET
HN_HAVE_BIN:
        MOV     A, KEYNOW
        MOV     R2, A           ; R2 保存投入袋数
        LCALL   HANDLE_BAGS
HN_RET:
        RET

HANDLE_BAGS:
        ; R2 为本次投放袋数。容量足够则扣减；
        ; 开盖后容量不足时显示 E、蜂鸣，并立即关盖，禁止继续投递。
        MOV     A, SELBIN
        CJNE    A, #0FFH, HB_HAVE_BIN
        RET
HB_HAVE_BIN:
        MOV     R3, A           ; R3 保存桶号
        ADD     A, #030H
        MOV     R0, A
        MOV     A, @R0
        CLR     C
        SUBB    A, R2
        JC      HB_ERROR
        MOV     @R0, A
        MOV     FULLBIN, #0FFH
        MOV     ERRBIN, #0FFH
        RET
HB_ERROR:
        MOV     A, R3
        MOV     ERRBIN, A
        MOV     FULLBIN, #0FFH
        CLR     EA
        MOV     HINTLO, #0E8H
        MOV     HINTHI, #003H
        SETB    EA
        LCALL   BEEP_LONG
        MOV     LIDOPEN, #00H
        MOV     SELBIN, #0FFH
        MOV     LIDLO, #00H
        MOV     LIDHI, #00H
        SETB    P0_0
        RET

GET_CAP:
        MOV     A, TMP
        CJNE    A, #0, GC1
        MOV     A, CAP0
        RET
GC1:    CJNE    A, #1, GC2
        MOV     A, CAP1
        RET
GC2:    CJNE    A, #2, GC3
        MOV     A, CAP2
        RET
GC3:    MOV     A, CAP3
        RET

DEC_CAP_IF_GT0:
        MOV     A, TMP
        CJNE    A, #0, DC1
        MOV     A, CAP0
        JZ      DC_FULL
        DEC     CAP0
        RET
DC1:    CJNE    A, #1, DC2
        MOV     A, CAP1
        JZ      DC_FULL
        DEC     CAP1
        RET
DC2:    CJNE    A, #2, DC3
        MOV     A, CAP2
        JZ      DC_FULL
        DEC     CAP2
        RET
DC3:    MOV     A, CAP3
        JZ      DC_FULL
        DEC     CAP3
        RET
DC_FULL:
        MOV     A, TMP
        MOV     FULLBIN, A
        MOV     ERRBIN, #0FFH
        CLR     EA
        MOV     HINTLO, #0E8H
        MOV     HINTHI, #003H
        SETB    EA
        LCALL   BEEP_LONG
        RET

RESET_ALL_CAP:
        MOV     CAP0, #9
        MOV     CAP1, #9
        MOV     CAP2, #9
        MOV     CAP3, #9
        MOV     FULLBIN, #0FFH
        MOV     ERRBIN, #0FFH
        MOV     LIDOPEN, #00H
        MOV     SELBIN, #0FFH
        MOV     LIDLO, #00H
        MOV     LIDHI, #00H
        SETB    P0_0
        MOV     LEDREG, #0FFH
        MOV     LASTBAR, #00H
        LCALL   SHIFT_LED_BAR
        LCALL   BEEP_LONG
        RET

;---------------- 容量随机初始化 ----------------
MAKE_RANDOM_CAP:
        MOV     CNT, #60
SEED_SPIN:
        LCALL   DELAY_DIG
        DJNZ    CNT, SEED_SPIN

        MOV     A, TL0
        XRL     A, TH0
        XRL     A, P2
        MOV     B, #10
        DIV     AB
        MOV     CAP0, B

        MOV     A, B
        MOV     B, #17
        MUL     AB
        ADD     A, #31
        MOV     B, #10
        DIV     AB
        MOV     CAP1, B

        MOV     A, B
        MOV     B, #13
        MUL     AB
        ADD     A, #7
        MOV     B, #10
        DIV     AB
        MOV     CAP2, B

        MOV     A, B
        MOV     B, #11
        MUL     AB
        ADD     A, #9
        MOV     B, #10
        DIV     AB
        MOV     CAP3, B
        RET

;---------------- 数码管显示 ----------------
REFRESH_ALL:
        MOV     A, CAP3         ; 最右位显示 4号桶
        MOV     DPTR, #SEG_TAB
        MOVC    A, @A+DPTR
        LCALL   APPLY_OVR3
        MOV     P1, A
        ANL     P0, #03FH
        LCALL   DELAY_DIG

        MOV     A, CAP2
        MOV     DPTR, #SEG_TAB
        MOVC    A, @A+DPTR
        LCALL   APPLY_OVR2
        MOV     P1, A
        ANL     P0, #03FH
        ORL     P0, #040H
        LCALL   DELAY_DIG

        MOV     A, CAP1
        MOV     DPTR, #SEG_TAB
        MOVC    A, @A+DPTR
        LCALL   APPLY_OVR1
        MOV     P1, A
        ANL     P0, #03FH
        ORL     P0, #080H
        LCALL   DELAY_DIG

        MOV     A, CAP0         ; 最左位显示 1号桶
        MOV     DPTR, #SEG_TAB
        MOVC    A, @A+DPTR
        LCALL   APPLY_OVR0
        MOV     P1, A
        ANL     P0, #03FH
        ORL     P0, #0C0H
        LCALL   DELAY_DIG
        RET

APPLY_OVR0:
        MOV     TMP, #0
        SJMP    AO_C
APPLY_OVR1:
        MOV     TMP, #1
        SJMP    AO_C
APPLY_OVR2:
        MOV     TMP, #2
        SJMP    AO_C
APPLY_OVR3:
        MOV     TMP, #3
AO_C:
        PUSH    ACC
        MOV     A, ERRBIN
        CJNE    A, TMP, AO_FULL
        POP     ACC
        MOV     A, #09EH        ; 显示 E
        RET
AO_FULL:
        MOV     A, FULLBIN
        CJNE    A, TMP, AO_BLINK
        POP     ACC
        MOV     A, #08EH        ; 显示 F
        RET

AO_BLINK:
        POP     ACC
        MOV     B, A
        MOV     A, LIDOPEN
        JZ      AO_RET
        MOV     A, TMP
        CJNE    A, SELBIN, AO_RET
        MOV     A, BLKFLG
        JZ      AO_RET_B
        MOV     A, #00H         ; 当前开盖桶闪烁熄灭
        RET
AO_RET_B:
        MOV     A, B
        RET
AO_RET:
        MOV     A, B
        RET

DELAY_DIG:
        MOV     R6, #8
DD1:    MOV     R5, #180
DD2:    DJNZ    R5, DD2
        DJNZ    R6, DD1
        RET

;---------------- 键盘扫描 ----------------
SCAN_KEY:
        MOV     ROWIDX, #0
        MOV     P2, #0FEH
        LCALL   READ_COL
        CJNE    A, #0FFH, KEY_OK

        MOV     ROWIDX, #1
        MOV     P2, #0FDH
        LCALL   READ_COL
        CJNE    A, #0FFH, KEY_OK

        MOV     ROWIDX, #2
        MOV     P2, #0FBH
        LCALL   READ_COL
        CJNE    A, #0FFH, KEY_OK

        MOV     ROWIDX, #3
        MOV     P2, #0F7H
        LCALL   READ_COL
        CJNE    A, #0FFH, KEY_OK

        MOV     P2, #0FFH
        MOV     A, #0FFH
        RET

KEY_OK:
        LCALL   DEBOUNCE_DELAY
        MOV     A, ROWIDX
        CJNE    A, #0, DB_R1
        MOV     P2, #0FEH
        SJMP    DB_READ
DB_R1:
        CJNE    A, #1, DB_R2
        MOV     P2, #0FDH
        SJMP    DB_READ
DB_R2:
        CJNE    A, #2, DB_R3
        MOV     P2, #0FBH
        SJMP    DB_READ
DB_R3:
        MOV     P2, #0F7H

DB_READ:
        LCALL   READ_COL
        MOV     P2, #0FFH
        CJNE    A, #0FFH, DB_OK
        MOV     A, #0FFH
        RET

DB_OK:
        MOV     TMP, A
        MOV     A, ROWIDX
        RL      A
        RL      A
        ADD     A, TMP
        MOV     DPTR, #KEY_REMAP_TAB
        MOVC    A, @A+DPTR
        RET

READ_COL:
        MOV     A, P2
        ANL     A, #0F0H
        CJNE    A, #0F0H, HAS_COL
        MOV     A, #0FFH
        RET
HAS_COL:
        JB      0A4H, RC1       ; P2.4
        MOV     A, #0
        RET
RC1:    JB      0A5H, RC2       ; P2.5
        MOV     A, #1
        RET
RC2:    JB      0A6H, RC3       ; P2.6
        MOV     A, #2
        RET
RC3:    JB      0A7H, RCN       ; P2.7
        MOV     A, #3
        RET
RCN:    MOV     A, #0FFH
        RET

DEBOUNCE_DELAY:
        MOV     R7, #30
DB1:    LCALL   REFRESH_ALL
        DJNZ    R7, DB1
        RET

;---------------- 进度灯和蜂鸣器 ----------------
UPDATE_LED_BAR:
        MOV     A, LIDOPEN
        JNZ     ULB_OPEN
        MOV     A, LASTBAR
        CJNE    A, #0FFH, ULB_CLOSE_APPLY
        RET
ULB_CLOSE_APPLY:
        MOV     A, #0FFH
        MOV     LEDREG, A
        MOV     LASTBAR, A
        LCALL   SHIFT_LED_BAR
        RET

ULB_OPEN:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #01BH
        JC      ULB_LE7
        JNZ     ULB_GE8
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #058H
        JC      ULB_LE7
ULB_GE8:
        MOV     A, #8
        LJMP    ULB_IDX

ULB_LE7:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #017H
        JC      ULB_LE6
        JNZ     ULB_GE7
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #070H
        JC      ULB_LE6
ULB_GE7:
        MOV     A, #7
        LJMP    ULB_IDX

ULB_LE6:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #013H
        JC      ULB_LE5
        JNZ     ULB_GE6
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #088H
        JC      ULB_LE5
ULB_GE6:
        MOV     A, #6
        LJMP    ULB_IDX

ULB_LE5:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #00FH
        JC      ULB_LE4
        JNZ     ULB_GE5
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #0A0H
        JC      ULB_LE4
ULB_GE5:
        MOV     A, #5
        LJMP    ULB_IDX

ULB_LE4:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #00BH
        JC      ULB_LE3
        JNZ     ULB_GE4
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #0B8H
        JC      ULB_LE3
ULB_GE4:
        MOV     A, #4
        LJMP    ULB_IDX

ULB_LE3:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #007H
        JC      ULB_LE2
        JNZ     ULB_GE3
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #0D0H
        JC      ULB_LE2
ULB_GE3:
        MOV     A, #3
        LJMP    ULB_IDX

ULB_LE2:
        MOV     A, LIDHI
        CLR     C
        SUBB    A, #003H
        JC      ULB_LE1
        JNZ     ULB_GE2
        MOV     A, LIDLO
        CLR     C
        SUBB    A, #0E8H
        JC      ULB_LE1
ULB_GE2:
        MOV     A, #2
        LJMP    ULB_IDX

ULB_LE1:
        MOV     A, LIDHI
        ORL     A, LIDLO
        JZ      ULB_ZERO
        MOV     A, #1
        LJMP    ULB_IDX
ULB_ZERO:
        MOV     A, #0

ULB_IDX:
        MOV     DPTR, #LED_BAR_TAB
        MOVC    A, @A+DPTR
        MOV     LEDREG, A
        XRL     A, LASTBAR
        JZ      ULB_RET
        MOV     A, LEDREG
        MOV     LASTBAR, A
        LCALL   SHIFT_LED_BAR
ULB_RET:
        RET

SHIFT_LED_BAR:
        CLR     EA              ; 移位时暂关中断，避免时钟被打断
        MOV     A, LEDREG
        MOV     R0, #8
SLB_LP:
        MOV     C, ACC7
        MOV     P3_3, C
        SETB    P3_4
        NOP
        CLR     P3_4
        RL      A
        DJNZ    R0, SLB_LP
        SETB    EA
        RET

BEEP_LONG:
        MOV     BUZZLO, #0E8H   ; 1000ms = 03E8H
        MOV     BUZZHI, #003H
        SETB    P3_1
        RET

;---------------- 查表 ----------------
LED_BAR_TAB:
        DB      0FFH,0FEH,0FCH,0F8H,0F0H,0E0H,0C0H,080H,000H

SEG_TAB:
        DB      0FCH,060H,0DAH,0F2H,066H,0B6H,0BEH,0E0H,0FEH,0F6H

; row*4+col 到 PDF 键号 K0~K15 的映射。
; 行：K0.0~K0.3，对应 P2.0~P2.3；
; 列：K1.0~K1.3，对应 P2.4~P2.7。
; PDF 键号按列排列：第一列 K0/K1/K2/K3，第二列 K4/K5/K6/K7。
; 因此 F1~F4 使用 K10/K11/K12/K13，F5 使用 K14，F6 使用 K15。
KEY_REMAP_TAB:
        DB      0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15

        END
