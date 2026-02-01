#!/usr/bin/env python3
"""Convert QR code PNG to simple binary string representation"""

from PIL import Image

# Open QR code image
img = Image.open('qr.png')
pixels = img.load()

width, height = img.size
print(f"QR code size: {width}x{height}")

# Convert to binary string (0=black, 1=white)
# QR codes use white as background and black as data
qr_bits = []
for y in range(height):
    for x in range(width):
        pixel = pixels[x, y]
        # Grayscale: pixel < 128 is black (0), pixel >= 128 is white (1)
        if isinstance(pixel, tuple):
            # RGB
            gray = sum(pixel[:3]) // 3
        else:
            # Grayscale
            gray = pixel

        # 0 for black, 1 for white
        qr_bits.append('0' if gray < 128 else '1')

qr_string = ''.join(qr_bits)

print(f"Total bits: {len(qr_bits)}")
print(f"\nQR_DATA = \"{qr_string}\"")

# Also output in Ruby format
ruby_output = f'QR_DATA = "{qr_string}"'
with open('qr_data.rb', 'w') as f:
    f.write(ruby_output)
print(f"\nSaved to qr_data.rb")
