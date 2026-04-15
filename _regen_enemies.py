"""
重新生成更自然的恐龙精灵（48x48每帧，192x144精灵表）
行0=idle(呼吸)，行1=walk(移动)，行2=attack(攻击)
"""
from PIL import Image, ImageDraw
import os

OUT = r"d:\youxi\soudache\assets\sprites2"
os.makedirs(OUT, exist_ok=True)


def make_sheet(filename, colors):
    """生成一张 192x144 精灵表（4列x3行，每格48x48）"""
    img = Image.new("RGBA", (192, 144), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    frames = [
        draw_idle(colors),
        draw_walk(colors),
        draw_attack(colors),
    ]
    for row, frame_data in enumerate(frames):
        for col, cell in enumerate(frame_data):
            x0 = col * 48
            y0 = row * 48
            for shape in cell:
                shape(draw, x0, y0)

    img.save(filename)
    # 验证
    px = img.load()
    non_trans = sum(1 for x in range(192) for y in range(144) if px[x,y][3] > 10)
    px_samp = [(px[x,y][0],px[x,y][1],px[x,y][2])
               for x in range(0,192,4) for y in range(0,144,4) if px[x,y][3]>10]
    if px_samp:
        avg = tuple(sum(c[i] for c in px_samp)//len(px_samp) for i in range(3))
        print(f"Saved: {filename}  non-transparent={non_trans}  avg={avg}")
    else:
        print(f"Saved: {filename}  non-transparent={non_trans}  ALL TRANSPARENT!")


def draw_idle(c):
    """Idle: 身体轻微上下抖动（腿不动）"""
    idle1 = [
        # 身体
        lambda d, x, y: d.ellipse([x+10, y+12, x+38, y+32], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 头
        lambda d, x, y: d.ellipse([x+28, y+8, x+44, y+22], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 眼睛
        lambda d, x, y: d.ellipse([x+36, y+12, x+40, y+16], fill=(c["eye_r"], c["eye_g"], c["eye_b"], 255)),
        # 腿（静止）
        lambda d, x, y: d.rectangle([x+14, y+30, x+20, y+40], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
        lambda d, x, y: d.rectangle([x+28, y+30, x+34, y+40], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
    ]
    idle2 = [
        lambda d, x, y: d.ellipse([x+10, y+11, x+38, y+31], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        lambda d, x, y: d.ellipse([x+28, y+7, x+44, y+21], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        lambda d, x, y: d.ellipse([x+36, y+11, x+40, y+15], fill=(c["eye_r"], c["eye_g"], c["eye_b"], 255)),
        lambda d, x, y: d.rectangle([x+14, y+29, x+20, y+39], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
        lambda d, x, y: d.rectangle([x+28, y+29, x+34, y+39], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
    ]
    idle3 = idle1  # 对称
    idle4 = idle2
    return [idle1, idle2, idle3, idle4]


def draw_walk(c):
    """Walk: 腿部交替，摆臂"""
    w1 = [
        # 身体
        lambda d, x, y: d.ellipse([x+10, y+12, x+38, y+32], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 头（稍微前倾）
        lambda d, x, y: d.ellipse([x+26, y+8, x+42, y+22], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 眼睛
        lambda d, x, y: d.ellipse([x+34, y+12, x+38, y+16], fill=(c["eye_r"], c["eye_g"], c["eye_b"], 255)),
        # 左腿伸出
        lambda d, x, y: d.ellipse([x+6, y+28, x+18, y+42], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
        # 右腿收回
        lambda d, x, y: d.rectangle([x+30, y+30, x+36, y+38], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
    ]
    w2 = [
        lambda d, x, y: d.ellipse([x+10, y+12, x+38, y+32], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        lambda d, x, y: d.ellipse([x+26, y+8, x+42, y+22], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        lambda d, x, y: d.ellipse([x+34, y+12, x+38, y+16], fill=(c["eye_r"], c["eye_g"], c["eye_b"], 255)),
        # 交替：左腿收，右腿伸
        lambda d, x, y: d.rectangle([x+12, y+30, x+18, y+38], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
        lambda d, x, y: d.ellipse([x+30, y+28, x+42, y+42], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
    ]
    w3 = w1
    w4 = w2
    return [w1, w2, w3, w4]


def draw_attack(c):
    """Attack: 身体猛冲，嘴巴张开"""
    atk1 = [
        # 身体（往前冲）
        lambda d, x, y: d.ellipse([x+6, y+12, x+34, y+32], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 头（猛咬）
        lambda d, x, y: d.ellipse([x+20, y+6, x+46, y+22], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 眼睛（凶）
        lambda d, x, y: d.ellipse([x+38, y+10, x+42, y+14], fill=(c["eye_r"], c["eye_g"], c["eye_b"], 255)),
        # 嘴（张开红色）
        lambda d, x, y: d.ellipse([x+40, y+16, x+46, y+22], fill=(c["mouth_r"], c["mouth_g"], c["mouth_b"], 255)),
        # 腿（发力）
        lambda d, x, y: d.ellipse([x+4, y+28, x+14, y+42], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
        lambda d, x, y: d.ellipse([x+28, y+26, x+38, y+40], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
    ]
    atk2 = [
        # 身体（收回）
        lambda d, x, y: d.ellipse([x+8, y+12, x+36, y+32], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 头
        lambda d, x, y: d.ellipse([x+22, y+7, x+46, y+21], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        # 眼睛
        lambda d, x, y: d.ellipse([x+38, y+10, x+42, y+14], fill=(c["eye_r"], c["eye_g"], c["eye_b"], 255)),
        # 嘴闭合
        lambda d, x, y: d.ellipse([x+40, y+16, x+46, y+21], fill=(c["body_r"], c["body_g"], c["body_b"], 255)),
        lambda d, x, y: d.ellipse([x+4, y+28, x+14, y+40], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
        lambda d, x, y: d.ellipse([x+30, y+28, x+40, y+42], fill=(c["leg_r"], c["leg_g"], c["leg_b"], 255)),
    ]
    atk3 = atk1
    atk4 = atk2
    return [atk1, atk2, atk3, atk4]


# ====== 生成 ======

# 迅猛龙：中型，棕红色
VELOCIRAPTOR = dict(
    body_r=155, body_g=78, body_b=48,   # 棕红身体
    eye_r=180, eye_g=20, eye_b=20,      # 红眼
    leg_r=120, leg_g=65, leg_b=38,      # 深棕腿
    mouth_r=200, mouth_g=40, mouth_b=30, # 深红口腔
)
make_sheet(f"{OUT}/enemy_velociraptor_sheet.png", VELOCIRAPTOR)

# 霸王龙：大型，棕橙色
TREX = dict(
    body_r=140, body_g=85, body_b=50,
    eye_r=200, eye_g=30, eye_b=10,
    leg_r=110, leg_g=68, leg_b=40,
    mouth_r=220, mouth_g=50, mouth_b=30,
)
make_sheet(f"{OUT}/enemy_trex_sheet.png", TREX)

# 三角龙：矮胖，棕绿色
TRICERATOPS = dict(
    body_r=100, body_g=95, body_b=65,
    eye_r=100, eye_g=100, eye_b=60,
    leg_r=80, leg_g=75, leg_b=50,
    mouth_r=180, mouth_g=140, mouth_b=80,
)
make_sheet(f"{OUT}/enemy_triceratops_sheet.png", TRICERATOPS)

print("Enemy sprites regenerated!")
