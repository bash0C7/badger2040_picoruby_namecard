puts "Line 1: Loading SPI..."
require 'spi'
puts "Line 2: SPI loaded"

puts "Line 3: Loading GPIO..."
require 'gpio'
puts "Line 4: GPIO loaded"

puts "Line 5: Loading Terminus..."
require 'terminus'
puts "Line 6: Terminus loaded"

WIDTH  = 128  # 論理的な幅（MicroPythonと同じ）
HEIGHT = 296  # 論理的な高さ（MicroPythonと同じ）

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

# draw_text_debug: Terminus.draw() 出力を詳しく検査するデバッグ版
def draw_text_debug(text, font_name = :"6x12")
  puts "=== draw_text_debug: #{text.inspect} ==="
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    puts "height=#{height}, total_width=#{total_width}"
    puts "glyph_data class: #{glyphs[0].class}"
    puts "glyph_data size: #{glyphs[0].size}"

    widths.each_with_index do |char_width, char_idx|
      puts ""
      puts "Char #{char_idx}: '#{text[char_idx]}' width=#{char_width}"
      glyph_data = glyphs[char_idx]

      height.times do |row|
        row_data = glyph_data[row]
        puts "  row #{row}: 0x#{row_data.to_s(16)} (class: #{row_data.class})"

        # ビット抽出を2パターン試す
        bits_order1 = ""
        bits_order2 = ""
        char_width.times do |col|
          pixel1 = (row_data >> (char_width - 1 - col)) & 1
          pixel2 = (row_data >> col) & 1
          bits_order1 += pixel1.to_s
          bits_order2 += pixel2.to_s
        end
        puts "    O1: #{bits_order1}"
        puts "    O2: #{bits_order2}"
      end
    end
  end
end

# draw_text: テキスト文字列を Terminus フォントで描画
def draw_text(fb, x, y, text, color = 0, font_name = :"6x12")
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    current_x = x
    widths.each_with_index do |char_width, char_idx|
      glyph_data = glyphs[char_idx]
      height.times do |row|
        row_data = glyph_data[row]
        char_width.times do |col|
          pixel = (row_data >> (char_width - 1 - col)) & 1  # MSB-first
          pixel_color = (pixel == 1) ? color : (1 - color)
          display_x = current_x + col
          display_y = y + row
          set_pixel(fb, display_x, display_y, pixel_color)
        end
      end
      current_x += char_width
    end
  end
end

# draw_text_scaled: テキストをスケーリング付きで描画
def draw_text_scaled(fb, x, y, text, scale = 2, color = 0, font_name = :"6x12")
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    current_x = x
    widths.each_with_index do |char_width, char_idx|
      glyph_data = glyphs[char_idx]
      height.times do |row|
        row_data = glyph_data[row]
        char_width.times do |col|
          pixel = (row_data >> (char_width - 1 - col)) & 1  # MSB-first
          pixel_color = (pixel == 1) ? color : (1 - color)
          scale.times do |sy|
            scale.times do |sx|
              display_x = current_x + col * scale + sx
              display_y = y + row * scale + sy
              set_pixel(fb, display_x, display_y, pixel_color)
            end
          end
        end
      end
      current_x += char_width * scale
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
send_data(spi, cs, dc, "\x97", "PSR.data")  # 0x97: bit7-6=10 RES_128x296, SCAN_DOWN, SHIFT_RIGHT (候補3)

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

# === デバッグ: glyph_data の生データを調査 ===
puts "Line 129: DEBUG - Analyzing glyph_data structure"
puts ""
draw_text_debug("b", :"6x12")
puts ""
puts "Line 132: DEBUG complete, proceeding to hypothesis tests"
puts ""

# === 修正版 draw_text() テスト ===
puts "Line 216: CORRECTED TEXT RENDERING TEST"
puts ""

# 修正版 draw_text() で "b" を描画
test_char = "b"
text_x = 5
test_y = 20

puts "=== draw_text() CORRECTED VERSION at Y=20-32 ==="
draw_text(@framebuffer, text_x, test_y, test_char, 0, :"6x12")
puts "draw_text() complete"

puts ""
puts "Line 225: TEXT RENDERING TEST COMPLETE - Ready for inspection"

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
