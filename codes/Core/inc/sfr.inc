;--------------------------------------------------------
; C8051F310 特殊功能寄存器定义（sdas8051 语法）
;--------------------------------------------------------

; 标准 8051 特殊功能寄存器
P0      = 0x80
SP      = 0x81
DPL     = 0x82
DPH     = 0x83
PCON    = 0x87
TCON    = 0x88
TMOD    = 0x89
TL0     = 0x8A
TL1     = 0x8B
TH0     = 0x8C
TH1     = 0x8D
P1      = 0x90
SCON    = 0x98
SBUF    = 0x99
P2      = 0xA0
IE      = 0xA8
P3      = 0xB0
IP      = 0xB8
PSW     = 0xD0
ACC     = 0xE0
B       = 0xF0

; P0 位地址
P0_0    = 0x80
P0_1    = 0x81
P0_2    = 0x82
P0_3    = 0x83
P0_4    = 0x84
P0_5    = 0x85
P0_6    = 0x86
P0_7    = 0x87

; P3 位地址
P3_0    = 0xB0
P3_1    = 0xB1
P3_2    = 0xB2
P3_3    = 0xB3
P3_4    = 0xB4
P3_5    = 0xB5
P3_6    = 0xB6
P3_7    = 0xB7

; IE 中断允许寄存器位地址
EX0     = 0xA8
ET0     = 0xA9
EX1     = 0xAA
ET1     = 0xAB
ES      = 0xAC
ET2     = 0xAD
EA      = 0xAF

; TCON 定时/中断控制寄存器位地址
IT0     = 0x88
IE0     = 0x89
IT1     = 0x8A
IE1     = 0x8B
TR0     = 0x8C
TF0     = 0x8D
TR1     = 0x8E
TF1     = 0x8F

; C8051F310 扩展特殊功能寄存器
PCA0MD  = 0xD9
P0MDOUT = 0xA4
P1MDOUT = 0xA5
P2MDOUT = 0xA6
P3MDOUT = 0xA7
P2MDIN  = 0xF3
XBR1    = 0xE2
OSCICN  = 0xB2

; 便于阅读的硬件别名
D9_LED  = P0_0      ; P0.0，低电平点亮
BUZZER  = P3_1      ; P3.1，高电平鸣响
LEDDAT  = P3_3      ; P3.3，74HCT164 数据线
LEDCLK  = P3_4      ; P3.4，74HCT164 时钟线
