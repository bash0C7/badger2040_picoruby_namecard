puts "Line 1: Loading SPI..."
require 'spi'
puts "Line 2: SPI loaded"

puts "Line 3: Loading GPIO..."
require 'gpio'
puts "Line 4: GPIO loaded"

puts "Line 5: Loading Terminus..."
require 'terminus'
puts "Line 6: Terminus loaded"

# === フォント データ定義 ===
# Terminus 6x12 フォント（6×12）
# 出典: picoruby-terminus mrbgem
FONT_TERMINUS = :"6x12"
FONT_WIDTH = 6
FONT_HEIGHT = 12

WIDTH  = 128
HEIGHT = 296

# === QR コード データ ===
# 出典: picoruby-oled-namecard (実績あり)
QR_WIDTH = 62
QR_HEIGHT = 62
QR_DATA = [
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F,
  0x3F, 0x3F, 0x3F, 0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0x3F, 0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0x3F, 0x3F,
  0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F,
  0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
  0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0xFF, 0xFF,
  0x00, 0x00, 0xFF, 0xFF, 0xF3, 0xF3, 0xC3, 0xC3, 0x00, 0x00, 0xCC, 0xCC, 0xF0, 0xF0, 0xFC, 0xFC,
  0xF3, 0xF3, 0x00, 0x00, 0xC0, 0xC0, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x03, 0x03, 0x03, 0x03,
  0x03, 0x03, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
  0xFF, 0xFF, 0x30, 0x30, 0x33, 0x33, 0x33, 0x33, 0xF3, 0xF3, 0x33, 0x33, 0x33, 0x33, 0x30, 0x30,
  0x3F, 0x3F, 0x03, 0x03, 0xCC, 0xCC, 0x03, 0x03, 0x3F, 0x3F, 0xC3, 0xC3, 0xCC, 0xCC, 0xF3, 0xF3,
  0xCC, 0xCC, 0x30, 0x30, 0x3F, 0x3F, 0x30, 0x30, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0x33, 0x33,
  0xF3, 0xF3, 0xF0, 0xF0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
  0xC0, 0xC0, 0xF0, 0xF0, 0xFF, 0xFF, 0x0F, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x33, 0x33, 0x0C, 0x0C,
  0xF0, 0xF0, 0xF3, 0xF3, 0xFC, 0xFC, 0xCC, 0xCC, 0x3F, 0x3F, 0x00, 0x00, 0x03, 0x03, 0xFF, 0xFF,
  0x30, 0x30, 0x00, 0x00, 0x0C, 0x0C, 0x0C, 0x0C, 0xC3, 0xC3, 0x3F, 0x3F, 0xF3, 0xF3, 0x03, 0x03,
  0x30, 0x30, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x33, 0x33,
  0xCC, 0xCC, 0x00, 0x00, 0x3C, 0x3C, 0xF0, 0xF0, 0x3F, 0x3F, 0x33, 0x33, 0xFC, 0xFC, 0x00, 0x00,
  0xF0, 0xF0, 0xCF, 0xCF, 0x30, 0x30, 0xC0, 0xC0, 0xC0, 0xC0, 0x0C, 0x0C, 0x3F, 0x3F, 0x0C, 0x0C,
  0x3C, 0x3C, 0x00, 0x00, 0x33, 0x33, 0x0F, 0x0F, 0x3C, 0x3C, 0xF3, 0xF3, 0xC3, 0xC3, 0xF0, 0xF0,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x03, 0x03, 0xF3, 0xF3,
  0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0xF3, 0xF3, 0x03, 0x03, 0xFF, 0xFF, 0x00, 0x00, 0x03, 0x03,
  0x0F, 0x0F, 0xCC, 0xCC, 0x3F, 0x3F, 0xF3, 0xF3, 0xFF, 0xFF, 0xC0, 0xC0, 0x00, 0x00, 0x3F, 0x3F,
  0x33, 0x33, 0x3F, 0x3F, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x30, 0x30, 0x30, 0x30, 0xFF, 0xFF,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x3F, 0x3F, 0x30, 0x30,
  0x30, 0x30, 0x30, 0x30, 0x3F, 0x3F, 0x00, 0x00, 0xFF, 0xFF, 0x03, 0x03, 0xCC, 0xCC, 0x0C, 0x0C,
  0x30, 0x30, 0xC0, 0xC0, 0xCC, 0xCC, 0x03, 0x03, 0x03, 0x03, 0x0F, 0x0F, 0x3F, 0x3F, 0xCF, 0xCF,
  0x3C, 0x3C, 0xC0, 0xC0, 0xCC, 0xCC, 0xFC, 0xFC, 0x0F, 0x0F, 0x33, 0x33, 0xFF, 0xFF, 0xFF, 0xFF,
  0xFF, 0xFF, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F,
  0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F,
  0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F,
  0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F,
]

def send_command(spi, cs, dc, cmd, label = "")
  dc.write(0); cs.write(0); spi.write(cmd.chr); cs.write(1)
end

def send_data(spi, cs, dc, data, label = "")
  dc.write(1); cs.write(0); spi.write(data); cs.write(1)
end

def send_data_chunked(spi, cs, dc, data, label = "")
  dc.write(1); cs.write(0)
  i = 0
  while i < data.size
    chunk_size = data.size - i < 1024 ? data.size - i : 1024
    spi.write(data[i, chunk_size])
    i += 1024
  end
  cs.write(1)
end

def wait_until_idle(busy)
  sleep_ms(10)
  while busy.read == 0; sleep_ms(10); end
end

# === Drawing Primitives ===

# set_pixel: フレームバッファ内の単一ピクセルを設定
def set_pixel(fb, x, y, color)
  return if x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT
  byte_idx = (y * WIDTH + x) / 8
  bit_idx = 7 - (x % 8)
  old_val = fb[byte_idx].ord
  if color == 0
    new_val = old_val & ~(1 << bit_idx)
  else
    new_val = old_val | (1 << bit_idx)
  end
  fb[byte_idx] = new_val.chr
end

# fill_rect: 矩形領域を塗りつぶす
def fill_rect(fb, x, y, width, height, color)
  (0...height).each do |dy|
    (0...width).each do |dx|
      set_pixel(fb, x + dx, y + dy, color)
    end
  end
end

# draw_line: Bresenham アルゴリズムで直線を描画
def draw_line(fb, x0, y0, x1, y1, color)
  dx = (x1 - x0).abs
  dy = (y1 - y0).abs
  sx = x0 < x1 ? 1 : -1
  sy = y0 < y1 ? 1 : -1

  if dy == 0
    fill_rect(fb, [x0, x1].min, y0, (dx + 1), 1, color)
    return
  end

  if dx == 0
    fill_rect(fb, x0, [y0, y1].min, 1, (dy + 1), color)
    return
  end

  if dx > dy
    err = dx / 2
    y = y0
    x = x0
    while true
      set_pixel(fb, x, y, color)
      break if x == x1
      err -= dy
      if err < 0
        y += sy
        err += dx
      end
      x += sx
    end
  else
    err = dy / 2
    x = x0
    y = y0
    while true
      set_pixel(fb, x, y, color)
      break if y == y1
      err -= dx
      if err < 0
        x += sx
        err += dy
      end
      y += sy
    end
  end
end

# draw_text: テキスト文字列を Terminus フォントで描画
def draw_text(fb, x, y, text, color = 0, font_name = :"6x12")
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    # 文字ごとに描画（水平レンダリング）
    current_x = x
    widths.each_with_index do |char_width, char_idx|
      glyph_data = glyphs[char_idx]

      # 各文字の行ごとに描画
      height.times do |row|
        row_data = glyph_data[row]

        # 1文字内のピクセルを描画
        char_width.times do |col|
          pixel = (row_data >> (char_width - 1 - col)) & 1
          pixel_color = (pixel == 1) ? color : (1 - color)
          display_x = current_x + col
          display_y = y + row
          set_pixel(fb, display_x, display_y, pixel_color)
        end
      end

      # 次の文字位置へ移動
      current_x += char_width
    end
  end
end

# draw_checkerboard: 市松模様を描画（描画システムの検証用）
# experiment.rb と同じ set_pixel ベースパターン
def draw_checkerboard(fb, x, y, width, height, cell_size)
  (height / cell_size).times do |row|
    (width / cell_size).times do |col|
      # 市松模様パターン
      color = (row + col) % 2 == 0 ? 0 : 1  # 黒 or 白

      # セルを塗りつぶす（set_pixel で1ピクセルずつ）
      cell_size.times do |dy|
        cell_size.times do |dx|
          px = x + col * cell_size + dx
          py = y + row * cell_size + dy
          set_pixel(fb, px, py, color)
        end
      end
    end
  end
end

# draw_circle: Midpoint Circle アルゴリズムで円を描画
def draw_circle(fb, cx, cy, radius, color, filled = false)
  x = radius
  y = 0
  d = 3 - 2 * radius

  while x >= y
    if filled
      draw_line(fb, cx - x, cy + y, cx + x, cy + y, color)
      draw_line(fb, cx - x, cy - y, cx + x, cy - y, color) if y != 0
      draw_line(fb, cx - y, cy + x, cx + y, cy + x, color) if x != y
      draw_line(fb, cx - y, cy - x, cx + y, cy - x, color) if y != 0 && x != y
    else
      set_pixel(fb, cx + x, cy + y, color)
      set_pixel(fb, cx - x, cy + y, color)
      set_pixel(fb, cx + x, cy - y, color)
      set_pixel(fb, cx - x, cy - y, color)
      set_pixel(fb, cx + y, cy + x, color)
      set_pixel(fb, cx - y, cy + x, color)
      set_pixel(fb, cx + y, cy - x, color) if x != y
      set_pixel(fb, cx - y, cy - x, color) if x != y
    end

    if d < 0
      d = d + 4 * y + 6
    else
      d = d + 4 * (y - x) + 10
      x -= 1
    end
    y += 1
  end
end

# === 初期化 ===
puts "Line 220: Starting initialization..."
spi = SPI.new(unit: :RP2040_SPI0, frequency: 2_000_000, sck_pin: 18, copi_pin: 19, mode: 0)
puts "Line 221: SPI initialized"
puts "Line 222: Initializing GPIO pins..."
cs   = GPIO.new(17, GPIO::OUT); cs.write(1)
dc   = GPIO.new(20, GPIO::OUT)
rst  = GPIO.new(21, GPIO::OUT); rst.write(1)
busy = GPIO.new(26, GPIO::IN)
pwr3v3 = GPIO.new(10, GPIO::OUT); pwr3v3.write(1)
puts "Line 228: GPIO pins initialized"

# ハードウェア リセット
puts "Line 230: Performing hardware reset..."
rst.write(0); sleep_ms(200); rst.write(1); sleep_ms(200)
wait_until_idle(busy)
puts "Line 233: Hardware reset complete"

# UC8151C 初期化（128x296モード）
puts "Line 235: Starting UC8151 initialization..."
send_command(spi, cs, dc, 0x00, "PSR")
send_data(spi, cs, dc, "\x5F", "PSR.data")
puts "Line 238: PSR configured"

send_command(spi, cs, dc, 0x01, "PWR")
send_data(spi, cs, dc, "\x03\x00\x2b\x2b\x1e", "PWR.data")

send_command(spi, cs, dc, 0x06, "BTST")
send_data(spi, cs, dc, "\x17\x17\x17", "BTST.data")

send_command(spi, cs, dc, 0x30, "PLL")
send_data(spi, cs, dc, "\x3c", "PLL.data")

send_command(spi, cs, dc, 0x04, "PON")
wait_until_idle(busy)

send_command(spi, cs, dc, 0x61, "TRES")
send_data(spi, cs, dc, "\x80\x01\x28", "TRES.data")

send_command(spi, cs, dc, 0x50, "CDI")
send_data(spi, cs, dc, "\x13", "CDI.data")

send_command(spi, cs, dc, 0x60, "TCON")
send_data(spi, cs, dc, "\x22", "TCON.data")

GC.start

# === フレームバッファ作成 ===
puts "Line 268: Creating framebuffer..."
@framebuffer = "\xFF" * (WIDTH * HEIGHT / 8)
puts "Line 270: Framebuffer created"

GC.start

# === Deep Clean: チップメモリをリセット ===
puts "Line 274: Starting Deep Clean..."
send_command(spi, cs, dc, 0x10, "DTM1")
send_data_chunked(spi, cs, dc, "\x00" * 4736, "DTM1_all_black")
puts "Line 277: DTM1 sent"

send_command(spi, cs, dc, 0x13, "DTM2")
send_data_chunked(spi, cs, dc, "\xFF" * 4736, "DTM2_all_white")

send_command(spi, cs, dc, 0x12, "DRF")
wait_until_idle(busy)

GC.start

# === レイアウト設計 ===
# Option C: 横並び（テキスト左側、QR右側）
text = "bash0C7"
text_width = FONT_WIDTH * text.size
text_x = 5
text_y = 260  # 下部（市松模様の下）

qr_scale = 2  # 62×2 = 124ピクセル
qr_display_size = QR_WIDTH * qr_scale
qr_x = (WIDTH - qr_display_size) / 2  # 中央: (128 - 124) / 2 = 2
qr_y = 60

# === 描画実行 ===
puts "Line 293: Drawing text..."
# draw_text(@framebuffer, text_x, text_y, text, 0, :"6x12")  # 一時的にコメント アウト
GC.start
puts "Line 296: Text drawn"

puts "Line 298: Drawing checkerboard (Phase 0 test)..."
# 市松模様で描画システムを検証（128×128、8×8ピクセルセル）
draw_checkerboard(@framebuffer, 0, 50, 128, 128, 8)
GC.start
puts "Line 301: Checkerboard drawn"

# === 画面更新 ===
puts "Line 304: Starting display update..."
send_command(spi, cs, dc, 0x10, "DTM1")
send_data_chunked(spi, cs, dc, "\xFF" * 4736, "DTM1.data")
puts "Line 307: DTM1 sent"

GC.start

puts "Line 310: Sending framebuffer..."
send_command(spi, cs, dc, 0x13, "DTM2")
send_data_chunked(spi, cs, dc, @framebuffer, "DTM2.data")
puts "Line 313: DTM2 sent"

GC.start

puts "Line 316: Triggering display refresh..."
send_command(spi, cs, dc, 0x12, "DRF")
wait_until_idle(busy)
sleep_ms(1000)
puts "Line 320: Display refresh complete"

puts "Line 322: Powering off..."
send_command(spi, cs, dc, 0x02, "POF")

GC.start

puts "Done: bash0C7 namecard displayed"
