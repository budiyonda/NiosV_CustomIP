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

## IMPLEMENTATION

  Follow these steps in order to build, program, and verify the project. Each step includes exact commands and a short explanation.

## Step 1 — Hardware build (Quartus)

  1. Open your Quartus project (or run from the command line):

  ```powershell
  cd D:\Quartus251\projects\[your_project]
  quartus Hello.qpf
  # or run full compile
  quartus_sh --flow compile Hello
  ```

  2. Confirm the compilation output file exists:

  ```powershell
  dir output_files\Hello.sof
  ```

  Expected output: `output_files/Hello.sof` (the .sof file used to program the FPGA).

## Step 2 — Generate BSP (Board Support Package)

  Use the Nios V command shell so the tools and paths are set correctly.

  ```powershell
  cd D:\Quartus251\projects\[your_project]
  # create software directory if it does not exist
  if (-not (Test-Path software)) { mkdir software }

  # Generate BSP (adjust the .sopcinfo filename if different)
  niosv-bsp -c -t=hal --sopcinfo=Hello.sopcinfo software/bsp/settings.bsp
  ```

  Notes:
  - After this command completes, `software/bsp` should contain generated headers (including `system.h`) and BSP configuration files.

## Step 3 — Build firmware (Ashling RiscFree or CMake)

  1. Launch Ashling RiscFree.
  2. Create a new project (File → New Project):
    - Project type: Empty project
    - Toolchain: CMake-driven (or the appropriate Ashling toolchain)
    - Location: `C:\Users\lab19\Documents\MBSY\SoC\SoC\NiosV_Hello\software\app`
    - Project name: `app`
  3. Import source files (if needed) and build the project (right-click project → Build Project).

  Option B — Command-line CMake (recommended for reproducibility / CI):

  ```powershell
  cd software/app
  if (-not (Test-Path build)) { mkdir build }
  cd build
  cmake ..
  cmake --build . --config Release
  ```

  Verify: `app.elf` is produced in the build directory.

## Step 4 — Program FPGA and upload firmware

  Program the FPGA using Quartus Programmer, then upload firmware over JTAG.

  ```powershell
  # Program FPGA
  quartus_pgm -c "USB-Blaster" -m JTAG -o "p;output_files/Hello.sof@1"

  # Upload firmware
  cd software/app/build
  niosv-download -g app.elf
  ```

  Alternatively, use Ashling RiscFree to run a hardware debug session:

  1. Connect the USB-JTAG cable to your board.
  2. In Ashling, Run as → Ashling RISC-V Hardware Debugging.
  3. In the debug configuration select the correct target board and choose core `Nios V`.
  4. Apply and launch the debugger.

  ### Step 5 — Hardware verification checklist

  1. Open a JTAG UART terminal (or the Ashling console) and verify the program prints on startup:

  ```text
  Counter app start (0-9999)
  7-seg display = 0, write to 0x30058 = 0x0000
  ```

  2. Verify 7-seg behavior:
  - On power-on the display should show `0000`.
  - Press `KEY0` (increment) — digits should increase `0001`, `0002`, ...
  - Press `KEY1` (decrement) — digits should decrease.

  3. If the display is incorrect, try these checks:
  - Confirm `SEVENSEG_BASE` in `system.h` matches `0x30058`.
  - If digits are in wrong positions, check `digit_select` mapping vs. shield wiring.
  - If segments are inverted, invert `seg_patterns` (common-cathode vs common-anode).

  Use the above procedure to implement and verify the design.

- **Step 5 — Hardware verification checklist**
**Expected Console Output:**
```
Counter app start (0-9999)
7-seg display = 0, write to 0x30058 = 0x0000
```

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

Repository link (download): https://github.com/budiyonda/NiosV_CustomIP

Minimal import steps for recipients:
1. Copy the `CustomIP` folder into your Quartus project directory.
2. Open Quartus and load `Hello.qpf` (or create a new project and add `Hello.qsf`).
3. In Quartus: Tools → Platform Designer → Import Component → point to `CustomIP/seven_seg_controller_hw.tcl` to register the IP.
4. Connect the IP in Platform Designer, assign an address (default 0x30058 used in this README), regenerate the system and export `.sopcinfo`.
5. Follow BSP and firmware build steps above.
