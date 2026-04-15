import os, glob

base = r"C:\Users\86134\AppData\Roaming\Godot\app_userdata\soudache"
log_dir = os.path.join(base, "logs")
print("Log dir:", log_dir)
if os.path.exists(log_dir):
    files = glob.glob(os.path.join(log_dir, "*"))
    for f in sorted(files, key=os.path.getmtime, reverse=True)[:3]:
        print("File:", f)
        with open(f, "rb") as fp:
            content = fp.read().decode("utf-8", errors="replace")
        lines = content.strip().split("\n")
        print("Total lines:", len(lines))
        # Print last 50 lines
        for line in lines[-50:]:
            print(line.encode('utf-8', errors='replace').decode('utf-8', errors='replace'))
else:
    print("No log dir found, checking user:// path")
    # Godot user:// resolves to app_userdata
    alt = r"C:\Users\86134\AppData\Roaming\Godot\app_userdata"
    print("Contents:", os.listdir(alt) if os.path.exists(alt) else "not found")
