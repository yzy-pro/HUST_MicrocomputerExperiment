;--------------------------------------------------------
; init.asm — MCU 硬件初始化与程序入口
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module init

    .globl START
    .globl MAIN_LOOP

    .area INIT_CODE (CODE)

START:
    ; 关闭看门狗（PCA0MD.6 = 0）
    anl  PCA0MD, #0xBF
    mov  PCA0MD, #0x00

    ; 内部振荡器 24.5 MHz
    mov  OSCICN, #0x83

    ; 端口输出模式：
    ;   P0：P0.0(D9) + P0.6/P0.7(数码管位选) 推挽输出
    ;   P1：全部推挽输出（数码管段选）
    ;   P2：P2.0-P2.3 推挽输出（键盘行），P2.4-P2.7 开漏输入（键盘列）
    ;   P3：P3.1(蜂鸣器) + P3.3(DATA) + P3.4(CLK) 推挽输出
    mov  P0MDOUT, #0xC1     ; P0.7、P0.6、P0.0
    mov  P1MDOUT, #0xFF
    mov  P2MDOUT, #0x0F
    mov  P3MDOUT, #0x1A     ; P3.4、P3.3、P3.1

    ; P2 列输入使用数字输入
    mov  P2MDIN,  #0xFF

    ; 使能交叉开关
    mov  XBR1, #0x40

    ; 初始端口状态
    setb D9_LED             ; D9 熄灭（低电平点亮）
    clr  BUZZER             ; 蜂鸣器关闭
    mov  P2, #0xFF          ; 所有键盘行释放为高电平

    ; Timer0 模式 1（16 位），时钟为 SYSCLK/12
    anl  TMOD, #0xF0
    orl  TMOD, #0x01
    mov  TH0, #0xF8         ; 24.5MHz/12 下 1ms 重装值
    mov  TL0, #0x06

    ; INT0 下降沿触发
    setb IT0

    ; 使能 Timer0 中断、INT0 中断和总中断
    setb ET0
    setb EX0
    setb EA

    ; 启动 Timer0
    setb TR0

    ; 初始化内部 RAM 状态
    mov  LIDOPEN, #0x00
    mov  SELBIN,  #0xFF
    mov  FULLBIN, #0xFF
    mov  ERRBIN,  #0xFF
    mov  LIDLO,   #0x00
    mov  LIDHI,   #0x00
    mov  BLKDIV,  #0x00
    mov  BLKFLG,  #0x00
    mov  HINTLO,  #0x00
    mov  HINTHI,  #0x00
    mov  KEYLAST, #0xFF
    mov  CALCMODE,  #0x00
    mov  CALCSTATE, #0x00
    mov  CALCOP,    #0x00
    mov  OP1,       #0x00
    mov  OP2,       #0x00
    mov  DIGCNT,    #0x00
    mov  CALCNEG,   #0x00
    mov  RESLO,     #0x00
    mov  RESHI,     #0x00
    mov  CALCD0,    #0x0A
    mov  CALCD1,    #0x0A
    mov  CALCD2,    #0x0A
    mov  CALCD3,    #0x0A

    ; 生成伪随机种子：先刷新显示 60 次，再读取 TL0^TH0^P2
    mov  CNT, #60
    
SEED_SPIN:
    lcall REFRESH_ALL
    djnz CNT, SEED_SPIN

    mov  A, TL0
    xrl  A, TH0
    xrl  A, P2

    ; 用简单 LCG 步进从种子生成 CAP0..CAP3
    mov  B, #10
    div  AB
    mov  CAP0, B            ; CAP0 = seed % 10

    mov  A, B
    mov  B, #17
    mul  AB
    add  A, #31
    mov  B, #10
    div  AB
    mov  CAP1, B

    mov  A, B
    mov  B, #13
    mul  AB
    add  A, #7
    mov  B, #10
    div  AB
    mov  CAP2, B

    mov  A, B
    mov  B, #11
    mul  AB
    add  A, #9
    mov  B, #10
    div  AB
    mov  CAP3, B

    ; 初始化流水灯（全灭）
    mov  LEDREG,  #0xFF
    mov  LASTBAR, #0xFF
    lcall SHIFT_LED_BAR

    ljmp MAIN_LOOP
