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


### Custom IP — Simple Explanation

- What is this IP?
  - This IP is a small FPGA module that receives numbers from the CPU and controls two 74HC595 shift registers to drive a 4-digit 7-segment display.

- How does the firmware send numbers?
  - The program packs four decimal digits into one 16-bit word: each digit occupies one nibble. Example: number `1234` is packed as `0x1234` (thousands in the high nibble, ones in the low nibble).
  - The program writes that 16-bit word to the IP base address (e.g., `0x30058`).

- How does the IP turn that into a visible display?
  - The IP extracts the nibble for the currently active digit and looks up the corresponding 7-seg pattern from a table.
  - The IP creates a 16-bit shift word and sends two bytes to the 74HC595 chain: a segment-pattern byte and a digit-select byte (with `SEG_FIRST` the pattern is sent first).
  - Bits are sent MSB-first by default (`LSB_FIRST = 0`). If the display looks reversed, change `LSB_FIRST` or enable `BIT_REVERSE`.

- Why does the memory map show 4 bytes (`0x30058 - 0x3005B`)?
  - The CPU addresses memory by byte, but registers are allocated per 32-bit word. That byte range is the single 4-byte word allocated for the IP register, even though the IP uses only 16 bits inside that word.

- Segment polarity (common-anode vs common-cathode)
  - The `seg_patterns` table is written for common-anode displays (segments active = 0). If your hardware is common-cathode, invert the pattern bits (bitwise NOT) so segments light correctly.

## Implementation

Follow these steps to build the FPGA design, generate the BSP, build the firmware, program the board, and run basic verifications. Commands are shown for Windows/PowerShell where applicable; adjust paths for your environment.

### Step 1 — Hardware build (Quartus)

1. Place the `CustomIP` folder inside your Quartus project directory so Platform Designer can find the IP files (`seven_seg_controller.v` and `seven_seg_controller_hw.tcl`).
2. Open the Quartus project (GUI) or run from the Quartus command shell:

```powershell
cd D:\Quartus251\projects\[your_project]
quartus Hello.qpf
quartus_sh --flow compile Hello
```

3. If you modify the Platform Designer system, open Platform Designer (Tools → Platform Designer), import or add the custom component, connect it into the design, regenerate the system, and re-run compilation.

4. Confirm the compilation produces the device programming file:

```
output_files/Hello.sof
```

### Step 2 — Generate BSP (Board Support Package)

Use the Nios V command shell so the Nios toolchain environment is correct. Generate the BSP from the exported `.sopcinfo`:

```powershell
cd D:\Quartus251\projects\[your_project]
niosv-bsp -c -t=hal --sopcinfo=Hello.sopcinfo software/bsp/settings.bsp
```

After this completes, verify `software/bsp` contains generated headers (for example `system.h`) and BSP metadata.

### Step 3 — Build firmware (application)

You can build the firmware either with the CMake flow or with the `niosv-app` helper. Examples:

- CMake (recommended when project already contains CMake files):

```Nios V Command Shell
cd software/app
if (-not (Test-Path build)) { mkdir build }
cd build
cmake ..
cmake --build . --config Release
```

- `niosv-app` (alternative legacy flow):

```Nios V Command Shell
niosv-app -a=software/app -b=software/bsp -s=software/app/counter.c
```

If you prefer to use Ashling riscfree IDE for development/debugging, import or create a new project in Ashling and point it to the `software/app` folder (select CMake-driven project or configure the toolchain appropriately). Then use the IDE's Build/Run configuration to compile the project.

Verify the build produces `app.elf` (typically in `software/app/build`).

### Step 4 — Program FPGA and upload firmware

1. Program the FPGA with the generated `.sof`:

```Nios V Command Shell
quartus_pgm -c "USB-Blaster" -m JTAG -o "p;output_files/Hello.sof@1"
```

2. Upload and run the firmware via JTAG:

```powershell
cd software/app/build
niosv-download -g app.elf
```

3. (Optional) Use Ashling riscfree for hardware debug: create a debug configuration, select the target device and the Nios V core, then launch the hardware debug session from the IDE.

### Step 5 — Hardware verification checklist

Perform these checks after programming and uploading firmware:

- Confirm UART output (JTAG UART) shows the application start message:

```
Counter app start (0-9999)
```

- Expected visible behavior on the 7-seg display:
  - Power-on: `0000` should be visible.
  - Press KEY0: counter increments.
  - Press KEY1: counter decrements.

- If digits are in the wrong positions, verify `digit_select` mapping (0x08,0x04,0x02,0x01) vs your shield wiring.
- If segment shapes are incorrect, check that your hardware matches the IP's expected polarity (common-anode). If not, invert `seg_patterns`.
- Use the diagnostic mode included in `counter.c` to run visible tests on startup (pattern `1234`, digit cycling, and debug-latch blink).


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
