"""
修仙桌宠 - 像素素材生成器
从源图片自动生成 idle/focus/sleep 三组动画帧
"""

from PIL import Image, ImageFilter, ImageEnhance, ImageDraw
import math
import os

# === 配置 ===
SOURCE_PATH = "source_character.jpg"
OUTPUT_DIR = "assets/sprites"
SPRITE_SIZE = 96  # 最终像素画尺寸
PIXEL_SCALE = 4   # 像素化程度 (越大越像素)
IDLE_FRAMES = 6
FOCUS_FRAMES = 8
SLEEP_FRAMES = 6


def load_and_prepare(path):
    """加载图片，裁剪为正方形，去除白色背景"""
    img = Image.open(path).convert("RGBA")
    
    # 裁剪为正方形（取上半身）
    w, h = img.size
    # 取上半部分（头部+上半身）
    crop_size = min(w, int(h * 0.7))
    left = (w - crop_size) // 2
    top = 0
    img = img.crop((left, top, left + crop_size, top + crop_size))
    
    # 去除白色/浅色背景 -> 透明
    img = remove_light_background(img, threshold=230)
    
    return img


def remove_light_background(img, threshold=200):
    """将接近白色/浅色的像素变为透明，带渐变边缘"""
    data = img.getdata()
    new_data = []
    for pixel in data:
        r, g, b, a = pixel
        # 计算亮度
        brightness = (r + g + b) / 3
        # 如果像素很亮（接近白色），设为透明
        if brightness > threshold:
            # 渐变过渡：越亮越透明
            fade = max(0, min(255, int((brightness - threshold) / (255 - threshold) * 255)))
            new_data.append((r, g, b, 255 - fade))
        else:
            new_data.append(pixel)
    img.putdata(new_data)
    return img


def pixelate(img, pixel_size=PIXEL_SCALE):
    """像素化处理"""
    w, h = img.size
    # 缩小再放大 = 像素化效果
    small = img.resize((w // pixel_size, h // pixel_size), Image.NEAREST)
    pixelated = small.resize((w, h), Image.NEAREST)
    return pixelated


def to_sprite(img, size=SPRITE_SIZE):
    """缩放到最终精灵尺寸并像素化"""
    # 先缩小到目标尺寸的1/4，再放大（创造像素感）
    tiny_size = size // 4  # 24x24 的超小版本
    tiny = img.resize((tiny_size, tiny_size), Image.LANCZOS)
    # 放大回目标尺寸，用最近邻插值保持像素感
    sprite = tiny.resize((size, size), Image.NEAREST)
    return sprite


def add_green_tint(img, intensity=0.3):
    """添加仙气绿色色调"""
    overlay = Image.new("RGBA", img.size, (100, 200, 150, int(255 * intensity)))
    return Image.alpha_composite(img, overlay)


def generate_idle_frames(base_sprite):
    """生成待机动画帧 - 上下浮动 + 呼吸缩放"""
    frames = []
    for i in range(IDLE_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        
        # 计算浮动偏移
        phase = (i / IDLE_FRAMES) * 2 * math.pi
        offset_y = int(math.sin(phase) * 3)  # 上下浮动 3 像素
        
        # 轻微呼吸缩放
        scale = 1.0 + math.sin(phase) * 0.02
        new_size = int(SPRITE_SIZE * scale)
        scaled = base_sprite.resize((new_size, new_size), Image.NEAREST)
        
        # 居中粘贴
        paste_x = (SPRITE_SIZE - new_size) // 2
        paste_y = (SPRITE_SIZE - new_size) // 2 + offset_y
        frame.paste(scaled, (paste_x, paste_y), scaled)
        
        # 添加微弱灵气光点
        draw = ImageDraw.Draw(frame)
        for j in range(3):
            px = int(20 + 56 * math.sin(phase + j * 2.1))
            py = int(15 + 40 * math.cos(phase + j * 1.7))
            alpha = int(100 + 80 * math.sin(phase + j))
            draw.ellipse([px-1, py-1, px+1, py+1], fill=(180, 255, 200, alpha))
        
        frames.append(frame)
    return frames


def generate_focus_frames(base_sprite):
    """生成专注/打坐动画帧 - 灵气环绕 + 发光"""
    frames = []
    for i in range(FOCUS_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        phase = (i / FOCUS_FRAMES) * 2 * math.pi
        
        # 角色静坐（稍微缩小，表示盘腿）
        sit_size = int(SPRITE_SIZE * 0.85)
        sit_sprite = base_sprite.resize((sit_size, sit_size), Image.NEAREST)
        paste_x = (SPRITE_SIZE - sit_size) // 2
        paste_y = SPRITE_SIZE - sit_size - 2  # 底部对齐
        frame.paste(sit_sprite, (paste_x, paste_y), sit_sprite)
        
        # 画灵气光环
        draw = ImageDraw.Draw(frame)
        center_x, center_y = SPRITE_SIZE // 2, SPRITE_SIZE // 2
        
        # 旋转的灵气粒子
        for j in range(6):
            angle = phase + j * (math.pi / 3)
            radius = 35 + 5 * math.sin(phase * 2 + j)
            px = int(center_x + radius * math.cos(angle))
            py = int(center_y + radius * math.sin(angle))
            alpha = int(150 + 100 * math.sin(phase + j))
            size_p = 2 if j % 2 == 0 else 1
            draw.ellipse([px-size_p, py-size_p, px+size_p, py+size_p], 
                        fill=(100, 255, 180, alpha))
        
        # 底部莲花座光晕
        for j in range(8):
            lx = int(center_x + 20 * math.cos(j * math.pi / 4))
            ly = SPRITE_SIZE - 8 + int(2 * math.sin(phase + j))
            draw.ellipse([lx-2, ly-1, lx+2, ly+1], fill=(150, 255, 200, 80))
        
        frames.append(frame)
    return frames


def generate_sleep_frames(base_sprite):
    """生成睡觉动画帧 - 倾斜 + ZZZ"""
    frames = []
    for i in range(SLEEP_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        phase = (i / SLEEP_FRAMES) * 2 * math.pi
        
        # 角色倾斜（旋转5度模拟打瞌睡）
        rotated = base_sprite.rotate(-8, expand=False, resample=Image.NEAREST)
        # 轻微上下晃动
        offset_y = int(math.sin(phase) * 2)
        frame.paste(rotated, (0, offset_y), rotated)
        
        # 画 ZZZ
        draw = ImageDraw.Draw(frame)
        for j in range(3):
            zx = 65 + j * 8
            zy = 10 + j * 10 + int(math.sin(phase + j * 0.8) * 3)
            alpha = int(180 - j * 40 + 40 * math.sin(phase + j))
            # 画 Z 字
            draw.line([(zx, zy), (zx+6, zy)], fill=(200, 220, 255, alpha), width=1)
            draw.line([(zx+6, zy), (zx, zy+6)], fill=(200, 220, 255, alpha), width=1)
            draw.line([(zx, zy+6), (zx+6, zy+6)], fill=(200, 220, 255, alpha), width=1)
        
        # 鼻涕泡
        bubble_size = int(3 + 2 * abs(math.sin(phase)))
        bx, by = 30, 55
        draw.ellipse([bx, by, bx + bubble_size*2, by + bubble_size*2], 
                    fill=(220, 240, 255, 100), outline=(200, 220, 255, 150))
        
        frames.append(frame)
    return frames


def main():
    print("=" * 50)
    print("  修仙桌宠 - 像素素材生成器")
    print("=" * 50)
    
    # 确保输出目录存在
    for sub in ["idle", "focus", "sleep"]:
        os.makedirs(os.path.join(OUTPUT_DIR, sub), exist_ok=True)
    
    # 加载源图
    print(f"\n[1/5] 加载源图: {SOURCE_PATH}")
    img = load_and_prepare(SOURCE_PATH)
    print(f"      裁剪后尺寸: {img.size}")
    
    # 像素化
    print("[2/5] 像素化处理...")
    sprite_base = to_sprite(img)
    print(f"      精灵尺寸: {sprite_base.size}")
    
    # 生成 idle 帧
    print(f"[3/5] 生成 idle 动画 ({IDLE_FRAMES} 帧)...")
    idle_frames = generate_idle_frames(sprite_base)
    for i, f in enumerate(idle_frames):
        path = os.path.join(OUTPUT_DIR, "idle", f"{i+1:02d}.png")
        f.save(path)
    print(f"      保存至: {OUTPUT_DIR}/idle/")
    
    # 生成 focus 帧
    print(f"[4/5] 生成 focus 动画 ({FOCUS_FRAMES} 帧)...")
    focus_frames = generate_focus_frames(sprite_base)
    for i, f in enumerate(focus_frames):
        path = os.path.join(OUTPUT_DIR, "focus", f"{i+1:02d}.png")
        f.save(path)
    print(f"      保存至: {OUTPUT_DIR}/focus/")
    
    # 生成 sleep 帧
    print(f"[5/5] 生成 sleep 动画 ({SLEEP_FRAMES} 帧)...")
    sleep_frames = generate_sleep_frames(sprite_base)
    for i, f in enumerate(sleep_frames):
        path = os.path.join(OUTPUT_DIR, "sleep", f"{i+1:02d}.png")
        f.save(path)
    print(f"      保存至: {OUTPUT_DIR}/sleep/")
    
    print("\n" + "=" * 50)
    print("  完成！共生成:")
    print(f"    idle:  {IDLE_FRAMES} 帧")
    print(f"    focus: {FOCUS_FRAMES} 帧")
    print(f"    sleep: {SLEEP_FRAMES} 帧")
    print(f"    总计:  {IDLE_FRAMES + FOCUS_FRAMES + SLEEP_FRAMES} 张 PNG")
    print("=" * 50)
    print("\n双击 run.bat 即可看到效果！")


if __name__ == "__main__":
    main()
