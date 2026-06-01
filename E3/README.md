# 可回收垃圾分类系统设计

本工程提供两份汇编实现：

- `garbage_sort_f310.ASM`：面向 C8051F310 / Keil A51 的纯汇编提交文件，使用 `inc/C8051F310.INC` 和课程给的 F310 初始化风格。
- `src/main.c`：为了兼容仓库原来的 SDCC/EIDE 工程，保留一个最小 C 外壳，业务逻辑仍全部写在 `__asm/__endasm` 块内，可直接生成 `build/Debug/main.hex`。

## 默认端口映射

| 模块 | 端口 | 说明 |
| --- | --- | --- |
| 数码管段选 | P0 | 共阳段码，低电平点亮 |
| 数码管位选 | P2.0-P2.3 | 4 位动态扫描，低电平选通 |
| 蜂鸣器 | P2.7 | 低电平鸣叫 |
| 流水灯 D1-D8 | P1 | 8 秒开盖剩余时间进度条，低电平点亮 |
| Kint | P3.2 / INT0 | 下降沿外部中断，提前关盖 |
| F1-F4 | P3.4-P3.7 | 低电平有效，分别对应 4 类垃圾桶 |

如果实验板实际使用矩阵键盘，只需要按板卡原理图修改 `SCAN_KEYS` / `scan_keys` 子程序；其他状态机逻辑可以保持不变。

## 已实现功能

- 系统初始化后生成 4 个 0-9 的剩余容量，并显示在 4 个数码管上。
- 按 F1-F4 打开对应桶盖；容量为 0 时拒绝开盖，蜂鸣器响 1s，对应数码管显示 `F`。
- 桶盖打开后，对应数码管以 5Hz 闪烁，再次按同一个 F 键投递一袋，容量减 1。
- 每次开盖 8s 后自动关闭，P1 的 D1-D8 显示剩余时间进度条。
- 开盖期间按 Kint 触发 INT0 中断，可提前关闭桶盖。
- Timer0 每 1ms 中断一次：`garbage_sort_f310.ASM` 按 C8051F310 24.5MHz 内部振荡器计算为 `F806H`；`src/main.c` 兼容仓库原 12MHz SDCC 配置，重装值为 `FC18H`。

## 构建

Keil/A51 路线：把 `garbage_sort_f310.ASM` 与 `inc/C8051F310.INC` 放在同一工程中汇编即可。

SDCC/EIDE 路线：工程已将 SDCC 参数设为：

```text
--nooverlay --stack-auto --iram-size 256 --xram-size 0 --code-size 8192
```

也可以在命令行直接构建：

```bash
/home/yzy/.eide/tools/sdcc_mcs51/sdcc-4.5.0-with-binutils/bin/sdcc \
  --std-c99 -Iinc -Isrc -mmcs51 --opt-code-speed --nooverlay --stack-auto \
  --iram-size 256 --xram-size 0 --code-size 8192 --out-fmt-ihx \
  -o ./build/Debug/main.ihx ./src/main.c
```

生成的烧录文件为 `build/Debug/main.hex`。

### 构建注意事项（EIDE + SDCC 4.5）

当前 `unify_builder` 在本环境下会出现“编译成功但链接阶段不识别 `.rel`”的问题。为避免这个工具链兼容问题，已提供稳定流程：

- VSCode 任务：`build (sdcc-direct)`（见 `.vscode/tasks.json`）
- 或脚本：`bash ./scripts/post_build_sdcc.sh`

以上两种方式会直接调用 SDCC 一步完成编译链接，并同步输出 `build/Debug/main.hex` 与 `build/Debug/89c52_sdcc_demo.hex`。

## 烧录

已提供脚本：`scripts/flash.sh`

默认烧录（端口 `COM3`，文件 `build/Debug/main.hex`）：

```bash
bash ./scripts/flash.sh
```

指定串口：

```bash
bash ./scripts/flash.sh /dev/ttyUSB0
```

指定串口和固件：

```bash
bash ./scripts/flash.sh /dev/ttyUSB0 build/Debug/main.hex
```

如果提示缺少依赖，请安装：

```bash
python3 -m pip install pyserial
```
