import subprocess, time, os

GODOT_EXE = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT = r"D:\youxi\soudache"

subprocess.run(["taskkill","/F","/IM","Godot_v4.6.1-stable_win64_console.exe"], capture_output=True)
subprocess.run(["taskkill","/F","/IM","Godot_v4.6.1-stable_win64.exe"], capture_output=True)
time.sleep(1)

print("[1] Starting Godot with VerifyTest autoload...")
proc = subprocess.Popen(
    [GODOT_EXE, "--path", PROJECT],
    cwd=PROJECT,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    creationflags=subprocess.CREATE_NEW_CONSOLE
)

print("[2] Reading Godot console output (30s timeout)...")
output_lines = []
start = time.time()
while time.time() - start < 30:
    try:
        line = proc.stdout.readline()
        if not line:
            break
        text = line.decode("utf-8", errors="replace").strip()
        if text:
            output_lines.append(text)
            print("  " + text)
    except:
        break

proc.terminate()

print("[3] Checking userdata for screenshots...")
userdata = r"C:\Users\86134\AppData\Roaming\Godot\app_userdata\Pet Extraction"
found_files = []
if os.path.exists(userdata):
    for root, dirs, files in os.walk(userdata):
        for f in files:
            if any(k in f.lower() for k in ["verify", "screenshot", "test", ".png"]):
                fp = os.path.join(root, f)
                sz = os.path.getsize(fp)
                print(f"  Found: {f} ({sz} bytes) in {root}")
                found_files.append(fp)
else:
    print(f"  Userdata dir not found: {userdata}")

if found_files:
    print(f"[OK] Screenshot files: {found_files}")
else:
    print("[WARN] No screenshot files found")

print(f"\nTotal output: {len(output_lines)} lines")
for line in output_lines:
    if "ERROR" in line or "WARN" in line or "FAIL" in line:
        print(f"  !!! {line}")
