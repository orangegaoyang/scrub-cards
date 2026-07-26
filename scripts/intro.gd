extends Control
## 标题/开场画面：交代玩家身份（实习 scrub nurse）+ 利害关系，点"开始值班"进游戏。

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var _title: Label = $TitleLabel
@onready var _subtitle: Label = $SubtitleLabel
@onready var _dialog: Panel = $DialogPanel
@onready var _start: Button = $StartButton


func _ready() -> void:
	_title.modulate.a = 0.0
	_title.scale = Vector2(0.92, 0.92)
	_title.pivot_offset = _title.size * 0.5
	_subtitle.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	_dialog.position.y += 20.0
	_start.modulate.a = 0.0
	_start.disabled = true
	_start.pressed.connect(_on_start_pressed)
	# 分拍淡入
	var tw_t := create_tween()
	tw_t.tween_property(_title, "modulate:a", 1.0, 0.5)
	tw_t.parallel().tween_property(_title, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.25).timeout
	var tw_s := create_tween()
	tw_s.tween_property(_subtitle, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(0.2).timeout
	var tw_d := create_tween()
	tw_d.tween_property(_dialog, "modulate:a", 1.0, 0.4)
	tw_d.parallel().tween_property(_dialog, "position:y", _dialog.position.y - 20.0, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.45).timeout
	_start.disabled = false
	var tw_b := create_tween()
	tw_b.tween_property(_start, "modulate:a", 1.0, 0.3)


func _on_start_pressed() -> void:
	_start.disabled = true
	AudioManager.play("pick", -2.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))
