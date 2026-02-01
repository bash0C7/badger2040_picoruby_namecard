# Badger 2040 PicoRuby Implementation - Task List

## Overview

Comparison: app.rb (current skeleton) vs spec.md (ideal specification)

**Status**: Phase 1 Complete - Waiting for Phase 2 and beyond

---

## Phase 1: Core Display Control ✅ (COMPLETED)

- [x] Hardware reset sequence (RST pin control)
- [x] UC8151 initialization (9-step sequence)
- [x] Frame buffer creation (4,736 bytes)
- [x] Deep clean execution (black → white)
- [x] Coordinate system verification (row-major, MSB-first)
- [x] Test pixel drawing (5×5 black square at origin)
- [x] Display refresh cycle (DTM1/DTM2/DRF)

**Verified**: Left-bottom 5×5 black area displayed correctly at (0,0)-(4,4) coordinates

---

## Phase 2: Core Library Functions

### Task 2.1: Extract set_pixel() as Reusable Function
**Status**: Not Started
**Priority**: High
**Description**:
- Extract hardcoded pixel-setting logic from test code (lines 109-120)
- Create standalone function `set_pixel(fb, x, y, color)`
- Add bounds checking (x: 0-127, y: 0-295)
- Support both black (0) and white (1) colors
- Verify with test cases

**Implementation Location**: Create utility functions section in app.rb

**Test Cases**:
```ruby
# Test 1: Single pixel at origin
set_pixel(fb, 0, 0, 0)  # should set bit at fb[0]

# Test 2: Single pixel at top-right
set_pixel(fb, 127, 295, 0)  # should set bit at fb[4735]

# Test 3: White color (restore)
set_pixel(fb, 0, 0, 1)  # should restore bit
```

### Task 2.2: Implement fill_rect()
**Status**: Not Started
**Priority**: High
**Description**:
- Fill rectangular area with specified color
- Signature: `fill_rect(fb, x, y, width, height, color)`
- Optimize for horizontal lines (set entire bytes where possible)
- Must handle partial byte edges

**Test Cases**:
```ruby
# Full-byte aligned test
fill_rect(fb, 0, 0, 8, 10, 0)  # 8 pixels wide (1 byte per row)

# Non-aligned test
fill_rect(fb, 3, 5, 10, 8, 0)  # 10 pixels wide (spans 2 bytes)

# Single-pixel high rectangle
fill_rect(fb, 10, 20, 5, 1, 0)
```

### Task 2.3: Implement draw_line()
**Status**: Not Started
**Priority**: Medium
**Description**:
- Draw line using Bresenham algorithm
- Signature: `draw_line(fb, x0, y0, x1, y1, color)`
- Handle diagonal, horizontal, vertical cases
- Optimize for common cases

**Test Cases**:
```ruby
# Horizontal line
draw_line(fb, 0, 10, 20, 10, 0)

# Vertical line
draw_line(fb, 50, 0, 50, 50, 0)

# Diagonal line
draw_line(fb, 0, 0, 50, 50, 0)
```

### Task 2.4: Implement draw_circle()
**Status**: Not Started
**Priority**: Medium
**Description**:
- Draw circle outline using Midpoint Circle algorithm
- Signature: `draw_circle(fb, cx, cy, radius, color, filled=false)`
- Support both filled and outline versions

**Test Cases**:
```ruby
# Small circle
draw_circle(fb, 64, 148, 10, 0, false)

# Filled circle
draw_circle(fb, 64, 148, 15, 0, true)
```

---

## Phase 3: QR Code Display

### Task 3.1: Parse QR Code Image
**Status**: Not Started
**Priority**: High
**Description**:
- Load qr.png from filesystem
- Extract bit pattern (21×21 or 25×25 pixels typical)
- Store as efficient binary representation
- Document expected QR code size

**Implementation Notes**:
- PicoRuby has limited image processing
- May need to convert PNG to raw binary format beforehand
- Or embed QR code data as hexadecimal string

**File Reference**: qr.png (already exists in project)

### Task 3.2: Implement draw_qr_code()
**Status**: Not Started
**Priority**: High
**Description**:
- Draw QR code at specified position
- Signature: `draw_qr_code(fb, x, y, qr_data)`
- Scale QR module appropriately (2×2 or 3×3 pixels per module)
- Ensure it fits on 128×296 display

**Layout Considerations**:
```
Display: 128 wide × 296 tall

Proposed layout:
- Text "bash0C7" at top-left
- QR code to the right of text or below
- Center vertically on screen
```

**Test Cases**:
```ruby
# Draw QR code at position
draw_qr_code(fb, 40, 50, qr_data)

# Verify it's visible in frame buffer
# (rough validation: not all pixels should be white)
```

---

## Phase 4: Text Display

### Task 4.1: Integrate Font Support
**Status**: Not Started
**Priority**: High
**Description**:
- Choose font: Shinonome or bitmap font
- Load font data (glyph bitmaps)
- Support ASCII characters minimum
- Consider: "bash0C7" = 7 characters

**Implementation Options**:
1. Pre-compute glyph bitmaps
2. Embed font as hexadecimal
3. Use simple 8×8 or 5×7 monospace

**Constraints**:
- PicoRuby has no external font libraries
- Must be simple and memory-efficient

### Task 4.2: Implement draw_text()
**Status**: Not Started
**Priority**: High
**Description**:
- Draw text string at specified position
- Signature: `draw_text(fb, x, y, text, font_data, color)`
- Handle character spacing
- Optimize for PicoRuby memory

**Test Cases**:
```ruby
# Simple text
draw_text(fb, 10, 20, "bash0C7", font_data, 0)

# Verify each character position
# "b" at (10, 20)
# "a" at (18, 20)
# etc.
```

---

## Phase 5: Final Integration and Layout

### Task 5.1: Design Display Layout
**Status**: Not Started
**Priority**: High
**Description**:
- Decide text + QR code positioning
- Text "bash0C7" placement (top-left? top-center?)
- QR code placement (right side? below text?)
- Verify visual balance on 128×296 display

**Proposed Layout Options**:

**Option A: Horizontal Layout**
```
┌────────────────────────────────┐
│ bash0C7   [QR Code Area]       │
│           [128×128 typical]    │
│                                │
└────────────────────────────────┘
```

**Option B: Vertical Layout**
```
┌────────────────────────────────┐
│        bash0C7                 │
│                                │
│     [QR Code Area]             │
│     [128×128 typical]          │
│                                │
└────────────────────────────────┘
```

**Option C: Stack Layout**
```
┌────────────────────────────────┐
│                                │
│         bash0C7                │
│                                │
│      [QR Code Area]            │
│      [128×128 typical]         │
│                                │
│                                │
└────────────────────────────────┘
```

**Task**: Decide and document preferred layout

### Task 5.2: Implement Complete Application
**Status**: Not Started
**Priority**: High
**Description**:
- Combine init + deep_clean + draw_text + draw_qr_code
- Follow spec.md update sequence
- Call GC.start strategically to prevent memory overflow
- Final cleanup: remove debug prints, keep essential logs

**Pseudo-code**:
```ruby
# 1. Initialize hardware
init_hardware()

# 2. Initialize display
init_display()

# 3. Create frame buffer
fb = create_framebuffer()

# 4. Draw content
draw_text(fb, x_text, y_text, "bash0C7", font, 0)
draw_qr_code(fb, x_qr, y_qr, qr_data)

# 5. Update display
deep_clean()  # if needed
update_display(fb)

# 6. Power off
power_off()
```

### Task 5.3: Code Cleanup and Optimization
**Status**: Not Started
**Priority**: Medium
**Description**:
- Remove debug prints (lines with p "..." and puts)
- Keep essential logging for deployment
- Verify memory usage (no memory leaks)
- Test on actual hardware
- Create final production version

**Cleanup Targets**:
- Lines 1-5: debug require logging
- Lines 11-13: command label prints
- Lines 17-19, 23, 32: data transfer debug prints
- Lines 47, 51, 81-83, 88, 97, 105-122, 127-137, 161-162: verbose logging

**Keep**:
- Error messages
- Critical state indicators (if any)
- Hardware status (optional)

---

## Phase 6: Deployment and Testing

### Task 6.1: Hardware Verification
**Status**: Not Started
**Priority**: High
**Description**:
- Deploy to Badger 2040 using PicoRuby toolchain
- Verify display renders correctly
- Check text legibility
- Verify QR code scanability
- Test coordinate system (all four corners)

**Deployment Steps**:
```bash
# Compile PicoRuby
picorbc app.rb  # generates app.mrb

# Copy to Badger 2040
cp app.mrb /Volumes/NO\ NAME/home/
```

### Task 6.2: Refinement Based on Hardware Testing
**Status**: Not Started
**Priority**: Medium
**Description**:
- Adjust QR code scaling if needed
- Adjust text positioning
- Optimize display refresh (may need additional deep_clean)
- Address any visual artifacts

### Task 6.3: Create Reusable Library
**Status**: Not Started
**Priority**: Low
**Description**:
- Extract core functions into badger2040.rb module
- Make easily reusable for future projects
- Document API clearly
- Include example usage

**Proposed Structure**:
```ruby
# badger2040.rb
class Badger2040
  def initialize(spi, pins)
    @spi = spi
    @pins = pins
    @fb = nil
  end

  def init
    # hardware init
  end

  def set_pixel(x, y, color)
    # pixel setting
  end

  def fill_rect(x, y, w, h, color)
    # rectangle filling
  end

  def draw_line(x0, y0, x1, y1, color)
    # line drawing
  end

  def update
    # display update
  end
end
```

---

## Blockers and Dependencies

### Current Blockers
None - all Phase 1 tasks completed successfully

### Dependencies
- **Phase 2**: Requires Phase 1 completion ✅
- **Phase 3**: Requires Phase 2 (fill_rect, set_pixel) ✅
- **Phase 4**: Requires font data (external dependency - TBD)
- **Phase 5**: Requires Phase 3 + Phase 4
- **Phase 6**: Requires Phase 5 completion

### External Dependencies to Resolve
1. **Font Data**: Need bitmap font for text rendering (Shinonome or similar)
2. **QR Code Data**: qr.png exists - needs parsing strategy

---

## Summary Statistics

| Phase | Status | Tasks | Completed | In Progress |
|-------|--------|-------|-----------|-------------|
| 1 | ✅ Complete | 7 | 7 | 0 |
| 2 | 🔲 Not Started | 4 | 0 | 0 |
| 3 | 🔲 Not Started | 2 | 0 | 0 |
| 4 | 🔲 Not Started | 2 | 0 | 0 |
| 5 | 🔲 Not Started | 3 | 0 | 0 |
| 6 | 🔲 Not Started | 3 | 0 | 0 |
| **Total** | | **21** | **7** | **0** |

---

## Next Steps

**Immediate Priority** (Phase 2):
1. Extract set_pixel() function from test code
2. Implement fill_rect()
3. Create test script to verify both functions
4. Commit working code

**Then** (Phase 3):
1. Resolve QR code parsing approach
2. Implement draw_qr_code()

**Finally** (Phase 4+):
1. Decide on font solution
2. Implement text drawing
3. Create final layout

---

**Last Updated**: 2026-02-01
**Phase Status**: Ready for Phase 2 Implementation
