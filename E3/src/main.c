typedef unsigned char u8;
typedef unsigned int u16;

/* C8051F310 SFR definitions (aligned with inc/C8051F310.INC) */
__sfr __at (0x80) P0;
__sfr __at (0x88) TCON;
__sfr __at (0x89) TMOD;
__sfr __at (0x8A) TL0;
__sfr __at (0x8C) TH0;
__sfr __at (0x90) P1;
__sfr __at (0xA0) P2;
__sfr __at (0xA8) IE;
__sfr __at (0xB0) P3;
__sfr __at (0xA7) P3MDOUT;
__sfr __at (0xD9) PCA0MD;

__sbit __at (0xA9) ET0;
__sbit __at (0xAF) EA;
__sbit __at (0x8C) TR0;

/* ---------------- Board mapping from C8051F310EVM manual ----------------
 * 7-seg segment control: P1.7..P1.0 -> a,b,c,d,e,f,g,dp (active high)
 * 7-seg digit control:   P0.7 -> B, P0.6 -> A (00:digit0, 01:digit1, 10:digit2, 11:digit3)
 * Keypad 4x4:            P2.0..P2.3 KO(row out), P2.4..P2.7 KI(col in), key active low
 * LED D1..D8 via 74HCT164: P3.3 DAT, P3.4 CLK, LED on when shifted bit = 0
 * Buzzer:                P3.1 (active high)
 * D9:                    P0.0 (active low)
 * KINT key:              P0.1 (active low)
 */

__sbit __at (0xB1) BUZZER;
__sbit __at (0x80) LED_D9;
__sbit __at (0x81) KINT;
__sbit __at (0xB3) LED_DAT;
__sbit __at (0xB4) LED_CLK;
__sbit __at (0x86) DIG_A;
__sbit __at (0x87) DIG_B;

/* Per C8051F310EVM manual: buzzer on P3.1 is active-high. */
#define BUZZER_ON_LEVEL  1
#define BUZZER_OFF_LEVEL 0

#define MODE_IDLE 0
#define MODE_OPEN 1
#define MODE_FULL 2

static volatile u16 g_ms = 0;
static volatile u8 g_scan_digit = 0;

static u8 g_bin[4];
static u8 g_mode = MODE_IDLE;
static u8 g_active_bin = 0xFF;

static u16 g_open_ms = 0;
static u16 g_beep_ms = 0;
static u16 g_full_ms = 0;

static u8 g_flash_toggle = 0;
static u16 g_flash_acc = 0;

static u8 g_key_last = 0xFF;
static u8 g_key_stable = 0xFF;
static u8 g_key_event = 0xFF;

static u8 g_lfsr = 0x5A;

/* abcdefg + dp, active high */
static const u8 SEG_TAB[16] = {
    0xFC, /*0*/ 0x60, /*1*/ 0xDA, /*2*/ 0xF2, /*3*/
    0x66, /*4*/ 0xB6, /*5*/ 0xBE, /*6*/ 0xE0, /*7*/
    0xFE, /*8*/ 0xF6, /*9*/ 0xEE, /*A*/ 0x3E, /*b*/
    0x9C, /*C*/ 0x7A, /*d*/ 0x9E, /*E*/ 0x8E  /*F*/
};

static void delay_small(void)
{
    unsigned char i;
    for (i = 0; i < 4; i++) {
        ;
    }
}

static void shift_led_bar(u8 mask)
{
    u8 i;
    for (i = 0; i < 8; i++) {
        LED_CLK = 0;
        LED_DAT = (mask & 0x80) ? 1 : 0;
        delay_small();
        LED_CLK = 1;
        mask <<= 1;
    }
}

static u8 prng_0_9(void)
{
    u8 x = g_lfsr;
    x ^= (x << 3);
    x ^= (x >> 5);
    x ^= 0x39;
    g_lfsr = x;
    return (u8)(x % 10);
}

static void close_cover(void)
{
    g_mode = MODE_IDLE;
    g_active_bin = 0xFF;
    g_open_ms = 0;
    g_beep_ms = 0;
    shift_led_bar(0xFF);
    LED_D9 = 1;
    BUZZER = BUZZER_OFF_LEVEL;
}

static void start_full_alarm(void)
{
    g_mode = MODE_FULL;
    g_full_ms = 1000;
    g_beep_ms = 1000;
    BUZZER = BUZZER_ON_LEVEL;
}

static void open_cover(u8 idx)
{
    g_mode = MODE_OPEN;
    g_active_bin = idx;
    g_open_ms = 8000;
    g_flash_acc = 0;
    g_flash_toggle = 1;
    LED_D9 = 0;
}

static void update_progress_led(void)
{
    u8 remain_slots;
    u8 lit_slots;
    u8 mask;

    if (g_mode != MODE_OPEN || g_open_ms == 0) {
        shift_led_bar(0xFF);
        return;
    }

    remain_slots = (u8)((g_open_ms + 999) / 1000);
    if (remain_slots > 8) {
        remain_slots = 8;
    }
    lit_slots = remain_slots;

    mask = 0xFF;
    while (lit_slots--) {
        mask <<= 1;
        mask |= 0x01;
    }
    shift_led_bar((u8)~mask);
}

static u8 scan_keypad_raw(void)
{
    u8 row;
    u8 col_bits;

    for (row = 0; row < 4; row++) {
        P2 = 0xFF;
        P2 &= (u8)~(1 << row);
        delay_small();
        col_bits = (u8)((P2 >> 4) & 0x0F);
        if (col_bits != 0x0F) {
            if ((col_bits & 0x01) == 0) return (u8)(row * 4 + 0);
            if ((col_bits & 0x02) == 0) return (u8)(row * 4 + 1);
            if ((col_bits & 0x04) == 0) return (u8)(row * 4 + 2);
            if ((col_bits & 0x08) == 0) return (u8)(row * 4 + 3);
        }
    }

    return 0xFF;
}

static void poll_keys_10ms(void)
{
    static u8 same_cnt = 0;
    u8 k = scan_keypad_raw();

    if (k == g_key_last) {
        if (same_cnt < 3) {
            same_cnt++;
        }
    } else {
        same_cnt = 0;
    }
    g_key_last = k;

    if (same_cnt >= 2 && k != g_key_stable) {
        g_key_stable = k;
        if (k != 0xFF) {
            g_key_event = k;
        }
    }
}

static void process_key_event(void)
{
    u8 key = g_key_event;
    g_key_event = 0xFF;

    /* Use top row keys as F1-F4: key 0,1,2,3 -> bin 0..3 */
    if (key > 3) {
        return;
    }

    if (g_mode == MODE_IDLE) {
        if (g_bin[key] == 0) {
            g_active_bin = key;
            start_full_alarm();
        } else {
            open_cover(key);
        }
        return;
    }

    if (g_mode == MODE_OPEN && g_active_bin == key) {
        if (g_bin[key] > 0) {
            g_bin[key]--;
        }
        if (g_bin[key] == 0) {
            close_cover();
            start_full_alarm();
            g_active_bin = key;
        }
    }
}

static u8 display_value_for_digit(u8 idx)
{
    if (idx >= 4) {
        return 0;
    }

    if (g_mode == MODE_FULL && idx == g_active_bin) {
        return 0x0F; /* F */
    }

    if (g_mode == MODE_OPEN && idx == g_active_bin && g_flash_toggle == 0) {
        return 0xFF; /* blank */
    }

    return g_bin[idx];
}

static void refresh_display_1ms(void)
{
    u8 v = display_value_for_digit(g_scan_digit);

    if (v == 0xFF) {
        P1 = 0x00;
    } else {
        P1 = SEG_TAB[v & 0x0F];
    }

    DIG_A = g_scan_digit & 0x01;
    DIG_B = (g_scan_digit >> 1) & 0x01;

    g_scan_digit++;
    g_scan_digit &= 0x03;
}

void timer0_isr(void) __interrupt(1)
{
    static u8 div10 = 0;

    TH0 = 0xFC;
    TL0 = 0x18;

    g_ms++;
    refresh_display_1ms();

    if (g_beep_ms > 0) {
        g_beep_ms--;
        if (g_beep_ms == 0) {
            BUZZER = BUZZER_OFF_LEVEL;
        }
    }

    if (g_mode == MODE_OPEN && g_open_ms > 0) {
        g_open_ms--;
        g_flash_acc++;
        if (g_flash_acc >= 100) {
            g_flash_acc = 0;
            g_flash_toggle = !g_flash_toggle;
        }
        if (g_open_ms == 0 || KINT == 0) {
            close_cover();
        }
    }

    if (g_mode == MODE_FULL && g_full_ms > 0) {
        g_full_ms--;
        if (g_full_ms == 0) {
            close_cover();
        }
    }

    div10++;
    if (div10 >= 10) {
        div10 = 0;
        poll_keys_10ms();
        update_progress_led();
    }
}

static void init_hw(void)
{
    u8 i;

    /* C8051F310 powers up with watchdog enabled: disable it first. */
    PCA0MD &= (u8)~0x40;

    EA = 0;

    P0 = 0xFF;
    P1 = 0x00;
    P2 = 0xFF;
    P3 = 0x00;
    P3MDOUT |= 0x1A; /* P3.1 buzzer, P3.3 DAT, P3.4 CLK as push-pull outputs */

    BUZZER = BUZZER_OFF_LEVEL;
    LED_D9 = 1;

    for (i = 0; i < 4; i++) {
        g_bin[i] = prng_0_9();
    }
    close_cover();

    TMOD &= 0xF0;
    TMOD |= 0x01;
    TH0 = 0xFC;
    TL0 = 0x18;
    ET0 = 1;
    TR0 = 1;
    EA = 1;
}

void main(void)
{
    init_hw();

    while (1) {
        if (g_key_event != 0xFF) {
            process_key_event();
        }
    }
}
