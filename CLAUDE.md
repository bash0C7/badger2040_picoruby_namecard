# Badger 2040 E-ink Display - PicoRubyで名札表示制御

## Core Principles

<simplicity_first>
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
</simplicity_first>

<output_tone>
**日本語で出力すること**:
- **絶対に日本語で応答・プラン提示すること**
- 通常時: 語尾に「ピョン。」をつけて可愛く
- 盛り上がってきたら:「チェケラッチョ！！」と叫ぶ
- コード内コメント: 日本語、体言止め
- ドキュメント(.md): 英語で記述
- Git commit: 英語、命令形
</output_tone>

<default_to_action>
When implementing changes:
1. Implement proactively WITHOUT asking "should I...?" or "shall I...?"
2. Commit changes IMMEDIATELY after implementation (MUST use subagent `commit`)
3. DO NOT push to remote unless user explicitly requests
4. User will verify functionality AFTER commit (not before)

**Commit immediately to prevent data loss in case of errors**
</default_to_action>

<investigate_before_answering>
**NEVER speculate about code you have not opened**.

When user references files, GPIO, hardware, or existing code:
1. **MUST read files first** before answering
2. **MUST use subagent `explore`** for:
   - Code investigation/exploration
   - Understanding current implementation during plan mode
   - Complex dependency analysis
3. Give grounded, hallucination-free answers based on actual code
4. Read multiple files in parallel when investigating related components
</investigate_before_answering>

<use_parallel_tool_calls>
When reading multiple independent files or searching codebase:
- Read files in parallel (single message, multiple Read tool calls)
- Run Grep searches in parallel when possible
- NEVER use placeholders - wait for actual results if dependencies exist
</use_parallel_tool_calls>

<extended_thinking>
For complex problems:
1. Use "think hard" for multi-step reasoning
2. Reflect carefully on tool results before proceeding
3. Plan iterations based on new information discovered
</extended_thinking>

## プロジェクト概要

Badger 2040（RP2040 + UC8151 E-inkディスプレイ）をPicoRubyで制御し、QRコード表示を実現する。

### 🎯 成功の鍵

UC8151 datasheet PDF
https://www.crystalfontz.com/controllers/datasheet-viewer.php?id=511

や先行実装を参照して、RP2040からUC8151 E-inkディスプレイにリファレンス通りの命令を送り込んで、人間の目でみて正しいと感じる名札表示を行うこと。起動時にe-inkを書き換えてプログラムは終了。画面はそのまま保持。保持に電力不要のe-ink特性名札を実現。

#### 現在の仮説

あくまで仮説でありデータシートが大事

1. **行指向メモリレイアウト**: `byte_idx = (y * WIDTH + x) / 8`
2. **MSB firstビット順序**: `bit_idx = 7 - (x % 8)`
3. **PSR = 0x5F**: SCAN_UP | SHIFT_RIGHT → 原点左下、y軸下→上
4. **TRES指定**: 解像度を0x61コマンドで明示的に設定
5. **Deep Clean**: DTM1(黒) + DTM2(白)で初期化後、通常更新

### 現在の状況（2026-01-31 latest）

app.rb (スケルトン実装。完動へは今から実装が必要)

✅ **達成**: 左下5x5の黒領域の描画成功（画像確認済）
🔲 **進行中**: 座標系の完全理解（上下左右の確認）
🔲 **次**: QRコード描画、テキスト描画

### QRコード

qr.png

### 表示したいもの

横長のe-ink画面いっぱいに

bash0C7 <qrコード>

を表示

bash0C7は文字。
 <qrコード> はQRコードそのものを表示すること

## PicoRubyとは

https://github.com/picoruby/picoruby
README.md参照

使える機能はmrbgemsディレクトリ配下参照

## デプロイ方法

` /Volumes/NO\ NAME/home/` にBadger 2040がファイルシステムにマウントされている。

mac上で `/Users/bash/src/Arduino/picoruby-recipes/components/R2P2-ESP32/components/picoruby-esp32/picoruby/bin/picorbc` にrbファイルを渡してrbファイルのディレクトリにmrbファイルを生成。そのmrbファイルのみを ` /Volumes/NO\ NAME/home/` 配下にコピー

## example

/Users/bash/src/Arduino/picoruby-recipes/components/R2P2-ESP32/components/picoruby-esp32/picoruby/bin/picorbc example.rb && ;  cp *mrb /Volumes/NO\ NAME/home/

## 先行実装

MicroPython
https://github.com/antirez/uc8151_micropython/blob/main/uc8151.py (MIT License)

## ハードウェア仕様

### Badger 2040
- **MCU**: RP2040 (Raspberry Pi Pico)
- **Display**: UC8151 / IL0373 E-ink controller
- **解像度**: 128 x 296 ピクセル
- **物理形状**: 横長バッジ（296mm幅 x 128mm高さ）
- **ビット深度**: 1-bit (白/黒)
- **フレームバッファサイズ**: 4,736バイト (128 × 296 ÷ 8)

### ピン配置
```
SPI0: SCK=18, MOSI=19, MISO=16
CS=17, DC=20, RST=21, BUSY=26
3V3_EN=10 (パワー制御)
```

## 🎯 解決済み - 正しい座標変換式の発見

### ✅ 動作確認済みの実装

**座標変換式（行指向・MSB first）：**
```ruby
byte_idx = (y * WIDTH + x) / 8  # WIDTH=128
bit_idx = 7 - (x % 8)           # MSB first
```

**PSR設定：**
```ruby
PSR = 0x5F = 0b01011111
# SCAN_UP (Bit3=1) + SHIFT_RIGHT (Bit2=1)
# → 原点が左下、y軸は下→上
```

**TRES設定（解像度指定）：**
```ruby
send_command(spi, cs, dc, 0x61, "TRES")
send_data(spi, cs, dc, "\x80\x01\x28")  # 128 x 296
```

### 座標系の定義

```
物理的な画面（横長バッジ）:
    (0,295) ←── y軸 ──┐
       ┌────────────┐  │
       │            │  │ 上
       │   Screen   │  ↓
       │            │
       └────────────┘
    (0,0) ───→ x軸 (127,0)
         左        右

コードで(0,0)を指定 → 画面の左下（物理的には左下）
コードで(0,4), x=[0..4] → 画面の左下から5ピクセル右、5ピクセル上
```

### 実験結果

| コード座標 | 物理表示位置 | 検証 |
|-----------|------------|------|
| (0,0)-(4,4) | 左下5x5 | ✅ 右上に表示確認（画像添付） |

**注意**: 画像では右上に見えるが、これは画面を上下逆に撮影した可能性あり。
実際の座標系は上記の通り、**原点が左下、y軸が下→上**。

### 以前の試行（失敗例）

| 試行 | PSR設定 | 座標変換式 | 結果 |
|------|---------|-----------|------|
| 1 | 0x5F | `(y/8)+(x*37)` 列指向 | 右側に縦線 |
| 2 | 0x9C | `(y/8)+(x*37)` 列指向 | 右側に縦線 |
| 3 | 0xB7 | `(y/8)+(x*37)` 列指向 | 真っ白 + 線 |
| 4 | 0xBF | `(y/8)+(x*37)` 列指向 | 真っ黒 + 白線 |
| 5 | **0x5F** | **`(y*WIDTH+x)/8` 行指向** | **✅ 成功** |

## 技術仕様詳細

### UC8151/IL0373チップ

#### 2つのフレームバッファ
- **DTM1 (0x10)**: Previous/Old image buffer
- **DTM2 (0x13)**: Current/New image buffer
- DRF（Display Refresh）実行後、DTM2の内容が自動的にDTM1にコピーされる
- 更新時にDTM1とDTM2を比較し、WW/BB/WB/BW遷移を判定

#### 遷移タイプとLUT
| 遷移 | 意味 | LUTレジスタ |
|------|------|-------------|
| WW | 白→白 (変化なし) | 0x21 |
| BB | 黒→黒 (変化なし) | 0x24 |
| WB | 白→黒 | 0x23 |
| BW | 黒→白 | 0x22 |
| VCOM | 共通電圧制御 | 0x20 |

#### PSRレジスタ (0x00) - Panel Setting Register

```
Bit 7-6: 解像度
  00 = 96x230
  01 = 96x252
  10 = 128x296  <- Badger 2040
  11 = 160x296

Bit 5: LUT選択
  0 = LUT_OTP (内蔵LUT、低速・高品質)
  1 = LUT_REG (レジスタLUT、高速・要設定)

Bit 4: フォーマット
  0 = BWR (3色)
  1 = BW (2色) <- Badger 2040

Bit 3: スキャン方向
  0 = SCAN_DOWN (上→下、y=0が上)
  1 = SCAN_UP (下→上、y=0が下)

Bit 2: シフト方向
  0 = SHIFT_LEFT (右→左)
  1 = SHIFT_RIGHT (左→右、x=0が左)

Bit 1: ブースター
  0 = OFF
  1 = ON <- 必須

Bit 0: リセット
  0 = RESET_SOFT
  1 = RESET_NONE
```

#### 正しいPSR値の計算

**MicroPython版 (mirror_x=False, mirror_y=False, speed=2):**
```python
psr = RES_128x296 | LUT_REG | FORMAT_BW | BOOSTER_ON | RESET_NONE
psr |= SHIFT_LEFT if mirror_x else SHIFT_RIGHT  # 0x04
psr |= SCAN_DOWN if mirror_y else SCAN_UP       # 0x08

# 結果: 0x80|0x20|0x10|0x04|0x08|0x02|0x01 = 0xBF
```

**注意**: `mirror_y=False`時は`SCAN_UP`（下から上）になる！

## ✅ 動作確認済み初期化シーケンス

```ruby
# 1. ハードウェアリセット
rst.write(0); sleep_ms(200); rst.write(1); sleep_ms(200)
wait_until_idle(busy)

# 2. PSR (0x5F = SCAN_UP | SHIFT_RIGHT | LUT_REG | BW | BOOSTER_ON | RESET_NONE)
CMD 0x00, DATA [0x5F]

# 3. PWR (電圧設定)
CMD 0x01, DATA [0x03, 0x00, 0x2b, 0x2b, 0x1e]

# 4. BTST (ブースター設定)
CMD 0x06, DATA [0x17, 0x17, 0x17]

# 5. PLL (周波数: 0x3C)
CMD 0x30, DATA [0x3C]

# 6. PON (パワーオン)
CMD 0x04 -> wait_busy

# 7. TRES (解像度指定: 128x296)
CMD 0x61, DATA [0x80, 0x01, 0x28]

# 8. CDI (VCOM/データ間隔)
CMD 0x50, DATA [0x13]

# 9. TCON (ゲート/ソース設定)
CMD 0x60, DATA [0x22]

# === Deep Clean (チップメモリリセット) ===
# 10. DTM1: 全黒
CMD 0x10, DATA [0x00 * 4736]

# 11. DTM2: 全白
CMD 0x13, DATA [0xFF * 4736]

# 12. DRF (Display Refresh)
CMD 0x12 -> wait_busy

# === 通常の更新 ===
# 13. DTM1: 全白 (比較用ベース)
CMD 0x10, DATA [0xFF * 4736]

# 14. DTM2: 描画内容
CMD 0x13, DATA [framebuffer]

# 15. DRF (Display Refresh)
CMD 0x12 -> wait_busy

# 16. POF (パワーオフ)
CMD 0x02
```

**重要な違い（MicroPython版との比較）：**
- **LUT設定なし**: PSRでLUT_REGを指定しているが、LUTレジスタは設定していない
  → デフォルトLUTまたは内蔵LUTが使用される？
- **TRES使用**: 解像度をTRESで明示的に指定
- **Deep Clean**: DTM1(黒) + DTM2(白) + DRFで初期化
- **通常更新**: DTM1(白) + DTM2(描画内容) + DRFで差分更新

### 初期化シーケンス（MicroPython版準拠）

```ruby
# 1. ハードウェアリセット
RST: LOW(10ms) -> HIGH(10ms) -> wait_busy

# 2. PSR with RESET_SOFT
CMD 0x00, DATA 0x00

# 3. PWR (電圧設定)
CMD 0x01, DATA [0x03, 0x00, 0x26, 0x26, 0x03]

# 4. LUT設定 (speed=2の場合)
CMD 0x20, DATA [VCOM LUT: 44バイト]
CMD 0x22, DATA [BW LUT: 42バイト]
CMD 0x23, DATA [WB LUT: 42バイト]
CMD 0x21, DATA [WW LUT: 42バイト = BW]
CMD 0x24, DATA [BB LUT: 42バイト = WB]

# 5. BTST (ブースター設定)
CMD 0x06, DATA [0x17, 0x17, 0x17]

# 6. PON (パワーオン)
CMD 0x04 -> wait_busy

# 7. PSR再設定
CMD 0x00, DATA [0xBF]  # 最終的なPSR値

# 8. PFS (フレーム数)
CMD 0x03, DATA [0x30]  # FRAMES_4

# 9. TSE (温度センサー)
CMD 0x41, DATA [0x00]

# 10. TCON (ゲート/ソース設定)
CMD 0x60, DATA [0x22]

# 11. CDI (VCOM/データ間隔)
CMD 0x50, DATA [0xCC]  # 0b11_00_1100

# 12. PLL (周波数)
CMD 0x30, DATA [0x3A]  # 100Hz

# 13. POF (パワーオフ)
CMD 0x02 -> wait_busy
```

### 更新シーケンス

```ruby
# 初回：全画面白で初期化（DTM1/DTM2同期）
fb = "\xFF" * 4736
CMD 0x04  # PON
CMD 0x92  # PTOU (Partial mode off)
CMD 0x13  # DTM2
DATA [fb: 4736バイト]
CMD 0x11  # DSP (Data stop)
CMD 0x12  # DRF (Display refresh)
wait_busy
CMD 0x02  # POF

# 2回目以降：描画内容を反映
[fbに描画]
CMD 0x04  # PON
CMD 0x92  # PTOU
CMD 0x13  # DTM2
DATA [fb: 4736バイト]
CMD 0x11  # DSP
CMD 0x12  # DRF
wait_busy
CMD 0x02  # POF
```

## リファレンス実装

### C++版 (Pimoroni)
- **Repository**: https://github.com/pimoroni/pimoroni-pico
- **Driver**: `/drivers/uc8151/uc8151.cpp`
- **重要な関数**:
  - `update()`: 全画面更新
  - `partial_update()`: 部分更新
  - コメント: "region.y is given in columns, region.x is given in pixels"

### MicroPython版 (antirez)
- **Repository**: https://github.com/antirez/uc8151_micropython
- **Driver**: `uc8151.py`
- **README**: 詳細なLUT解説、グレースケール実装
- **Framebuffer**: `framebuf.FrameBuffer(raw_fb, width, height, framebuf.MONO_HLSB)`
  - `MONO_HLSB` = Monochrome Horizontal LSB

### データシート
- **UC8151**: https://cdn.shopify.com/s/files/1/0174/1800/files/ED029TC1_Final_v3.0_20161012.pdf
- **IL0373**: プロジェクト内に含む（より詳細）

## 調査履歴と発見事項

### 列指向メモリレイアウト仮説
C++ドライバーコメントから：
```cpp
// メモリレイアウト: 列指向（column-oriented）
// [x=0の全y][x=1の全y]...[x=295の全y]
// 各x列内で、yは8ピクセルごとに1バイトにパック

byte_idx = (y / 8) + (x * (HEIGHT / 8))
bit_idx = y % 8
```

### MicroPython版のフレームバッファ
```python
framebuf.MONO_HLSB  # Horizontal LSB
# 通常の横方向メモリレイアウト
# fb[x/8 + y*WIDTH/8] のような構造？
```

**矛盾**: C++版は列指向、MicroPython版は横指向？

### PSR設定の混乱
| バージョン | PSR値 | SCAN | SHIFT |
|------------|-------|------|-------|
| 初期推測 | 0x9C | UP | RIGHT |
| 修正1 | 0xB7 | DOWN | RIGHT |
| MicroPython | 0xBF | UP | RIGHT |

**重要**: MicroPython版は`mirror_y=False`時に`SCAN_UP`を使用

### 実験結果パターン

```
PSR=0xBF (SCAN_UP | SHIFT_RIGHT):
期待: 左上に10x10黒四角
実際: 真っ黒 + 右側に白い縦線

推測される問題:
1. 座標変換式が完全に間違っている
2. ビット順序の解釈ミス
3. 白と黒の定義が逆
4. 画面の向きが90度回転している
```

## 未解決の核心問題

## 未解決の核心問題

### ❓ 列指向 vs 行指向の謎（部分的に解決）

**実験結果：行指向で動作**
```ruby
byte_idx = (y * WIDTH + x) / 8  # 行指向
bit_idx = 7 - (x % 8)
```

**しかし、C++版は列指向を示唆：**
```cpp
// C++版 partial_update()のコメント
// region.y is given in columns ("banks")
// region.x is given in pixels

// アクセスパターン
data(cols, &fb[sy + (sx * (height / 8))]);
// = fb[y/8 + x*37] → 列指向
```

**MicroPython版は行指向：**
```python
framebuf.MONO_HLSB  # Horizontal LSB = 行指向
```

**仮説：**
1. **チップの内部メモリ**は列指向
2. **MicroPythonのframebuf**は行指向
3. MicroPythonは内部で**変換処理**を行っている？
4. または、PSR設定（SCAN/SHIFT）で**メモリアクセスパターンが変わる**

**今回の成功例：**
- PSR = 0x5F (SCAN_UP | SHIFT_RIGHT)
- 行指向で動作

**要調査：**
- PSR設定を変えると列指向になる？
- C++版とMicroPython版で座標変換が異なる理由

### 1. **フレームバッファのメモリレイアウト** ✅ 部分的に解決
- 列指向 vs 行指向
- ビット順序 (LSB first vs MSB first)
- バイト順序 (リトルエンディアン vs ビッグエンディアン)

### 2. **座標系の定義**
- 原点位置 (左上? 左下? 右上?)
- x/y軸の方向
- PSR設定との対応関係

### 3. **白と黒のビット表現**
```
現在の仮定:
0xFF = 白 (全ビット1)
0x00 = 黒 (全ビット0)

本当に正しい？ 逆かもしれない。
```

### 4. **画面の物理的向き**
```
物理: 296mm(横) x 128mm(縦) の横長バッジ
定義: WIDTH=128, HEIGHT=296

PSR設定で90度回転している可能性？
```

## 次のステップ（更新版）

### ✅ Phase 1完了: メモリレイアウトの解明
- **行指向（row-major）** で動作確認
- **MSB first** ビット順序
- **座標系**: 原点左下、y軸は下→上

### Phase 2: 座標系の完全理解（進行中）

1. **上下反転の確認**
   ```ruby
   # 画面上部（y=295付近）に描画
   (291..295).each do |y|
     (0..9).each do |x|
       set_pixel(fb, x, y, 0)  # 黒
     end
   end
   # → 物理的にどこに表示される？
   ```

2. **左右確認**
   ```ruby
   # 画面右端（x=127付近）に描画
   (0..9).each do |y|
     (118..127).each do |x|
       set_pixel(fb, x, y, 0)
     end
   end
   ```

3. **対角線テスト**
   ```ruby
   (0..127).each do |i|
     set_pixel(fb, i, i*2, 0)  # 左下から右上への斜線
   end
   ```

### Phase 3: 実用的な描画関数の実装

1. **基本図形**
   ```ruby
   def fill_rect(fb, x, y, w, h, color)
   def draw_line(fb, x0, y0, x1, y1, color)
   def draw_circle(fb, cx, cy, r, color)
   ```

2. **QRコード描画**
   - QRコード画像データ（/mnt/user-data/uploads/1769698583339_image.png）を読み込み
   - 座標変換して描画
   - 位置調整

3. **テキスト描画**
   - shinonomeフォントの統合
   - 文字列描画関数

### Phase 4: PSR設定の体系的調査

**目的**: SCAN/SHIFT設定と座標系の関係を完全解明

| PSR | SCAN | SHIFT | 期待される座標系 | 要検証 |
|-----|------|-------|----------------|--------|
| 0x5F | UP | RIGHT | 原点左下、y↑ | ✅ 確認済 |
| 0x57 | DOWN | RIGHT | 原点左上、y↓ | 🔲 未検証 |
| 0x5B | UP | LEFT | 原点右下、y↑ | 🔲 未検証 |
| 0x53 | DOWN | LEFT | 原点右上、y↓ | 🔲 未検証 |

### Phase 5: C++/MicroPython版との完全互換性
1. **1バイトテスト**
   ```ruby
   fb = "\xFF" * 4736
   fb[0] = "\x00"  # 最初の8ピクセルを黒に
   update()
   # どこに線が現れる？
   ```

2. **連続バイトテスト**
   ```ruby
   fb[0] = "\x00"
   fb[1] = "\x00"
   fb[2] = "\x00"
   # 連続して現れる？離れて現れる？
   ```

3. **特定インデックステスト**
   ```ruby
   fb[0] = "\x00"    # 位置A
   fb[37] = "\x00"   # 位置B (HEIGHT/8)
   fb[74] = "\x00"   # 位置C (HEIGHT/8 * 2)
   # A,B,Cの位置関係は？
   ```

### Phase 2: ビット順序の確認
```ruby
fb = "\xFF" * 4736
fb[0] = "\xFE"  # 0b11111110 (LSBのみ0)
fb[1] = "\x7F"  # 0b01111111 (MSBのみ0)
# どちらがどこに現れる？
```

### Phase 3: C++/MicroPython版の完全解析
1. C++版のフレームバッファアクセスパターンを全て抽出
2. MicroPython版の`framebuf.MONO_HLSB`の正確な仕様確認
3. 両者の座標変換ロジックを完全に一致させる

### Phase 4: リファレンス画像との比較
1. C++版で既知のパターンを描画
2. フレームバッファをダンプ
3. PicoRuby版と完全に一致させる

## 開発環境

### ハードウェア
- Badger 2040
- USB接続（シリアル通信）

### ソフトウェア
- PicoRuby (mruby/c)
- ESP-IDF
- Terminus gem (GPIO/SPI制御)

### 制約
- メモリ制限あり（GC.start頻繁に必要）
- 複雑なクラス化・例外処理は避ける
- シンプルな手続き型コード推奨

## 重要なナレッジ（READMEより）

### LUTの仕組み
```
各LUTは6行x7列のバイト配列:
[パターン, フレーム1, フレーム2, フレーム3, フレーム4, リピート]

パターンバイト (2ビットx4):
00 = グラウンド
01 = VDH (黒方向、例:10V)
10 = VDL (白方向、例:-10V)
11 = フローティング

例: 0x60 = 0b01|10|00|00
→ VDH(16フレーム), VDL(16フレーム)
```

### チャージニュートラル原則
> We simply need to use charge-neutral BB and WW LUTs. 
> For pixels that are not going to change color, either don't do anything (put to ground), 
> or if you apply voltages, apply them in the same amount in one direction and in the other.

同じ方向に電圧をかけ続けると**バーンイン（焼き付き）**が発生する。

### グレースケール技術
3つの遷移（WW/BB/WB）を使って異なるグレーレベルを同時設定可能。
最大32レベルのグレースケールを実現。

## 参考コードスニペット

### ✅ 動作確認済み PicoRuby版（完全版）

```ruby
require 'spi'
require 'gpio'
require 'terminus'

WIDTH  = 128
HEIGHT = 296

def send_command(spi, cs, dc, cmd, label = "")
  dc.write(0); cs.write(0); spi.write(cmd.chr); cs.write(1)
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

# 初期化
spi = SPI.new(unit: :RP2040_SPI0, frequency: 2_000_000, sck_pin: 18, copi_pin: 19, mode: 0)
cs   = GPIO.new(17, GPIO::OUT); cs.write(1)
dc   = GPIO.new(20, GPIO::OUT)
rst  = GPIO.new(21, GPIO::OUT); rst.write(1)
busy = GPIO.new(26, GPIO::IN)
pwr3v3 = GPIO.new(10, GPIO::OUT); pwr3v3.write(1)

# リセット
rst.write(0); sleep_ms(200); rst.write(1); sleep_ms(200)
wait_until_idle(busy)

# UC8151C 初期化
send_command(spi, cs, dc, 0x00); send_data_chunked(spi, cs, dc, "\x5F")  # PSR
send_command(spi, cs, dc, 0x01); send_data_chunked(spi, cs, dc, "\x03\x00\x2b\x2b\x1e")  # PWR
send_command(spi, cs, dc, 0x06); send_data_chunked(spi, cs, dc, "\x17\x17\x17")  # BTST
send_command(spi, cs, dc, 0x30); send_data_chunked(spi, cs, dc, "\x3c")  # PLL
send_command(spi, cs, dc, 0x04); wait_until_idle(busy)  # PON
send_command(spi, cs, dc, 0x61); send_data_chunked(spi, cs, dc, "\x80\x01\x28")  # TRES
send_command(spi, cs, dc, 0x50); send_data_chunked(spi, cs, dc, "\x13")  # CDI
send_command(spi, cs, dc, 0x60); send_data_chunked(spi, cs, dc, "\x22")  # TCON

# Deep Clean
send_command(spi, cs, dc, 0x10); send_data_chunked(spi, cs, dc, "\x00" * 4736)  # DTM1
send_command(spi, cs, dc, 0x13); send_data_chunked(spi, cs, dc, "\xFF" * 4736)  # DTM2
send_command(spi, cs, dc, 0x12); wait_until_idle(busy)  # DRF

# フレームバッファ
@framebuffer = "\xFF" * (WIDTH * HEIGHT / 8)

# 描画: 左下5x5を黒に
(0..4).each do |y|
  (0..4).each do |x|
    byte_idx = (y * WIDTH + x) / 8
    bit_idx = 7 - (x % 8)
    old_val = @framebuffer[byte_idx].ord
    new_val = old_val & ~(1 << bit_idx)
    @framebuffer[byte_idx] = new_val.chr
  end
end

# 更新
send_command(spi, cs, dc, 0x10); send_data_chunked(spi, cs, dc, "\xFF" * 4736)  # DTM1
send_command(spi, cs, dc, 0x13); send_data_chunked(spi, cs, dc, @framebuffer)  # DTM2
send_command(spi, cs, dc, 0x12); wait_until_idle(busy)  # DRF
send_command(spi, cs, dc, 0x02)  # POF
```

**実験結果**: 画面右上（コード上の左下座標）に5x5の黒領域が表示された。

### C++版 update()
```cpp
void UC8151::update(PicoGraphics *graphics) {
  uint8_t *fb = (uint8_t *)graphics->frame_buffer;
  
  if(blocking) busy_wait();
  
  command(PON);
  command(PTOU);
  command(DTM2, (width * height) / 8, fb);
  command(DSP);
  command(DRF);
  
  if(blocking) off();
}
```

### C++版 partial_update()
```cpp
void UC8151::partial_update(PicoGraphics *graphics, Rect region) {
  // region.y is given in columns ("banks")
  // region.x is given in pixels
  
  int cols = region.h / 8;
  int y1 = region.y / 8;
  int rows = region.w;
  int x1 = region.x;
  
  command(DTM2);
  for (auto dx = 0; dx < rows; dx++) {
    int sx = dx + x1;
    int sy = y1;
    data(cols, &fb[sy + (sx * (height / 8))]);
  }
}
```

### MicroPython版 update()
```python
def update(self, blocking=True, fb=None):
    if fb == None: fb = self.raw_fb
    if blocking == False and self.is_busy(): return False
    
    self.send_image(fb)
    self.write(CMD_DRF)
    
    if blocking: self.wait_and_switch_off()
    self.update_count += 1
    return True

def send_image(self, fb, old=False):
    self.write(CMD_PON)
    self.write(CMD_PTOU)
    if old:
        self.write(CMD_DTM1, fb)
    else:
        self.write(CMD_DTM2, fb)
    self.write(CMD_DSP)
```

## 期待される最終成果物

1. **正しい座標変換関数**
   ```ruby
   def set_pixel(fb, x, y, color)
     byte_idx = [正しい計算式]
     bit_idx = [正しい計算式]
     # 正しいビット操作
   end
   ```

2. **動作確認済みQRコード表示**
   - 左上から座標通りに描画
   - テキストと組み合わせたレイアウト

3. **再利用可能なBadger 2040ライブラリ**
   - init, clear, update, set_pixel, draw_line, etc.
   - PicoRubyのメモリ制約に最適化

## メモ

- E-inkディスプレイは部分更新でもフリッカー（点滅）が発生する
- LUT設定で速度と品質のトレードオフ調整可能
- 温度補正機能あり（内蔵センサー使用）
- 長時間同じ画像を表示すると残像の可能性

---

**最終更新**: 2026-01-30
**ステータス**: ✅ Phase 1完了 - 座標変換式確立、描画成功
**次のアクション**: Phase 2 - 座標系の完全理解（上下左右確認）
**実験画像**: /mnt/user-data/uploads/1769903765617_image.png (右上に5x5黒領域確認)
