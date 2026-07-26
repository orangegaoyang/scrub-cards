extends Control
class_name DoctorPanel
## 右侧医生面板：滑入/滑出、需求展示、进度环、递送区。
## 倒计时(橙)→ 递送正确 → 操作(绿填充) → operate_complete 信号 → main 吐牌。

signal countdown_expired()
signal operate_complete(card: Card)

const PANEL_W: float = 260.0
const COUNTDOWN_DURATION: float = 6.0
const OPERATE_DURATION: float = 2.0

@onready var _ring: ProgressRing = $ProgressRing
@onready var _demand_icon: ColorRect = $DemandIcon
@onready var _demand_name: Label = $DemandName
@onready var _status: Label = $StatusLabel

## 需求激活期间为 true，允许 main 判定递送。
var deliverable: bool = false
var current_demand_id: String = ""

var _ring_tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_W, 720)
	size = Vector2(PANEL_W, 720)
	position = Vector2(1280, 0)  # 屏幕右外
	_demand_icon.pivot_offset = _demand_icon.size * 0.5
	clear_demand()


func slide_in() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:x", 1280.0 - PANEL_W, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


func slide_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:x", 1280.0, 0.4)


func clear_demand() -> void:
	_kill_ring_tween()
	deliverable = false
	_ring.auto_tension = false
	_ring.progress = 0.0
	_ring.visible = false
	_demand_icon.visible = false
	_demand_icon.scale = Vector2.ZERO
	_demand_name.visible = false
	_status.text = ""


func show_demand(def) -> void:
	current_demand_id = def.id
	_demand_icon.color = def.color
	_demand_icon.scale = Vector2.ZERO
	_demand_icon.visible = true
	_demand_name.text = def.name_cn
	_demand_name.visible = true
	_ring.visible = true
	_ring.color = Color(1.0, 0.78, 0.25)
	_ring.auto_tension = true   # 倒计时随时间变红 + 尾段脉动
	_ring.progress = 1.0
	_status.text = "Halberg 需要：%s" % def.name_cn
	deliverable = true
	# 需求图标弹入
	var pop := create_tween()
	pop.tween_property(_demand_icon, "scale", Vector2(1.18, 1.18), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_demand_icon, "scale", Vector2.ONE, 0.10)
	AudioManager.play("demand", -4.0)
	_tween_ring(0.0, COUNTDOWN_DURATION, _on_countdown_done)


func _on_countdown_done() -> void:
	if not deliverable:
		return
	deliverable = false
	countdown_expired.emit()


## 尝试接收卡牌。返回 true=正确接收，false=不接受（未激活/错的器械）。
func receive_card(card: Card) -> bool:
	if not deliverable or card.def.id != current_demand_id:
		return false
	deliverable = false
	_kill_ring_tween()
	return true


func start_operating(card: Card) -> void:
	_status.text = "Halberg 操作中…"
	# 卡牌吸附在圆环中心，圆环本身转绿色填充当操作进度（大而明显）
	_demand_icon.visible = false
	_ring.visible = true
	_ring.auto_tension = false
	_ring.color = Color(0.4, 0.95, 0.5)
	_kill_ring_tween()
	_ring_tween = create_tween()
	_ring_tween.tween_property(_ring, "progress", 1.0, OPERATE_DURATION) \
		.set_ease(Tween.EASE_OUT)
	_ring_tween.finished.connect(_on_operate_done.bind(card))


func _on_operate_done(card: Card) -> void:
	operate_complete.emit(card)


## 落点判定矩形 = 圆环本身（卡牌要拖到环里）。
func get_drop_rect() -> Rect2:
	return Rect2(_ring.global_position, _ring.size)


## 卡牌吸附目标 = 圆环中心。
func get_drop_anchor_global_pos() -> Vector2:
	return _ring.global_position + _ring.size * 0.5 - Card.CARD_SIZE * 0.5


func _tween_ring(target: float, duration: float, on_done: Callable) -> void:
	_kill_ring_tween()
	_ring_tween = create_tween()
	_ring_tween.tween_property(_ring, "progress", target, duration)
	if on_done.is_valid():
		_ring_tween.finished.connect(on_done)


func _kill_ring_tween() -> void:
	if _ring_tween != null:
		_ring_tween.kill()
		_ring_tween = null
