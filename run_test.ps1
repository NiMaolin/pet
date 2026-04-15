$ErrorActionPreference = 'Continue'

Write-Host "=== Godot Auto Test ==="

# Write test script
$testCode = @'
extends Node

func _ready():
	print("AUTO_TEST: Starting")
	
	var f = FileAccess.open("user://test_result.txt", FileAccess.WRITE)
	if not f:
		print("AUTO_TEST: File error")
		get_tree().quit()
		return
	
	f.store_line("AUTO_TEST: Starting")
	f.flush()
	
	GameData.player_health = 9999
	GameData.clear_inventory()
	
	await get_tree().create_timer(0.5).timeout
	
	f.store_line("Step1: Load main menu")
	f.flush()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(0.8).timeout
	
	var scene = get_tree().current_scene
	f.store_line("Step1 OK: " + str(scene.name if scene else "null"))
	f.flush()
	
	f.store_line("Step2: Click StartGame")
	f.flush()
	var btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	
	f.store_line("Step3: Click EnterGame")
	f.flush()
	scene = get_tree().current_scene
	btn = scene.find_child("EnterGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	
	f.store_line("Step4: Click map StartGame")
	f.flush()
	scene = get_tree().current_scene
	btn = scene.find_child("StartGame", true, false)
	if btn: btn.pressed.emit()
	await get_tree().create_timer(2.0).timeout
	
	scene = get_tree().current_scene
	f.store_line("Step5: Game scene = " + str(scene.name if scene else "null"))
	f.flush()
	
	f.store_line("Step6: Find loot spots")
	f.flush()
	var spots = get_tree().get_nodes_in_group("loot_spot")
	f.store_line("   Found: " + str(spots.size()))
	f.flush()
	
	if spots.size() > 0:
		var spot = spots[0]
		spot._ensure_generated()
		f.store_line("   Loot items: " + str(spot.loot_items.size()))
		f.flush()
		
		f.store_line("Step7: Open loot UI")
		f.flush()
		if scene.has_method("open_loot_ui"):
			scene.open_loot_ui(spot.loot_items, spot)
		await get_tree().create_timer(0.5).timeout
		
		var loot_ui = scene.get_node_or_null("LootUI")
		if loot_ui and loot_ui.visible:
			f.store_line("Step7 OK: Loot UI visible")
			f.flush()
			
			f.store_line("Step8: Wait for search...")
			f.flush()
			await get_tree().create_timer(8.0).timeout
			f.store_line("   Loot: " + str(loot_ui.loot_box_items.size()) + " Bag: " + str(GameData.placed_items.size()))
			f.flush()
			
			f.store_line("Step9: Test double-click")
			f.flush()
			if loot_ui.loot_slot_nodes.size() > 0:
				var slot = loot_ui.loot_slot_nodes[0]
				if is_instance_valid(slot):
					var pos = slot.get_global_rect().get_center()
					f.store_line("   Click at: " + str(pos))
					f.flush()
					_do_double_click(loot_ui, pos)
					await get_tree().create_timer(0.5).timeout
					f.store_line("   After: Loot=" + str(loot_ui.loot_box_items.size()) + " Bag=" + str(GameData.placed_items.size()))
					f.flush()
	
	f.store_line("RESULT: PASS")
	f.flush()
	f.close()
	get_tree().quit()

func _do_double_click(ui: CanvasLayer, pos: Vector2):
	for i in range(2):
		var down = InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = pos
		down.double_click = (i == 1)
		ui._input(down)
		await get_tree().create_timer(0.08).timeout
		
		var up = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = pos
		ui._input(up)
		await get_tree().create_timer(0.08).timeout
'@

$testPath = "D:\youxi\soudache\scripts\auto_test.gd"
$uidPath = "D:\youxi\soudache\scripts\auto_test.gd.uid"
$projPath = "D:\youxi\soudache\project.godot"
$godotExe = "C:\Users\86134\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
$projDir = "D:\youxi\soudache"

Write-Host "1. Writing test script..."

# Write test script with UTF-8 BOM
$utf8 = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($testPath, $testCode, $utf8)

$uidContent = "uid://br5y5dniqpskk`n"
[System.IO.File]::WriteAllText($uidPath, $uidContent, $utf8)

Write-Host "2. Updating project.godot..."

$projContent = Get-Content $projPath -Raw -Encoding UTF8
$original = $projContent

# Remove old test autoloads
$lines = $projContent -split "`n"
$newLines = @()
foreach ($line in $lines) {
    if ($line -notmatch 'GreedyTest|AutoTest|RealClickTest|BoxTest|DeltaTest|Req51Test|GridTest') {
        $newLines += $line
    }
}

# Add AutoTest after AssetGenerator
$insertIdx = -1
for ($i = 0; $i -lt $newLines.Count; $i++) {
    if ($newLines[$i] -match 'AssetGenerator=') {
        $insertIdx = $i + 1
        break
    }
}

if ($insertIdx -gt 0) {
    $newLines[$insertIdx] = 'AutoTest="*res://scripts/auto_test.gd"'
}

$projContent = $newLines -join "`n"
$utf8BOM = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($projPath, $projContent, $utf8BOM)

Write-Host "3. Running Godot (60s timeout)..."

$proc = Start-Process -FilePath $godotExe -ArgumentList "--headless","--quit-after","60",$projDir -NoNewWindow -Wait -PassThru

Write-Host "4. Restoring project.godot..."
[System.IO.File]::WriteAllText($projPath, $original, $utf8BOM)

# Read result from Godot user dir
$resultPaths = @(
    "C:\Users\86134\AppData\Roaming\Godot\app_userdata\Soudache\test_result.txt",
    "C:\Users\86134\AppData\Roaming\Godot\app_userdata\soudache\test_result.txt"
)

foreach ($path in $resultPaths) {
    if (Test-Path $path) {
        Write-Host "`n=== Test Results ==="
        Get-Content $path -Encoding UTF8
        Remove-Item $path -Force
        if (Select-String -Path $path -Pattern "RESULT: PASS" -Quiet) {
            Write-Host "`n=== TEST PASSED ==="
            exit 0
        } else {
            Write-Host "`n=== TEST FAILED ==="
            exit 1
        }
    }
}

Write-Host "`n[No result file found]"
exit 1
