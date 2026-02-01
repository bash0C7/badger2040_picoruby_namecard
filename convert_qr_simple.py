#!/usr/bin/env python3
"""Extract QR code bits from PNG without PIL"""

import struct

def read_png_pixels(filename):
    """Simple PNG reader to extract grayscale pixel data"""
    with open(filename, 'rb') as f:
        # Check PNG signature
        signature = f.read(8)
        if signature != b'\x89PNG\r\n\x1a\n':
            raise ValueError("Not a valid PNG file")

        width = None
        height = None
        pixels = None

        while True:
            # Read chunk length
            length_bytes = f.read(4)
            if not length_bytes:
                break
            length = struct.unpack('>I', length_bytes)[0]

            # Read chunk type
            chunk_type = f.read(4)
            chunk_data = f.read(length)
            crc = f.read(4)

            if chunk_type == b'IHDR':
                width = struct.unpack('>I', chunk_data[0:4])[0]
                height = struct.unpack('>I', chunk_data[4:8])[0]
                print(f"Image size: {width}x{height}")

            elif chunk_type == b'IDAT':
                import zlib
                if pixels is None:
                    pixels = b''
                pixels += chunk_data

            elif chunk_type == b'IEND':
                break

        if pixels:
            # Decompress IDAT data
            import zlib
            decompressed = zlib.decompress(pixels)

            # Parse scanlines (simple grayscale)
            pixel_data = []
            pos = 0
            for y in range(height):
                filter_type = decompressed[pos]
                pos += 1
                for x in range(width):
                    # Assuming 8-bit grayscale
                    gray = decompressed[pos]
                    pos += 1
                    pixel_data.append(gray)

            return width, height, pixel_data

    return None, None, None

# Read PNG
w, h, pixels = read_png_pixels('qr.png')

if pixels:
    # Convert to binary string (0=black, 1=white)
    qr_bits = []
    for gray in pixels:
        # 0 for black (gray < 128), 1 for white (gray >= 128)
        qr_bits.append('0' if gray < 128 else '1')

    qr_string = ''.join(qr_bits)
    print(f"Total bits: {len(qr_bits)} ({w}x{h})")
    print(f"\nQR_DATA = \"{qr_string}\"")
else:
    print("Failed to read PNG")
