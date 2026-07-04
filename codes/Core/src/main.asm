;--------------------------------------------------------
; main.asm — 主循环与垃圾桶状态机
;
; 按键逻辑：
;   K10-K13（F1-F4）选择 0-3 号垃圾桶
;   桶满（容量为 0）时蜂鸣 1 秒，并显示 F
;   桶未满且桶盖关闭时，开盖 8 秒，D9 点亮
;   开盖期间按同一个 F 键或 K1-K9 进行投放
;   Kint 键提前关盖，由 EXT0_ISR 处理
;   K15（F6）为物业清空，将所有容量恢复为 9
;   K14（F5）进入计算器模式，Kint 退出计算器模式
;
; SCAN_KEY 返回 reference.asm 中的 PDF 键号：
;   K0-K9 为数字键，K10-K13 为 F1-F4，K14 为 F5，K15 为 F6
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module main

    .globl MAIN_LOOP
    .globl ENTER_CALC
    .globl CALC_HANDLE_KEY

    .area MAIN_CODE (CODE)

;--------------------------------------------------------
; 主循环
;--------------------------------------------------------
MAIN_LOOP:
    lcall UPDATE_LED_BAR

    ; 每次键盘扫描之间刷新显示约 40 次（约 40ms）
    mov  CNT, #40
ML_REFRESH:
    lcall REFRESH_ALL
    djnz CNT, ML_REFRESH

    lcall SCAN_KEY          ; A = 重映射后的 PDF 键号，0xFF 表示无键
    mov  KEYNOW, A

    cjne A, #0xFF, ML_HAS_KEY
    mov  KEYLAST, #0xFF
    sjmp MAIN_LOOP

ML_HAS_KEY:
    ; 边沿检测：忽略持续按住的按键
    mov  A, KEYNOW
    cjne A, KEYLAST, ML_NEW_KEY
    sjmp MAIN_LOOP

ML_NEW_KEY:
    mov  KEYLAST, A

    ; 计算器模式下，键盘改由计算器状态机解释。
    mov  A, CALCMODE
    jz   ML_NORMAL_KEY
    lcall CALC_HANDLE_KEY
    sjmp MAIN_LOOP

ML_NORMAL_KEY:
    mov  A, KEYNOW

    ; K15/F6：物业清空所有垃圾桶
    cjne A, #15, ML_CHECK_CAT
    lcall PROP_CLEAR
    sjmp MAIN_LOOP

ML_CHECK_CAT:
    ; K14/F5：进入计算器模式
    mov  A, KEYNOW
    cjne A, #14, ML_CHECK_NUM
    lcall ENTER_CALC
    sjmp MAIN_LOOP

ML_CHECK_NUM:
    ; K1-K9：批量投放袋数，仅在开盖时有效。
    ; K0 不作为投放数量。
    mov  A, KEYNOW
    jz   MAIN_LOOP
    clr  C
    subb A, #10
    jnc  ML_CHECK_FUNC
    lcall HANDLE_NUMBER
    sjmp MAIN_LOOP

ML_CHECK_FUNC:
    ; K10-K13/F1-F4：减 10 得到按键序号，再按数码管位选方向换算桶号。
    mov  A, KEYNOW
    clr  C
    subb A, #10
    mov  TMP, A
    clr  C
    subb A, #4
    jc   ML_CAT_KEY
    sjmp MAIN_LOOP

ML_CAT_KEY:
    mov  A, #3
    clr  C
    subb A, TMP
    mov  TMP, A
    lcall HANDLE_CATEGORY
    sjmp MAIN_LOOP

;--------------------------------------------------------
; HANDLE_CATEGORY — 处理 F1-F4 分类键，TMP 中为桶号
;--------------------------------------------------------
HANDLE_CATEGORY:
    ; 判断桶盖是否已经打开
    mov  A, LIDOPEN
    jz   HC_LID_CLOSED

    ; 桶盖已打开时，只有再次按同一类才投放 1 袋
    mov  A, TMP
    cjne A, SELBIN, HC_RET
    mov  R2, #1
    lcall HANDLE_BAGS
HC_RET:
    ret

HC_LID_CLOSED:
    ; 检查容量
    lcall GET_CAP           ; A = TMP 对应桶的容量
    jnz  HC_OPEN_LID

    ; 桶满：蜂鸣并显示 F 约 1 秒
    lcall FULL_ALERT
    ret

HC_OPEN_LID:
    ; 选中桶未满：开盖并启动 8 秒倒计时
    mov  A, TMP
    mov  SELBIN, A
    mov  FULLBIN, #0xFF
    mov  ERRBIN,  #0xFF
    mov  LIDOPEN, #1
    clr  EA
    mov  LIDLO,  #0x40      ; 8000ms = 0x1F40
    mov  LIDHI,  #0x1F
    setb EA
    mov  BLKDIV, #0
    mov  BLKFLG, #0
    clr  D9_LED             ; D9 点亮
    ret

;--------------------------------------------------------
; HANDLE_NUMBER — 处理 K1-K9 批量投放，KEYNOW 中为袋数
;--------------------------------------------------------
HANDLE_NUMBER:
    mov  A, LIDOPEN
    jz   HN_RET
    mov  A, SELBIN
    cjne A, #0xFF, HN_HAVE_BIN
    ret
HN_HAVE_BIN:
    mov  A, KEYNOW
    mov  R2, A
    lcall HANDLE_BAGS
HN_RET:
    ret

;--------------------------------------------------------
; HANDLE_BAGS — 若容量足够，向 SELBIN 投放 R2 袋。
; 容量不足时显示 E、蜂鸣并立即关盖。
;--------------------------------------------------------
HANDLE_BAGS:
    mov  A, SELBIN
    cjne A, #0xFF, HB_HAVE_BIN
    ret
HB_HAVE_BIN:
    mov  R3, A              ; 保存桶号
    add  A, #CAP0
    mov  R0, A
    mov  A, @R0
    clr  C
    subb A, R2
    jc   HB_ERROR
    mov  @R0, A
    mov  FULLBIN, #0xFF
    mov  ERRBIN,  #0xFF
    ret
HB_ERROR:
    mov  A, R3
    mov  ERRBIN, A
    mov  FULLBIN, #0xFF
    clr  EA
    mov  HINTLO, #0xE8
    mov  HINTHI, #0x03
    setb EA
    setb BUZZER
    mov  LIDOPEN, #0
    mov  SELBIN,  #0xFF
    mov  LIDLO,   #0
    mov  LIDHI,   #0
    setb D9_LED
    ret

;--------------------------------------------------------
; GET_CAP — 读取 TMP 指定桶的容量
; 返回：A = 容量（0-9）
;--------------------------------------------------------
GET_CAP:
    mov  A, TMP
    cjne A, #0, GC1
    mov  A, CAP0
    ret
GC1:
    cjne A, #1, GC2
    mov  A, CAP1
    ret
GC2:
    cjne A, #2, GC3
    mov  A, CAP2
    ret
GC3:
    mov  A, CAP3
    ret

;--------------------------------------------------------
; FULL_ALERT — 蜂鸣约 1 秒，并在 TMP 指定数码管显示 F
;--------------------------------------------------------
FULL_ALERT:
    mov  A, TMP
    mov  FULLBIN, A
    mov  ERRBIN, #0xFF
    setb BUZZER
    clr  EA
    mov  HINTLO, #0xE8      ; 1000ms = 0x03E8
    mov  HINTHI, #0x03
    setb EA
    ret

;--------------------------------------------------------
; PROP_CLEAR — F6：所有垃圾桶容量恢复为 9
;--------------------------------------------------------
PROP_CLEAR:
    mov  CAP0, #9
    mov  CAP1, #9
    mov  CAP2, #9
    mov  CAP3, #9
    mov  FULLBIN, #0xFF
    mov  ERRBIN,  #0xFF
    mov  LIDOPEN, #0
    mov  SELBIN,  #0xFF
    mov  LIDLO,   #0
    mov  LIDHI,   #0
    setb D9_LED
    mov  LEDREG,  #0xFF
    mov  LASTBAR, #0
    lcall SHIFT_LED_BAR
    setb BUZZER
    clr  EA
    mov  HINTLO, #0xE8
    mov  HINTHI, #0x03
    setb EA
    ret
