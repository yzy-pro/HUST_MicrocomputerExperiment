;--------------------------------------------------------
; 内部 RAM 符号定义（各模块共享）
;--------------------------------------------------------

; 四个垃圾桶剩余容量（每个 0-9）
CAP0    = 0x30
CAP1    = 0x31
CAP2    = 0x32
CAP3    = 0x33

; 键盘扫描状态
KEYNOW  = 0x34
KEYLAST = 0x35
ROWIDX  = 0x36

; 通用临时变量和循环计数
TMP     = 0x37
CNT     = 0x38

; 流水灯状态（D1-D8 经 74HCT164 驱动，1=灭，0=亮）
LEDREG  = 0x39
LASTBAR = 0x3B

; 桶盖倒计时（16 位，单位 ms，由 Timer0 中断递减）
LIDLO   = 0x42
LIDHI   = 0x43

; 5 Hz 闪烁状态
BLKDIV  = 0x44      ; 每 1ms 递增，到 100 后清零
BLKFLG  = 0x45      ; 每 100ms 翻转一次（0 或 1）

; 报警倒计时（16 位，单位 ms，用于驱动蜂鸣器约 1 秒）
HINTLO  = 0x46
HINTHI  = 0x47

; 系统状态
LIDOPEN = 0x4D      ; 0=关闭，1=打开
SELBIN  = 0x4E      ; 当前打开的桶号（0-3），0xFF=无
FULLBIN = 0x4F      ; 当前显示 F 的桶号，0xFF=无
ERRBIN  = 0x50      ; 当前显示 E 的桶号，0xFF=无

; 计算器模式状态
CALCMODE  = 0x51    ; 0=垃圾投放模式，1=计算器模式
CALCSTATE = 0x52    ; 0=输入操作数1，1=已选运算符，2=输入操作数2，3=显示结果
CALCOP    = 0x53    ; 1=加，2=减，3=乘，4=除
OP1       = 0x54
OP2       = 0x55
DIGCNT    = 0x56    ; 当前操作数已输入位数（0-2）
CALCNEG   = 0x57    ; 结果是否为负
RESLO     = 0x58
RESHI     = 0x59
CALCD0    = 0x5A    ; 计算器显示缓存：0-9 数字，0x0A=空白，0x0B='-'，0x0C='E'
CALCD1    = 0x5B
CALCD2    = 0x5C
CALCD3    = 0x5D
