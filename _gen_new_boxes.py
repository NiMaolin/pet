"""
生成更鲜明的箱子精灵（48x48，RGBA透明背景）
确保与暗色游戏背景形成强烈对比
"""
from PIL import Image, ImageDraw
import os

OUT = r"d:\youxi\soudache\assets\ink"
os.makedirs(OUT, exist_ok=True)

def make_box48(out_path, design_fn):
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    design_fn(draw)
    img.save(out_path)
    px = img.load()
    non_trans = [1 for x in range(48) for y in range(48) if px[x,y][3] > 5]
    print(f"Saved: {out_path}  non-transparent pixels={len(non_trans)}")
    return img

def enemy_box(draw):
    """怪物死亡掉落箱 - 暖棕色木板箱"""
    # 主体：暖棕色木板
    draw.rectangle([6, 12, 41, 41], fill=(148, 92, 52, 255))
    # 木板纹理（水平线）
    draw.line([(6, 20), (41, 20)], fill=(118, 72, 32, 255), width=1)
    draw.line([(6, 28), (41, 28)], fill=(118, 72, 32, 255), width=1)
    draw.line([(6, 36), (41, 36)], fill=(118, 72, 32, 255), width=1)
    # 顶部/底部木条
    draw.rectangle([4, 10, 43, 15], fill=(118, 72, 32, 255))
    draw.rectangle([4, 38, 43, 43], fill=(118, 72, 32, 255))
    # 铁环装饰
    draw.ellipse([9, 17, 14, 22], fill=(90, 90, 100, 255))
    draw.ellipse([33, 17, 38, 22], fill=(90, 90, 100, 255))
    draw.ellipse([22, 30, 27, 35], fill=(70, 70, 80, 255))
    # 血迹斑点
    draw.ellipse([30, 25, 34, 30], fill=(160, 20, 20, 180))
    draw.ellipse([16, 34, 20, 38], fill=(150, 10, 10, 160))
    # 裂缝
    draw.line([(12, 15), (15, 20)], fill=(80, 50, 20, 200), width=1)

def map_box(draw):
    """地图固定物资箱 - 军绿色金属箱"""
    # 主体：军绿色
    draw.rectangle([5, 10, 42, 41], fill=(65, 95, 55, 255))
    # 黄色警示条纹
    draw.rectangle([5, 17, 42, 21], fill=(210, 180, 40, 255))
    draw.rectangle([5, 29, 42, 33], fill=(210, 180, 40, 255))
    # 金属边框
    draw.rectangle([3, 8, 44, 11], fill=(45, 65, 35, 255))
    draw.rectangle([3, 40, 44, 43], fill=(45, 65, 35, 255))
    draw.rectangle([3, 8, 6, 43], fill=(45, 65, 35, 255))
    draw.rectangle([41, 8, 44, 43], fill=(45, 65, 35, 255))
    # 铆钉
    for bx in [9, 19, 29, 38]:
        draw.ellipse([bx-2, 8, bx+2, 12], fill=(100, 120, 90, 255))
        draw.ellipse([bx-2, 39, bx+2, 43], fill=(100, 120, 90, 255))
    # 顶部提手
    draw.rectangle([18, 4, 30, 9], fill=(80, 80, 70, 255))
    # 盖子接缝
    draw.line([(5, 24), (42, 24)], fill=(40, 60, 30, 255), width=1)

make_box48(f"{OUT}/loot_box_enemy.png", enemy_box)
make_box48(f"{OUT}/loot_box_map.png", map_box)
print("Box sprites regenerated!")
