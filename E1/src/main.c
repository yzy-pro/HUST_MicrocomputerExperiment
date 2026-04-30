/**
 * CPU: AT89S52
 * Freq: 12MHz
 *
 * 基本要求:
 * - P2.7~P2.4: 按键输入，低电平表示按下
 * - P1.0~P1.3: 盖板控制，1=关闭，0=打开
 * - 选中的盖板打开 8 秒后自动关闭
 *
 * 扩展功能:
 * - R0~R3 存放四个垃圾桶剩余容量（上电随机 0~9）
 * - 每次成功投放后，对应容量减 1
 * - 满载标志字节在 IRAM 0x20，bit0~bit3 对应 bin0~bin3
 * - 若容量为 0，则置满载标志并拒绝开盖
 */

void main(void) __naked
{
        __asm;
        初始化：默认全部盖板关闭
        mov 0x90, #0xFF;
        P1 = 0xFF，P1.0 ~P1.3 输出高电平(1 = 关盖)

            ;
        满载标志清零（IRAM 0x20 的 bit0 ~bit3）
            mov 0x20,
            #0x00;
        0x20 < -0，表示四个桶初始都未满 lcall UPDATE_FULL_LED;
        立即把满载标志同步到 P3.0 ~P3.3 指示灯

            ;
        启动 T0 作为伪随机种子来源
            mov 0x89,
            #0x01;
        TMOD = 0x01，定时器0工作在模式1(16位定时 / 计数)
            setb 0x8C;
        TR0 = 1，启动 T0 计数，让 TL0 / TH0 持续变化

            ;
        生成四个桶的初始容量到 R0 ~R3（范围 0 ~9） lcall RAND_0_9;
        调用随机子程序，返回值在 A
            mov R0,
            A;
        R0 < -A，保存 bin0 初始容量
                 lcall RAND_0_9;
        再次生成随机数
        mov R1, A;
        R1 < -A，保存 bin1 初始容量
                 lcall RAND_0_9;
        再次生成随机数
        mov R2, A;
        R2 < -A，保存 bin2 初始容量
                 lcall RAND_0_9;
        再次生成随机数
        mov R3, A;
        R3 < -A，保存 bin3 初始容量

                 MAIN_LOOP :;
        按键扫描优先级：P2.7->P2.4（高位优先） jnb 0xA7, KEY_BIN0;
        若 P2.7 = 0(按下)则跳转处理 bin0
            jnb 0xA6,
           KEY_BIN1;
        否则若 P2.6 = 0(按下)则处理 bin1
            jnb 0xA5,
               KEY_BIN2;
        否则若 P2.5 = 0(按下)则处理 bin2
            jnb 0xA4,
               KEY_BIN3;
        否则若 P2.4 = 0(按下)则处理 bin3
            ljmp MAIN_LOOP;
        无按键按下则长跳回主循环继续轮询

KEY_BIN0:
        ljmp TRY_BIN0;
        路由到 bin0 的具体处理流程
            KEY_BIN1 : ljmp TRY_BIN1;
        路由到 bin1 的具体处理流程
            KEY_BIN2 : ljmp TRY_BIN2;
        路由到 bin2 的具体处理流程
            KEY_BIN3 : ljmp TRY_BIN3;
        路由到 bin3 的具体处理流程

            TRY_BIN0 : mov A,
                       0x20;
        A < -满载标志字节(0x20)
                anl A,
            #0x01;
        仅保留 bit0，检查 bin0 是否已满
            jnz BIN0_DENY;
        若 bit0 != 0，说明已满，跳到拒绝流程 mov A, R0;
        A < -R0，读取 bin0 当前剩余容量
                jz BIN0_MARK_FULL;
        若 A = 0，容量已空，转去置满标志 dec R0;
        R0 = R0 - 1，成功投放一次，容量减 1 mov A, R0;
        A < -R0，检查减 1 后是否变成 0 jnz BIN0_OPEN;
        若仍非 0，直接开盖流程 orl 0x20, #0x01;
        若刚好减到 0，置 0x20 的 bit0 = 1(标记满载)
            lcall UPDATE_FULL_LED;
        更新 LED，使满载状态可视化
            BIN0_OPEN : anl 0x90,
                        #0xFE;
        P1 &= 11111110b，清 P1.0 = 0，打开 bin0 盖板
            lcall DELAY_8S;
        调用 8 秒延时，保持开盖状态
            orl 0x90,
            #0x01;
        P1 |= 00000001b，置 P1.0 = 1，关闭 bin0 盖板
            lcall WAIT_RELEASE;
        等待按键释放，避免一次按下被重复触发
        ljmp MAIN_LOOP;
        返回主循环继续扫描按键
BIN0_MARK_FULL:
        orl 0x20, #0x01;
        发现容量已 0，直接置 bit0 满载标志
            lcall UPDATE_FULL_LED;
        同步满载标志到 P3 指示灯
            BIN0_DENY : lcall WAIT_RELEASE;
        拒绝开盖时同样等待按键松开
        ljmp MAIN_LOOP;
        回到主循环

TRY_BIN1:
        mov A, 0x20;
        A < -满载标志字节
                anl A,
            #0x02;
        提取 bit1，检查 bin1 是否已满
            jnz BIN1_DENY;
        bit1 = 1 时拒绝开盖
            mov A,
        R1;
        A < -R1，读取 bin1 剩余容量
                jz BIN1_MARK_FULL;
        容量 = 0，转去置满标志 dec R1;
        成功投放后，bin1 容量减 1 mov A, R1;
        A < -R1，检查是否减到 0 jnz BIN1_OPEN;
        非 0 则直接开盖
            orl 0x20,
            #0x02;
        若变 0，则置 bit1 满载标志
            lcall UPDATE_FULL_LED;
        更新满载 LED 显示
            BIN1_OPEN : anl 0x90,
                        #0xFD;
        P1 &= 11111101b，清 P1.1 = 0，打开 bin1 盖板
            lcall DELAY_8S;
        保持开盖 8 秒
            orl 0x90,
            #0x02;
        P1 |= 00000010b，置 P1.1 = 1，关闭 bin1 盖板
            lcall WAIT_RELEASE;
        等按键释放后再返回
        ljmp MAIN_LOOP;
        回主循环
BIN1_MARK_FULL:
        orl 0x20, #0x02;
        置 bit1，标记 bin1 满载
            lcall UPDATE_FULL_LED;
        刷新 LED 状态
            BIN1_DENY : lcall WAIT_RELEASE;
        拒绝时防抖 / 防连发
                         ljmp MAIN_LOOP;
        回主循环

TRY_BIN2:
        mov A, 0x20;
        A < -满载标志字节
                anl A,
            #0x04;
        提取 bit2，检查 bin2 满载状态
            jnz BIN2_DENY;
        bit2 = 1 则已满，拒绝开盖
            mov A,
        R2;
        A < -R2，读取 bin2 剩余容量
                jz BIN2_MARK_FULL;
        容量为 0 则置满标志
            dec R2;
        容量减 1，记录本次投放 mov A, R2;
        A < -R2，检查是否归零
                jnz BIN2_OPEN;
        未归零则开盖
        orl 0x20, #0x04;
        归零则置 bit2 满载标志
            lcall UPDATE_FULL_LED;
        刷新 LED
            BIN2_OPEN : anl 0x90,
                        #0xFB;
        P1 &= 11111011b，清 P1.2 = 0，打开 bin2 盖板
            lcall DELAY_8S;
        延时 8 秒
            orl 0x90,
            #0x04;
        P1 |= 00000100b，置 P1.2 = 1，关闭 bin2 盖板
            lcall WAIT_RELEASE;
        等待按键释放
        ljmp MAIN_LOOP;
        返回主循环
BIN2_MARK_FULL:
        orl 0x20, #0x04;
        置 bit2，标记 bin2 已满
            lcall UPDATE_FULL_LED;
        更新 LED
            BIN2_DENY : lcall WAIT_RELEASE;
        拒绝后等待松键
        ljmp MAIN_LOOP;
        回主循环

TRY_BIN3:
        mov A, 0x20;
        A < -满载标志字节
                anl A,
            #0x08;
        提取 bit3，检查 bin3 满载状态
            jnz BIN3_DENY;
        bit3 = 1 说明已满，拒绝开盖
            mov A,
        R3;
        A < -R3，读取 bin3 容量
                jz BIN3_MARK_FULL;
        若容量为 0，直接置满标志 dec R3;
        成功投放一次，容量减 1 mov A, R3;
        A < -R3，检查是否减到 0 jnz BIN3_OPEN;
        若非 0，执行开盖流程 orl 0x20, #0x08;
        若为 0，置 bit3 满载标志
            lcall UPDATE_FULL_LED;
        刷新满载 LED
            BIN3_OPEN : anl 0x90,
                        #0xF7;
        P1 &= 11110111b，清 P1.3 = 0，打开 bin3 盖板
            lcall DELAY_8S;
        保持开盖 8 秒
            orl 0x90,
            #0x08;
        P1 |= 00001000b，置 P1.3 = 1，关闭 bin3 盖板
            lcall WAIT_RELEASE;
        等待按键释放
        ljmp MAIN_LOOP;
        回主循环
BIN3_MARK_FULL:
        orl 0x20, #0x08;
        置 bit3，标记 bin3 满载
            lcall UPDATE_FULL_LED;
        更新 LED
            BIN3_DENY : lcall WAIT_RELEASE;
        拒绝时等待按键松开
        ljmp MAIN_LOOP;
        回主循环

RAND_0_9:;
        随机子程序：读取 T0 计数并做轻量扰动，最后压缩到 0 ~9 mov A, 0x8A;
        A < -TL0，取定时器0低字节作为动态源
                xrl A,
            0x8C;
        A ^= TH0，把高字节混入，增强变化
            xrl A,
            #0x5A;
        A ^= 0x5A，与常量异或打散位分布 rl A;
        A 循环左移 1 位，重排位权
            xrl A,
            #0x1D;
        再次与常量异或，进一步扰动
        rr A;
        A 循环右移 1 位，继续重排
            anl A,
            #0x1F;
        A &= 0x1F，先限制到 0..31 RAND_MOD10 : clr C;
        C = 0，确保后续 SUBB 仅做 A - 10（不额外减借位） subb A, #10;
        A = A - 10，尝试做模10的重复减法 jnc RAND_MOD10;
        若无借位(C = 0，表示 A 原本 >= 10)，继续减
            add A,
            #10;
        出现借位说明减过头，A += 10 回到 0..9 ret;
        返回，A 中即随机结果 0..9

            UPDATE_FULL_LED :;
        子程序：把 0x20 的 bit0 ~bit3 镜像到 P3.0 ~P3.3（高四位保持不变） mov A, 0x20;
        A < -满载标志字节
                anl A,
            #0x0F;
        仅保留低四位（四个桶的满载位）
        mov 0x21, A;
        暂存到 0x21，避免覆盖 mov A, 0xB0;
        A < -P3 当前端口值
                anl A,
            #0xF0;
        清除低四位，只保留高四位原状态
        orl A, 0x21;
        把新的低四位满载标志并入 A
            mov 0xB0,
            A;
        写回 P3，实现 LED 更新
            ret;
        子程序返回

DELAY_8S:;
        8 秒延时：80 次调用 100ms 延时
            mov R7,
            #80;
        R7 < -80，作为外层计数器 DELAY_8S_LOOP : lcall DELAY_100MS;
        每次循环延时约 100ms djnz R7, DELAY_8S_LOOP;
        R7--，非 0 则继续循环
            ret;
        累计约 8s 后返回

            DELAY_100MS :;
        粗略 100ms 延时（12MHz 下通过双层循环 + NOP 标定）
                                                    mov R5,
            #166;
        外层循环计数
D100_OUTER:
        mov R6, #200;
        内层循环计数
D100_INNER:
        nop;
        空操作，占用 1 个机器周期用于延时
            djnz R6,
            D100_INNER;
        R6--，非 0 则继续内层循环
            djnz R5,
            D100_OUTER;
        R5--，非 0 则重装内层继续
            ret;
        双层循环结束，返回

WAIT_RELEASE:;
        等待按键全部释放（P2.7 ~P2.4 都应为高电平）
            mov A,
            0xA0;
        A < -P2 端口当前值
                anl A,
            #0xF0;
        仅保留高四位（按键输入位）
        cjne A, #0xF0, WAIT_RELEASE;
        只要不全为1(仍有按下)
        就继续等待
            ret;
        全部释放后返回
        __endasm;
}
