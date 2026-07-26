extends Control
class_name SurgeryPack
## 闭合的手术包卡牌。点击 → 播放开包动画 → 发 opened 信号。
## main.gd 监听后从包的位置生成 6 张器械卡。

signal opened(pack)

var _opened: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	size = Vector2(140, 140)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	for c in get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if _opened:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_opened = true
		opened.emit(self)
		_play_open_anim()
		accept_event()


func _play_open_anim() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	tw.finished.connect(func() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
