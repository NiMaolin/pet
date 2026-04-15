"""
生成俯视角像素风精灵表
每张精灵表: 4列(帧) x 3行(idle/walk/attack) = 12帧
每帧: 48x48 像素
输出到 d:/youxi/soudache/assets/sprites2/
"""
from PIL import Image, ImageDraw
import os, math

OUT = "d:/youxi/soudache/assets/sprites2"
os.makedirs(OUT, exist_ok=True)

FRAME_W, FRAME_H = 48, 48
COLS = 4  # 每行4帧
ROWS = 3  # idle / walk / attack

def new_sheet():
    img = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS), (0, 0, 0, 0))
    return img

def draw_frame(draw, fx, fy, draw_fn, frame_idx):
    """在精灵表的 (fx列, fy行) 位置绘制一帧"""
    ox = fx * FRAME_W
    oy = fy * FRAME_H
    draw_fn(draw, ox, oy, frame_idx)

# ─────────────────────────────────────────────
# 工具函数
# ─────────────────────────────────────────────

def rect(draw, ox, oy, x, y, w, h, color):
    draw.rectangle([ox+x, oy+y, ox+x+w-1, oy+y+h-1], fill=color)

def circle(draw, ox, oy, cx, cy, r, color):
    draw.ellipse([ox+cx-r, oy+cy-r, ox+cx+r, oy+cy+r], fill=color)

# ─────────────────────────────────────────────
# 玩家 (探险家 - 俯视角小人)
# 颜色: 皮肤#F4C08A 衣服#3A7BD5 头发#5C3A1E 裤#1A3A6B 靴#4A2800
# ─────────────────────────────────────────────

SKIN   = (244, 192, 138, 255)
SHIRT  = ( 58, 123, 213, 255)
HAIR   = ( 92,  58,  30, 255)
PANTS  = ( 26,  58, 107, 255)
BOOTS  = ( 74,  40,   0, 255)
WEAPON = (200, 200, 210, 255)
OUTLINE= ( 30,  20,  10, 255)

def draw_player_idle(draw, ox, oy, frame):
    """静止：4帧轻微呼吸"""
    bob = [0, -1, 0, 1][frame]  # 上下微动
    b = bob
    # 靴子
    rect(draw, ox, oy, 17, 38+b, 6, 8, BOOTS)
    rect(draw, ox, oy, 25, 38+b, 6, 8, BOOTS)
    # 裤子
    rect(draw, ox, oy, 17, 30+b, 6, 9, PANTS)
    rect(draw, ox, oy, 25, 30+b, 6, 9, PANTS)
    # 身体/衬衫
    rect(draw, ox, oy, 15, 20+b, 18, 12, SHIRT)
    # 手臂
    rect(draw, ox, oy, 10, 21+b, 5, 10, SKIN)
    rect(draw, ox, oy, 33, 21+b, 5, 10, SKIN)
    # 头
    rect(draw, ox, oy, 16, 8+b, 16, 14, SKIN)
    # 头发
    rect(draw, ox, oy, 16, 8+b, 16, 5, HAIR)
    rect(draw, ox, oy, 16, 8+b, 3, 14, HAIR)
    # 眼睛
    rect(draw, ox, oy, 20, 14+b, 3, 3, OUTLINE)
    rect(draw, ox, oy, 25, 14+b, 3, 3, OUTLINE)
    # 武器(小刀)
    rect(draw, ox, oy, 35, 22+b, 3, 14, WEAPON)

def draw_player_walk(draw, ox, oy, frame):
    """行走：4帧腿部交替"""
    leg_offsets = [(0, 4), (3, 0), (0, -2), (-3, 0)]  # 左腿, 右腿的y偏移
    lo = leg_offsets[frame]
    arm_swing = [2, -1, -2, 1][frame]
    # 靴子
    rect(draw, ox, oy, 17, 36+lo[0], 6, 8, BOOTS)
    rect(draw, ox, oy, 25, 36+lo[1], 6, 8, BOOTS)
    # 裤子
    rect(draw, ox, oy, 17, 28+lo[0], 6, 9, PANTS)
    rect(draw, ox, oy, 25, 28+lo[1], 6, 9, PANTS)
    # 身体
    rect(draw, ox, oy, 15, 19, 18, 12, SHIRT)
    # 手臂摆动
    rect(draw, ox, oy, 10, 20+arm_swing, 5, 10, SKIN)
    rect(draw, ox, oy, 33, 20-arm_swing, 5, 10, SKIN)
    # 头
    rect(draw, ox, oy, 16, 7, 16, 14, SKIN)
    rect(draw, ox, oy, 16, 7, 16, 5, HAIR)
    rect(draw, ox, oy, 16, 7, 3, 14, HAIR)
    rect(draw, ox, oy, 20, 13, 3, 3, OUTLINE)
    rect(draw, ox, oy, 25, 13, 3, 3, OUTLINE)
    # 武器
    rect(draw, ox, oy, 35, 20-arm_swing, 3, 14, WEAPON)

def draw_player_attack(draw, ox, oy, frame):
    """攻击：挥砍动作"""
    poses = [
        # (arm_x, arm_y, weapon_angle_hint, head_tilt)
        (33, 18, 0, 0),
        (36, 14, -10, -1),
        (38, 10, -20, -1),
        (34, 20, 5, 0),
    ]
    ax, ay, _, _ = poses[frame]
    # 腿
    rect(draw, ox, oy, 17, 36, 6, 8, BOOTS)
    rect(draw, ox, oy, 25, 36, 6, 8, BOOTS)
    rect(draw, ox, oy, 17, 28, 6, 9, PANTS)
    rect(draw, ox, oy, 25, 28, 6, 9, PANTS)
    # 身体
    rect(draw, ox, oy, 15, 19, 18, 12, SHIRT)
    # 挥砍手臂
    rect(draw, ox, oy, 10, 22, 5, 10, SKIN)  # 左臂不动
    rect(draw, ox, oy, ax, ay, 5, 10, SKIN)  # 右臂大幅挥动
    # 头
    rect(draw, ox, oy, 16, 7, 16, 14, SKIN)
    rect(draw, ox, oy, 16, 7, 16, 5, HAIR)
    rect(draw, ox, oy, 16, 7, 3, 14, HAIR)
    rect(draw, ox, oy, 20, 13, 3, 3, OUTLINE)
    rect(draw, ox, oy, 25, 13, 3, 3, OUTLINE)
    # 武器 - 随手臂移动
    sword_x = ax + 3
    sword_y = ay - 12 + frame * 3
    rect(draw, ox, oy, max(0, min(44, sword_x)), max(0, min(40, sword_y)), 4, 18, WEAPON)
    # 攻击特效
    if frame in [1, 2]:
        eff_color = (255, 240, 100, 180)
        for i in range(3):
            ex = ox + ax + 8 + i*4
            ey = oy + ay - 4 - i*3
            if 0 < ex < ox+48 and 0 < ey < oy+48:
                draw.ellipse([ex-2, ey-2, ex+2, ey+2], fill=eff_color)

# ─────────────────────────────────────────────
# 迅猛龙 (velociraptor) - 小型快速
# 颜色: 体#5A8F4A 斑纹#3A5F2A 爪#C8A050 眼#FF4400
# ─────────────────────────────────────────────

VEL_BODY  = ( 90, 143,  74, 255)
VEL_DARK  = ( 58,  95,  42, 255)
VEL_CLAW  = (200, 160,  80, 255)
VEL_EYE   = (255,  68,   0, 255)

def draw_velociraptor(draw, ox, oy, anim, frame):
    bob = [0,-1,0,1][frame] if anim == 0 else 0
    leg_anim = [0,3,-2,-3][frame] if anim == 1 else 0
    
    # 尾巴
    rect(draw, ox, oy, 5, 22+bob, 10, 6, VEL_BODY)
    rect(draw, ox, oy, 3, 24+bob, 6, 4, VEL_DARK)
    # 身体
    rect(draw, ox, oy, 13, 18+bob, 20, 14, VEL_BODY)
    rect(draw, ox, oy, 15, 20+bob, 6, 5, VEL_DARK)
    # 前腿
    rect(draw, ox, oy, 13, 30+bob+leg_anim, 5, 10, VEL_BODY)
    rect(draw, ox, oy, 26, 30+bob-leg_anim, 5, 10, VEL_BODY)
    # 爪子
    rect(draw, ox, oy, 12, 38+bob, 6, 3, VEL_CLAW)
    rect(draw, ox, oy, 25, 38+bob, 6, 3, VEL_CLAW)
    # 脖子
    rect(draw, ox, oy, 28, 12+bob, 8, 10, VEL_BODY)
    # 头
    rect(draw, ox, oy, 30, 6+bob, 14, 10, VEL_BODY)
    # 嘴
    rect(draw, ox, oy, 40, 10+bob, 6, 3, VEL_DARK)
    if anim == 2 and frame >= 1:  # 攻击张嘴
        rect(draw, ox, oy, 40, 8+bob, 6, 6, VEL_DARK)
    # 眼睛
    rect(draw, ox, oy, 36, 8+bob, 4, 4, VEL_EYE)

def draw_velociraptor_idle(draw, ox, oy, frame):
    draw_velociraptor(draw, ox, oy, 0, frame)

def draw_velociraptor_walk(draw, ox, oy, frame):
    draw_velociraptor(draw, ox, oy, 1, frame)

def draw_velociraptor_attack(draw, ox, oy, frame):
    draw_velociraptor(draw, ox, oy, 2, frame)
    if frame in [1, 2]:
        for i in range(4):
            draw.ellipse([ox+44-i, oy+8+i*2, ox+46-i, oy+10+i*2], fill=(255,100,0,200))

# ─────────────────────────────────────────────
# 霸王龙 (trex) - 大型
# 颜色: 深绿灰 #4A6050
# ─────────────────────────────────────────────

TREX_BODY = ( 74,  96,  80, 255)
TREX_DARK = ( 50,  70,  55, 255)
TREX_BELLY= (140, 160, 130, 255)
TREX_EYE  = (255, 200,   0, 255)

def draw_trex(draw, ox, oy, anim, frame):
    bob = [0,-1,0,1][frame] if anim == 0 else 0
    leg = [0,4,-2,-4][frame] if anim == 1 else 0
    roar = frame >= 2 if anim == 2 else False
    
    # 尾巴(粗)
    rect(draw, ox, oy, 2, 24+bob, 14, 9, TREX_BODY)
    rect(draw, ox, oy, 2, 26+bob, 8, 5, TREX_DARK)
    # 身体(大)
    rect(draw, ox, oy, 12, 16+bob, 22, 18, TREX_BODY)
    rect(draw, ox, oy, 14, 24+bob, 18, 8, TREX_BELLY)
    # 纹路
    for i in range(3):
        rect(draw, ox, oy, 16+i*5, 18+bob, 3, 6, TREX_DARK)
    # 短前臂
    rect(draw, ox, oy, 32, 22+bob, 4, 7, TREX_BODY)
    rect(draw, ox, oy, 33, 28+bob, 3, 2, TREX_DARK)
    # 后腿(大)
    rect(draw, ox, oy, 14, 32+bob+leg, 7, 12, TREX_BODY)
    rect(draw, ox, oy, 24, 32+bob-leg, 7, 12, TREX_BODY)
    rect(draw, ox, oy, 13, 42+bob, 8, 4, TREX_DARK)
    rect(draw, ox, oy, 23, 42+bob, 8, 4, TREX_DARK)
    # 脖子
    rect(draw, ox, oy, 30, 10+bob, 10, 10, TREX_BODY)
    # 头(大)
    rect(draw, ox, oy, 28, 3+bob, 18, 12, TREX_BODY)
    # 嘴/牙
    jaw_open = 4 if roar else 0
    rect(draw, ox, oy, 38, 10+bob, 8, 3+jaw_open, TREX_DARK)
    rect(draw, ox, oy, 39, 10+bob, 2, 2, (240,240,220,255))  # 牙
    rect(draw, ox, oy, 43, 10+bob, 2, 2, (240,240,220,255))
    # 眼
    rect(draw, ox, oy, 32, 6+bob, 5, 5, TREX_EYE)
    rect(draw, ox, oy, 33, 7+bob, 3, 3, (0,0,0,255))

def draw_trex_idle(draw, ox, oy, frame):
    draw_trex(draw, ox, oy, 0, frame)

def draw_trex_walk(draw, ox, oy, frame):
    draw_trex(draw, ox, oy, 1, frame)

def draw_trex_attack(draw, ox, oy, frame):
    draw_trex(draw, ox, oy, 2, frame)

# ─────────────────────────────────────────────
# 三角龙 (triceratops) - 重型坦克
# ─────────────────────────────────────────────

TRI_BODY  = ( 80, 110, 140, 255)
TRI_DARK  = ( 55,  80, 105, 255)
TRI_FRILL = (160,  60,  60, 255)
TRI_HORN  = (220, 200, 160, 255)
TRI_EYE   = (255, 240,   0, 255)

def draw_triceratops(draw, ox, oy, anim, frame):
    bob = [0,-1,0,1][frame] if anim == 0 else 0
    leg = [0,3,-1,-3][frame] if anim == 1 else 0
    charge = frame * 3 if anim == 2 else 0
    
    # 尾巴
    rect(draw, ox, oy, 2, 24+bob, 12, 8, TRI_BODY)
    # 身体(矮胖)
    rect(draw, ox, oy, 10, 18+bob, 28, 20, TRI_BODY)
    rect(draw, ox, oy, 12, 24+bob, 24, 10, (100, 135, 165, 255))  # 肚皮
    # 装甲纹
    for i in range(4):
        rect(draw, ox, oy, 12+i*6, 19+bob, 4, 8, TRI_DARK)
    # 四条腿
    rect(draw, ox, oy, 12, 36+bob+leg, 6, 9, TRI_BODY)
    rect(draw, ox, oy, 20, 36+bob-leg, 6, 9, TRI_BODY)
    rect(draw, ox, oy, 28, 36+bob+leg, 6, 9, TRI_BODY)
    rect(draw, ox, oy, 34, 36+bob-leg, 5, 9, TRI_BODY)
    # 头盾(大)
    frill_y = 4+bob-charge//2
    rect(draw, ox, oy, 35-charge, frill_y, 14, 16, TRI_FRILL)
    # 嘴部
    rect(draw, ox, oy, 36-charge, 16+bob, 12, 8, TRI_BODY)
    # 三只角
    rect(draw, ox, oy, 44-charge, 6+bob, 4, 10, TRI_HORN)  # 鼻角
    rect(draw, ox, oy, 40-charge, 4+bob, 3, 8, TRI_HORN)   # 左角
    rect(draw, ox, oy, 48-charge, 4+bob, 3, 8, TRI_HORN)   # 右角
    # 眼
    rect(draw, ox, oy, 38-charge, 10+bob, 4, 4, TRI_EYE)
    rect(draw, ox, oy, 39-charge, 11+bob, 2, 2, (0,0,0,255))

def draw_triceratops_idle(draw, ox, oy, frame):
    draw_triceratops(draw, ox, oy, 0, frame)

def draw_triceratops_walk(draw, ox, oy, frame):
    draw_triceratops(draw, ox, oy, 1, frame)

def draw_triceratops_attack(draw, ox, oy, frame):
    draw_triceratops(draw, ox, oy, 2, frame)

# ─────────────────────────────────────────────
# 生成精灵表
# ─────────────────────────────────────────────

def make_spritesheet(name, row_fns):
    """row_fns: [idle_fn, walk_fn, attack_fn]"""
    sheet = new_sheet()
    draw = ImageDraw.Draw(sheet)
    for row_idx, fn in enumerate(row_fns):
        for col_idx in range(COLS):
            fn(draw, col_idx * FRAME_W, row_idx * FRAME_H, col_idx)
    path = f"{OUT}/{name}_sheet.png"
    sheet.save(path)
    print(f"  生成: {path}  ({sheet.width}x{sheet.height})")
    return path

print("=== 生成像素风精灵表 ===")
make_spritesheet("player", [draw_player_idle, draw_player_walk, draw_player_attack])
make_spritesheet("enemy_velociraptor", [draw_velociraptor_idle, draw_velociraptor_walk, draw_velociraptor_attack])
make_spritesheet("enemy_trex", [draw_trex_idle, draw_trex_walk, draw_trex_attack])
make_spritesheet("enemy_triceratops", [draw_triceratops_idle, draw_triceratops_walk, draw_triceratops_attack])
print("=== 完成 ===")
