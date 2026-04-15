"""
生成两种箱子像素图：
  - loot_box_enemy.png  怪物死亡掉落箱（骨头/血迹风格，暗色破旧木箱）
  - loot_box_map.png    地图固定物资箱（军绿/金属箱，正规整洁）
每张 48x48 像素，RGBA 透明背景
"""
from PIL import Image, ImageDraw
import os

OUT = "d:/youxi/soudache/assets/sprites2"
os.makedirs(OUT, exist_ok=True)

def hex2rgba(h, a=255):
    h = h.lstrip('#')
    r,g,b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    return (r,g,b,a)

def draw_pixel(draw, x, y, color, size=1):
    draw.rectangle([x, y, x+size-1, y+size-1], fill=color)

# ─────────────────────────────────────────────
# 怪物死亡箱：破旧暗木箱，带血迹/裂缝/骨头装饰
# ─────────────────────────────────────────────
def make_enemy_box():
    img = Image.new("RGBA", (48, 48), (0,0,0,0))
    d = ImageDraw.Draw(img)
    
    # 箱体 - 暗棕色老木
    BOX_X, BOX_Y = 4, 8
    BOX_W, BOX_H = 40, 34
    
    # 阴影
    d.rectangle([BOX_X+3, BOX_Y+3, BOX_X+BOX_W+2, BOX_Y+BOX_H+2],
                fill=(20,10,5,120))
    
    # 主体暗木色
    dark_wood = hex2rgba('3d2010')
    mid_wood  = hex2rgba('5a3018')
    light_wood= hex2rgba('7a4822')
    
    d.rectangle([BOX_X, BOX_Y, BOX_X+BOX_W, BOX_Y+BOX_H], fill=dark_wood)
    
    # 木板纹路（水平线）
    for i in range(3):
        y = BOX_Y + 9 + i*10
        d.rectangle([BOX_X+1, y, BOX_X+BOX_W-1, y+1], fill=mid_wood)
    
    # 木板光泽
    d.rectangle([BOX_X+1, BOX_Y+1, BOX_X+BOX_W-1, BOX_Y+3], fill=light_wood)
    
    # 铁箍（横向金属带）
    iron_dark = hex2rgba('2a2a2a')
    iron_mid  = hex2rgba('444444')
    iron_hi   = hex2rgba('666666')
    
    # 上箍
    d.rectangle([BOX_X, BOX_Y+6, BOX_X+BOX_W, BOX_Y+9], fill=iron_dark)
    d.rectangle([BOX_X+1, BOX_Y+6, BOX_X+BOX_W-1, BOX_Y+7], fill=iron_hi)
    # 下箍
    d.rectangle([BOX_X, BOX_Y+BOX_H-9, BOX_X+BOX_W, BOX_Y+BOX_H-6], fill=iron_dark)
    d.rectangle([BOX_X+1, BOX_Y+BOX_H-9, BOX_X+BOX_W-1, BOX_Y+BOX_H-8], fill=iron_hi)
    
    # 裂缝
    crack = hex2rgba('1a0a00')
    # 右侧斜裂缝
    for px in range(5):
        d.point((BOX_X+BOX_W-8+px, BOX_Y+10+px), fill=crack)
        d.point((BOX_X+BOX_W-8+px, BOX_Y+11+px), fill=crack)
    # 左侧小裂缝
    for px in range(3):
        d.point((BOX_X+6+px, BOX_Y+20+px), fill=crack)
    
    # 锁扣（中间）
    lock_x = BOX_X + BOX_W//2 - 4
    lock_y = BOX_Y + BOX_H//2 - 4
    d.rectangle([lock_x, lock_y, lock_x+8, lock_y+8], fill=iron_dark)
    d.rectangle([lock_x+1, lock_y+1, lock_x+7, lock_y+7], fill=iron_mid)
    # 锁孔
    d.rectangle([lock_x+3, lock_y+3, lock_x+5, lock_y+5], fill=hex2rgba('111111'))
    
    # 血迹（暗红）
    blood = hex2rgba('6b0000', 180)
    d.ellipse([BOX_X+2, BOX_Y+BOX_H-8, BOX_X+8, BOX_Y+BOX_H-4], fill=blood)
    d.ellipse([BOX_X+BOX_W-10, BOX_Y+4, BOX_X+BOX_W-5, BOX_Y+8], fill=blood)
    # 血滴
    for dx, dy in [(BOX_X+4,BOX_Y+BOX_H-3),(BOX_X+6,BOX_Y+BOX_H-2)]:
        d.ellipse([dx-1,dy-1,dx+2,dy+2], fill=blood)
    
    # 边框
    outline = hex2rgba('1a0800')
    d.rectangle([BOX_X, BOX_Y, BOX_X+BOX_W, BOX_Y+BOX_H], outline=outline, width=1)
    
    # 骨头小图标（右上角装饰，两根交叉骨）
    bx, by = BOX_X+BOX_W-12, BOX_Y+1
    bone_color = hex2rgba('c8b89a')
    # 斜骨 \
    for i in range(7):
        d.point((bx+i, by+i), fill=bone_color)
        if i < 6: d.point((bx+i+1, by+i), fill=bone_color)
    # 骨头端点圆
    d.ellipse([bx-1,by-1,bx+2,by+2], fill=bone_color)
    d.ellipse([bx+5,by+5,bx+8,by+8], fill=bone_color)
    # 斜骨 /
    for i in range(7):
        d.point((bx+6-i, by+i), fill=bone_color)
    d.ellipse([bx+5,by-1,bx+8,by+2], fill=bone_color)
    d.ellipse([bx-1,by+5,bx+2,by+8], fill=bone_color)
    
    return img

# ─────────────────────────────────────────────
# 地图物资箱：军绿金属箱，整洁规整，黄色警戒条纹
# ─────────────────────────────────────────────
def make_map_box():
    img = Image.new("RGBA", (48, 48), (0,0,0,0))
    d = ImageDraw.Draw(img)
    
    BOX_X, BOX_Y = 4, 6
    BOX_W, BOX_H = 40, 36
    
    # 阴影
    d.rectangle([BOX_X+3, BOX_Y+3, BOX_X+BOX_W+2, BOX_Y+BOX_H+2],
                fill=(0,20,0,100))
    
    # 主体军绿
    army_dark  = hex2rgba('2d4a1e')
    army_mid   = hex2rgba('3d6428')
    army_light = hex2rgba('4e7a32')
    
    d.rectangle([BOX_X, BOX_Y, BOX_X+BOX_W, BOX_Y+BOX_H], fill=army_mid)
    
    # 金属面板质感（顶部亮边）
    d.rectangle([BOX_X+1, BOX_Y+1, BOX_X+BOX_W-1, BOX_Y+4], fill=army_light)
    # 侧面阴影
    d.rectangle([BOX_X+BOX_W-3, BOX_Y+1, BOX_X+BOX_W, BOX_Y+BOX_H], fill=army_dark)
    d.rectangle([BOX_X, BOX_Y+BOX_H-3, BOX_X+BOX_W, BOX_Y+BOX_H], fill=army_dark)
    
    # 黄黑警示条纹（中部斜纹带）
    warn_y = BOX_Y + BOX_H//2 - 4
    yellow = hex2rgba('e8c040')
    black  = hex2rgba('1a1a1a')
    stripe_w = 5
    d.rectangle([BOX_X, warn_y, BOX_X+BOX_W, warn_y+8], fill=black)
    # 斜条纹
    for sx in range(0, BOX_W+stripe_w*2, stripe_w*2):
        pts = [
            (BOX_X+sx,       warn_y),
            (BOX_X+sx+stripe_w, warn_y),
            (BOX_X+sx+stripe_w-8, warn_y+8),
            (BOX_X+sx-8,     warn_y+8),
        ]
        # 裁剪到箱体范围
        clipped = [(max(BOX_X, min(BOX_X+BOX_W, x)), y) for x,y in pts]
        if len(set(clipped)) >= 3:
            try:
                d.polygon(pts, fill=yellow)
            except:
                pass
    
    # 金属加固角
    corner = hex2rgba('888888')
    corner_hi = hex2rgba('bbbbbb')
    sz = 6
    for cx, cy in [(BOX_X, BOX_Y),(BOX_X+BOX_W-sz, BOX_Y),
                   (BOX_X, BOX_Y+BOX_H-sz),(BOX_X+BOX_W-sz, BOX_Y+BOX_H-sz)]:
        d.rectangle([cx,cy,cx+sz,cy+sz], fill=corner)
        d.rectangle([cx+1,cy+1,cx+sz-1,cy+sz-1], fill=corner_hi)
    
    # 中央锁（圆形）
    lx = BOX_X + BOX_W//2
    ly = BOX_Y + 3
    d.ellipse([lx-7, ly, lx+7, ly+10], fill=hex2rgba('555555'))
    d.ellipse([lx-5, ly+1, lx+5, ly+8], fill=hex2rgba('888888'))
    d.ellipse([lx-2, ly+3, lx+2, ly+6], fill=hex2rgba('222222'))
    
    # 铆钉（四角）
    rivet = hex2rgba('999999')
    rivet_hi = hex2rgba('cccccc')
    for rx, ry in [(BOX_X+8,BOX_Y+2),(BOX_X+BOX_W-8,BOX_Y+2),
                   (BOX_X+8,BOX_Y+BOX_H-2),(BOX_X+BOX_W-8,BOX_Y+BOX_H-2)]:
        d.ellipse([rx-3,ry-3,rx+3,ry+3], fill=rivet)
        d.ellipse([rx-1,ry-1,rx+1,ry+1], fill=rivet_hi)
    
    # 文字标识（SUPPLY 缩写，像素点阵 S）
    px_color = hex2rgba('c8e060')
    # 小像素字 "S" 在左上
    s_pixels = [
        (1,0),(2,0),(3,0),
        (0,1),
        (1,2),(2,2),
        (3,3),
        (0,4),(1,4),(2,4),
    ]
    bx2, by2 = BOX_X+4, BOX_Y+14
    for sx,sy in s_pixels:
        d.rectangle([bx2+sx*2, by2+sy*2, bx2+sx*2+1, by2+sy*2+1], fill=px_color)
    
    # 边框
    d.rectangle([BOX_X, BOX_Y, BOX_X+BOX_W, BOX_Y+BOX_H],
                outline=hex2rgba('1a2a10'), width=1)
    
    return img

# ─────────────────────────────────────────────
# 生成并保存
# ─────────────────────────────────────────────
enemy_box = make_enemy_box()
enemy_box.save(f"{OUT}/loot_box_enemy.png")
print("OK enemy box")

map_box = make_map_box()
map_box.save(f"{OUT}/loot_box_map.png")
print("OK map box")

import shutil
shutil.copy(f"{OUT}/loot_box_enemy.png", "d:/youxi/soudache/assets/ink/loot_box_enemy.png")
shutil.copy(f"{OUT}/loot_box_map.png",   "d:/youxi/soudache/assets/ink/loot_box_map.png")
print("OK copied to ink/")
