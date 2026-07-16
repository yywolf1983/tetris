#!/usr/bin/env python3
"""生成满铺全屏的俄罗斯方块 App 图标（无透明边距、无留白）。

输出: generated-images/tetris_app_icon.png (1024x1024)
随后由 apply_icons.py 缩放并应用到各平台。
"""

import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = "generated-images/tetris_app_icon.png"

# 背景对角渐变（深紫 -> 深蓝，呼应游戏界面配色）
BG_TOP = (94, 53, 177)     # #5e35b1
BG_BOTTOM = (30, 136, 229) # #1e88e5

# 经典方块配色（青/黄/紫/红）
BLOCK_COLORS = [
    (38, 198, 218),   # cyan  #26c6da
    (255, 202, 40),   # amber #ffca28
    (171, 71, 188),   # purple#ab47bc
    (239, 83, 80),    # red   #ef5350
]


def lerp(a, b, t):
    return int(a + (b - a) * t)


def make_background():
    img = Image.new("RGBA", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        # 加一点水平方向的轻微偏移，形成对角感
        r = lerp(BG_TOP[0], BG_BOTTOM[0], t)
        g = lerp(BG_TOP[1], BG_BOTTOM[1], t)
        b = lerp(BG_TOP[2], BG_BOTTOM[2], t)
        for x in range(SIZE):
            px[x, y] = (r, g, b, 255)
    return img


def round_rect_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def draw_block(canvas, box, color):
    """在 box 内绘制带高光与暗边的立体方块。"""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    radius = int(min(w, h) * 0.18)

    # 主体渐变（左上亮、右下暗）
    base = Image.new("RGBA", (w, h))
    bp = base.load()
    light = tuple(min(255, c + 90) for c in color)
    dark = tuple(max(0, c - 70) for c in color)
    for yy in range(h):
        t = yy / max(1, h - 1)
        for xx in range(w):
            tt = (xx / max(1, w - 1) + t) / 2
            r = lerp(light[0], dark[0], tt)
            g = lerp(light[1], dark[1], tt)
            b = lerp(light[2], dark[2], tt)
            bp[xx, yy] = (r, g, b, 255)

    mask = round_rect_mask((w, h), radius)
    base.putalpha(mask)
    canvas.alpha_composite(base, (x0, y0))

    # 顶部玻璃高光
    gloss = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gh = int(h * 0.42)
    gd.rounded_rectangle([int(w * 0.14), int(h * 0.08),
                          int(w * 0.86), int(h * 0.08) + gh],
                         radius=int(min(w, h) * 0.14),
                         fill=(255, 255, 255, 90))
    gloss.putalpha(mask)
    canvas.alpha_composite(gloss, (x0, y0))

    # 描边
    sd = ImageDraw.Draw(canvas)
    sd.rounded_rectangle([x0, y0, x1, y1], radius=radius,
                         outline=tuple(max(0, c - 90) for c in color), width=max(2, int(min(w, h) * 0.04)))


def main():
    img = make_background()
    d = ImageDraw.Draw(img)

    # 2x2 大块，铺满中央约 78% 区域
    margin = int(SIZE * 0.13)
    gap = int(SIZE * 0.045)
    cell = (SIZE - 2 * margin - gap) // 2
    top = (SIZE - (2 * cell + gap)) // 2
    left = (SIZE - (2 * cell + gap)) // 2

    positions = [
        (left, top),
        (left + cell + gap, top),
        (left, top + cell + gap),
        (left + cell + gap, top + cell + gap),
    ]
    for (px0, py0), color in zip(positions, BLOCK_COLORS):
        draw_block(img, (px0, py0, px0 + cell, py0 + cell), color)

    # 轻微整体锐化/清晰化
    img = img.filter(ImageFilter.SHARPEN)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "PNG")
    print(f"✅ 已生成满铺图标: {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
