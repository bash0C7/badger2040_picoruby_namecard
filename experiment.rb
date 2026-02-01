puts "Line 1: Loading SPI..."
require 'spi'
puts "Line 2: SPI loaded"

puts "Line 3: Loading GPIO..."
require 'gpio'
puts "Line 4: GPIO loaded"

puts "Line 5: Loading Terminus..."
require 'terminus'
puts "Line 6: Terminus loaded"

WIDTH  = 128
HEIGHT = 296

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

def fill_rect(fb, x, y, width, height, color)
  (0...height).each do |dy|
    (0...width).each do |dx|
      set_pixel(fb, x + dx, y + dy, color)
    end
  end
end

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

# === 座標系実証実験v2: 異なる太さ・長さの線 ===
puts "Line 283: COORDINATE SYSTEM DIAGNOSTIC TEST"
puts ""

# 4隅から内側に向かって異なる長さの線を描画
puts "Test 1: Top-left corner (0,0) lines"
# 垂直線: x=5, y=0→30 (長さ30)
30.times do |y|
  set_pixel(@framebuffer, 5, y, 0)
end
puts "  Vert: x=5, y=0-30 (len=30)"

# 水平線: x=0→30, y=5 (長さ30)
30.times do |x|
  set_pixel(@framebuffer, x, 5, 0)
end
puts "  Horiz: x=0-30, y=5 (len=30)"

puts ""
puts "Test 2: Top-right corner (127,0) lines"
# 垂直線: x=122, y=0→50 (長さ50)
50.times do |y|
  set_pixel(@framebuffer, 122, y, 0)
end
puts "  Vert: x=122, y=0-50 (len=50)"

# 水平線: x=97→127, y=10 (長さ30)
30.times do |x|
  set_pixel(@framebuffer, 97 + x, 10, 0)
end
puts "  Horiz: x=97-127, y=10 (len=30)"

puts ""
puts "Test 3: Bottom-left corner (0,295) lines"
# 垂直線: x=10, y=265→295 (長さ30)
30.times do |i|
  set_pixel(@framebuffer, 10, 265 + i, 0)
end
puts "  Vert: x=10, y=265-295 (len=30)"

# 水平線: x=0→40, y=280 (長さ40)
40.times do |x|
  set_pixel(@framebuffer, x, 280, 0)
end
puts "  Horiz: x=0-40, y=280 (len=40)"

puts ""
puts "Test 4: Bottom-right corner (127,295) lines"
# 垂直線: x=117, y=245→295 (長さ50)
50.times do |i|
  set_pixel(@framebuffer, 117, 245 + i, 0)
end
puts "  Vert: x=117, y=245-295 (len=50)"

# 水平線: x=87→127, y=270 (長さ40)
40.times do |x|
  set_pixel(@framebuffer, 87 + x, 270, 0)
end
puts "  Horiz: x=87-127, y=270 (len=40)"

puts ""
puts "Test 5: Center cross"
# 中央の交点 at (64, 148) with thick lines
# 垂直線中央: x=63-64, y=128→168 (長さ40, 太さ2)
40.times do |y|
  set_pixel(@framebuffer, 63, 128 + y, 0)
  set_pixel(@framebuffer, 64, 128 + y, 0)
end
puts "  Vert cross: x=63-64, y=128-168 (thick=2, len=40)"

# 水平線中央: x=44→84, y=147-148 (長さ40, 太さ2)
40.times do |x|
  set_pixel(@framebuffer, 44 + x, 147, 0)
  set_pixel(@framebuffer, 44 + x, 148, 0)
end
puts "  Horiz cross: x=44-84, y=147-148 (thick=2, len=40)"

puts ""
puts "Line 310: DIAGNOSTIC TEST COMPLETE - Ready for inspection"

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

puts "Done: Experiment complete"
