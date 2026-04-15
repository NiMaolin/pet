from PIL import Image

img = Image.open(r"D:/youxi/soudache/_test_screenshots/05_loot_ui.png")
px = img.load()
w, h = img.size
print("Size: %dx%d" % (w, h))

cells = []
cs = 40
step = 2
for sy in range(0, h - cs, step):
    for sx in range(0, w - cs, step):
        r_avg, g_avg, b_avg = 0, 0, 0
        cnt = 0
        for dy in range(0, cs, 5):
            for dx in range(0, cs, 5):
                if sx+dx < w and sy+dy < h:
                    r, g, b = px[sx+dx, sy+dy][:3]
                    r_avg += r; g_avg += g; b_avg += b
                    cnt += 1
        r_avg /= cnt; g_avg /= cnt; b_avg /= cnt
        brightness = (r_avg + g_avg + b_avg) / 3
        if 22 < brightness < 50:
            cells.append((sx, sy, r_avg, g_avg, b_avg, brightness))

unique = []
for cx, cy, r, g, b, br in cells:
    is_dup = False
    for ux, uy, *_ in unique:
        if abs(cx-ux) < 25 and abs(cy-uy) < 25:
            is_dup = True
            break
    if not is_dup:
        unique.append((cx, cy, r, g, b, br))

print("Found %d cells" % len(unique))
for i, (cx, cy, r, g, b, br) in enumerate(unique[:8]):
    mid_y = cy + cs // 2
    left_bright = []
    right_bright = []
    for tx in range(cx + 3, cx + cs // 2, 2):
        if tx < w:
            r2, g2, b2 = px[tx, mid_y][:3]
            br2 = (r2 + g2 + b2) / 3
            if br2 > 80: left_bright.append(br2)
    for tx in range(cx + cs // 2, cx + cs - 3, 2):
        if tx < w:
            r2, g2, b2 = px[tx, mid_y][:3]
            br2 = (r2 + g2 + b2) / 3
            if br2 > 80: right_bright.append(br2)
    avg_left = sum(left_bright) / len(left_bright) if left_bright else 0
    avg_right = sum(right_bright) / len(right_bright) if right_bright else 0
    tag = "[OK]" if avg_left > 20 and avg_right > 20 else ("[LEFT]" if avg_left > avg_right * 1.5 else "[RIGHT]")
    print("[%d] pos=(%d,%d) left=%d right=%d -> %s" % (i, cx, cy, avg_left, avg_right, tag))
