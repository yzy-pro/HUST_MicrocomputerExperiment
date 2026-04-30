; 小区居民通过键入相应按键选择垃圾类型（分别用P2.4~P2.7端口模拟按键输入，低电平有效，P2.7=0、P2.6=0、P2.5=0、P2.4=0分别代表“塑料纸张”、“玻璃金属”、“厨余垃圾”和“危害垃圾”四类）。
; P1.0-P1.3四位代表垃圾桶盖开关控制，控制名为“塑料纸张”、“玻璃金属”、“厨余垃圾”和“危化品垃圾”四个垃圾桶盖，高电平为关闭状态，低电平为打开状态。 
; P3.0~P3.3：4 个满载指示灯输出
; R0~R3：4 个桶当前剩余容量（范围 0~9）
; 20H bit0~bit3：4 个桶的满载标志位（1=满载）

            ORG     0000H
            LJMP    START

START:
            ; 上电默认关闭全部盖板（P1.0~P1.3 置 1）
            MOV     P1, #0FFH

            ; 清空满载标志字节，并刷新到 P3 指示灯
            MOV     20H, #00H
            LCALL   UPDATE_FULL_LED

            ; 启动 T0 作为伪随机扰动源
            ; TMOD=01H -> 定时器0工作在模式1（16位）
            MOV     TMOD, #01H
            SETB    TR0

            ; 为 4 个桶生成初始容量（0~9）
            LCALL   RAND_0_9
            MOV     R0, A
            LCALL   RAND_0_9
            MOV     R1, A
            LCALL   RAND_0_9
            MOV     R2, A
            LCALL   RAND_0_9
            MOV     R3, A

MAIN_LOOP:
            ; 按键扫描
            JNB     P2.7, KEY_BIN0
            JNB     P2.6, KEY_BIN1
            JNB     P2.5, KEY_BIN2
            JNB     P2.4, KEY_BIN3
            SJMP    MAIN_LOOP

KEY_BIN0:
            LJMP    TRY_BIN0
KEY_BIN1:
            LJMP    TRY_BIN1
KEY_BIN2:
            LJMP    TRY_BIN2
KEY_BIN3:
            LJMP    TRY_BIN3

TRY_BIN0:
            ; 若 bin0 已满（bit0=1），拒绝开盖
            MOV     A, 20H
            ANL     A, #01H
            JNZ     BIN0_DENY

            ; 若容量已经是 0，则直接标记满载
            MOV     A, R0
            JZ      BIN0_MARK_FULL

            ; 成功投放一次，容量减 1
            DEC     R0
            MOV     A, R0
            JNZ     BIN0_OPEN

            ; 若减到 0，置满载标志并刷新 LED
            ORL     20H, #01H
            LCALL   UPDATE_FULL_LED

BIN0_OPEN:
            ; 开盖 8 秒后关盖
            ANL     P1, #0FEH
            LCALL   DELAY_8S
            ORL     P1, #01H
            LCALL   KEY_AUTO_RESET
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

BIN0_MARK_FULL:
            ORL     20H, #01H
            LCALL   UPDATE_FULL_LED

BIN0_DENY:
            ; 拒绝时也等待按键释放，避免连发
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

TRY_BIN1:
            ; 若 bin1 已满（bit1=1），拒绝开盖
            MOV     A, 20H
            ANL     A, #02H
            JNZ     BIN1_DENY

            ; 若容量已经是 0，则直接标记满载
            MOV     A, R1
            JZ      BIN1_MARK_FULL

            ; 成功投放一次，容量减 1
            DEC     R1
            MOV     A, R1
            JNZ     BIN1_OPEN

            ; 若减到 0，置满载标志并刷新 LED
            ORL     20H, #02H
            LCALL   UPDATE_FULL_LED

BIN1_OPEN:
            ; 开盖 8 秒后关盖
            ANL     P1, #0FDH
            LCALL   DELAY_8S
            ORL     P1, #02H
            LCALL   KEY_AUTO_RESET
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

BIN1_MARK_FULL:
            ORL     20H, #02H
            LCALL   UPDATE_FULL_LED

BIN1_DENY:
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

TRY_BIN2:
            MOV     A, 20H
            ANL     A, #04H
            JNZ     BIN2_DENY

            MOV     A, R2
            JZ      BIN2_MARK_FULL

            DEC     R2
            MOV     A, R2
            JNZ     BIN2_OPEN

            ORL     20H, #04H
            LCALL   UPDATE_FULL_LED

BIN2_OPEN:
            ANL     P1, #0FBH
            LCALL   DELAY_8S
            ORL     P1, #04H
            LCALL   KEY_AUTO_RESET
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

BIN2_MARK_FULL:
            ORL     20H, #04H
            LCALL   UPDATE_FULL_LED

BIN2_DENY:
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

TRY_BIN3:
            MOV     A, 20H
            ANL     A, #08H
            JNZ     BIN3_DENY

            MOV     A, R3
            JZ      BIN3_MARK_FULL

            DEC     R3
            MOV     A, R3
            JNZ     BIN3_OPEN

            ORL     20H, #08H
            LCALL   UPDATE_FULL_LED

BIN3_OPEN:
            ANL     P1, #0F7H
            LCALL   DELAY_8S
            ORL     P1, #08H
            LCALL   KEY_AUTO_RESET
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

BIN3_MARK_FULL:
            ORL     20H, #08H
            LCALL   UPDATE_FULL_LED

BIN3_DENY:
            LCALL   WAIT_RELEASE
            LJMP    MAIN_LOOP

; 伪随机子程序：返回 A=0~9
; 思路：使用 TL0/TH0 做扰动，做若干异或与移位后，采用重复减 10 得到模 10
RAND_0_9:
            MOV     A, TL0
            XRL     A, TH0
            XRL     A, #05AH
            RL      A
            XRL     A, #01DH
            RR      A
            ANL     A, #01FH

RAND_MOD10:
            CLR     C
            SUBB    A, #0AH
            JNC     RAND_MOD10
            ADD     A, #0AH
            RET

; 将 20H 的 bit0~bit3 同步到 P3.0~P3.3（P3 高四位保持原值）
UPDATE_FULL_LED:
            MOV     A, 20H
            ANL     A, #0FH
            MOV     21H, A

            MOV     A, P3
            ANL     A, #0F0H
            ORL     A, 21H
            MOV     P3, A
            RET

; 8 秒延时：80 次 100ms
DELAY_8S:
            MOV     R7, #80
DELAY_8S_LOOP:
            LCALL   DELAY_100MS
            DJNZ    R7, DELAY_8S_LOOP
            RET

; 粗略 100ms 延时（按 12MHz 经典 8051 估算）
DELAY_100MS:
            MOV     R5, #166
D100_OUTER:
            MOV     R6, #200
D100_INNER:
            NOP
            DJNZ    R6, D100_INNER
            DJNZ    R5, D100_OUTER
            RET

; 等待 P2.7~P2.4 全部释放（都为 1）
WAIT_RELEASE:
            MOV     A, P2
            ANL     A, #0F0H
            CJNE    A, #0F0H, WAIT_RELEASE
            RET

; 关盖后自动将按键输入位复位为高电平状态（释放 P2.7~P2.4）
KEY_AUTO_RESET:
            ORL     P2, #0F0H
            RET

            END
