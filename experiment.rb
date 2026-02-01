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

# draw_text_debug: Terminus.draw() 出力を詳しく検査するデバッグ版
def draw_text_debug(text, font_name = :"6x12")
  puts "=== draw_text_debug: #{text.inspect} ==="
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    puts "height=#{height}, total_width=#{total_width}"

    widths.each_with_index do |char_width, char_idx|
      puts ""
      puts "Char #{char_idx}: '#{text[char_idx]}' width=#{char_width}"
      glyph_data = glyphs[char_idx]

      height.times do |row|
        row_data = glyph_data[row]
        puts "  row #{row}: 0x#{row_data.to_s(16)}"

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
# 修正版: glyph_data は上下反転で返されるので height-1-row でアクセス
def draw_text(fb, x, y, text, color = 0, font_name = :"6x12")
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    current_x = x
    widths.each_with_index do |char_width, char_idx|
      glyph_data = glyphs[char_idx]
      char_width.times do |col|
        height.times do |row|
          row_data = glyph_data[height - 1 - row]  # 行を反転
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
# 修正版: glyph_data は上下反転で返されるので height-1-row でアクセス
def draw_text_scaled(fb, x, y, text, scale = 2, color = 0, font_name = :"6x12")
  Terminus.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    current_x = x
    widths.each_with_index do |char_width, char_idx|
      glyph_data = glyphs[char_idx]
      char_width.times do |col|
        height.times do |row|
          row_data = glyph_data[height - 1 - row]  # 行を反転
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

# === デバッグ: glyph_data の生データを調査 ===
puts "Line 129: DEBUG - Analyzing glyph_data structure"
puts ""
draw_text_debug("b", :"6x12")
puts ""
puts "Line 132: DEBUG complete, proceeding to hypothesis tests"
puts ""

# === 仮説別テキスト描画テスト ===
puts "Line 283: HYPOTHESIS-BASED TEXT RENDERING TEST"
puts ""

# 1文字 'b' で複数の仮説をテスト
test_char = "b"
text_x = 5
font_name = :"6x12"

# ==============================================
# 仮説1: 現在の実装（char → height ループ）
# ==============================================
puts "=== H1: Current (char → height) at Y=20-32 ==="
test1_y = 20
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H1: height=#{height}, char_width=#{widths[0]}"
  current_x = text_x
  widths.each_with_index do |char_width, char_idx|
    glyph_data = glyphs[char_idx]
    puts "H1: Processing char at x=#{current_x}"
    height.times do |row|
      row_data = glyph_data[row]
      char_width.times do |col|
        pixel = (row_data >> (char_width - 1 - col)) & 1
        pixel_color = (pixel == 1) ? 0 : 1
        display_x = current_x + col
        display_y = test1_y + row
        set_pixel(@framebuffer, display_x, display_y, pixel_color)
      end
    end
    current_x += char_width
  end
end

# ==============================================
# 仮説2: height → char ループ反転
# ==============================================
puts ""
puts "=== H2: Reversed (height → char) at Y=50-62 ==="
test2_y = 50
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H2: height=#{height}, char_width=#{widths[0]}"
  height.times do |row|
    current_x = text_x
    widths.each_with_index do |char_width, char_idx|
      glyph_data = glyphs[char_idx]
      row_data = glyph_data[row]
      puts "H2: row=#{row}, x=#{current_x}"
      char_width.times do |col|
        pixel = (row_data >> (char_width - 1 - col)) & 1
        pixel_color = (pixel == 1) ? 0 : 1
        display_x = current_x + col
        display_y = test2_y + row
        set_pixel(@framebuffer, display_x, display_y, pixel_color)
      end
      current_x += char_width
    end
  end
end

# ==============================================
# 仮説3: glyph_data[col] アクセス（column indexed?）
# ==============================================
puts ""
puts "=== H3: Column-indexed (glyph_data[col]) at Y=80-92 ==="
test3_y = 80
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H3: height=#{height}, char_width=#{widths[0]}"
  current_x = text_x
  widths.each_with_index do |char_width, char_idx|
    glyph_data = glyphs[char_idx]
    puts "H3: Trying column-indexed access"
    char_width.times do |col|
      height.times do |row|
        begin
          row_data = glyph_data[col]
          if row_data.nil?
            puts "H3: glyph_data[#{col}] is nil"
          else
            pixel = (row_data >> (height - 1 - row)) & 1
            pixel_color = (pixel == 1) ? 0 : 1
            display_x = current_x + col
            display_y = test3_y + row
            set_pixel(@framebuffer, display_x, display_y, pixel_color)
          end
        rescue
          puts "H3: Error accessing glyph_data[#{col}]"
        end
      end
    end
    current_x += char_width
  end
end

# ==============================================
# 仮説4: Column-first ループ + row_dataのheight方向ビット抽出
# ==============================================
puts ""
puts "=== H4: Column-first (col → row) at Y=100-112 ==="
test4_y = 100
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H4: height=#{height}, char_width=#{widths[0]}"
  current_x = text_x
  widths.each_with_index do |char_width, char_idx|
    glyph_data = glyphs[char_idx]
    puts "H4: Processing char at x=#{current_x}"
    # 外側: 列（左から右）
    char_width.times do |col|
      # 内側: 行（上から下）
      height.times do |row|
        row_data = glyph_data[col]
        if row_data.nil?
          puts "H4: glyph_data[#{col}] is nil"
        else
          # ビット抽出: height方向（上から下）
          pixel = (row_data >> (height - 1 - row)) & 1
          pixel_color = (pixel == 1) ? 0 : 1
          display_x = current_x + col
          display_y = test4_y + row
          set_pixel(@framebuffer, display_x, display_y, pixel_color)
        end
      end
    end
    current_x += char_width
  end
end

# ==============================================
# 仮説5: Row反転 + LSB-first ビット抽出
# ==============================================
puts ""
puts "=== H5: Row-reversed + LSB-first bit extraction at Y=130-142 ==="
test5_y = 130
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H5: height=#{height}, char_width=#{widths[0]}"
  current_x = text_x
  widths.each_with_index do |char_width, char_idx|
    glyph_data = glyphs[char_idx]
    puts "H5: Processing char at x=#{current_x}"
    # 外側: 列（左から右）
    char_width.times do |col|
      # 内側: 行（上から下）
      height.times do |row|
        # row方向を反転（glyph_data[height-1-row]でアクセス）
        row_data = glyph_data[height - 1 - row]

        # ビット抽出: LSB-first（右から左）
        pixel = (row_data >> col) & 1
        pixel_color = (pixel == 1) ? 0 : 1
        display_x = current_x + col
        display_y = test5_y + row
        set_pixel(@framebuffer, display_x, display_y, pixel_color)
      end
    end
    current_x += char_width
  end
end

# ==============================================
# 仮説6: Row反転 + MSB-first ビット抽出
# ==============================================
puts ""
puts "=== H6: Row-reversed + MSB-first at Y=160-172 ==="
test6_y = 160
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H6: height=#{height}, char_width=#{widths[0]}"
  current_x = text_x
  widths.each_with_index do |char_width, char_idx|
    glyph_data = glyphs[char_idx]
    puts "H6: Processing char at x=#{current_x}"
    char_width.times do |col|
      height.times do |row|
        # row方向を反転
        row_data = glyph_data[height - 1 - row]
        # ビット抽出: MSB-first（左から右）
        pixel = (row_data >> (char_width - 1 - col)) & 1
        pixel_color = (pixel == 1) ? 0 : 1
        display_x = current_x + col
        display_y = test6_y + row
        set_pixel(@framebuffer, display_x, display_y, pixel_color)
      end
    end
    current_x += char_width
  end
end

# ==============================================
# 仮説7: Row正常 + LSB-first ビット抽出
# ==============================================
puts ""
puts "=== H7: Row-normal + LSB-first at Y=190-202 ==="
test7_y = 190
Terminus.draw(font_name, test_char, 1) do |height, total_width, widths, glyphs|
  puts "H7: height=#{height}, char_width=#{widths[0]}"
  current_x = text_x
  widths.each_with_index do |char_width, char_idx|
    glyph_data = glyphs[char_idx]
    puts "H7: Processing char at x=#{current_x}"
    char_width.times do |col|
      height.times do |row|
        # row方向は正常
        row_data = glyph_data[row]
        # ビット抽出: LSB-first（右から左）
        pixel = (row_data >> col) & 1
        pixel_color = (pixel == 1) ? 0 : 1
        display_x = current_x + col
        display_y = test7_y + row
        set_pixel(@framebuffer, display_x, display_y, pixel_color)
      end
    end
    current_x += char_width
  end
end

puts ""
puts "Line 310: HYPOTHESIS TEST COMPLETE - Ready for inspection"

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
