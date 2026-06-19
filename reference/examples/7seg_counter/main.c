#include <reg52.h>

/* C8051F310 SFRs */
__sfr __at (0xD9) PCA0MD;
__sfr __at (0xA4) P0MDOUT;
__sfr __at (0xA5) P1MDOUT;
__sfr __at (0xF1) P0MDIN;
__sfr __at (0xF2) P1MDIN;
__sfr __at (0xD4) P0SKIP;
__sfr __at (0xD5) P1SKIP;
__sfr __at (0xE1) XBR0;
__sfr __at (0xE2) XBR1;
__sfr __at (0xB2) OSCICN;

#define SEG_ACTIVE_HIGH 1

static const unsigned char seg_tab_high[10] = {
    0xFC, 0x60, 0xDA, 0xF2, 0x66, 0xB6, 0xBE, 0xE0, 0xFE, 0xE6
};

static void delay_short(void) {
    unsigned char i, j;
    for (i = 0; i < 22; i++) {
        for (j = 0; j < 250; j++) {
            __asm nop __endasm;
        }
    }
}

static void init_device(void) {
    PCA0MD &= ~0x40;   /* disable watchdog */
    PCA0MD = 0x00;

    /* force digital I/O mode */
    P0MDIN = 0xFF;
    P1MDIN = 0xFF;

    /* push-pull outputs used by display */
    P0MDOUT = 0xC0;    /* P0.7/P0.6 = B/A */
    P1MDOUT = 0xFF;    /* P1.7..P1.0 = segments */

    /* keep crossbar from stealing pins */
    XBR0 = 0x00;
    P0SKIP = 0xFF;
    P1SKIP = 0xFF;
    XBR1 = 0x40;       /* enable crossbar */

    OSCICN = 0x83;

    P0 |= 0xC0;        /* default BA high */
    P1 = 0x00;
}

static void scan_one(unsigned char ba, unsigned char num) {
    unsigned char seg;

    seg = seg_tab_high[num];
#if SEG_ACTIVE_HIGH
    P1 = seg;
#else
    P1 = ~seg;
#endif

    P0 &= 0x3F;
    P0 |= (unsigned char)(ba << 6);
    delay_short();
}

static void refresh_4digit(unsigned char d3, unsigned char d2, unsigned char d1, unsigned char d0) {
    scan_one(0, d0);
    scan_one(1, d1);
    scan_one(2, d2);
    scan_one(3, d3);
}

void main(void) {
    unsigned char d0 = 0, d1 = 0, d2 = 0, d3 = 0;
    unsigned char k;

    init_device();

    while (1) {
        for (k = 0; k < 200; k++) {
            refresh_4digit(d3, d2, d1, d0);
        }

        d0++;
        if (d0 >= 10) { d0 = 0; d1++; }
        if (d1 >= 10) { d1 = 0; d2++; }
        if (d2 >= 10) { d2 = 0; d3++; }
        if (d3 >= 10) { d3 = 0; }
    }
}
