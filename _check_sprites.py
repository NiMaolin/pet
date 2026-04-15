from PIL import Image
for fname in ["assets/sprites2/player_sheet.png",
              "assets/sprites2/enemy_velociraptor_sheet.png",
              "assets/sprites2/enemy_trex_sheet.png",
              "assets/sprites2/enemy_triceratops_sheet.png"]:
    img = Image.open(fname).convert("RGBA")
    px = img.load()
    w, h = img.size
    non_trans = [(px[x,y][0], px[x,y][1], px[x,y][2])
                 for x in range(w) for y in range(h) if px[x,y][3] > 10]
    if non_trans:
        avg = tuple(sum(c[i] for c in non_trans)//len(non_trans) for i in range(3))
        print(f"{fname.split('/')[-1]:40s} {len(non_trans):5d} px  avg={avg}")
    else:
        print(f"{fname.split('/')[-1]:40s} ALL TRANSPARENT!")
