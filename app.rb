p "start"
require 'spi'
require 'gpio'
require 'terminus'
p "require"

# === フォント データ定義 ===
# Shinonome ascii12 フォント（6×12）
# 出典: picoruby-shinonome mrbgem
FONT_SHINONOME = :ascii12
FONT_WIDTH = 6
FONT_HEIGHT = 12

WIDTH  = 128
HEIGHT = 296

# === QR コード データ ===
# 出典: qr.png を Python で解析して抽出（27×27 モジュール）
QR_WIDTH = 27
QR_HEIGHT = 27
QR_DATA = "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x80"

def send_command(spi, cs, dc, cmd, label = "")
  puts ">CMD #{label} 0x#{cmd.to_s(16).rjust(2, '0')}" unless label.empty?
  dc.write(0); cs.write(0); spi.write(cmd.chr); cs.write(1)
  puts "<CMD #{label}" unless label.empty?
end

def send_data(spi, cs, dc, data, label = "")
  puts ">DAT #{label} size=#{data.size}" unless label.empty?
  dc.write(1); cs.write(0); spi.write(data); cs.write(1)
  puts "<DAT #{label}" unless label.empty?
end

def send_data_chunked(spi, cs, dc, data, label = "")
  puts ">DAT #{label} size=#{data.size} (chunked)" unless label.empty?
  dc.write(1); cs.write(0)
  i = 0
  while i < data.size
    chunk_size = data.size - i < 1024 ? data.size - i : 1024
    spi.write(data[i, chunk_size])
    i += 1024
  end
  cs.write(1)
  puts "<DAT #{label}" unless label.empty?
end

def wait_until_idle(busy)
  sleep_ms(10)
  while busy.read == 0; sleep_ms(10); end
end

# === Drawing Primitives ===

# set_pixel: フレームバッファ内の単一ピクセルを設定
# fb: フレームバッファ（文字列）
# x, y: 座標（原点左下、0-127, 0-295）
# color: 0=黒、1=白
def set_pixel(fb, x, y, color)
  # 範囲チェック
  return if x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT

  # メモリレイアウト: 行指向、MSB first
  byte_idx = (y * WIDTH + x) / 8
  bit_idx = 7 - (x % 8)

  old_val = fb[byte_idx].ord
  if color == 0  # 黒
    new_val = old_val & ~(1 << bit_idx)
  else  # 白
    new_val = old_val | (1 << bit_idx)
  end
  fb[byte_idx] = new_val.chr
end

# fill_rect: 矩形領域を塗りつぶす
# fb: フレームバッファ（文字列）
# x, y: 左下のコーナー座標（原点左下）
# width, height: 幅と高さ（ピクセル）
# color: 0=黒、1=白
# 実装: set_pixel() を活用した単純版
# 参考: C++ Pimoroni はバイト単位で最適化、MicroPython framebuf も同様アプローチ
def fill_rect(fb, x, y, width, height, color)
  # 高さループ（y軸：下から上へ）
  (0...height).each do |dy|
    # 幅ループ（x軸：左から右へ）
    (0...width).each do |dx|
      set_pixel(fb, x + dx, y + dy, color)
    end
  end
end

# draw_line: Bresenham アルゴリズムで直線を描画
# fb: フレームバッファ（文字列）
# x0, y0, x1, y1: 開始座標と終了座標
# color: 0=黒、1=白
# 参考: Bresenham line algorithm - https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
# 最適化: 水平線・垂直線は fill_rect() で処理
def draw_line(fb, x0, y0, x1, y1, color)
  dx = (x1 - x0).abs
  dy = (y1 - y0).abs
  sx = x0 < x1 ? 1 : -1
  sy = y0 < y1 ? 1 : -1

  # 水平線の最適化
  if dy == 0
    fill_rect(fb, [x0, x1].min, y0, (dx + 1), 1, color)
    return
  end

  # 垂直線の最適化
  if dx == 0
    fill_rect(fb, x0, [y0, y1].min, 1, (dy + 1), color)
    return
  end

  # Bresenham アルゴリズム（一般的な直線）
  if dx > dy
    # x駆動
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
    # y駆動
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

# draw_text: テキスト文字列を Shinonome フォントで描画
# fb: フレームバッファ（文字列）
# x, y: 左下のコーナー座標（原点左下）
# text: 描画するテキスト（UTF-8 文字列）
# color: 0=黒、1=白
# font_name: Shinonome フォント（:ascii12, :ascii16, :go12, など）
# 出典: picoruby-shinonome mrbgem
# 参考: https://github.com/picoruby/picoruby/tree/main/mrbgems/picoruby-shinonome
def draw_text(fb, x, y, text, color = 0, font_name = :ascii12)
  # Shinonome フォント レンダリング
  Shinonome.draw(font_name, text, 1) do |height, total_width, widths, glyphs|
    # 各文字を描画
    current_x = x
    widths.each_with_index do |char_width, char_idx|
      # グリフの各行を処理
      height.times do |row|
        # グリフデータ（uint64_t）からビット抽出
        glyph_data = glyphs[char_idx][row]

        # 各列（ピクセル）を処理
        char_width.times do |col|
          # ビット位置: MSB优先、左→右
          # (char_width - 1 - col) で左から右へ
          pixel = (glyph_data >> (char_width - 1 - col)) & 1

          # ピクセル描画（1=前景色=黒、0=背景色=白）
          pixel_color = (pixel == 1) ? color : (1 - color)
          display_x = current_x + col
          display_y = y + row

          set_pixel(fb, display_x, display_y, pixel_color)
        end
      end

      # 次の文字へ
      current_x += char_width
    end
  end
end

# draw_qr_code: QR コード データから QR コードを描画
# fb: フレームバッファ（文字列）
# x, y: 左下のコーナー座標（原点左下）
# qr_data: QR モジュール データ（hex string）
# module_size: 1 モジュール当たりの display ピクセル数
# qr_width: QR コード幅（モジュール数、通常 21-29）
# 出典: TODO.md Task 3.2 + qr.png を Python で解析したデータ
def draw_qr_code(fb, x, y, qr_data, module_size, qr_width = 27)
  # hex string をバイナリに変換
  qr_bytes = []
  i = 0
  while i < qr_data.size
    if qr_data[i] == '\\'
      hex_chars = qr_data[i+1..i+2]
      qr_bytes.push(hex_chars.to_i(16))
      i += 3
    else
      i += 1
    end
  end

  # バイナリデータをモジュールに展開
  qr_bits = []
  qr_bytes.each do |byte|
    8.times do |bit|
      qr_bits.push((byte >> (7 - bit)) & 1)
    end
  end

  # QR モジュールを描画
  qr_height = qr_width
  qr_bits[0...qr_width * qr_height].each_with_index do |bit, idx|
    mx = idx % qr_width
    my = idx / qr_width

    # bit: 1=黒、0=白
    color = (bit == 1) ? 0 : 1

    # display 上の座標（module_size × module_size のブロック）
    display_x = x + mx * module_size
    display_y = y + my * module_size

    # rectangle を描画
    fill_rect(fb, display_x, display_y, module_size, module_size, color)
  end
end

# draw_circle: Midpoint Circle アルゴリズムで円を描画
# fb: フレームバッファ（文字列）
# cx, cy: 円の中心座標
# radius: 半径（ピクセル）
# color: 0=黒、1=白
# filled: true=塗りつぶし、false=輪郭のみ
# 参考: Midpoint Circle algorithm - https://en.wikipedia.org/wiki/Midpoint_circle_algorithm
# 最適化: 8-way symmetry で計算量を1/8に削減
def draw_circle(fb, cx, cy, radius, color, filled = false)
  x = radius
  y = 0
  d = 3 - 2 * radius  # Decision parameter

  while x >= y
    # 8-way symmetry で8個のピクセルを描画
    if filled
      # フィルされた円：水平線で塗りつぶし
      draw_line(fb, cx - x, cy + y, cx + x, cy + y, color)
      draw_line(fb, cx - x, cy - y, cx + x, cy - y, color) if y != 0
      draw_line(fb, cx - y, cy + x, cx + y, cy + x, color) if x != y
      draw_line(fb, cx - y, cy - x, cx + y, cy - x, color) if y != 0 && x != y
    else
      # 円輪郭：8-way symmetry で点を描画
      set_pixel(fb, cx + x, cy + y, color)
      set_pixel(fb, cx - x, cy + y, color)
      set_pixel(fb, cx + x, cy - y, color)
      set_pixel(fb, cx - x, cy - y, color)
      set_pixel(fb, cx + y, cy + x, color)
      set_pixel(fb, cx - y, cy + x, color)
      set_pixel(fb, cx + y, cy - x, color) if x != y
      set_pixel(fb, cx - y, cy - x, color) if x != y
    end

    # Decision parameter 更新
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
spi = SPI.new(unit: :RP2040_SPI0, frequency: 2_000_000, sck_pin: 18, copi_pin: 19, mode: 0)
cs   = GPIO.new(17, GPIO::OUT); cs.write(1)
dc   = GPIO.new(20, GPIO::OUT)
rst  = GPIO.new(21, GPIO::OUT); rst.write(1)
busy = GPIO.new(26, GPIO::IN)
pwr3v3 = GPIO.new(10, GPIO::OUT); pwr3v3.write(1)
p "new"

rst.write(0); sleep_ms(200); rst.write(1); sleep_ms(200)
wait_until_idle(busy)
p "reset"

# UC8151C 初期化（128x296モード）
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

# === フレームバッファ ===
p "framebuffer_init"
@framebuffer = "\xFF" * (WIDTH * HEIGHT / 8)
p "f init done"

GC.start

# === Deep Clean: チップメモリをリセット（強制クリーン：全黒→全白） ===
p "deep_clean_start"
send_command(spi, cs, dc, 0x10, "DTM1")
send_data_chunked(spi, cs, dc, "\x00" * 4736, "DTM1_all_black")

send_command(spi, cs, dc, 0x13, "DTM2")
send_data_chunked(spi, cs, dc, "\xFF" * 4736, "DTM2_all_white")

send_command(spi, cs, dc, 0x12, "DRF")
wait_until_idle(busy)
p "deep_clean_done"

GC.start

# === 描画テスト：左下 5x5 の黒領域 ===
# 座標系: 原点左下、x軸=左→右、y軸=下→上
p "draw_simple_test"
pixel_count = 0
drawn_bytes = {}

(0..4).each do |y|
  (0..4).each do |x|
    set_pixel(@framebuffer, x, y, 0)  # 0=黒
    byte_idx = (y * WIDTH + x) / 8
    drawn_bytes[byte_idx] = true
    pixel_count += 1
  end
end

p "draw_simple_test: #{pixel_count} pixels"

GC.start

# === set_pixel() テストケース ===
p "set_pixel_test: detailed verification"

# テスト1: 原点 (0, 0) に黒ピクセル
test_fb = "\xFF" * 4736
set_pixel(test_fb, 0, 0, 0)
test_val = test_fb[0].ord
expected_bit = 7  # 原点は byte_idx=0, bit_idx=7
is_set = (test_val & (1 << expected_bit)) == 0 ? true : false
puts "Test1 (0,0) black: byte[0]=0x#{test_val.to_s(16).rjust(2, '0')} bit#{expected_bit} set=#{is_set}"

# テスト2: 右上 (127, 295) に黒ピクセル
test_fb2 = "\xFF" * 4736
set_pixel(test_fb2, 127, 295, 0)
byte_idx_expected = (295 * WIDTH + 127) / 8
bit_idx_expected = 7 - (127 % 8)
test_val2 = test_fb2[byte_idx_expected].ord
is_set2 = (test_val2 & (1 << bit_idx_expected)) == 0 ? true : false
puts "Test2 (127,295) black: byte[#{byte_idx_expected}]=0x#{test_val2.to_s(16).rjust(2, '0')} bit#{bit_idx_expected} set=#{is_set2}"

# テスト3: 白ピクセルの復元
test_fb3 = "\x00" * 4736  # 全黒スタート
set_pixel(test_fb3, 0, 0, 1)  # 白に設定
test_val3 = test_fb3[0].ord
is_white = (test_val3 & (1 << 7)) == 0 ? false : true
puts "Test3 (0,0) white: byte[0]=0x#{test_val3.to_s(16).rjust(2, '0')} bit7 white=#{is_white}"

# テスト4: 範囲外のピクセル（ハンドルされるべき）
test_fb4 = "\xFF" * 4736
orig_byte = test_fb4[0].ord
set_pixel(test_fb4, 128, 0, 0)  # x=128 は範囲外
set_pixel(test_fb4, 0, 296, 0)  # y=296 は範囲外
new_byte = test_fb4[0].ord
puts "Test4 (128,0) and (0,296) out of bounds: byte[0] unchanged=#{orig_byte == new_byte}"

p "set_pixel_test: done"

# === fill_rect() テストケース ===
p "fill_rect_test: detailed verification"

# テスト1: バイト境界アライン 8x10 矩形
test_fb_rect = "\xFF" * 4736
fill_rect(test_fb_rect, 0, 0, 8, 10, 0)  # 0=黒
# 期待値: y=0-9 のそれぞれで、byte_idx = (y * 128 + 0-7) / 8 = y * 16 が変更される
rect1_bytes = 0
(0..9).each do |y|
  byte_idx = y * 16  # y * WIDTH / 8
  if test_fb_rect[byte_idx].ord != 0xFF
    rect1_bytes += 1
  end
end
puts "Test1 (0,0,8,10) black rect: #{rect1_bytes}/10 bytes modified as expected"

# テスト2: 非アライン矩形 10x8 (x=3, y=5)
test_fb_rect2 = "\xFF" * 4736
fill_rect(test_fb_rect2, 3, 5, 10, 8, 0)  # 0=黒
# 10ピクセル幅は複数バイトにまたがる
rect2_non_white = 0
(0...test_fb_rect2.size).each do |i|
  rect2_non_white += 1 if test_fb_rect2[i].ord != 0xFF
end
puts "Test2 (3,5,10,8) black rect: #{rect2_non_white} bytes modified"

# テスト3: フルスクリーン黒 (全バイト = 0x00)
test_fb_full = "\xFF" * 4736
fill_rect(test_fb_full, 0, 0, WIDTH, HEIGHT, 0)
full_black_bytes = 0
(0...test_fb_full.size).each do |i|
  full_black_bytes += 1 if test_fb_full[i].ord == 0x00
end
puts "Test3 (0,0,128,296) full black: #{full_black_bytes}/4736 bytes = 0x00"

# テスト4: 白矩形 16x16
test_fb_white = "\x00" * 4736  # 全黒スタート
fill_rect(test_fb_white, 0, 0, 16, 16, 1)  # 1=白
white_rect_bytes = 0
(0...test_fb_white.size).each do |i|
  val = test_fb_white[i].ord
  if val != 0x00
    white_rect_bytes += 1
  end
end
puts "Test4 (0,0,16,16) white rect: #{white_rect_bytes} bytes modified"

p "fill_rect_test: done"

# === draw_line() テストケース ===
p "draw_line_test: detailed verification"

# テスト1: 水平線 (0, 10) -> (20, 10)
test_fb_line = "\xFF" * 4736
draw_line(test_fb_line, 0, 10, 20, 10, 0)  # 0=黒
hline_non_white = 0
(0...test_fb_line.size).each do |i|
  hline_non_white += 1 if test_fb_line[i].ord != 0xFF
end
puts "Test1 horizontal line (0,10)-(20,10): #{hline_non_white} bytes modified"

# テスト2: 垂直線 (50, 0) -> (50, 50)
test_fb_line2 = "\xFF" * 4736
draw_line(test_fb_line2, 50, 0, 50, 50, 0)  # 0=黒
vline_non_white = 0
(0...test_fb_line2.size).each do |i|
  vline_non_white += 1 if test_fb_line2[i].ord != 0xFF
end
puts "Test2 vertical line (50,0)-(50,50): #{vline_non_white} bytes modified"

# テスト3: 対角線 (0, 0) -> (50, 50) (45度)
test_fb_line3 = "\xFF" * 4736
draw_line(test_fb_line3, 0, 0, 50, 50, 0)  # 0=黒
diag_non_white = 0
(0...test_fb_line3.size).each do |i|
  diag_non_white += 1 if test_fb_line3[i].ord != 0xFF
end
puts "Test3 diagonal line (0,0)-(50,50): #{diag_non_white} bytes modified"

# テスト4: 短い斜線 (10, 10) -> (20, 15)
test_fb_line4 = "\xFF" * 4736
draw_line(test_fb_line4, 10, 10, 20, 15, 0)  # 0=黒
short_non_white = 0
(0...test_fb_line4.size).each do |i|
  short_non_white += 1 if test_fb_line4[i].ord != 0xFF
end
puts "Test4 short diagonal line (10,10)-(20,15): #{short_non_white} bytes modified"

p "draw_line_test: done"

# === draw_circle() テストケース ===
p "draw_circle_test: detailed verification"

# テスト1: 小さい円輪郭 (64, 148, r=10)
test_fb_circle = "\xFF" * 4736
draw_circle(test_fb_circle, 64, 148, 10, 0, false)  # 0=黒、false=輪郭
circle_outline_bytes = 0
(0...test_fb_circle.size).each do |i|
  circle_outline_bytes += 1 if test_fb_circle[i].ord != 0xFF
end
puts "Test1 circle outline (64,148,r=10): #{circle_outline_bytes} bytes modified"

# テスト2: フィルされた円 (64, 148, r=15)
test_fb_circle2 = "\xFF" * 4736
draw_circle(test_fb_circle2, 64, 148, 15, 0, true)  # 0=黒、true=塗りつぶし
circle_filled_bytes = 0
(0...test_fb_circle2.size).each do |i|
  circle_filled_bytes += 1 if test_fb_circle2[i].ord != 0xFF
end
puts "Test2 circle filled (64,148,r=15): #{circle_filled_bytes} bytes modified"

# テスト3: 非常に小さい円 (r=1)
test_fb_circle3 = "\xFF" * 4736
draw_circle(test_fb_circle3, 50, 50, 1, 0, false)  # 0=黒、false=輪郭
tiny_circle_bytes = 0
(0...test_fb_circle3.size).each do |i|
  tiny_circle_bytes += 1 if test_fb_circle3[i].ord != 0xFF
end
puts "Test3 circle tiny (50,50,r=1): #{tiny_circle_bytes} bytes modified"

# テスト4: 大きい円輪郭 (64, 148, r=40)
test_fb_circle4 = "\xFF" * 4736
draw_circle(test_fb_circle4, 64, 148, 40, 0, false)  # 0=黒、false=輪郭
large_circle_bytes = 0
(0...test_fb_circle4.size).each do |i|
  large_circle_bytes += 1 if test_fb_circle4[i].ord != 0xFF
end
puts "Test4 circle outline (64,148,r=40): #{large_circle_bytes} bytes modified"

p "draw_circle_test: done"

# === draw_qr_code() テストケース ===
p "draw_qr_code_test: detailed verification"

# テスト1: QR コード描画（2 pixels/module = 54×54 pixels）
test_fb_qr = "\xFF" * 4736
draw_qr_code(test_fb_qr, 0, 0, QR_DATA, 2, QR_WIDTH)
qr_non_white = 0
(0...test_fb_qr.size).each do |i|
  qr_non_white += 1 if test_fb_qr[i].ord != 0xFF
end
puts "Test1 QR code (0,0,2px/module): #{qr_non_white} bytes modified"

# テスト2: QR コード位置の確認（異なるモジュールサイズ）
test_fb_qr2 = "\xFF" * 4736
draw_qr_code(test_fb_qr2, 10, 50, QR_DATA, 3, QR_WIDTH)  # 3 pixels/module = 81×81
qr2_non_white = 0
(0...test_fb_qr2.size).each do |i|
  qr2_non_white += 1 if test_fb_qr2[i].ord != 0xFF
end
puts "Test2 QR code (10,50,3px/module): #{qr2_non_white} bytes modified"

# テスト3: 縮小 QR（1 pixel/module = 27×27）
test_fb_qr3 = "\xFF" * 4736
draw_qr_code(test_fb_qr3, 50, 100, QR_DATA, 1, QR_WIDTH)
qr3_non_white = 0
(0...test_fb_qr3.size).each do |i|
  qr3_non_white += 1 if test_fb_qr3[i].ord != 0xFF
end
puts "Test3 QR code (50,100,1px/module): #{qr3_non_white} bytes modified"

p "draw_qr_code_test: done"

# === draw_text() テストケース ===
p "draw_text_test: detailed verification"

# テスト1: "bash0C7" テキスト（英数字、小）
test_fb_text = "\xFF" * 4736
draw_text(test_fb_text, 0, 100, "bash0C7", 0, :ascii12)
text1_non_white = 0
(0...test_fb_text.size).each do |i|
  text1_non_white += 1 if test_fb_text[i].ord != 0xFF
end
puts "Test1 draw_text('bash0C7', 0, 100): #{text1_non_white} bytes modified"

# テスト2: 別の位置に テキスト描画
test_fb_text2 = "\xFF" * 4736
draw_text(test_fb_text2, 40, 50, "Test", 0, :ascii12)
text2_non_white = 0
(0...test_fb_text2.size).each do |i|
  text2_non_white += 1 if test_fb_text2[i].ord != 0xFF
end
puts "Test2 draw_text('Test', 40, 50): #{text2_non_white} bytes modified"

# テスト3: 単一文字
test_fb_text3 = "\xFF" * 4736
draw_text(test_fb_text3, 10, 10, "A", 0, :ascii12)
text3_non_white = 0
(0...test_fb_text3.size).each do |i|
  text3_non_white += 1 if test_fb_text3[i].ord != 0xFF
end
puts "Test3 draw_text('A', 10, 10): #{text3_non_white} bytes modified"

# テスト4: 白色テキスト（黒背景）
test_fb_text4 = "\x00" * 4736  # 全黒背景
draw_text(test_fb_text4, 20, 30, "Hi", 1, :ascii12)  # 白テキスト
text4_non_black = 0
(0...test_fb_text4.size).each do |i|
  text4_non_black += 1 if test_fb_text4[i].ord != 0x00
end
puts "Test4 draw_text('Hi', 20, 30, color=1): #{text4_non_black} bytes modified"

p "draw_text_test: done"

GC.start

# === フレームバッファ検証：0xFF以外のバイトを全て出力 ===
p "framebuffer_scan"
non_white_count = 0
(0...@framebuffer.size).each do |i|
  val = @framebuffer[i].ord
  if val != 0xFF
    expected = drawn_bytes[i] ? "OK" : "UNEXPECTED"
    puts "fb[#{i}]=0x#{val.to_s(16).rjust(2, '0')} #{expected}"
    non_white_count += 1
  end
end
p "framebuffer_scan: #{non_white_count} non-white bytes"

GC.start

# === 画面更新 ===
# DTM1には真っ白を送ってリセット、DTM2に描画画像を送る
send_command(spi, cs, dc, 0x10, "DTM1")
send_data_chunked(spi, cs, dc, "\xFF" * 4736, "DTM1.data")

GC.start

send_command(spi, cs, dc, 0x13, "DTM2")
send_data_chunked(spi, cs, dc, @framebuffer, "DTM2.data")

GC.start

send_command(spi, cs, dc, 0x12, "DRF")
wait_until_idle(busy)
sleep_ms(1000)

send_command(spi, cs, dc, 0x02, "POF")

GC.start

puts "Done: 5x5 black square at bottom-left (0,0)-(4,4)"
puts "Result: Displayed at top-right (coordinate system origin is bottom-left)"
