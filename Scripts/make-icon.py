#!/usr/bin/env python3
"""Render the Rec Translate app icon (macOS squircle) at high res, then downscale."""
from PIL import Image, ImageDraw, ImageFilter

WORK = 2048          # supersample working canvas
OUT = 1024

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def gradient(w, h, stops, diagonal=True):
    """3-stop gradient, computed small then upscaled (smooth + fast)."""
    g = 256
    img = Image.new("RGB", (g, g))
    px = img.load()
    c0, c1, c2 = stops
    for y in range(g):
        for x in range(g):
            t = ((x + y) / (2 * (g - 1))) if diagonal else (y / (g - 1))
            if t < 0.5:
                px[x, y] = lerp(c0, c1, t / 0.5)
            else:
                px[x, y] = lerp(c1, c2, (t - 0.5) / 0.5)
    return img.resize((w, h), Image.LANCZOS)

def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m

img = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))

# ---- macOS squircle body geometry ----
margin = 196
body = (margin, margin - 30, WORK - margin, WORK - margin - 60)  # slight upward bias for shadow room
radius = int((body[2] - body[0]) * 0.2237)

# ---- drop shadow under the icon body ----
shadow = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sbox = (body[0] + 8, body[1] + 30, body[2] - 8, body[3] + 30)
sd.rounded_rectangle(sbox, radius=radius, fill=(18, 8, 40, 80))
shadow = shadow.filter(ImageFilter.GaussianBlur(40))
img = Image.alpha_composite(img, shadow)

# ---- gradient body (deep indigo -> violet -> pink) ----
bw, bh = body[2] - body[0], body[3] - body[1]
grad = gradient(bw, bh, [(80, 72, 255), (148, 66, 246), (255, 78, 150)]).convert("RGBA")
bodymask = rounded_mask((bw, bh), (0, 0, bw, bh), radius)
img.paste(grad, (body[0], body[1]), bodymask)
bodymask_full = rounded_mask((WORK, WORK), body, radius)

# ---- top glass sheen (subtle) ----
sheen = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
ImageDraw.Draw(sheen).ellipse(
    (body[0] - 120, body[1] - 820, body[2] + 120, body[1] + 560),
    fill=(255, 255, 255, 52),
)
sheen = sheen.filter(ImageFilter.GaussianBlur(64))
sheen.putalpha(Image.composite(sheen.getchannel("A"), Image.new("L", (WORK, WORK), 0), bodymask_full))
img = Image.alpha_composite(img, sheen)

# ---- soft glow behind the bubble for depth ----
glow = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((420, 470, 1628, 1360), fill=(255, 255, 255, 42))
glow = glow.filter(ImageFilter.GaussianBlur(110))
glow.putalpha(Image.composite(glow.getchannel("A"), Image.new("L", (WORK, WORK), 0), bodymask_full))
img = Image.alpha_composite(img, glow)

# ---- speech bubble ----
bub = (560, 540, 1488, 1300)
br = 210
bubble_shadow = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
ImageDraw.Draw(bubble_shadow).rounded_rectangle((bub[0], bub[1] + 26, bub[2], bub[3] + 26),
                                                radius=br, fill=(20, 10, 40, 120))
bubble_shadow = bubble_shadow.filter(ImageFilter.GaussianBlur(34))
img = Image.alpha_composite(img, bubble_shadow)

bubble = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
bd = ImageDraw.Draw(bubble)
bd.rounded_rectangle(bub, radius=br, fill=(255, 255, 255, 255))
# tail at bottom-left
bd.polygon([(690, 1250), (690, 1452), (878, 1276)], fill=(255, 255, 255, 255))
img = Image.alpha_composite(img, bubble)

# ---- bidirectional translate arrows (gradient-filled) inside the bubble ----
arrow_mask = Image.new("L", (WORK, WORK), 0)
am = ImageDraw.Draw(arrow_mask)
# top arrow -> right
am.rounded_rectangle((720, 770, 1300, 856), radius=43, fill=255)
am.polygon([(1276, 712), (1430, 813), (1276, 914)], fill=255)
# bottom arrow -> left
am.rounded_rectangle((748, 984, 1328, 1070), radius=43, fill=255)
am.polygon([(772, 926), (618, 1027), (772, 1128)], fill=255)
arrows = gradient(WORK, WORK, [(88, 70, 240), (123, 70, 235), (214, 56, 130)]).convert("RGBA")
img.paste(arrows, (0, 0), arrow_mask)

import os, sys
ICONSET = sys.argv[1] if len(sys.argv) > 1 else "/home/kta/projects/rec-translate/Resources/AppIcon.iconset"
os.makedirs(ICONSET, exist_ok=True)
names = {
    16: ["icon_16x16.png"],
    32: ["icon_16x16@2x.png", "icon_32x32.png"],
    64: ["icon_32x32@2x.png"],
    128: ["icon_128x128.png"],
    256: ["icon_128x128@2x.png", "icon_256x256.png"],
    512: ["icon_256x256@2x.png", "icon_512x512.png"],
    1024: ["icon_512x512@2x.png"],
}
for size, files in names.items():
    im = img.resize((size, size), Image.LANCZOS)
    for f in files:
        im.save(os.path.join(ICONSET, f))
img.resize((OUT, OUT), Image.LANCZOS).save("/tmp/icon_master.png")

# small-size legibility preview
sizes = [16, 32, 64, 128]
pad = 28
strip = Image.new("RGBA", (sum(sizes) + pad * (len(sizes) + 1), 128 + 2 * pad), (244, 244, 247, 255))
x = pad
for s in sizes:
    im = img.resize((s, s), Image.LANCZOS)
    strip.paste(im, (x, (strip.height - s) // 2), im)
    x += s + pad
strip.save("/tmp/icon_small_preview.png")
print("iconset ->", ICONSET)
