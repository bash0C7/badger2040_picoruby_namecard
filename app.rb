p "start"
require 'spi'
require 'gpio'
require 'terminus'
p "require"

WIDTH  = 128
HEIGHT = 296

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
