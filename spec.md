# Badger 2040 PicoRuby E-ink Display Specification

## Project Overview

Display QR codes and text on Badger 2040 (RP2040 + UC8151 E-ink controller) using PicoRuby.

**Key Goal**:
- Initialize UC8151 display controller
- Draw QR code and text on 128×296 pixel e-ink screen
- Display "bash0C7 <QRCode>" on the namecard
- Keep image on screen without power (e-ink characteristic)

## Hardware Specification

### Badger 2040
- **MCU**: RP2040 (Raspberry Pi Pico)
- **Display**: UC8151 / IL0373 E-ink controller
- **Resolution**: 128 × 296 pixels
- **Aspect Ratio**: Horizontal badge (296mm wide × 128mm tall)
- **Color Depth**: 1-bit (black/white only)
- **Frame Buffer Size**: 4,736 bytes (128 × 296 ÷ 8)

### Pin Assignment
```
SPI0: SCK=18, MOSI=19, MISO=16
CS=17, DC=20, RST=21, BUSY=26
3V3_EN=10 (Power control)
```

### E-ink Display Characteristics
- Pixel requires power to change, but maintains state without power
- Partial updates cause flickering (white flash)
- Deep clean needed after major updates to reset memory
- Temperature compensation available (built-in sensor)

## Coordinate System

**Physical Layout** (horizontal badge):
```
    (0,295) ←── y-axis ──┐
       ┌────────────┐     │
       │            │     │ upward
       │   Screen   │     ↓
       │            │
       └────────────┘
    (0,0) ──→ x-axis (127,0)
         left      right

Origin: bottom-left
X-axis: left → right (0 to 127)
Y-axis: bottom → up (0 to 295)
```

**Important**: When code specifies (0,0), it refers to the bottom-left corner of the physical display.

## Frame Buffer Memory Layout

### Row-Major (Horizontal) Layout

**Verified**: This implementation uses **row-major, row-oriented** layout.

```
Frame buffer format:
byte_index = (y * WIDTH + x) / 8
bit_index  = 7 - (x % 8)  // MSB-first bit ordering

Example: Position (5, 10)
byte_idx = (10 * 128 + 5) / 8 = 1280 / 8 = 160
bit_idx  = 7 - (5 % 8) = 7 - 5 = 2
→ access fb[160], check bit 2 (MSB-first)
```

### Bit Representation
- `0` = black (set bit to 0)
- `1` = white (set bit to 1)

### Frame Buffer Initialization
```ruby
@framebuffer = "\xFF" * (WIDTH * HEIGHT / 8)  # All white (4,736 bytes)
```

## UC8151 Command Specification

### Initialization Sequence (Verified Working)

**Source**: Verified against UC8151 datasheet and confirmed working in app.rb (lines 49-76)

```ruby
# 1. Hardware reset
rst.write(0)
sleep_ms(200)
rst.write(1)
sleep_ms(200)
wait_until_idle(busy)

# 2. PSR (Panel Setting Register) - 0x00
# Value: 0x5F = 0b01011111
#   Bit 7-6: Resolution (10 = 128×296)
#   Bit 5: LUT (0=OTP, 1=REG)
#   Bit 4: Format (0=BWR, 1=BW)
#   Bit 3: Scan direction (0=DOWN, 1=UP)
#   Bit 2: Shift direction (0=LEFT, 1=RIGHT)
#   Bit 1: Booster (0=OFF, 1=ON)
#   Bit 0: Reset (0=SOFT, 1=NONE)
CMD 0x00, DATA [0x5F]

# 3. PWR (Power Setting) - 0x01
CMD 0x01, DATA [0x03, 0x00, 0x2B, 0x2B, 0x1E]

# 4. BTST (Booster Setting) - 0x06
CMD 0x06, DATA [0x17, 0x17, 0x17]

# 5. PLL (Clock Frequency) - 0x30
CMD 0x30, DATA [0x3C]  # Frequency setting code

# 6. PON (Power On) - 0x04
CMD 0x04
wait_until_idle(busy)

# 7. TRES (Resolution Setting) - 0x61
CMD 0x61, DATA [0x80, 0x01, 0x28]  # 128 × 296

# 8. CDI (VCOM/Data Interval) - 0x50
CMD 0x50, DATA [0x13]

# 9. TCON (Gate/Source Setting) - 0x60
CMD 0x60, DATA [0x22]
```

### Display Update Sequence

#### Deep Clean (After Major Updates)
```ruby
# Clear chip memory: black → white transition
CMD 0x10, DATA [0x00 * 4736]  # DTM1 (previous/black)
CMD 0x13, DATA [0xFF * 4736]  # DTM2 (current/white)
CMD 0x12  # DRF (Display Refresh)
wait_until_idle(busy)
```

#### Normal Update
```ruby
# Standard refresh cycle (for subsequent updates)
CMD 0x04  # PON (Power on - required if display was powered off)
wait_until_idle(busy)

# Optional but recommended for reliability (from MicroPython reference):
CMD 0x92  # PTOU (Partial mode off - ensures full refresh, not partial)

# Image transfer
CMD 0x10, DATA [0xFF * 4736]  # DTM1 (white baseline for comparison)
CMD 0x13, DATA [framebuffer]  # DTM2 (new image to display)

# Optional but recommended:
CMD 0x11  # DSP (Data stop - flush data pipeline before refresh)

# Refresh
CMD 0x12  # DRF (Display Refresh)
wait_until_idle(busy)

# Power off
CMD 0x02  # POF (Power off - save energy)
```

**Important Notes**:
- **PON required**: Must be called if display was previously powered off (POF)
- **PTOU/DSP optional**: These commands are recommended for reliable multi-update operation
- **Single-update programs**: Like app.rb (one-shot namecard), can omit PON (already active) and PTOU/DSP
- **Multi-update loops**: Must include PON and should include PTOU/DSP

### Important Commands

| Command | Code | Purpose | Notes |
|---------|------|---------|-------|
| PSR | 0x00 | Panel Setting Register | Controls resolution, scan, shift |
| PWR | 0x01 | Power Setting | Voltage configuration |
| PON | 0x04 | Power On | Enable supply |
| BTST | 0x06 | Booster Setting | Voltage multiplier |
| PLL | 0x30 | Clock Frequency | Display refresh rate |
| TRES | 0x61 | Resolution | Explicit size specification |
| TCON | 0x60 | Gate/Source Setting | Display timing |
| CDI | 0x50 | VCOM/Data Interval | Signal timing |
| DTM1 | 0x10 | Previous Frame Buffer | Old image for comparison |
| DTM2 | 0x13 | Current Frame Buffer | New image to display |
| DRF | 0x12 | Display Refresh | Execute update |
| POF | 0x02 | Power Off | Disable supply |
| BUSY | GPIO 26 | Busy Signal | Poll until idle |

## Drawing Primitives API

### Core Function: set_pixel

```ruby
def set_pixel(framebuffer, x, y, color)
  # color: 0 = black, 1 = white

  byte_idx = (y * WIDTH + x) / 8
  bit_idx = 7 - (x % 8)

  current = framebuffer[byte_idx].ord
  if color == 0  # black
    framebuffer[byte_idx] = (current & ~(1 << bit_idx)).chr
  else  # white
    framebuffer[byte_idx] = (current | (1 << bit_idx)).chr
  end
end
```

### Expected Drawing Functions

```ruby
def fill_rect(fb, x, y, width, height, color)
  # Fill rectangle with specified color
end

def draw_line(fb, x0, y0, x1, y1, color)
  # Draw line using Bresenham or similar
end

def draw_circle(fb, cx, cy, radius, color)
  # Draw circle outline or filled
end

def draw_qr_code(fb, x, y, qr_data)
  # Draw QR code from binary data
end

def draw_text(fb, x, y, text, font)
  # Draw text using font bitmap
end
```

## Expected Deliverables

### Phase 1: Core Display Control ✅ (COMPLETED)
- ✅ Hardware reset sequence
- ✅ UC8151 initialization
- ✅ Frame buffer creation
- ✅ Deep clean execution
- ✅ Coordinate system verification
- ✅ set_pixel() function working

### Phase 2: Drawing Primitives
- Draw basic shapes (line, rectangle, circle)
- Implement efficient pixel setting
- Test coordinate system thoroughly

### Phase 3: QR Code Display
- Parse QR code image (qr.png)
- Convert to frame buffer format
- Position correctly on display
- Combine with text

### Phase 4: Text Display
- Integrate font rendering (Shinonome or similar)
- Draw text at specified positions
- Combine text and QR code layout

### Phase 5: Final Integration
- Combine all components
- Optimize for Badger 2040 hardware
- Create reusable library module
- Clean up memory usage (GC.start strategically)

## Final Output Format

Display on 128×296 horizontal badge:

```
┌──────────────────────────────────┐
│                                  │
│  bash0C7      [QR Code Here]     │
│              [128x128 area]      │
│                                  │
│                                  │
└──────────────────────────────────┘
128 pixels wide × 296 pixels tall
```

## Memory Constraints

- Available RAM: 520KB
- Frame Buffer: 4,736 bytes (fixed)
- Shallow nesting required
- Pre-allocate arrays before loops
- Avoid dynamic allocation
- Call `GC.start` after large operations

## Implementation Platform

- **Language**: PicoRuby (mruby/c subset, NOT standard Ruby)
- **Framework**: Terminus gem (GPIO/SPI control)
- **No stdlib**: Limited to PicoRuby mrbgems
- **Deployment**: Convert .rb → .mrb via picorbc compiler

## Reference Implementations

- **C++**: https://github.com/pimoroni/pimoroni-pico (drivers/uc8151/uc8151.cpp)
- **MicroPython**: https://github.com/antirez/uc8151_micropython (uc8151.py)
- **UC8151 Datasheet**: https://www.crystalfontz.com/controllers/datasheet-viewer.php?id=511

## Key Success Factors

1. **Correct Coordinate Transform**: Use row-major byte indexing and MSB-first bit ordering
2. **Proper PSR Configuration**: 0x5F for SCAN_UP + SHIFT_RIGHT
3. **Complete Initialization**: All 9 steps required for proper functionality
4. **Memory Efficiency**: Strategic GC.start calls, avoid allocations in loops
5. **Hardware Synchronization**: Always wait_until_idle(busy) after critical operations

---

## Implementation Source Requirements

**All implementations MUST be grounded in verified sources**:

### Verified Sources
1. **UC8151 Datasheet** (primary reference)
   - https://www.crystalfontz.com/controllers/datasheet-viewer.php?id=511
   - Register definitions, command sequences, timing diagrams

2. **Working Code Examples** (ground truth)
   - app.rb (Phase 1 verified on hardware)
   - C++ Pimoroni reference: https://github.com/pimoroni/pimoroni-pico/blob/main/drivers/uc8151/uc8151.cpp
   - MicroPython antirez: https://github.com/antirez/uc8151_micropython/blob/main/uc8151.py

3. **Standard Algorithms** (where applicable)
   - Bresenham line algorithm (computer graphics standard)
   - Midpoint circle algorithm (computer graphics standard)
   - Frame buffer row-major memory layout (standard embedded graphics)

### Implementation Notes
- **NO speculation** - every algorithm and value must come from above sources
- When uncertain, consult reference implementation or datasheet first
- Document algorithm source as inline comment
- Test implementations against reference behavior

---

**Status**: Phase 1 Complete - Display controller initialized and tested
**Verification Date**: 2026-02-01
**Last Updated**: 2026-02-01
