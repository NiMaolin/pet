#!/usr/bin/env python3
"""生成水墨风格游戏贴图"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# 输出目录
OUT_DIR = r"D:\youxi\soudache\assets\ink"
os.makedirs(OUT_DIR, exist_ok=True)

CELL = 40  # 格子大小
SCALE = 2  # 放大倍数

def ink_effect(img: Image.Image) -> Image.Image:
    """水墨效果"""
    # 转灰度
    gray = img.convert("L")
    # 反色（墨色）
    inverted = Image.eval(gray, lambda x: 255 - x)
    # 模糊边缘
    inverted = inverted.filter(ImageFilter.GaussianBlur(radius=1))
    # 增强对比
    enhancer = ImageEnhance.Contrast(inverted)
    result = enhancer.enhance(2.5)
    # 转回RGB加一点茶色
    result = result.convert("RGB")
    # 添加茶色色调
    datas = result.getdata()
    new_data = []
    for r, g, b in datas:
        new_data.append((int(r * 0.9), int(g * 0.85), int(b * 0.7)))
    result.putdata(new_data)
    return result

def add_ink_border(img: Image.Image, color=(30, 20, 10)) -> Image.Image:
    """添加墨线边框"""
    draw = ImageDraw.Draw(img)
    w, h = img.size
    # 随机墨迹边框
    for i in range(3):
        x = (i * 2) % w
        draw.line([(x, 0), (x + 3, h)], fill=color, width=1)
    return img

def create_player_sprite() -> Image.Image:
    """创建水墨风格玩家（恐龙猎人）"""
    size = (CELL * SCALE, CELL * SCALE)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = size[0] // 2
    
    # 身体轮廓（水墨风）
    # 头
    draw.ellipse([c-12, c-18, c+12, c+2], fill=(40, 35, 25), outline=(20, 15, 5))
    # 身体
    draw.ellipse([c-14, c-5, c+14, c+18], fill=(50, 42, 30), outline=(20, 15, 5))
    # 武器（砍刀）
    draw.line([c+10, c-5, c+22, c+15], fill=(80, 70, 60), width=3)
    draw.line([c+10, c-5, c+22, c+15], fill=(30, 25, 15), width=1)
    # 腿部
    draw.line([c-6, c+18, c-8, c+30], fill=(40, 32, 20), width=3)
    draw.line([c+6, c+18, c+8, c+30], fill=(40, 32, 20), width=3)
    
    # 墨迹效果
    img = ink_effect(img)
    return img

def create_enemy_sprite(enemy_type: str) -> Image.Image:
    """创建水墨风格敌人"""
    size = (CELL * SCALE, CELL * SCALE)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = size[0] // 2
    
    colors = {
        "velociraptor": ((60, 50, 35), (25, 18, 8)),    # 棕褐/深棕
        "trex": ((50, 40, 30), (20, 12, 5)),           # 深褐
        "triceratops": ((55, 48, 38), (22, 16, 8)),    # 灰褐
        "default": ((48, 40, 32), (18, 12, 5)),
    }
    fill_c, outline_c = colors.get(enemy_type, colors["default"])
    
    if enemy_type == "velociraptor":
        # 速龙 - 瘦长
        draw.ellipse([c-10, c-15, c+10, c+8], fill=fill_c, outline=outline_c)  # 头
        draw.ellipse([c-12, c-3, c+12, c+18], fill=fill_c, outline=outline_c)  # 身体
        draw.line([c+8, c+5, c+20, c+12], fill=fill_c, width=2)  # 尾巴
        draw.line([c-5, c+18, c-6, c+30], fill=fill_c, width=2)  # 腿
        draw.line([c+5, c+18, c+6, c+30], fill=fill_c, width=2)
    elif enemy_type == "trex":
        # 霸王龙 - 大头短臂
        draw.ellipse([c-15, c-20, c+15, c+5], fill=fill_c, outline=outline_c)  # 大头
        draw.ellipse([c-12, c, c+12, c+20], fill=fill_c, outline=outline_c)  # 身体
        draw.line([c-5, c+20, c-6, c+32], fill=fill_c, width=4)  # 粗腿
        draw.line([c+5, c+20, c+6, c+32], fill=fill_c, width=4)
        # 牙齿
        draw.line([c-8, c-20, c-6, c-16], fill=(220, 220, 200), width=1)
        draw.line([c+2, c-20, c+4, c-16], fill=(220, 220, 200), width=1)
    elif enemy_type == "triceratops":
        # 三角龙 - 三根角
        draw.ellipse([c-12, c-10, c+12, c+12], fill=fill_c, outline=outline_c)  # 头
        draw.ellipse([c-10, c+5, c+10, c+22], fill=fill_c, outline=outline_c)  # 身体
        draw.line([c-8, c-10, c-15, c-25], fill=fill_c, width=3)  # 角1
        draw.line([c+0, c-10, c+0, c-28], fill=fill_c, width=3)  # 角2
        draw.line([c+8, c-10, c+15, c-25], fill=fill_c, width=3)  # 角3
        draw.line([c-5, c+22, c-6, c+34], fill=fill_c, width=3)  # 腿
        draw.line([c+5, c+22, c+6, c+34], fill=fill_c, width=3)
    else:
        # 默认
        draw.ellipse([c-14, c-14, c+14, c+14], fill=fill_c, outline=outline_c)
        draw.line([c-5, c+14, c-6, c+30], fill=fill_c, width=3)
        draw.line([c+5, c+14, c+6, c+30], fill=fill_c, width=3)
    
    img = ink_effect(img)
    return img

def create_loot_spot_sprite(level: int) -> Image.Image:
    """创建水墨风格物资箱"""
    size = (CELL * SCALE, CELL * SCALE)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    colors = {
        1: ((100, 95, 85), (60, 55, 45)),   # 灰色
        2: ((80, 130, 180), (40, 80, 130)), # 蓝色
        3: ((180, 130, 60), (130, 80, 20)), # 金色
    }
    fill_c, outline_c = colors.get(level, colors[1])
    
    # 箱子
    draw.rectangle([4, 10, 76, 70], fill=fill_c, outline=outline_c, width=2)
    draw.line([4, 35, 76, 35], fill=outline_c, width=1)  # 盖子线
    # 锁
    draw.ellipse([33, 25, 47, 40], fill=(60, 50, 40), outline=(30, 20, 10))
    
    img = ink_effect(img)
    return img

def create_escape_point_sprite() -> Image.Image:
    """创建水墨风格撤离点"""
    size = (CELL * SCALE * 2, CELL * SCALE * 2)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = size[0] // 2
    
    # 圆形传送门
    draw.ellipse([8, 8, size[0]-8, size[1]-8], fill=(30, 25, 15), outline=(15, 10, 5), width=3)
    # 内圈
    draw.ellipse([20, 20, size[0]-20, size[1]-20], fill=(50, 40, 30), outline=(25, 15, 5))
    # 墨迹文字 "撤"
    # 简化：用线条表示
    draw.line([c-15, c, c+15, c], fill=(220, 200, 150), width=2)
    draw.line([c, c-15, c, c+15], fill=(220, 200, 150), width=2)
    
    img = ink_effect(img)
    return img

def create_pet_egg_sprite(rarity: str) -> Image.Image:
    """创建水墨风格宠物蛋"""
    size = (CELL * SCALE, CELL * SCALE)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = size[0] // 2
    
    colors = {
        "common": ((180, 175, 165), (100, 95, 85)),
        "rare": ((100, 160, 220), (50, 100, 160)),
        "epic": ((160, 80, 200), (100, 40, 140)),
        "legendary": ((220, 160, 50), (160, 100, 20)),
    }
    fill_c, outline_c = colors.get(rarity, colors["common"])
    
    # 蛋形
    draw.ellipse([8, 5, 72, 75], fill=fill_c, outline=outline_c, width=2)
    # 斑点
    draw.ellipse([20, 20, 35, 32], fill=(fill_c[0]//2, fill_c[1]//2, fill_c[2]//2))
    draw.ellipse([45, 35, 58, 45], fill=(fill_c[0]//2, fill_c[1]//2, fill_c[2]//2))
    draw.ellipse([30, 50, 42, 60], fill=(fill_c[0]//2, fill_c[1]//2, fill_c[2]//2))
    
    img = ink_effect(img)
    return img

def main():
    print("=== 生成水墨风格贴图 ===\n")
    
    # 玩家
    print("生成玩家贴图...")
    player = create_player_sprite()
    player.save(os.path.join(OUT_DIR, "player.png"))
    print(f"  保存: {OUT_DIR}\\player.png")
    
    # 敌人
    for enemy_type in ["velociraptor", "trex", "triceratops"]:
        print(f"生成 {enemy_type} 贴图...")
        enemy = create_enemy_sprite(enemy_type)
        enemy.save(os.path.join(OUT_DIR, f"enemy_{enemy_type}.png"))
        print(f"  保存: {OUT_DIR}\\enemy_{enemy_type}.png")
    
    # 物资箱
    for level in [1, 2, 3]:
        print(f"生成 物资箱Lv{level} 贴图...")
        loot = create_loot_spot_sprite(level)
        loot.save(os.path.join(OUT_DIR, f"loot_level{level}.png"))
        print(f"  保存: {OUT_DIR}\\loot_level{level}.png")
    
    # 撤离点
    print("生成撤离点贴图...")
    escape = create_escape_point_sprite()
    escape.save(os.path.join(OUT_DIR, "escape_point.png"))
    print(f"  保存: {OUT_DIR}\\escape_point.png")
    
    # 宠物蛋
    for rarity in ["common", "rare", "epic", "legendary"]:
        print(f"生成 {rarity} 宠物蛋贴图...")
        egg = create_pet_egg_sprite(rarity)
        egg.save(os.path.join(OUT_DIR, f"pet_egg_{rarity}.png"))
        print(f"  保存: {OUT_DIR}\\pet_egg_{rarity}.png")
    
    print("\n=== 完成 ===")
    print(f"所有贴图保存在: {OUT_DIR}")

if __name__ == "__main__":
    main()
