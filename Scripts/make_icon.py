#!/usr/bin/env python3
"""生成 App 图标 (Resources/AppIcon.png, 1024x1024)。

纯标准库实现：用有向距离场 (SDF) 做抗锯齿，再用 zlib 手写 PNG，
不依赖 Pillow 等第三方库，任何装了 Python 3 的机器都能跑。

用法: python3 Scripts/make_icon.py
"""

import math
import os
import struct
import zlib

SIZE = 1024
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Resources", "AppIcon.png")

# 主题色：薄荷绿 -> 湖蓝
TOP = (0x3C, 0xDD, 0xAA)
BOTTOM = (0x2A, 0x86, 0xC8)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else (hi if v > hi else v)


def sd_rounded_rect(px, py, cx, cy, half_w, half_h, radius):
    qx = abs(px - cx) - (half_w - radius)
    qy = abs(py - cy) - (half_h - radius)
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - radius


def sd_circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r


def sd_capsule(px, py, ax, ay, bx, by, r):
    pax, pay = px - ax, py - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    h = clamp((pax * bax + pay * bay) / denom) if denom else 0.0
    return math.hypot(pax - bax * h, pay - bay * h) - r


def coverage(d):
    """把距离转换成 0~1 的覆盖率，实现 1px 宽的柔和边缘。"""
    return clamp(0.5 - d)


def blend(dst, src, alpha):
    return tuple(int(round(dst[i] + (src[i] - dst[i]) * alpha)) for i in range(3))


def build_pixels():
    half = SIZE / 2.0
    # 图标本体略小于画布，四周留白，符合 macOS 图标网格
    body_half = SIZE * 0.44
    body_radius = SIZE * 0.225

    # 人形：抬头挺胸、双臂上举伸展。整体按 SCALE 缩小，四周留出安全边距
    scale = 0.86

    def s(*values):
        """把一组 (x, y, ...) 坐标按中心缩放，末位半径同步缩放。"""
        out = []
        for i, v in enumerate(values[:-1]):
            center = 512.0 if i % 2 == 0 else 512.0
            out.append(center + (v - center) * scale)
        out.append(values[-1] * scale)
        return tuple(out)

    head = s(512.0, 268.0, 84.0)
    torso = s(512.0, 380.0, 512.0, 596.0, 54.0)
    arm_l = s(500.0, 418.0, 336.0, 246.0, 40.0)
    arm_r = s(524.0, 418.0, 688.0, 246.0, 40.0)
    leg_l = s(508.0, 588.0, 404.0, 800.0, 42.0)
    leg_r = s(516.0, 588.0, 620.0, 800.0, 42.0)

    rows = []
    for y in range(SIZE):
        row = bytearray()
        fy = y + 0.5
        # 背景渐变（沿左上 -> 右下方向）
        for x in range(SIZE):
            fx = x + 0.5

            d_body = sd_rounded_rect(fx, fy, half, half, body_half, body_half, body_radius)
            a_body = coverage(d_body)
            if a_body <= 0.0:
                row += b"\x00\x00\x00\x00"
                continue

            t = clamp((fx * 0.35 + fy * 0.65) / SIZE)
            base = tuple(int(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t)) for i in range(3))

            # 左上角一层很淡的高光，让平面色不那么呆板
            gloss = clamp(1.0 - math.hypot(fx - SIZE * 0.28, fy - SIZE * 0.22) / (SIZE * 0.62))
            color = blend(base, (255, 255, 255), gloss * 0.14)

            # 人形（白色）
            d_fig = min(
                sd_circle(fx, fy, *head),
                sd_capsule(fx, fy, *torso),
                sd_capsule(fx, fy, *arm_l),
                sd_capsule(fx, fy, *arm_r),
                sd_capsule(fx, fy, *leg_l),
                sd_capsule(fx, fy, *leg_r),
            )
            a_fig = coverage(d_fig)
            if a_fig > 0.0:
                color = blend(color, (255, 255, 255), a_fig)

            alpha = int(round(a_body * 255))
            row += bytes((color[0], color[1], color[2], alpha))
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        payload = tag + data
        return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    write_png(OUT, build_pixels())
    print("已生成", OUT)
