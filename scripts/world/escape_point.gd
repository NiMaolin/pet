## EscapePoint - 撤离点（水墨风格贴图版）
extends Area2D

var is_active: bool = true
var player_inside: bool = false
var progress: float = 0.0
const ESCAPE_TIME: float = 1.0
var visual: Sprite2D = null

func _ready() -> void:
	add_to_group("escape_point")
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

	# 水墨风格撤离点贴图
	visual = Sprite2D.new()
	visual.centered = false
	var tex = load("res://assets/ink/escape_point.png")
	if tex:
		visual.texture = tex
		add_child(visual)
	
	# 碰撞区域
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	add_child(shape)

func _process(delta: float) -> void:
	if not is_active:
		return
	if player_inside:
		progress = min(1.0, progress + delta / ESCAPE_TIME)
		_notify_world(progress)
		if progress >= 1.0:
			_complete_escape()
	else:
		if progress > 0.0:
			progress = max(0.0, progress - delta * 0.8)
			_notify_world(progress)

func _notify_world(p: float) -> void:
	var world = get_tree().current_scene
	if world and world.has_method("show_escape_progress"):
		world.call("show_escape_progress", p)

func _complete_escape() -> void:
	is_active = false
	print("✅ 撤离成功！")
	var world = get_tree().current_scene
	if world and world.has_method("on_escape_success"):
		world.call("on_escape_success")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		print("进入撤离点 — 自动读秒 %.1f 秒..." % ESCAPE_TIME)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		progress = max(0.0, progress - 0.001)
		print("离开撤离点，进度重置")
