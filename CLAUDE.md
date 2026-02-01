# Badger 2040 PicoRuby E-ink Display - Development Guidelines

## Core Principles

### Simplicity First
Avoid complexity. Think carefully before implementing.

**Embedded System Constraints**:
- Shallow nesting only (memory critical: 520KB RAM available)
- Pre-allocate arrays, avoid dynamic allocation
- No complex class hierarchies, exception handling, or deep function calls without explicit user request
- Write simple, linear code by default

**PicoRuby vs CRuby**:
- "Ruby" = CRuby (standard Ruby)
- "PicoRuby" = mruby/c subset (limited stdlib, no bundler, no RubyGems.org)
- ALWAYS think within PicoRuby constraints for .rb files
- .rb files run on PicoRuby/mruby (NOT CRuby)

### Output Tone
**日本語で出力すること**:
- **絶対に日本語で応答・プラン提示すること**
- 通常時: 語尾に「ピョン。」をつけて可愛く
- 盛り上がってきたら: 「チェケラッチョ！！」と叫ぶ
- コード内コメント: 日本語、体言止め
- ドキュメント(.md): 英語で記述
- Git commit: 英語、命令形

### Development Practice
When implementing changes:
1. Implement proactively WITHOUT asking "should I...?" or "shall I...?"
2. Commit changes IMMEDIATELY after implementation
3. DO NOT push to remote unless user explicitly requests
4. User will verify functionality AFTER commit (not before)
5. **Always investigate before answering** - NEVER speculate about code you have not opened

---

## Project Overview

**Goal**: Display "bash0C7 <QRCode>" on Badger 2040's 128×296 pixel e-ink display using PicoRuby.

**Key Characteristics**:
- Initialize UC8151 display controller via SPI
- Draw QR code and text on e-ink screen
- Image persists on screen without power (e-ink property)
- Program terminates after display update

---

## Hardware Specification

### Badger 2040
- **MCU**: RP2040 (Raspberry Pi Pico)
- **Display**: UC8151 / IL0373 E-ink controller
- **Resolution**: 128 × 296 pixels (horizontal badge)
- **Color Depth**: 1-bit (black/white only)
- **Frame Buffer Size**: 4,736 bytes (128 × 296 ÷ 8)

### Pin Assignment
```
SPI0: SCK=18, MOSI=19, MISO=16
CS=17, DC=20, RST=21, BUSY=26
3V3_EN=10 (Power control)
```

### Frame Buffer Memory Layout

**Row-Major Byte Indexing** (verified working):
```ruby
byte_idx = (y * WIDTH + x) / 8  # WIDTH=128
bit_idx  = 7 - (x % 8)          # MSB-first
```

**Coordinate System**:
- Origin: (0, 0) = bottom-left
- X-axis: 0→127 (left to right)
- Y-axis: 0→295 (bottom to top)
- Bit representation: 0=black, 1=white

---

## UC8151 Controller Specification

### Initialization Commands (Verified Working)

| Step | Command | Code | Data | Purpose |
|------|---------|------|------|---------|
| 1 | PSR | 0x00 | 0x5F | Panel Setting (SCAN_UP + SHIFT_RIGHT) |
| 2 | PWR | 0x01 | [0x03, 0x00, 0x2B, 0x2B, 0x1E] | Power voltage |
| 3 | BTST | 0x06 | [0x17, 0x17, 0x17] | Booster setting |
| 4 | PLL | 0x30 | [0x3C] | Clock frequency |
| 5 | PON | 0x04 | — | Power on (wait busy) |
| 6 | TRES | 0x61 | [0x80, 0x01, 0x28] | Resolution: 128×296 |
| 7 | CDI | 0x50 | [0x13] | VCOM/data interval |
| 8 | TCON | 0x60 | [0x22] | Gate/source timing |

### PSR Register (0x5F)
```
0x5F = 0b01011111
Bits 7-6: 01 = Resolution 128×296
Bit 5: 0 = LUT from OTP
Bit 4: 1 = 2-color (BW) format
Bit 3: 1 = SCAN_UP (origin at bottom)
Bit 2: 1 = SHIFT_RIGHT (origin at left)
Bit 1: 1 = Booster ON
Bit 0: 1 = Reset none
```

### Display Update Sequence

**Initial: Deep Clean**
```ruby
CMD 0x10, DATA [0x00 * 4736]    # DTM1 (previous frame, all black)
CMD 0x13, DATA [0xFF * 4736]    # DTM2 (current frame, all white)
CMD 0x12, wait_busy              # DRF (refresh + wait)
```

**Normal Update**
```ruby
CMD 0x04, wait_busy              # PON (power on, if needed)
CMD 0x10, DATA [0xFF * 4736]    # DTM1 (white baseline)
CMD 0x13, DATA [framebuffer]    # DTM2 (new image)
CMD 0x12, wait_busy              # DRF (refresh)
CMD 0x02                         # POF (power off)
```

### Key Commands
- **DTM1 (0x10)**: Previous frame buffer (for comparison)
- **DTM2 (0x13)**: Current frame buffer (image to display)
- **DRF (0x12)**: Display refresh (wait until busy goes high then low)
- **PON (0x04)**: Power on
- **POF (0x02)**: Power off
- **BUSY (GPIO 26)**: Busy signal, poll until idle

---

## Verified Working Code (Phase 1)

**Status**: ✅ Core display control working
- Hardware reset sequence
- UC8151 initialization (9 steps)
- Frame buffer creation and management
- Deep clean execution
- Coordinate system verification: 5×5 black square at (0,0)-(4,4) displays correctly
- Display refresh cycle

**Reference**: `app.rb` lines 49-157 (verified working)

---

## Reference Implementations

### C++ (Pimoroni)
- Repository: https://github.com/pimoroni/pimoroni-pico
- Driver: `/drivers/uc8151/uc8151.cpp`
- Key insight: Column-oriented partial update indexing (different from frame buffer layout)

### MicroPython (antirez)
- Repository: https://github.com/antirez/uc8151_micropython
- Driver: `uc8151.py`
- Uses `framebuf.MONO_HLSB` (horizontal LSB, row-major layout - same as our implementation)
- Includes comprehensive LUT documentation and grayscale examples

### UC8151 Datasheet
- **Main**: https://www.crystalfontz.com/controllers/datasheet-viewer.php?id=511
- **Alternative**: ED029TC1 datasheet (IL0373 compatible)

---

## Deployment

**Toolchain**:
- PicoRuby compiler: `picorbc`
- Badger 2040 mounts as USB storage

**Deploy Steps**:
```bash
picorbc app.rb                    # Generate app.mrb
cp app.mrb /Volumes/NO\ NAME/home/  # Copy to device
```

---

## Development Phases

Detailed task breakdown: see `TODO.md`

1. **Phase 1** ✅: Core display control
2. **Phase 2**: Drawing primitives (set_pixel, fill_rect, draw_line, draw_circle)
3. **Phase 3**: QR code display
4. **Phase 4**: Text rendering
5. **Phase 5**: Final integration and layout
6. **Phase 6**: Hardware testing and optimization

---

**Status**: Phase 1 Complete - Ready for Phase 2 implementation
**Last Updated**: 2026-02-01
