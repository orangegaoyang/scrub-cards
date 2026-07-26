extends Control
class_name ProgressRing
## 自绘进度环：背景满圆 + 前景弧。
## - progress: 0..1，前景弧占比（倒计时从 1→0 消减；操作从 0→1 填充）
## - color: 前景弧颜色（倒计时橙黄；操作变绿）
## - 整弧锚点随 _spin 缓慢旋转，保留"在转"的活力感

@export var color: Color = Color(1.0, 0.78, 0.25):
	set(v): color = v; queue_redraw()
@export var bg_color: Color = Color(1, 1, 1, 0.12)
@export var thickness: float = 12.0
@export var spin_speed: float = 1.4  # 弧度/秒

var progress: float = 1.0:
	set(v): progress = clamp(v, 0.0, 1.0); queue_redraw()

var _spin: float = 0.0
const _POINTS: int = 64


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_spin += delta * spin_speed
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var r: float = min(size.x, size.y) * 0.5 - thickness * 0.5
	if r <= 1.0:
		return
	# 背景满圆
	draw_arc(center, r, 0.0, TAU, _POINTS, bg_color, thickness, true)
	# 前景弧（锚点顶部，缓慢旋转）
	var start: float = -PI * 0.5 + _spin
	var end: float = start + max(progress, 0.001) * TAU
	draw_arc(center, r, start, end, _POINTS, color, thickness, true)
