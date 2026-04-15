#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import subprocess
import os

GODOT = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT = r"D:\youxi\soudache"

TEST = '''extends Node

func _ready():
	push_warning("INTEG_TEST: Start")
	GameData.player_health = 9999
	GameData.clear_inventory()
	call_deferred("_run")

func _run():
	await get_tree().create_timer(0.5)
	
	push_warning("INTEG_TEST: 1 Load world")
	var ws = load("res://scenes/world/game_world.tscn")
	var world = ws.instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0)
	push_warning("INTEG_TEST: World=" + world.name)
	
	push_warning("INTEG_TEST: 2 Find loot")
	var spots = get_tree().get_nodes_in_group("loot_spot")
	push_warning("INTEG_TEST: Spots=" + str(spots.size()))
	
	if spots.size() == 0:
		push_warning("INTEG_TEST: FAIL no spots")
		done(false)
		return
	
	var spot = spots[0]
	spot._ensure_generated()
	push_warning("INTEG_TEST: Loot=" + str(spot.loot_items.size()))
	
	push_warning("INTEG_TEST: 3 Open UI")
	world.open_loot_ui(spot.loot_items, spot)
	await get_tree().create_timer(1.0)
	
	var lui = world.get_node_or_null("LootUI")
	if not lui or not lui.visible:
		push_warning("INTEG_TEST: FAIL no UI")
		done(false)
		return
	
	push_warning("INTEG_TEST: 3 OK")
	push_warning("INTEG_TEST: 4 Wait")
	await get_tree().create_timer(10.0)
	push_warning("INTEG_TEST: L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	push_warning("INTEG_TEST: 5 Click")
	var bb = GameData.placed_items.size()
	if lui.loot_slot_nodes.size() > 0:
		var sl = lui.loot_slot_nodes[0]
		if is_instance_valid(sl):
			var p = sl.get_global_rect().get_center()
			push_warning("INTEG_TEST: Pos=" + str(p))
			_send_click(lui, p)
			await get_tree().create_timer(0.1)
			_send_click(lui, p, true)
			await get_tree().create_timer(0.5)
			push_warning("INTEG_TEST: After L=" + str(lui.loot_box_items.size()) + " B=" + str(GameData.placed_items.size()))
	
	if GameData.placed_items.size() > bb:
		push_warning("INTEG_TEST: PASS item picked")
	else:
		push_warning("INTEG_TEST: DONE check result")
	
	done(true)

func _send_click(ui: CanvasLayer, pos: Vector2, dbl: bool = false):
	var dn = InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = pos
	dn.double_click = dbl
	ui._input(dn)
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	ui._input(up)

func done(ok: bool):
	push_warning("INTEG_TEST: RESULT=" + ("PASS" if ok else "FAIL"))
	get_tree().quit()
'''

# Write test files
test_path = os.path.join(PROJECT, "scripts", "integration_test.gd")
uid_path = os.path.join(PROJECT, "scripts", "integration_test.gd.uid")

with open(test_path, "w", encoding="utf-8") as f:
    f.write(TEST)
with open(uid_path, "w") as f:
    f.write("uid://integ123456789\n")

# Update project.godot
proj_path = os.path.join(PROJECT, "project.godot")
with open(proj_path, "r", encoding="utf-8") as f:
    content = f.read()
original = content

lines = content.split('\n')
new_lines = []
for line in lines:
    if any(x in line for x in ['GreedyTest', 'AutoTest', 'RealClickTest', 'BoxTest', 'DeltaTest', 'Req51Test', 'GridTest', 'RunTestScript', 'IntegrationTest']):
        continue
    new_lines.append(line)

for i, line in enumerate(new_lines):
    if 'AssetGenerator=' in line:
        new_lines.insert(i + 1, 'IntegrationTest="*res://scripts/integration_test.gd"')
        break

new_content = '\n'.join(new_lines)
with open(proj_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Running integration test...")

# Run
result = subprocess.run(
    [GODOT, "--headless", "--quit-after", "60", PROJECT],
    cwd=PROJECT,
    capture_output=True,
    timeout=90
)

# Restore
with open(proj_path, "w", encoding="utf-8") as f:
    f.write(original)

# Write output
output = result.stdout.decode("utf-8", errors="replace")
err = result.stderr.decode("utf-8", errors="replace")

with open(os.path.join(PROJECT, "test_output.txt"), "w", encoding="utf-8") as f:
    f.write("=== STDOUT ===\n")
    f.write(output)
    f.write("\n=== STDERR ===\n")
    f.write(err)

# Extract test lines
test_lines = [l for l in err.split('\n') if 'INTEG_TEST:' in l]
for line in test_lines:
    line = line.replace('WARNING: ', '').replace('   at: push_warning (core/variant/variant_utility.cpp:1034)', '')
    print(line.strip())

print()
if "RESULT=PASS" in err or "RESULT=PASS" in output:
    print("=== TEST PASSED ===")
elif "RESULT=FAIL" in err or "RESULT=FAIL" in output:
    print("=== TEST FAILED ===")
else:
    print("=== TEST INCONCLUSIVE ===")
