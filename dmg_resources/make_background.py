"""Generate DMG background image with arrow pointing from app to Applications."""
from PIL import Image, ImageDraw, ImageFont
import math

WIDTH, HEIGHT = 660, 400
BG_TOP = (200, 210, 225)
BG_BOT = (160, 170, 190)

img = Image.new("RGBA", (WIDTH, HEIGHT))
draw = ImageDraw.Draw(img)

# Gradient background
for y in range(HEIGHT):
    t = y / HEIGHT
    r = int(BG_TOP[0] * (1 - t) + BG_BOT[0] * t)
    g = int(BG_TOP[1] * (1 - t) + BG_BOT[1] * t)
    b = int(BG_TOP[2] * (1 - t) + BG_BOT[2] * t)
    draw.line([(0, y), (WIDTH, y)], fill=(r, g, b, 255))

# Arrow from left icon area to right icon area
# Icons will be at x=165 (app) and x=495 (Applications)
arrow_y = 200
arrow_x_start = 240
arrow_x_end = 420
arrow_color = (80, 90, 110, 200)

# Arrow shaft
shaft_thickness = 4
draw.rectangle(
    [arrow_x_start, arrow_y - shaft_thickness // 2,
     arrow_x_end - 20, arrow_y + shaft_thickness // 2],
    fill=arrow_color
)

# Arrowhead (triangle)
head_size = 18
draw.polygon([
    (arrow_x_end, arrow_y),
    (arrow_x_end - head_size * 1.5, arrow_y - head_size),
    (arrow_x_end - head_size * 1.5, arrow_y + head_size),
], fill=arrow_color)

# Subtle bottom text
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
except:
    font = ImageFont.load_default()

text = "Drag to Applications to install"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((WIDTH - tw) // 2, 310), text, fill=(60, 65, 80, 180), font=font)

img.save("/Users/avie/Desktop/MPA2/Versions/MyPsychAdmin/dmg_resources/background.png")
print(f"Created background: {WIDTH}x{HEIGHT}")
