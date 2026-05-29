"""
修仙桌宠 - 自定义角色制作脚本
用一张照片自动生成 idle / focus / sleep 三组动画帧，
输出到 assets/characters/<name>/ ，运行时可在游戏内点击「切换形象」按钮循环使用。

用法:
    python make_character.py --source 照片.jpg --name 道长
    python make_character.py --source 全身照.jpg --name 剑仙 --crop full --sleep-pose sit
    python make_character.py --source 新照片.jpg --name 道长 --state focus --force  # R-12 单态替换
    python make_character.py                       # 交互模式

依赖:
    pip install pillow

说明:
    --crop upper   只取上半身（默认，证件照/半身像用）
    --crop full    保留全身（等比缩放，建议用纵向全身照）
    --crop square  居中裁最大正方形（不丢内容）
    --sleep-pose drift  默认走火入魔（歪头 + 漂浮 + ZZZ）
    --sleep-pose sit    盘腿打坐睡（蒲团 + 歪头 + 呼吸 + ZZZ）
    --state idle/focus/sleep/all  仅生成指定状态帧（默认 all）
    --no-preview                  跳过 preview.png 拼接大图（默认会输出）
"""

import argparse
import math
import os
import re
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("[错误] 缺少 Pillow，请先执行: pip install pillow")
    sys.exit(1)


# ─── 配置 ──────────────────────────────────────────────────────────────────────
SPRITE_SIZE = 96
PIXEL_SCALE = 4
IDLE_FRAMES = 6
FOCUS_FRAMES = 8
SLEEP_FRAMES = 6
ROOT = os.path.dirname(os.path.abspath(__file__))
CHARACTERS_DIR = os.path.join(ROOT, "assets", "characters")
RESERVED_NAMES = {"default", "generated"}  # 与游戏内置约定冲突，禁止使用


# ─── 图像处理 ─────────────────────────────────────────────────────────────────
def load_and_prepare(path: str, crop_mode: str = "upper") -> Image.Image:
    """加载图片 → 按 crop_mode 裁剪为正方形 → 抠浅色背景。

    crop_mode:
      upper  取上半身（正方形 = min(w, h*0.7)）
      square 居中裁最大正方形
      full   保留全身：等比贴到 max(w,h) 透明正方形画布上
    """
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if crop_mode == "upper":
        crop_size = min(w, int(h * 0.7))
        left = (w - crop_size) // 2
        img = img.crop((left, 0, left + crop_size, crop_size))
    elif crop_mode == "square":
        crop_size = min(w, h)
        left = (w - crop_size) // 2
        top = (h - crop_size) // 2
        img = img.crop((left, top, left + crop_size, top + crop_size))
    elif crop_mode == "full":
        side = max(w, h)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(img, ((side - w) // 2, (side - h) // 2), img)
        img = canvas
    else:
        raise ValueError("crop 必须是 upper / full / square 之一，当前: %s" % crop_mode)
    return remove_light_background(img, threshold=230)


def remove_light_background(img: Image.Image, threshold: int = 200) -> Image.Image:
    """亮度高于阈值的像素 → 渐变透明。"""
    data = img.getdata()
    new_data = []
    for r, g, b, a in data:
        brightness = (r + g + b) / 3
        if brightness > threshold:
            fade = max(0, min(255, int((brightness - threshold) / max(1, 255 - threshold) * 255)))
            new_data.append((r, g, b, 255 - fade))
        else:
            new_data.append((r, g, b, a))
    img.putdata(new_data)
    return img


def to_sprite(img: Image.Image, size: int = SPRITE_SIZE) -> Image.Image:
    """缩到 1/4 再放大 → 像素化效果。"""
    tiny = img.resize((size // 4, size // 4), Image.LANCZOS)
    return tiny.resize((size, size), Image.NEAREST)


# ─── 三组动画 ──────────────────────────────────────────────────────────────────
def generate_idle_frames(base: Image.Image):
    """待机：上下浮动 + 微弱灵气光点。"""
    frames = []
    for i in range(IDLE_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        phase = (i / IDLE_FRAMES) * 2 * math.pi
        offset_y = int(math.sin(phase) * 3)
        scale = 1.0 + math.sin(phase) * 0.02
        new_size = max(1, int(SPRITE_SIZE * scale))
        scaled = base.resize((new_size, new_size), Image.NEAREST)
        px = (SPRITE_SIZE - new_size) // 2
        py = (SPRITE_SIZE - new_size) // 2 + offset_y
        frame.paste(scaled, (px, py), scaled)
        draw = ImageDraw.Draw(frame)
        for j in range(3):
            sx = int(20 + 56 * math.sin(phase + j * 2.1))
            sy = int(15 + 40 * math.cos(phase + j * 1.7))
            alpha = int(100 + 80 * math.sin(phase + j))
            draw.ellipse([sx - 1, sy - 1, sx + 1, sy + 1], fill=(180, 255, 200, alpha))
        frames.append(frame)
    return frames


def generate_focus_frames(base: Image.Image):
    """打坐：缩坐底部 + 灵气光环旋转 + 莲花座光晕。"""
    frames = []
    for i in range(FOCUS_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        phase = (i / FOCUS_FRAMES) * 2 * math.pi
        sit_size = int(SPRITE_SIZE * 0.85)
        sit = base.resize((sit_size, sit_size), Image.NEAREST)
        frame.paste(sit, ((SPRITE_SIZE - sit_size) // 2, SPRITE_SIZE - sit_size - 2), sit)
        draw = ImageDraw.Draw(frame)
        cx, cy = SPRITE_SIZE // 2, SPRITE_SIZE // 2
        for j in range(6):
            angle = phase + j * (math.pi / 3)
            radius = 35 + 5 * math.sin(phase * 2 + j)
            sx = int(cx + radius * math.cos(angle))
            sy = int(cy + radius * math.sin(angle))
            alpha = int(150 + 100 * math.sin(phase + j))
            r = 2 if j % 2 == 0 else 1
            draw.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(100, 255, 180, alpha))
        for j in range(8):
            lx = int(cx + 20 * math.cos(j * math.pi / 4))
            ly = SPRITE_SIZE - 8 + int(2 * math.sin(phase + j))
            draw.ellipse([lx - 2, ly - 1, lx + 2, ly + 1], fill=(150, 255, 200, 80))
        frames.append(frame)
    return frames


def generate_sleep_sit_frames(base: Image.Image):
    """盘腿打坐睡：蒲团 + 歪头 + 缓慢呼吸 + ZZZ。"""
    frames = []
    for i in range(SLEEP_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        phase = (i / SLEEP_FRAMES) * 2 * math.pi
        # 蒲团（盘腿底座）
        draw_bg = ImageDraw.Draw(frame)
        cx = SPRITE_SIZE // 2
        bottom = SPRITE_SIZE - 4
        draw_bg.ellipse([cx - 26, bottom - 6, cx + 26, bottom + 2],
                        fill=(110, 70, 50, 180), outline=(70, 40, 25, 220))
        draw_bg.ellipse([cx - 22, bottom - 7, cx + 22, bottom - 2],
                        fill=(160, 110, 80, 200))
        # 缩坐 + 微弱呼吸 + 头歪
        breath = 1.0 + math.sin(phase) * 0.015
        sit_size = max(1, int(SPRITE_SIZE * 0.82 * breath))
        sit = base.resize((sit_size, sit_size), Image.NEAREST)
        sit = sit.rotate(-7, expand=False, resample=Image.NEAREST)
        px = (SPRITE_SIZE - sit_size) // 2
        py = SPRITE_SIZE - sit_size - 6
        frame.paste(sit, (px, py), sit)
        # ZZZ
        draw = ImageDraw.Draw(frame)
        for j in range(3):
            zx = 62 + j * 6
            zy = 10 + j * 9 + int(math.sin(phase + j * 0.8) * 3)
            alpha = max(0, min(255, int(180 - j * 40 + 40 * math.sin(phase + j))))
            color = (200, 220, 255, alpha)
            draw.line([(zx, zy), (zx + 6, zy)], fill=color, width=1)
            draw.line([(zx + 6, zy), (zx, zy + 6)], fill=color, width=1)
            draw.line([(zx, zy + 6), (zx + 6, zy + 6)], fill=color, width=1)
        frames.append(frame)
    return frames


def generate_sleep_frames(base: Image.Image):
    """走火入魔：歪头 + ZZZ + 鼻涕泡。"""
    frames = []
    for i in range(SLEEP_FRAMES):
        frame = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        phase = (i / SLEEP_FRAMES) * 2 * math.pi
        rotated = base.rotate(-8, expand=False, resample=Image.NEAREST)
        offset_y = int(math.sin(phase) * 2)
        frame.paste(rotated, (0, offset_y), rotated)
        draw = ImageDraw.Draw(frame)
        for j in range(3):
            zx = 65 + j * 8
            zy = 10 + j * 10 + int(math.sin(phase + j * 0.8) * 3)
            alpha = int(180 - j * 40 + 40 * math.sin(phase + j))
            color = (200, 220, 255, max(0, min(255, alpha)))
            draw.line([(zx, zy), (zx + 6, zy)], fill=color, width=1)
            draw.line([(zx + 6, zy), (zx, zy + 6)], fill=color, width=1)
            draw.line([(zx, zy + 6), (zx + 6, zy + 6)], fill=color, width=1)
        bubble = int(3 + 2 * abs(math.sin(phase)))
        bx, by = 30, 55
        draw.ellipse([bx, by, bx + bubble * 2, by + bubble * 2],
                     fill=(220, 240, 255, 100), outline=(200, 220, 255, 150))
        frames.append(frame)
    return frames


# ─── R-12 预览大图 ─────────────────────────────────────────────────────────────────
def build_preview(out_dir: str) -> str:
    """拼接 idle/focus/sleep 三行帧 → preview.png。返回输出路径（不存在返 ""）。"""
    rows = []
    max_cols = 0
    for sub in ("idle", "focus", "sleep"):
        sub_dir = os.path.join(out_dir, sub)
        if not os.path.isdir(sub_dir):
            continue
        files = sorted(f for f in os.listdir(sub_dir) if f.lower().endswith(".png"))
        if not files:
            continue
        imgs = [Image.open(os.path.join(sub_dir, fn)).convert("RGBA") for fn in files]
        rows.append((sub, imgs))
        max_cols = max(max_cols, len(imgs))
    if not rows or max_cols == 0:
        return ""

    cell = SPRITE_SIZE
    label_w = 64
    canvas_w = label_w + cell * max_cols
    canvas_h = cell * len(rows)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (245, 245, 250, 255))
    draw = ImageDraw.Draw(canvas)
    for ri, (label, imgs) in enumerate(rows):
        y0 = ri * cell
        # 状态标签
        draw.rectangle([0, y0, label_w, y0 + cell], fill=(60, 70, 90, 255))
        draw.text((6, y0 + cell // 2 - 6), label.upper(), fill=(255, 255, 255, 255))
        # 帧拼接
        for ci, im in enumerate(imgs):
            canvas.paste(im, (label_w + ci * cell, y0), im)
        # 网格线
        for ci in range(len(imgs) + 1):
            x = label_w + ci * cell
            draw.line([(x, y0), (x, y0 + cell)], fill=(200, 205, 215, 200), width=1)
        draw.line([(0, y0 + cell - 1), (canvas_w, y0 + cell - 1)], fill=(200, 205, 215, 200), width=1)

    out_path = os.path.join(out_dir, "preview.png")
    canvas.save(out_path)
    return out_path


# ─── 输入校验 / 主流程 ─────────────────────────────────────────────────────────
def sanitize_name(name: str) -> str:
    """只允许字母、数字、下划线、中文，避免文件系统问题。"""
    name = name.strip()
    if not re.match(r"^[\w\u4e00-\u9fa5\-]+$", name):
        raise ValueError("角色名只能包含字母 / 数字 / 下划线 / 短横线 / 中文")
    if name in RESERVED_NAMES:
        raise ValueError("角色名 '%s' 是保留名，请换一个" % name)
    return name


def parse_args():
    p = argparse.ArgumentParser(description="修仙桌宠 - 角色制作脚本")
    p.add_argument("--source", "-s", help="源图片路径 (jpg/png)")
    p.add_argument("--name", "-n", help="角色名 (用作目录名)")
    p.add_argument("--force", "-f", action="store_true", help="覆盖已存在的角色")
    p.add_argument("--crop", "-c", choices=["upper", "full", "square"], default="upper",
                   help="裁剪模式: upper=上半身(默认) / full=全身 / square=居中正方形")
    p.add_argument("--sleep-pose", dest="sleep_pose",
                   choices=["drift", "sit"], default="drift",
                   help="睡眠姿势: drift=歪头漂浮(默认) / sit=盘腿打坐睡")
    p.add_argument("--state", choices=["idle", "focus", "sleep", "all"], default="all",
                   help="R-12: 只生成指定状态 (idle/focus/sleep)，默认 all 全量生成")
    p.add_argument("--no-preview", dest="no_preview", action="store_true",
                   help="R-12: 跳过 preview.png 拼接大图（默认会输出）")
    return p.parse_args()


def prompt_if_missing(args):
    if not args.source:
        args.source = input("源图片路径: ").strip().strip('"').strip("'")
    if not args.name:
        args.name = input("角色名 (例如: 道长): ").strip()
    return args


def main():
    args = prompt_if_missing(parse_args())

    if not args.source or not os.path.exists(args.source):
        print("[错误] 源图不存在: %s" % args.source)
        sys.exit(1)

    try:
        name = sanitize_name(args.name or "")
    except ValueError as e:
        print("[错误]", e)
        sys.exit(1)

    out_dir = os.path.join(CHARACTERS_DIR, name)
    state = getattr(args, "state", "all")
    is_partial = (state != "all")

    if os.path.exists(out_dir) and not args.force and not is_partial:
        ans = input("角色 '%s' 已存在，覆盖? [y/N]: " % name).strip().lower()
        if ans != "y":
            print("已取消。")
            sys.exit(0)
    elif is_partial and not os.path.exists(out_dir):
        print("[错误] 角色 '%s' 不存在，--state 单态替换需先全量生成。" % name)
        sys.exit(1)

    print("=" * 50)
    if is_partial:
        print("  修仙桌宠 · 角色单态替换: %s [%s]" % (name, state))
    else:
        print("  修仙桌宠 · 角色制作: %s" % name)
    print("=" * 50)

    print("[1/5] 加载源图: %s  (裁剪模式: %s)" % (args.source, args.crop))
    img = load_and_prepare(args.source, args.crop)
    print("      处理后尺寸: %dx%d" % img.size)

    print("[2/5] 像素化处理 ...")
    sprite = to_sprite(img)

    targets = ["idle", "focus", "sleep"] if state == "all" else [state]
    for sub in targets:
        os.makedirs(os.path.join(out_dir, sub), exist_ok=True)

    total_frames = 0
    if "idle" in targets:
        print("[3/5] 生成 idle (%d 帧) ..." % IDLE_FRAMES)
        for i, f in enumerate(generate_idle_frames(sprite)):
            f.save(os.path.join(out_dir, "idle", "%02d.png" % (i + 1)))
        total_frames += IDLE_FRAMES

    if "focus" in targets:
        print("[4/5] 生成 focus (%d 帧) ..." % FOCUS_FRAMES)
        for i, f in enumerate(generate_focus_frames(sprite)):
            f.save(os.path.join(out_dir, "focus", "%02d.png" % (i + 1)))
        total_frames += FOCUS_FRAMES

    if "sleep" in targets:
        sleep_gen = generate_sleep_sit_frames if args.sleep_pose == "sit" else generate_sleep_frames
        print("[5/5] 生成 sleep (%d 帧, 姿势=%s) ..." % (SLEEP_FRAMES, args.sleep_pose))
        for i, f in enumerate(sleep_gen(sprite)):
            f.save(os.path.join(out_dir, "sleep", "%02d.png" % (i + 1)))
        total_frames += SLEEP_FRAMES

    # R-12 拼接预览大图
    preview_path = ""
    if not getattr(args, "no_preview", False):
        preview_path = build_preview(out_dir)

    rel = os.path.relpath(out_dir, ROOT)
    print()
    print("=" * 50)
    if is_partial:
        print("  ✓ 单态替换完成! 状态=%s, 帧数=%d" % (state, total_frames))
    else:
        print("  ✓ 完成! 共 %d 帧" % total_frames)
    print("  输出目录: %s" % rel)
    if preview_path:
        print("  预览大图: %s" % os.path.relpath(preview_path, ROOT))
    print("=" * 50)
    print()
    if is_partial:
        print("下一步: 重启桌宠，在设置面板切到形象 '%s' 即可看到新的 %s 帧。" % (name, state))
    else:
        print("下一步:")
        print("  1. 双击 run.bat 启动桌宠")
        print("  2. 右键弹出修仙面板 → 点击「切换形象」按钮循环切换")
        print("     (新角色 '%s' 会自动出现在循环列表中)" % name)


if __name__ == "__main__":
    main()
