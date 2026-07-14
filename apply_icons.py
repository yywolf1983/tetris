#!/usr/bin/env python3
"""将生成的图标应用到所有平台"""

import os
import shutil
from PIL import Image

# 源图标路径
SOURCE_ICON = "generated-images/Design_a_modern_app_icon_for_a_2026-05-28T05-28-01.png"

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

def resize_and_save(source_img, size, output_path):
    """调整图片大小并保存"""
    img = source_img.resize((size, size), Image.LANCZOS)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
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
        resize_and_save(source_img, size, os.path.join(android_base, path))
    
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