    ORG 0000H
    LJMP MAIN

    ORG 0030H
MAIN:
    MOV SP, #5FH
    ; 初始化显示缓存：默认全灭。共阴极时 0x00 为熄灭
    MOV 40H, #SEG_OFF   ; 第1位显示数据
    MOV 41H, #SEG_OFF   ; 第2位显示数据
    MOV 42H, #SEG_OFF   ; 第3位显示数据
    MOV 43H, #SEG_OFF   ; 第4位显示数据
    MOV 44H, #00H       ; K0按下标志

    ; 段码按接线映射：P1.7=A ... P1.0=DP
    ; 若为共阳极，请把段码与 SEG_OFF 全部按位取反
SEG_S   EQU 0B6H
SEG_O   EQU 0FCH
SEG_E   EQU 09EH
SEG_I   EQU 060H
SEG_OFF EQU 000H
    
MAIN_LOOP:
    LCALL KEY_SCAN    ; 扫描键盘并更新显示缓存
    LCALL DISPLAY     ; 动态刷新一次数码管
    LJMP MAIN_LOOP


; 键盘扫描子程序 (结合基本与提高要求)
; 键盘接在P2口：P2.0~2.3为行，P2.4~2.7为列
; 这里将 K0, K1, K2, K3 定义为按键 1, 2, 3, 4
KEY_SCAN:
    ; 扫描第1行 (P2.0 = 0)
    MOV P2, #0FEH
    NOP
    NOP
    MOV A, P2
    JNB ACC.4, KEY_4_PRESSED   ; K0被按下 -> 1
    JNB ACC.5, KEY_3_PRESSED   ; K4被按下 -> 2
    JNB ACC.6, KEY_2_PRESSED   ; K8被按下 -> 3
    JNB ACC.7, KEY_1_PRESSED   ; K12被按下 -> 4
    ; 无按键按下则直接返回（保持当前显示）
    RET

KEY_1_PRESSED:
    ; K0 -> 清零后显示第1位 S
    MOV 40H, #SEG_OFF
    MOV 41H, #SEG_OFF
    MOV 42H, #SEG_OFF
    MOV 43H, #SEG_OFF

    MOV 40H, #SEG_S
    MOV 44H, #01H
    RET

KEY_2_PRESSED:
    ; K4 -> 清零后显示第1、2位 S O
    MOV 40H, #SEG_OFF
    MOV 41H, #SEG_OFF
    MOV 42H, #SEG_OFF
    MOV 43H, #SEG_OFF

    MOV 44H, #00H
    MOV 40H, #SEG_S
    MOV 41H, #SEG_O
    RET

KEY_3_PRESSED:
    ; K8 -> 清零后显示第1、2、3位 S O E
    MOV 40H, #SEG_OFF
    MOV 41H, #SEG_OFF
    MOV 42H, #SEG_OFF
    MOV 43H, #SEG_OFF
    MOV 44H, #00H
    MOV 40H, #SEG_S
    MOV 41H, #SEG_O
    MOV 42H, #SEG_E
    RET

KEY_4_PRESSED:
    ; K12 -> 清零后显示第1~4位 S O E I（最终稳定显示）
    MOV 40H, #SEG_OFF
    MOV 41H, #SEG_OFF
    MOV 42H, #SEG_OFF
    MOV 43H, #SEG_OFF
    MOV A, 44H
    JZ K12_NO_DELAY
    MOV 44H, #00H
    LCALL STEP_DELAY
    MOV 40H, #SEG_S
    LCALL STEP_DELAY

    MOV 41H, #SEG_O
    LCALL STEP_DELAY

    MOV 42H, #SEG_E
    LCALL STEP_DELAY

    MOV 43H, #SEG_I
    LCALL STEP_DELAY
    LCALL STEP_DELAY
    LCALL STEP_DELAY
    LCALL STEP_DELAY
    LCALL STEP_DELAY
    MOV 40H, #SEG_OFF
    MOV 41H, #SEG_OFF
    MOV 42H, #SEG_OFF
    MOV 43H, #SEG_OFF
    RET

K12_NO_DELAY:
    MOV 44H, #00H
    MOV 40H, #SEG_S
    MOV 41H, #SEG_O
    MOV 42H, #SEG_E
    MOV 43H, #SEG_I
    RET

; 数码管动态显示子程序
; 位选由 P0.6, P0.7 控制 (74HC139译码输出Y0~Y3)
; 00->第1位，01->第2位，10->第3位，11->第4位
; 段选由 P1 口控制 (共阴极，1亮0灭)
DISPLAY:
    ;第1位
    MOV P1, #SEG_OFF   ; 先消隐
    MOV A, P0
    ANL A, #03FH       ; 清零 P0.6, P0.7 (编码00)
    MOV P0, A
    MOV P1, 40H        ; 送段码
    LCALL DELAY_1MS

    ;第2位
    MOV P1, #SEG_OFF   ; 先消隐
    MOV A, P0
    ANL A, #03FH
    ORL A, #40H        ; P0.6=1, P0.7=0 (编码01)
    MOV P0, A
    MOV P1, 41H
    LCALL DELAY_1MS

    ;第3位
    MOV P1, #SEG_OFF   ; 先消隐
    MOV A, P0
    ANL A, #03FH
    ORL A, #80H        ; P0.6=0, P0.7=1 (编码10)
    MOV P0, A
    MOV P1, 42H
    LCALL DELAY_1MS

    ;第4位
    MOV P1, #SEG_OFF   ; 先消隐
    MOV A, P0
    ANL A, #03FH
    ORL A, #0C0H       ; P0.6=1, P0.7=1 (编码11)
    MOV P0, A
    MOV P1, 43H
    LCALL DELAY_1MS

    RET

; 1ms 软件延时子程序 (适用于动态刷新)
DELAY_1MS:
    MOV R7, #10
D1: MOV R6, #50
    DJNZ R6, $
    DJNZ R7, D1
    RET

; 逐步点亮时的可见延时（保持动态刷新）
STEP_DELAY:
    MOV R5, #80
STEP_D1:
    LCALL DISPLAY
    DJNZ R5, STEP_D1
    RET

    END