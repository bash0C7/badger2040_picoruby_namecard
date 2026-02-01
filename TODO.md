# Badger 2040 PicoRuby Implementation - Task List

## Overview

Comparison: app.rb (current skeleton) vs spec.md (ideal specification)

**Status**: Phase 1 Complete - Waiting for Phase 2 and beyond

## Implementation Requirements

**ALL implementations MUST be based on**:
1. ✅ UC8151 datasheet (official reference)
2. ✅ Verified working code (app.rb Phase 1)
3. ✅ Reference implementations:
   - C++ Pimoroni: https://github.com/pimoroni/pimoroni-pico/blob/main/drivers/uc8151/uc8151.cpp
   - MicroPython antirez: https://github.com/antirez/uc8151_micropython/blob/main/uc8151.py
4. ❌ NO speculation, guessing, or assumptions
5. ❌ If uncertain, investigate source code or datasheet first

**Code Review Checklist**:
- [ ] Implementation matches reference code
- [ ] Comments cite source (e.g., "// Bresenham algorithm")
- [ ] Test cases cover reference implementation behavior
- [ ] Hardware constraints considered (memory, bit-width)

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
**Source**: app.rb lines 109-120 (working reference) + CLAUDE.md spec.md
**Description**:
- Extract hardcoded pixel-setting logic from test code (lines 109-120)
- Create standalone function `set_pixel(fb, x, y, color)`
- Add bounds checking (x: 0-127, y: 0-295)
- Support both black (0) and white (1) colors
- Verify with test cases

**Implementation Basis**:
```ruby
# Working logic from app.rb (lines 110-116)
byte_idx = (y * WIDTH + x) / 8
bit_idx = 7 - (x % 8)
old_val = @framebuffer[byte_idx].ord
new_val = old_val & ~(1 << bit_idx)  # for black (0)
# or
new_val = old_val | (1 << bit_idx)   # for white (1)
@framebuffer[byte_idx] = new_val.chr
```

**Implementation Location**: Create utility functions section in app.rb

**Test Cases** (must verify memory layout matches CLAUDE.md coordinate system):
```ruby
# Test 1: Single pixel at origin (bottom-left)
set_pixel(fb, 0, 0, 0)  # should set bit at fb[0]
# Expected: byte_idx = (0 * 128 + 0) / 8 = 0

# Test 2: Single pixel at top-right
set_pixel(fb, 127, 295, 0)  # should set bit at fb[4735]
# Expected: byte_idx = (295 * 128 + 127) / 8 = 4735

# Test 3: White color (restore)
set_pixel(fb, 0, 0, 1)  # should restore white bit

# Test 4: Bounds checking
set_pixel(fb, 128, 0, 0)  # should handle gracefully or raise error
set_pixel(fb, 0, 296, 0)  # should handle gracefully or raise error
```

### Task 2.2: Implement fill_rect()
**Status**: Not Started
**Priority**: High
**Source**: C++ Pimoroni and standard graphics algorithms
**Description**:
- Fill rectangular area with specified color
- Signature: `fill_rect(fb, x, y, width, height, color)`
- Optimize for horizontal lines (set entire bytes where possible to reduce bit operations)
- Must handle partial byte edges correctly

**Implementation Strategy** (based on standard framebuffer techniques):
1. Loop through each scan line (y: y to y+height-1)
2. For each line, fill from x to x+width-1
3. Optimize by checking if entire bytes can be filled:
   - If x is byte-aligned and width is multiple of 8, fill entire bytes
   - Otherwise, handle partial bytes with bit manipulation
4. Use set_pixel() for small rectangles or fallback

**Reference**:
- C++ Pimoroni uses byte-aligned fills in critical loops
- MicroPython framebuf module uses similar byte-packing approach

**Test Cases** (verify coordinate system and byte layout):
```ruby
# Test 1: Full-byte aligned (8 pixels = 1 byte per row)
fill_rect(fb, 0, 0, 8, 10, 0)
# Expected: 10 bytes modified (0, 128, 256, ...)

# Test 2: Non-aligned test (spans partial bytes)
fill_rect(fb, 3, 5, 10, 8, 0)
# Expected: Each row touches 2 bytes due to bit misalignment

# Test 3: Single-byte wide rectangle
fill_rect(fb, 10, 20, 5, 1, 0)

# Test 4: Full screen black
fill_rect(fb, 0, 0, 128, 296, 0)
# Expected: All 4736 bytes = 0x00

# Test 5: White color
fill_rect(fb, 0, 0, 16, 16, 1)
# Expected: Specific bytes = 0xFF in correct positions
```

### Task 2.3: Implement draw_line()
**Status**: Not Started
**Priority**: Medium
**Source**: Bresenham line algorithm (standard computer graphics)
**Description**:
- Draw line using Bresenham algorithm (optimal for pixel grids)
- Signature: `draw_line(fb, x0, y0, x1, y1, color)`
- Handle diagonal, horizontal, vertical cases
- Optimize horizontal/vertical lines (use fill_rect approach)

**Algorithm Basis**:
- Bresenham algorithm: https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
- Used in C++ Pimoroni and most graphics libraries
- Reduces line drawing to integer arithmetic (no floating point)

**Implementation Strategy**:
1. Handle special cases: horizontal, vertical (use fill_rect for speed)
2. Use Bresenham for diagonal lines
3. Respect coordinate system: origin (0,0) = bottom-left, y increases upward

**Test Cases** (verify line endpoints and pixel count):
```ruby
# Test 1: Horizontal line
draw_line(fb, 0, 10, 20, 10, 0)
# Expected: 21 pixels on same y-coordinate

# Test 2: Vertical line
draw_line(fb, 50, 0, 50, 50, 0)
# Expected: 51 pixels on same x-coordinate

# Test 3: Diagonal line (45 degrees)
draw_line(fb, 0, 0, 50, 50, 0)
# Expected: ~50 pixels along diagonal

# Test 4: Verify coordinate system (bottom-left origin)
draw_line(fb, 0, 0, 10, 10, 0)
# Expected: Line from bottom-left upward and rightward
```

### Task 2.4: Implement draw_circle()
**Status**: Not Started
**Priority**: Medium
**Source**: Midpoint Circle Algorithm (standard computer graphics)
**Description**:
- Draw circle outline using Midpoint Circle algorithm (optimal for pixel grids)
- Signature: `draw_circle(fb, cx, cy, radius, color, filled=false)`
- Support both filled and outline versions using 8-way symmetry

**Algorithm Basis**:
- Midpoint Circle Algorithm: https://en.wikipedia.org/wiki/Midpoint_circle_algorithm
- Reduces circle drawing to integer arithmetic
- 8-way symmetry reduces computation by 8×

**Implementation Strategy**:
1. Midpoint algorithm for outline circles
2. Use horizontal lines (fill_rect) for filled circles (scan line algorithm)
3. Respect coordinate system: center (cx, cy), origin is bottom-left

**Reference**:
- C++ graphics libraries (e.g., Adafruit GFX)
- MicroPython machine vision libraries

**Test Cases** (verify 8-way symmetry and center position):
```ruby
# Test 1: Small circle outline
draw_circle(fb, 64, 148, 10, 0, false)
# Expected: ~63 pixels forming circle outline

# Test 2: Filled circle
draw_circle(fb, 64, 148, 15, 0, true)
# Expected: All pixels within radius filled

# Test 3: Tiny circle (radius 1-2)
draw_circle(fb, 50, 50, 1, 0, false)

# Test 4: Large circle
draw_circle(fb, 64, 148, 40, 0, false)
```

---

## Phase 3: QR Code Display

### Task 3.1: Investigate QR Code Image Format
**Status**: Not Started
**Priority**: High
**Source**: qr.png (examine existing file)
**Description**:
- Analyze qr.png file format and size
- Determine QR code version (size in modules: 21×21, 25×25, 29×29, etc.)
- Extract bit pattern and dimensions
- Decide on binary representation strategy
- **NO speculation** - must first examine actual file properties

**Investigation Steps**:
1. Inspect qr.png file size and dimensions
2. Determine pixel format (1-bit, 8-bit grayscale, RGB, etc.)
3. Decide on approach:
   - Option A: Convert PNG to raw binary format beforehand
   - Option B: Embed QR code as hexadecimal string constant
   - Option C: Use simple PNG parsing in PicoRuby (if stdlib available)
4. Document chosen approach and rationale

**File Reference**: qr.png (already exists in project)

**Constraints**:
- PicoRuby has NO external image libraries (limited mrbgems)
- Cannot use gems like `png` or `chunky_png`
- Must use manual binary data or pre-processing

### Task 3.2: Implement draw_qr_code()
**Status**: Not Started
**Priority**: High
**Depends On**: Task 3.1 (QR code format decision)
**Description**:
- Draw QR code at specified position on frame buffer
- Signature: `draw_qr_code(fb, x, y, qr_data, module_size)`
- module_size: pixels per QR module (typically 2-4 for 128×296 display)
- Must respect coordinate system (origin bottom-left, y increases upward)

**Implementation Strategy**:
1. Iterate through QR code modules (bit array)
2. For each module, draw module_size×module_size pixel block
3. Black module (0) = draw pixels as black
4. White module (1) = leave pixels white
5. Handle coordinate transformation (QR typically top-left origin)

**Layout Considerations** (Task 5.1 will finalize):
```
Display: 128 wide × 296 tall

Typical layout options:
- Text "bash0C7" at top-left (needs conversion to bottom-left coords)
- QR code to the right or below
- 128×128 QR area with 2× module scaling fits easily
```

**Test Cases** (after Phase 3.1):
```ruby
# Determine QR size from Task 3.1
qr_size = 21  # or 25, 29, etc.
module_size = 3  # 3 pixels per module = 63×63 display pixels

# Draw QR code at position
draw_qr_code(fb, 10, 100, qr_data, module_size)

# Verification:
# - Expected display size: qr_size * module_size pixels
# - Pattern should be visible (mixture of black/white modules)
# - Pattern should match reference image when inspected
```

---

## Phase 4: Text Display

### Task 4.1: Research and Select Font Solution
**Status**: Not Started
**Priority**: High
**Source**: Investigate available font options for PicoRuby
**Description**:
- Choose font solution appropriate for PicoRuby constraints
- Load font data (glyph bitmaps) efficiently
- Support ASCII characters minimum (for "bash0C7" = 7 characters)
- **NO speculation** - must research actual PicoRuby capabilities first

**Investigation Approach**:
1. Check PicoRuby mrbgems for font libraries
   - Search: https://github.com/picoruby/picoruby/tree/main/mrbgems
2. Evaluate options:
   - Option A: Embedded bitmap font (8×8 or 5×7 monospace)
   - Option B: Shinonome font (Japanese + ASCII)
   - Option C: Pre-computed glyph data (hex strings)
3. Consider Badger 2040 precedents
   - Pimoroni C++ examples
   - Any existing PicoRuby font implementations

**Constraints**:
- PicoRuby: NO external gems like `ttf2bmf` or `fonttools`
- Memory: Keep font data < 50KB
- Must work with existing binary data in program

**Minimum Requirements**:
- ASCII 32-126 (printable characters)
- At least 5×7 pixels per character for readability
- Monospace preferred (simpler indexing)

### Task 4.2: Implement draw_text()
**Status**: Not Started
**Priority**: High
**Depends On**: Task 4.1 (Font solution decision)
**Description**:
- Draw text string at specified position on frame buffer
- Signature: `draw_text(fb, x, y, text, font_data, color)`
- Each character advances by font width
- Respect coordinate system (origin bottom-left)

**Implementation Strategy**:
1. For each character in text:
   - Look up glyph in font_data
   - Draw glyph pixels using fill_rect or set_pixel
   - Advance x by character width
2. Handle character spacing/kerning (if used)
3. Bounds checking (text extends off-screen)

**Implementation Basis**:
- Monospace fonts simplify character positioning
- Typical character width: 6-8 pixels
- Typical character height: 5-8 pixels
- Glyph data: 1-bit (packed bitmap per character)

**Test Cases** (after font solution finalized):
```ruby
# Simple text "bash0C7"
draw_text(fb, 10, 280, "bash0C7", font_data, 0)  # y=280 = near top of display (bottom-left origin)

# Verify layout:
# Character positions depend on font width
# If 6px wide: b(10), a(16), s(22), h(28), 0(34), C(40), 7(46)

# Partial text
draw_text(fb, 50, 100, "test", font_data, 0)

# Single character
draw_text(fb, 0, 0, "A", font_data, 0)
```

---

## Phase 5: Final Integration and Layout

### Task 5.1: Design Display Layout
**Status**: Not Started
**Priority**: High
**Based On**: Phase 2-4 completion (primitives + QR + text working)
**Description**:
- Finalize text + QR code positioning
- Text "bash0C7" placement (position in coordinate system)
- QR code placement and scaling
- Verify visual balance on 128×296 display
- Document layout with coordinate values

**Layout Constraints**:
- Display: 128 pixels wide × 296 pixels tall
- Origin: (0, 0) = bottom-left
- Y increases upward, X increases rightward
- QR code typical size: 21×21 modules (63×63 with 3× scaling)
- Text "bash0C7": ~7 characters × ~6px each = ~42px wide

**Proposed Layout Options**:

**Option A: Text Top-Left, QR Bottom-Right**
```
(0,296) ──────────────────────── (128,296)
   │ bash0C7
   │
   │                    [QR Code]
   │                       ■ ■ ■
(0,0) ──────────────────────── (128,0)

Coordinates (bottom-left origin):
- Text: x=5, y=270
- QR: x=50, y=30
```

**Option B: Text Top-Center, QR Below**
```
(0,296) ──────────────────────── (128,296)
   │      bash0C7
   │
   │
   │      [QR Code]
   │         ■ ■ ■
   │
(0,0) ──────────────────────── (128,0)

Coordinates:
- Text: x=40, y=270
- QR: x=35, y=60
```

**Option C: Side by Side**
```
(0,296) ──────────────────────── (128,296)
   │ bash0C7 [QR Code]
   │         ■ ■ ■ ■
   │         ■ ■ ■ ■
(0,0) ──────────────────────── (128,0)

Coordinates:
- Text: x=5, y=150
- QR: x=65, y=60
```

**Task**:
1. Implement draft layout (use Option B as default)
2. Test on hardware
3. Adjust if visual balance unsatisfactory

### Task 5.2: Implement Complete Application
**Status**: Not Started
**Priority**: High
**Depends On**: Task 5.1, Phase 2-4 functions complete
**Source**: spec.md (initialization, update sequences)
**Description**:
- Combine all components: init + deep_clean + draw_text + draw_qr_code
- Follow spec.md update sequence (verified from UC8151 datasheet)
- Call GC.start strategically to prevent memory overflow
- Final cleanup: remove debug prints, keep essential logs

**Implementation Flow** (follows spec.md):

```ruby
# 1. Initialize hardware (from app.rb lines 41-46)
spi = SPI.new(...)
cs, dc, rst, busy, pwr3v3 = setup_gpio()

# 2. Hardware reset (from app.rb lines 49-50)
rst.write(0); sleep_ms(200); rst.write(1); sleep_ms(200)
wait_until_idle(busy)

# 3. UC8151 Initialization (from CLAUDE.md table, spec.md lines 87-96)
# Send PSR, PWR, BTST, PLL, PON, TRES, CDI, TCON commands
init_display(spi, cs, dc, busy)

# 4. Create frame buffer
fb = "\xFF" * 4736  # All white

# 5. Deep Clean (from spec.md lines 130-137)
deep_clean(spi, cs, dc, busy)

GC.start  # Memory management

# 6. Draw content (Phase 2-4 functions)
draw_text(fb, x_text, y_text, "bash0C7", font_data, 0)
draw_qr_code(fb, x_qr, y_qr, qr_data, module_size)

GC.start  # Before large data transfer

# 7. Display Update (from spec.md lines 139-157)
# PON -> DTM1 -> DTM2 -> DRF -> POF
update_display(spi, cs, dc, busy, fb)

# 8. Done (program exits, display content persists)
```

**Memory Management**:
- Call GC.start after framebuffer creation (large allocation)
- Call GC.start before display update (large data transfer)
- Avoid allocations in loops

### Task 5.3: Code Cleanup and Optimization
**Status**: Not Started
**Priority**: Medium
**Depends On**: Task 5.2 complete and working
**Description**:
- Remove debug prints from development
- Extract reusable library functions (badger2040.rb module)
- Verify memory usage (strategic GC.start calls)
- Create final production version

**Code Cleanup**:
- Remove all debug prints: `p "..."`, `puts "..."`
- Keep only essential hardware initialization code
- Document critical sections with inline comments

**Library Extraction** (optional for Phase 5, important for Phase 6):
Extract following functions into `badger2040.rb` module:
- `init_display(spi, cs, dc, busy)` - hardware + controller init
- `set_pixel(fb, x, y, color)` - single pixel
- `fill_rect(fb, x, y, w, h, color)` - rectangle
- `draw_line(fb, x0, y0, x1, y1, color)` - Bresenham line
- `draw_circle(fb, cx, cy, r, color, filled)` - circle
- `draw_qr_code(fb, x, y, qr_data, scale)` - QR rendering
- `draw_text(fb, x, y, text, font, color)` - text rendering
- `update_display(spi, cs, dc, busy, fb)` - display refresh

**Memory Verification**:
- Confirm GC.start calls at appropriate locations
- No memory leaks (program terminates cleanly)
- All temporary allocations freed before exit

---

## Phase 6: Deployment and Testing

### Task 6.1: Hardware Verification
**Status**: Not Started
**Priority**: High
**Depends On**: Task 5.2 and 5.3 complete
**Source**: PicoRuby toolchain (picorbc compiler)
**Description**:
- Deploy compiled .mrb file to Badger 2040
- Verify display renders "bash0C7" + QR code correctly
- Check text legibility and QR code scanability
- Test coordinate system behavior (visual verification)

**Deployment Steps**:
```bash
# 1. Compile PicoRuby source to bytecode
picorbc app.rb  # generates app.mrb

# 2. Copy to Badger 2040 USB mount
cp app.mrb /Volumes/NO\ NAME/home/

# 3. Device auto-executes app.mrb on boot
# 4. Verify display update (should see "bash0C7" + QR code)
```

**Verification Checklist**:
- [ ] Display activates and shows new content
- [ ] "bash0C7" text appears at expected position
- [ ] QR code pattern is clearly visible
- [ ] QR code is scannable (test with QR scanner app)
- [ ] No flickering or artifacts
- [ ] E-ink persistence verified (image remains after power off)

### Task 6.2: Refinement Based on Hardware Testing
**Status**: Not Started
**Priority**: Medium
**Depends On**: Task 6.1 (must see actual hardware output)
**Description**:
- Adjust QR code scaling if readability insufficient
- Adjust text positioning for visual balance
- Address any display artifacts or refresh issues
- Document any hardware-specific quirks

**Potential Adjustments**:
- QR code scale: decrease if too small, increase if too large
- Text position: shift x/y if not properly centered
- Deep clean: may need additional runs if residual image visible
- Contrast: adjust black/white ratio if legibility poor

### Task 6.3: Documentation and Examples
**Status**: Not Started
**Priority**: Low
**Description**:
- Document final API in comments
- Create usage example (namecard.rb as template)
- Optional: Extract badger2040.rb module for reuse
- Document coordinate system and limitations

**Documentation Content**:
- API reference for all drawing functions
- Coordinate system explanation
- Memory constraints and GC guidelines
- Deployment procedure
- Example code snippets

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

---

## Coordinate System Status ✅ (RESOLVED 2026-02-01)

### Diagnostic Test Results
- **Test File**: experiment_coords.rb
- **Test Method**: 4-corner diagnostic pattern with varying line lengths and thickness
- **Result**: ALL patterns displayed at expected positions on hardware
- **Conclusion**: Coordinate system is 100% correct as documented in CLAUDE.md

**Confirmed Facts**:
```
Origin: (0, 0) = TOP-LEFT
X-axis: 0→127 (left → right) ✅
Y-axis: 0→295 (top → bottom) ✅
set_pixel() implementation: CORRECT ✅
Byte layout: row-major, MSB-first ✅
```

### Previous Issues (Context Update)

#### Former Issue 1: Text Display Direction Wrong
**Status**: ✅ RESOLVED - Coordinate system was correct
- Original assumption: Maybe coordinates were inverted (bottom-left origin)
- Reality: Coordinates ARE top-left origin, set_pixel() is 100% correct
- True root cause: NOT coordinate system (must be Terminus.draw callback behavior)
- Action: Phase 4 will address text rendering with correct coordinate knowledge

#### Former Issue 2: QR Code Not Displaying
**Status**: ✅ RESOLVED - Coordinate system was correct
- Original assumption: Maybe fill_rect() had bugs due to coordinate confusion
- Reality: Coordinate system verified; fill_rect() can now be trusted
- True root cause: NOT coordinate system (must investigate QR data interpretation)
- Action: Phase 3 will implement draw_qr_code() with proven coordinates

#### Former Issue 3: Layout Coordination
**Status**: ✅ RESOLVED - Now with verified coordinates
- Can confidently position text and QR code using (0,0)=top-left, y increases downward
- All future layout calculations use verified coordinate system

---

## Next Phase Tasks (Confirmed Ready for Phase 2+)

### Phase 2: Core Library Functions (READY TO START)
**Status**: High confidence with verified coordinate system

1. **Task 2.1**: Implement fill_rect() - coordinate system verified ✅
2. **Task 2.2**: Implement draw_line() - coordinate system verified ✅
3. **Task 2.3**: Implement draw_circle() - coordinate system verified ✅

### Phase 3: QR Code Display
**Status**: Proceed when Phase 2 complete
- Investigate qr.png format
- Implement draw_qr_code() with verified coordinates

### Phase 4: Text Display
**Status**: Proceed when Phase 3 complete
- Investigate Terminus.draw() callback mechanism (not a coordinate issue)
- Implement draw_text() with proper glyph handling

### Phase 5: Final Integration
**Status**: Proceed when Phases 2-4 complete
- Design display layout (coordinates are now certain)
- Integrate all components

---

**Last Updated**: 2026-02-01
**Current Phase Status**: Phase 1 ✅ Complete - Coordinate System Verified and Confirmed
**Ready For**: Phase 2 implementation with full confidence
