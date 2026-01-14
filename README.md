# NiosV Counter with 7-Segment Display

A Nios V soft-core processor project for DE10-Nano FPGA that implements a 4-digit decimal counter (0-9999) using an Arduino multifunction shield with 74HC595 shift register-based 7-segment display.

## Project Overview

This project demonstrates:
- **Intel Nios V/m** soft-core processor implementation
- **Custom Avalon-MM slave IP** for serial shift register control (74HC595)
- **Multiplexed 4-digit 7-segment display** control
- **Button input handling** via PIO for increment/decrement
- **JTAG UART** for debug output

## Hardware Requirements

### Primary Components
- **DE10-Nano Development Board** (Cyclone V 5CSEBA6U23I7)
- **Arduino Multifunction Shield**

### Connections

#### 7-Segment Display Interface (Shift Registers)
| Shield Pin | Signal | FPGA Pin | Description |
|-----------|--------|----------|-------------|
| D4 (Arduino) | DATA | AF17 | Serial data to first 74HC595 |
| D7 (Arduino) | CLOCK | AH8 | Shift register clock |
| D8 (Arduino) | LATCH | U14 | Output register latch |

#### Button Interface (PIO)
| Button | FPGA Pin | Function |
|--------|----------|----------|
| KEY0 | AH17 | Increment counter |
| KEY1 | AH16 | Decrement counter |

**Note:** DE10-Nano onboard keys are active-low (pressed = logic 0).

## Software Requirements

### Development Tools
- **Quartus Prime** 25.1 Standard Edition or later
- **Platform Designer** (included with Quartus)
- **Nios V Tools** : `niosv-shell` (for software build)
- **Ashling riscfree** (RISC-V toolchain / for firmware upload)

## Project Structure

```
NiosV_Hello/
├── CustomIP/
│   ├── seven_seg_controller.v       # Custom IP HDL source
│   └── seven_seg_controller_hw.tcl  # Platform Designer component definition
├── NiosV/
│   ├── NiosV.qsys                   # Platform Designer system
│   └── synthesis/
│       └── submodules/
│           └── seven_seg_controller.v  # Generated IP copy
├── software/
│   ├── app/
│   │   ├── counter.c                # Main application
│   │   └── CMakeLists.txt           # Build configuration
│   └── bsp/                         # Board Support Package
├── Hello.qpf                        # Quartus project file
├── Hello.qsf                        # Quartus settings (pin assignments)
└── README.md                        # This file
```

## Custom IP Specification

### Seven-Segment Controller (`seven_seg_controller`)

**Interface:**
- **Avalon-MM Slave**:
  - Base address: `0x30058`
  - Data width: 16-bit
  - Register 0: Display data (4 nibbles, one per digit)
    - `[15:12]` = Digit 3 (leftmost, thousands)
    - `[11:8]`  = Digit 2 (hundreds)
    - `[7:4]`   = Digit 1 (tens)
    - `[3:0]`   = Digit 0 (rightmost, ones)

- **Conduit Export (`conduit_shift`)**:
  - `sr_data`: Serial data output
  - `sr_clk`: Shift clock output
  - `sr_latch`: Output latch control

**Operation:**
1. Receives 16-bit value from CPU
2. Extracts nibble for current digit (0-9)
3. Looks up 7-segment pattern (common anode)
4. Serializes 16 bits: `[segment_pattern][digit_select]`
5. Shifts out MSB-first to 74HC595 chain
6. Pulses latch to update display
7. Multiplexes through all 4 digits

### Custom IP — Concepts (brief)

- **Addressing / Register width:** Platform Designer assigns peripherals in word (32-bit) address units. The IP exposes a single logical register for display data (16 bits) at the assigned base address (e.g. `0x30058`). The memory map shows the byte range `0x30058 - 0x3005B` because that is the 4-byte word region allocated for the register.

- **Data packing convention:** The firmware packs decimal digits into 4 nibbles in little-endian nibble order: `[d3][d2][d1][d0]` where `d0` is ones (rightmost). The IP extracts the nibble for the active digit using the `(digit_sel*4)+:4` slice.

- **Shift sequence:** The IP composes a 16-bit shift word consisting of a segment pattern byte and a digit-select byte. With `SEG_FIRST=1` the shift order is `[segment][digit]`. `LSB_FIRST=0` indicates MSB-first transmission into the first 74HC595 in the chain.

- **Segment polarity / encoding:** `seg_patterns` are encoded for a common-anode display (active-low segments). If your hardware uses common-cathode, invert the pattern bits (bitwise NOT) or change the pattern table accordingly.

- **Extending the IP:** To add more features (brightness control, decimal point control, status flags), add additional word-aligned registers at `base + 4`, `base + 8`, etc., and expand the address decode in the Avalon slave logic.


## Build Instructions

### 1. Hardware Compilation (FPGA)
**Expected Output:** `output_files/Hello.sof`

### 2. Software Compilation (Firmware)

#### Option A: Using Nios V Command Shell

```bash
# Navigate to project directory
cd D:\Quartus251\projects\[nama project]
# (Ganti dengan directory folder project anda)

# Check directory contents
dir

# Create software directory
mkdir software

# Verify directory created
dir

# Create Board Support Package (BSP)
niosv-bsp -c -t=hal --sopcinfo=[nama file].sopcinfo software/bsp/settings.bsp

# Create application
niosv-app -a=software/app -b=software/bsp -s=software/app/[nama file].c

# Open UART terminal
juart-terminal
```

## Programming Instructions

### 1. Program FPGA

### 2. Upload Firmware

**Expected Console Output:**
```
Counter app start (0-9999)
7-seg display = 0, write to 0x30058 = 0x0000
```

## Usage

### Counter Operation

1. **Power On:** Display shows `0000`
2. **Increment:** Press KEY0 (AH17) → count increases: `0001`, `0002`, ..., `9999`
3. **Decrement:** Press KEY1 (AH16) → count decreases
4. **Wrap:** At `9999`, next increment → `0000`
5. **Wrap (down):** At `0000`, decrement → `9999`

### UART Debug Output

Connect to JTAG UART terminal to see debug messages:
```
7-seg display = 5, write to 0x30058 = 0x0005
7-seg display = 6, write to 0x30058 = 0x0006
...
```

## System Architecture

### Platform Designer Components

| Component | Type | Base Address | Description |
|-----------|------|--------------|-------------|
| `intel_niosv_m_0` | Nios V/m CPU | - | 32-bit RISC-V processor |
| `onchip_memory2_0` | On-Chip Memory | 0x00000000 | 128 KB RAM |
| `jtag_uart_0` | JTAG UART | 0x30050 | Debug console |
| `pio_0` | PIO | 0x30040 | 2-bit input (buttons) |
| `seven_seg_controller_0` | Custom IP | 0x30058 | 7-segment display controller |


## Technical Details

### 7-Segment Encoding (Common Anode)

```
Bit mapping: [DP][G][F][E][D][C][B][A]
```

| Digit | Hex Code | Binary | Segments ON |
|-------|----------|--------|-------------|
| 0 | 0xC0 | 11000000 | A,B,C,D,E,F |
| 1 | 0xF9 | 11111001 | B,C |
| 2 | 0xA4 | 10100100 | A,B,D,E,G |
| 3 | 0xB0 | 10110000 | A,B,C,D,G |
| 4 | 0x99 | 10011001 | B,C,F,G |
| 5 | 0x92 | 10010010 | A,C,D,F,G |
| 6 | 0x82 | 10000010 | A,C,D,E,F,G |
| 7 | 0xF8 | 11111000 | A,B,C |
| 8 | 0x80 | 10000000 | A,B,C,D,E,F,G |
| 9 | 0x90 | 10010000 | A,B,C,D,F,G |

### Timing Parameters

- **System Clock:** 50 MHz
- **Shift Clock:** ~12.2 kHz (4096 FPGA cycles per bit)
- **Digit Refresh Rate:** ~47 Hz (262,143 FPGA cycles per digit)
- **Full Display Refresh:** ~12 Hz (4 digits × 21.5 ms)

### Memory Map

```
0x00000000 - 0x0001FFFF : On-chip RAM (128 KB)
0x00030040 - 0x00030043 : PIO (Buttons)
0x00030050 - 0x00030057 : JTAG UART
0x00030058 - 0x0003005B : Seven-Segment Controller
```

## License

This project is provided as-is for educational purposes.

## Author

**Budi Yonda**
- GitHub: [@budiyonda](https://github.com/budiyonda)
- Repository: [NiosV](https://github.com/budiyonda/NiosV)

## Acknowledgments

- Intel FPGA University Program
- Nios V soft-core processor documentation
- Arduino multifunction shield community

---

**Last Updated:** January 14, 2026  
**Quartus Version:** 25.1 Standard Edition  
**Target Device:** Cyclone V 5CSEBA6U23I7 (DE10-Nano)

## Reproducibility Guide

This section provides step-by-step instructions and checks so another engineer can reproduce the hardware build, BSP generation, firmware build, and basic verification.

- **Prerequisites**
  - Quartus Prime 25.1 Standard Edition (or compatible 25.1.x)
  - Nios V tools installed with Quartus (ensure `niosv-bsp`, `niosv-app`, `niosv-download` are available in PATH)
  - Windows machine with USB-Blaster connected to DE10-Nano

- **Directory layout (assumed)**
  - Project root example: `D:\Quartus251\projects\[nama project]` (replace with your path)
  - Quartus project files: `Hello.qpf`, `Hello.qsf`
  - Custom IP: `CustomIP/seven_seg_controller.v`
  - Software sources: `software/app/counter.c`

- **Step 1 — Hardware build (Quartus)**
  - Open project in Quartus GUI or run compile from shell:
```powershell
cd D:\Quartus251\projects\[nama project]
quartus Hello.qpf
quartus_sh --flow compile Hello
```
  - Confirm `output_files/Hello.sof` exists.

- **Step 2 — Generate BSP (Board Support Package)**
  - Use Nios V command shell to ensure correct tool environment:
```powershell
cd D:\Quartus251\projects\[nama project]
niosv-bsp -c -t=hal --sopcinfo=Hello.sopcinfo software/bsp/settings.bsp
```
  - After successful run, check `software/bsp` for generated headers (e.g., `system.h`) and BSP metadata.

- **Step 3 — Build firmware (app)**
  - Using CMake (preferred):
```powershell
cd software/app
if (-not (Test-Path build)) { mkdir build }
cd build
cmake ..
cmake --build . --config Release
```
  - Or with Nios V app tool:
```powershell
niosv-app -a=software/app -b=software/bsp -s=software/app/counter.c
```
  - Verify `app.elf` creation and that `system.h` defines `PIO_0_BASE` and `SEVENSEG_BASE` (expected 0x30058).

- **Step 4 — Program FPGA and upload firmware**
```powershell
# Program FPGA
quartus_pgm -c "USB-Blaster" -m JTAG -o "p;output_files/Hello.sof@1"

# Upload firmware
cd software/app/build
niosv-download -g app.elf

# Open JTAG UART terminal
juart-terminal
```

- **Step 5 — Hardware verification checklist**
  - UART should print: `Counter app start (0-9999)`.
  - Press KEY0 (increment) and KEY1 (decrement) to verify displayed digits update.
  - If digits appear in wrong positions, check `digit_select` bytes (0x08,0x04,0x02,0x01) vs shield wiring.
  - If segment shapes are incorrect, check `seg_patterns` polarity (current patterns are active-low for common-anode displays); invert patterns if shield is common-cathode.
  - If segments/digits are scrambled, test send-order and bit-order using diagnostic writes (see debugging tips).

- **Debugging tips**
  - IP special value `0xFFFF` triggers debug latch blink — use to validate latch behavior.
  - If bit-order mismatch suspected, toggle `LSB_FIRST` or `BIT_REVERSE` parameters in `CustomIP/seven_seg_controller.v`, then rebuild IP and Quartus.
  - Use oscilloscope/logic analyzer on `sr_data`, `sr_clk`, `sr_latch` to inspect timing and order.

- **Optional automation**
  - Add a `test_mode` to `software/app/counter.c` to run diagnostic patterns at startup and print results to UART.

### Minimal Reproduction Package

If you intend to share a minimal package (so others can reproduce quickly), include these files and folders:

- `CustomIP/` (folder)
  - Must contain `seven_seg_controller.v` and `seven_seg_controller_hw.tcl`.
- `Hello.qsf`
  - Project pin assignments and important settings — place in the Quartus project root.
- `README.md`
  - This file with the Reproducibility Guide and notes.

Repository link (download): https://github.com/budiyonda/NiosV_CustomIP

Minimal import steps for recipients:
1. Copy the `CustomIP` folder into your Quartus project directory.
2. Open Quartus and load `Hello.qpf` (or create a new project and add `Hello.qsf`).
3. In Quartus: Tools → Platform Designer → Import Component → point to `CustomIP/seven_seg_controller_hw.tcl` to register the IP.
4. Connect the IP in Platform Designer, assign an address (default 0x30058 used in this README), regenerate the system and export `.sopcinfo`.
5. Follow BSP and firmware build steps above.

Notes for sharers:
- Keep `seven_seg_controller_hw.tcl` alongside `seven_seg_controller.v` so Platform Designer can import correctly.
- If you want a fully self-contained package, include `Hello.qpf`, `Hello.qsf`, `CustomIP/`, and this `README.md`.

