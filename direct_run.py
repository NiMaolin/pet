#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import subprocess
import os
import time

GODOT = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT = r"D:\youxi\soudache"
TEST_SCRIPT = os.path.join(PROJECT, "scripts", "direct_test.gd")
TEST_UID = os.path.join(PROJECT, "scripts", "direct_test.gd.uid")
OUTPUT = os.path.join(PROJECT, "test_output.txt")

# Update UID file
with open(TEST_UID, "w") as f:
    f.write("uid://direct123456789\n")

print("=== Godot Direct Script Test ===")
print("1. Running test script directly...")

# Run with --script parameter
try:
    proc = subprocess.Popen(
        [GODOT, "--headless", "--quit-after", "60", "--script", TEST_SCRIPT, PROJECT],
        cwd=PROJECT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = proc.communicate(timeout=90)
except:
    print("Error running Godot")
    exit(1)

output = stdout.decode("utf-8", errors="replace")
err = stderr.decode("utf-8", errors="replace")

# Write output
with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write("=== STDOUT ===\n")
    f.write(output)
    f.write("\n=== STDERR ===\n")
    f.write(err)

print("2. Output written to test_output.txt")
print()

# Extract warnings
warnings = [l for l in err.split('\n') if 'WARNING' in l and 'TEST:' in l]
for w in warnings:
    # Clean up
    w = w.replace('WARNING: ', '').replace('   at: push_warning (core/variant/variant_utility.cpp:1034)', '')
    print(w.strip())

print()
if "PASS" in err and "RESULT" in err:
    print("=== TEST PASSED ===")
elif "FAIL" in err:
    print("=== TEST FAILED ===")
else:
    print("=== TEST INCONCLUSIVE ===")
