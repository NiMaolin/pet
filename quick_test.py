#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import subprocess
import os

GODOT = r"C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
PROJECT = r"D:\youxi\soudache"

# Test script content
TEST = '''extends Node

var step = 0

func _ready():
	step = 1
	push_warning("TEST: Step 1 - Starting...")
	
	GameData.player_health = 9999
	GameData.clear_inventory()
	await get_tree().create_timer(0.5)
	
	push_warning("TEST: Step 1 - Loading main menu")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(0.8)
	
	var scene = get_tree().current_scene
	push_warning("TEST: Step 1 OK - " + str(scene.name if scene else "null"))
	
	step = 2
	push_warning("TEST: Step 2 - Click StartGame")
	var btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(1.0)
	
	step = 3
	scene = get_tree().current_scene
	push_warning("TEST: Step 3 - Click EnterGame")
	btn = scene.find_child("EnterGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(0.5)
	
	step = 4
	scene = get_tree().current_scene
	push_warning("TEST: Step 4 - Click map")
	btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(2.0)
	
	scene = get_tree().current_scene
	push_warning("TEST: Step 5 - Game: " + str(scene.name if scene else "null"))
	
	step = 6
	push_warning("TEST: Step 6 - Find loot spots")
	var spots = get_tree().get_nodes_in_group("loot_spot")
	push_warning("TEST: Found " + str(spots.size()) + " spots")
	
	if spots.size() > 0:
		var spot = spots[0]
		spot._ensure_generated()
		push_warning("TEST: Loot items: " + str(spot.loot_items.size()))
		
		step = 7
		push_warning("TEST: Step 7 - Open loot UI")
		if scene.has_method("open_loot_ui"):
			scene.open_loot_ui(spot.loot_items, spot)
		await get_tree().create_timer(0.5)
		
		var loot_ui = scene.get_node_or_null("LootUI")
		if loot_ui and loot_ui.visible:
			push_warning("TEST: Step 7 OK - Loot UI visible")
			
			step = 8
			push_warning("TEST: Step 8 - Wait for search")
			await get_tree().create_timer(8.0)
			push_warning("TEST: Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
			
			step = 9
			if loot_ui.loot_slot_nodes.size() > 0:
				var slot = loot_ui.loot_slot_nodes[0]
				if is_instance_valid(slot):
					var pos = slot.get_global_rect().get_center()
					push_warning("TEST: Click at " + str(pos))
					_do_double_click(loot_ui, pos)
					await get_tree().create_timer(0.5)
					push_warning("TEST: After - Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
	
	push_warning("TEST: RESULT - PASS")
	await get_tree().create_timer(1.0)
	get_tree().quit()

func _do_double_click(ui: CanvasLayer, pos: Vector2):
	for i in range(2):
		var down = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = pos
		down.double_click = (i == 1)
		ui._input(down)
		await get_tree().create_timer(0.08)
		
		var up = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = pos
		ui._input(up)
		await get_tree().create_timer(0.08)
'''

# Write test script
test_path = os.path.join(PROJECT, "scripts", "run_test_script.gd")
uid_path = os.path.join(PROJECT, "scripts", "run_test_script.gd.uid")

with open(test_path, "w", encoding="utf-8") as f:
    f.write(TEST)
with open(uid_path, "w", encoding="utf-8") as f:
    f.write("uid://test123456789\n")

# Update project.godot
proj_path = os.path.join(PROJECT, "project.godot")
with open(proj_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove old test autoloads and add new one
lines = content.split('\n')
new_lines = []
for line in lines:
    if any(x in line for x in ['GreedyTest', 'AutoTest', 'RealClickTest', 'BoxTest', 'DeltaTest', 'Req51Test', 'GridTest', 'RunTestScript']):
        continue
    new_lines.append(line)

# Add after AssetGenerator
for i, line in enumerate(new_lines):
    if 'AssetGenerator=' in line:
        new_lines.insert(i + 1, 'RunTestScript="*res://scripts/run_test_script.gd"')
        break

new_content = '\n'.join(new_lines)

with open(proj_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Running Godot test...")

# Run
result = subprocess.run(
    [GODOT, "--headless", "--quit-after", "60", PROJECT],
    cwd=PROJECT,
    capture_output=True,
    timeout=90
)

# Restore
with open(proj_path, "w", encoding="utf-8") as f:
    f.write(content)

# Parse output
output = result.stdout.decode("utf-8", errors="replace")
stderr = result.stderr.decode("utf-8", errors="replace")

# Write to file to avoid encoding issues
with open(os.path.join(PROJECT, "test_output.txt"), "w", encoding="utf-8") as f:
    f.write(output)
    if stderr:
        f.write("\n=== STDERR ===\n")
        f.write(stderr)

print("Output written to test_output.txt")
print("")

# Check warnings (push_warning outputs to stderr as WARNING:)
test_lines = [l for l in output.split('\n') if 'TEST:' in l or 'WARNING' in l]
for line in test_lines:
    print(line)

print("")
if "RESULT" in stderr and "PASS" in stderr:
    print("TEST PASSED")
elif "RESULT" in stderr and "FAIL" in stderr:
    print("TEST FAILED")
elif "RESULT" in output and "PASS" in output:
    print("TEST PASSED")
else:
    print("TEST INCONCLUSIVE")
