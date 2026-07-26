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
## 倒计时张力色：开启后随 progress 1→0 由橙渐变为红，并在尾段轻微脉动。
@export var auto_tension: bool = false

const _COLOR_SAFE := Color(1.0, 0.78, 0.25)
const _COLOR_DANGER := Color(0.95, 0.22, 0.22)

var progress: float = 1.0:
	set(v): progress = clamp(v, 0.0, 1.0); queue_redraw()

var _spin: float = 0.0
var _eff_color: Color = _COLOR_SAFE
const _POINTS: int = 64


func _ready() -> void:
	_eff_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_spin += delta * spin_speed
	if auto_tension:
		# progress 越低越红
		_eff_color = _COLOR_DANGER.lerp(_COLOR_SAFE, progress)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var r: float = min(size.x, size.y) * 0.5 - thickness * 0.5
	if r <= 1.0:
		return
	# 尾段脉动（最后 25% 时间轻微胀缩，制造紧迫感）
	var pulse: float = 1.0
	if auto_tension and progress < 0.25:
		pulse = 1.0 + sin(_spin * 8.0) * 0.03
	var draw_color: Color = _eff_color if auto_tension else color
	# 背景满圆
	draw_arc(center, r * pulse, 0.0, TAU, _POINTS, bg_color, thickness, true)
	# 前景弧（锚点顶部，缓慢旋转）
	var start: float = -PI * 0.5 + _spin
	var end: float = start + max(progress, 0.001) * TAU
	draw_arc(center, r * pulse, start, end, _POINTS, draw_color, thickness, true)
