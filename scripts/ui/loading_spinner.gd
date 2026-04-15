## LoadingSpinner - 旋转加载图标
## 在指定物品槽位上显示一个旋转的加载动画
extends Control

var _rotation: float = 0.0
var _speed: float = 3.0  # 旋转速度（弧度/秒）

func _ready() -> void:
	# 使用自定义绘制
	custom_minimum_size = Vector2(16, 16)

func _process(delta: float) -> void:
	_rotation += _speed * delta
	queue_redraw()

func _draw() -> void:
	# 绘制一个弧形（像加载图标一样）
	var center = Vector2(size.x / 2, size.y / 2)
	var radius = min(size.x, size.y) / 2 - 1

	# 绘制弧形（3/4 圆）
	var arc_color = Color(1, 1, 1, 0.8)
	var start_angle = _rotation
	var end_angle = _rotation + TAU * 0.75

	# 绘制多个点来形成弧形
	for i in range(12):
		var t = float(i) / 12.0
		var angle = lerp(start_angle, end_angle, t)
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		var alpha = 0.3 + 0.7 * t  # 渐变透明度
		draw_circle(point, 2, Color(arc_color.r, arc_color.g, arc_color.b, alpha))
