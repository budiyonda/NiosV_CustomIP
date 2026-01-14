/* counter.c
 * Simple up/down counter using PIO buttons and custom seven-seg controller.
 * - Reads 4-bit PIO at PIO_0_BASE (buttons) where bit0 = btn_inc, bit1 = btn_dec, bit2 = btn_reset
 * - Writes 16-bit value to seven-seg controller base (lower 4 bits shown on digit0)
 */
#include <stdint.h>
#include <stdio.h>
#include "system.h"

#define PIO_BASE PIO_0_BASE
#define SEVENSEG_BASE 0x30058

// Diagnostic delay tuning (adjust if needed for your board/toolchain)
// These are loop iteration counts for crude delays; increase if the sequence
// is still too fast on your target platform.
#define DIAG_DELAY_LONG   3000000u
#define DIAG_DELAY_MED     800000u
#define DIAG_DELAY_SHORT   300000u

static inline void mmio_write32(uint32_t addr, uint32_t value) {
    volatile uint32_t *ptr = (volatile uint32_t *)addr;
    *ptr = value;
}

static inline uint32_t mmio_read32(uint32_t addr) {
    volatile uint32_t *ptr = (volatile uint32_t *)addr;
    return *ptr;
}

int main(void) {
    uint16_t display = 0;
    uint16_t last_printed = 0xFFFF;
    uint32_t btn_state = 0, btn_prev = 0;
    uint32_t debounced = 0;

    printf("Counter app start (0-9999)\n");

    // Run a more visible diagnostic sequence on startup to help verification.
    // Use the DIAG_DELAY_* constants above to tune visibility on your board.
    {
        printf("Running diagnostic test (visible)...\n");

        // 1) Show fixed pattern 1 2 3 4 for a longer duration
        uint16_t p = (1) | (2<<4) | (3<<8) | (4<<12);
        mmio_write32(SEVENSEG_BASE, (uint32_t)p);
        for (volatile unsigned i = 0; i < DIAG_DELAY_LONG; ++i);

        // 2) Cycle ones digit 0..9 slowly so each digit is easily seen
        for (int d = 0; d < 10; ++d) {
            uint16_t pack = (d & 0xF);
            mmio_write32(SEVENSEG_BASE, (uint32_t)pack);
            for (volatile unsigned i = 0; i < DIAG_DELAY_MED; ++i);
        }

        // Repeat the cycle once more for assurance
        for (int d = 0; d < 10; ++d) {
            uint16_t pack = (d & 0xF);
            mmio_write32(SEVENSEG_BASE, (uint32_t)pack);
            for (volatile unsigned i = 0; i < DIAG_DELAY_SHORT; ++i);
        }

        // 3) Trigger IP debug mode (0xFFFF) to blink latch (visible test)
        mmio_write32(SEVENSEG_BASE, 0xFFFF);
        for (volatile unsigned i = 0; i < DIAG_DELAY_LONG; ++i);

        // Clear display to 0
        mmio_write32(SEVENSEG_BASE, 0x0000);
        for (volatile unsigned i = 0; i < DIAG_DELAY_SHORT; ++i);

        printf("Diagnostic complete. Entering normal mode.\n");
    }

    while (1) {
        uint32_t p = mmio_read32(PIO_BASE);

        // simple debouncing: require stable reading over few loops
        if (p == btn_prev) {
            debounced = p;
        }
        btn_prev = p;

        // For DE10-Nano onboard keys: active-low when pressed.
        // pio bits: bit0 = KEY0, bit1 = KEY1
        // We detect a press event as a transition from 1->0 (unpressed->pressed).
        // falling edge detection: previous was 1 and now 0 => (prev=1, cur=0)
        if ((btn_state & 0x1) && !(debounced & 0x1)) { // KEY0 pressed -> increment
            display = (display + 1);
            if (display >= 10000) display = 0;  // wrap at 10000
        }
        if ((btn_state & 0x2) && !(debounced & 0x2)) { // KEY1 pressed -> decrement
            if (display == 0) 
                display = 9999;
            else
                display = display - 1;
        }

        btn_state = debounced;

        // Extract individual decimal digits: ones, tens, hundreds, thousands
        uint16_t d0 = display % 10;           // ones (rightmost)
        uint16_t d1 = (display / 10) % 10;    // tens
        uint16_t d2 = (display / 100) % 10;   // hundreds
        uint16_t d3 = (display / 1000) % 10;  // thousands (leftmost)
        
        // Pack as 4 nibbles: [d3][d2][d1][d0]
        uint16_t packed = (d0 & 0xF) | ((d1 & 0xF) << 4) | ((d2 & 0xF) << 8) | ((d3 & 0xF) << 12);
        mmio_write32(SEVENSEG_BASE, (uint32_t)packed);

        // Print to serial only when displayed digit changes
        if (display != last_printed) {
            printf("7-seg display = %u (0x%04X written to 0x%08X)\n", 
                   (unsigned)display, (unsigned)packed, SEVENSEG_BASE);
            last_printed = display;
        }

        for (volatile int i=0;i<50000;i++); // crude delay
    }

    return 0;
}
