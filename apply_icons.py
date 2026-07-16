#!/usr/bin/env python3
"""将生成的图标应用到所有平台"""

import os
import shutil
from PIL import Image

# 源图标路径（保留原图图案、满铺渐变背景）
SOURCE_ICON = "generated-images/tetris_app_icon.png"

# 各平台图标尺寸配置
IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_SIZES = {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}

WEB_SIZES = {
    "icons/Icon-192.png": 192,
    "icons/Icon-512.png": 512,
    "icons/Icon-maskable-192.png": 192,
    "icons/Icon-maskable-512.png": 512,
    "icons/favicon.png": 32,
}

MACOS_SIZES = {
    "AppIcon.appiconset/app_icon_16.png": 16,
    "AppIcon.appiconset/app_icon_32.png": 32,
    "AppIcon.appiconset/app_icon_64.png": 64,
    "AppIcon.appiconset/app_icon_128.png": 128,
    "AppIcon.appiconset/app_icon_256.png": 256,
    "AppIcon.appiconset/app_icon_512.png": 512,
    "AppIcon.appiconset/app_icon_1024.png": 1024,
}

def resize_and_save(source_img, size, output_path, overscan=1.1, bg_color=(255, 255, 255, 255),
                    contain=False, contain_scale=0.72):
    """裁掉透明外边距后缩放。
    cover 模式：放大铺满正方形并居中裁切（默认，传统图标用）。
    contain 模式：完整居中放入，四周留底色（自适应图标 foreground 用，避免过满）。
    """
    # 1) 裁掉透明外边距，保留图案主体
    bbox = source_img.getbbox()
    base = source_img.crop(bbox) if bbox else source_img
    # 二次裁剪：去掉羽化/半透明淡边，使不透明内容真正贴边，避免边缘白圈
    alpha = base.split()[3].point(lambda a: 255 if a > 40 else 0)
    tb = alpha.getbbox()
    if tb:
        base = base.crop(tb)
    cw, ch = base.size

    if contain:
        # 完整居中放入，按 contain_scale 缩小，四周留底色（自适应图标风格）
        scale = min(size / cw, size / ch) * contain_scale
        nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
        scaled = base.resize((nw, nh), Image.LANCZOS)
        left = (size - nw) // 2
        top = (size - nh) // 2
        squared = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        squared.paste(scaled, (left, top))
    else:
        # 2) cover 缩放到正方形并居中裁切，使图案铺满整个图标
        #    OVERSCAN 让主体主动放大出血，边缘被裁切，视觉上更满更大
        scale = max(size / cw, size / ch) * overscan
        nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
        scaled = base.resize((nw, nh), Image.LANCZOS)
        left = (nw - size) // 2
        top = (nh - size) // 2
        squared = scaled.crop((left, top, left + size, top + size)).convert("RGBA")

    # 3) 残差透明填底，保证不透明满铺
    bg = Image.new("RGBA", (size, size), bg_color)
    out = Image.alpha_composite(bg, squared).convert("RGB")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    out.save(output_path, "PNG")
    print(f"  ✓ {output_path} ({size}x{size})")

def main():
    if not os.path.exists(SOURCE_ICON):
        print(f"错误: 找不到源图标 {SOURCE_ICON}")
        return
    
    source_img = Image.open(SOURCE_ICON).convert("RGBA")
    print(f"源图标: {source_img.size[0]}x{source_img.size[1]}")
    print()
    
    # iOS
    print("📱 iOS 图标:")
    ios_base = "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
    for filename, size in IOS_SIZES.items():
        resize_and_save(source_img, size, os.path.join(ios_base, filename))
    
    # Android
    print("\n🤖 Android 图标:")
    android_base = "android/app/src/main/res/"
    for path, size in ANDROID_SIZES.items():
        resize_and_save(source_img, size, os.path.join(android_base, path), overscan=1.1)

    # Android 自适应图标 foreground：满铺深蓝底，避免系统自动套白底形成白圈
    print("\n🤖 Android 自适应 foreground:")
    FG_BG = (255, 255, 255, 255)
    for path, size in ANDROID_SIZES.items():
        fg_path = path.replace("ic_launcher.png", "ic_launcher_foreground.png")
        resize_and_save(source_img, size, os.path.join(android_base, fg_path), bg_color=FG_BG,
                        contain=True, contain_scale=0.6)
    
    # Web
    print("\n🌐 Web 图标:")
    web_base = "web/"
    for path, size in WEB_SIZES.items():
        resize_and_save(source_img, size, os.path.join(web_base, path))
    
    # macOS
    print("\n🖥️  macOS 图标:")
    macos_base = "macos/Runner/Assets.xcassets/"
    for path, size in MACOS_SIZES.items():
        resize_and_save(source_img, size, os.path.join(macos_base, path))
    
    print("\n✅ 所有平台图标已更新!")

if __name__ == "__main__":
    main()