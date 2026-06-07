import os
from PIL import Image

image_path = r"c:\Users\sebas\OneDrive\Escritorio\Lingiux\lingiux_app\assets\references\referencia_uxuiuni.png"

if not os.path.exists(image_path):
    print(f"Error: {image_path} does not exist")
    exit(1)

try:
    img = Image.open(image_path)
    img = img.convert("RGB")
    width, height = img.size
    print(f"Image size: {width}x{height}")
    
    # Let's scan pixels at different coordinates to find the blue/purple gradient
    # We will print the colors of pixels where red < 240, blue > 100 or green > 100
    # to find the colored areas.
    for y in range(0, height, 20):
        row_colors = []
        for x in range(0, width, 40):
            r, g, b = img.getpixel((x, y))
            # If not too white or too black/grey
            if not (abs(r-g) < 15 and abs(g-b) < 15 and abs(r-b) < 15):
                hex_color = f"#{r:02X}{g:02X}{b:02X}"
                row_colors.append((x, hex_color))
        if row_colors:
            print(f"y={y}: {row_colors[:6]}")
            
except Exception as e:
    print(f"Error reading image: {e}")
